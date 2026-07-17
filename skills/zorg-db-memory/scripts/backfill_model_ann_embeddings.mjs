import { createRequire } from 'node:module';
import { readFile, appendFile, readdir } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

async function loadLocalEmbeddingProvider() {
  const dist = '/home/openclaw/.npm-global/lib/node_modules/openclaw/dist';
  const candidates = (await readdir(dist))
    .filter((name) => /^embeddings-[^/]+\.js$/.test(name))
    .sort();
  for (const name of candidates) {
    try {
      const mod = await import(pathToFileURL(`${dist}/${name}`).href);
      if (typeof mod.n === 'function') return mod.n;
    } catch {}
  }
  throw new Error('OpenClaw local embeddings provider bundle not found');
}

const require = createRequire('/home/openclaw/.openclaw/workspace/lan-chat/package.json');
const { Client } = require('pg');

const WORKSPACE = '/home/openclaw/.openclaw/workspace';
const SKILL_ROOT = new URL('..', import.meta.url).pathname;
const CONFIG_PATH = `${SKILL_ROOT}/config/sql_memory_map.json`;
const LOG_PATH = `${WORKSPACE}/tmp/model_ann_backfill.log`;

const limit = Number.parseInt(process.env.MODEL_ANN_LIMIT || '256', 10);
const batchSize = Number.parseInt(process.env.MODEL_ANN_BATCH || '8', 10);
const textLimit = Number.parseInt(process.env.MODEL_ANN_TEXT_LIMIT || '400', 10);
const occurrenceOnly = process.env.MODEL_ANN_OCCURRENCES_ONLY === '1';
const modelName = 'embeddinggemma-300m-qat-q8_0';
const providerName = 'local';

async function log(line) {
  const stamped = `${new Date().toISOString()} ${line}\n`;
  process.stdout.write(stamped);
  await appendFile(LOG_PATH, stamped);
}

function vectorLiteral(vec) {
  return `[${vec.map((v) => (Number.isFinite(v) ? Number(v).toPrecision(9) : '0')).join(',')}]`;
}

function sourceType(sourceTable) {
  return {
    directive: 'directive',
    runbook: 'runbook',
    project: 'project',
    project_fact: 'project_fact',
    host: 'host',
    service: 'service',
    relationship: 'relationship',
    recall_hint: 'recall_hint',
    query_observation: 'query_observation',
    operational_fact: 'operational_fact',
    contact: 'contact',
    logic_rule: 'logic_rule',
    memory_event_occurrence: 'memory_event_occurrence',
  }[sourceTable] || 'memory';
}

async function main() {
  const cfg = JSON.parse(await readFile(CONFIG_PATH, 'utf8')).postgres;
  const client = new Client({
    host: cfg.host,
    port: cfg.port,
    database: cfg.database,
    user: cfg.user,
    password: cfg.password,
  });
  await client.connect();

  const createLocalEmbeddingProviderInProcess = await loadLocalEmbeddingProvider();
  const provider = await createLocalEmbeddingProviderInProcess({
    model: modelName,
    local: { contextSize: 512 },
  });

  try {
    await log(`start model=${modelName} limit=${limit} batch=${batchSize} text_limit=${textLimit}`);
    const selected = await client.query(
      `
      with src as (
        select
          source_table,
          source_id,
          coalesce(priority, 'medium') as priority,
          event_ts,
          left(coalesce(content, ''), 4000) as content_text
        from public.zorg_memory_search_mv
        where coalesce(content, '') <> ''
          and not (
            length(btrim(content)) <= 80
          and btrim(content) ~ '^"?[0-9a-f]{8,64}"?,?$'
          )
        union all
        select
          'memory_event_occurrence' as source_table,
          o.id::text as source_id,
          'high' as priority,
          o.occurred_at as event_ts,
          left(coalesce(b.content_text, b.content_json::text, ''), 4000) as content_text
        from public.memory_event_occurrences o
        join public.memory_content_blobs b on b.id=o.payload_blob_id
        where coalesce(b.content_text, b.content_json::text, '') <> ''
      )
      select src.*
      from src
      left join public.memory_ann_model_embeddings m
        on m.source_type = case src.source_table
          when 'directive' then 'directive'
          when 'runbook' then 'runbook'
          when 'project' then 'project'
          when 'project_fact' then 'project_fact'
          when 'host' then 'host'
          when 'service' then 'service'
          when 'relationship' then 'relationship'
          when 'recall_hint' then 'recall_hint'
          when 'query_observation' then 'query_observation'
          when 'operational_fact' then 'operational_fact'
          when 'contact' then 'contact'
          when 'logic_rule' then 'logic_rule'
          when 'memory_event_occurrence' then 'memory_event_occurrence'
          else 'memory'
        end
       and m.source_key = src.source_id
       and m.content_hash = md5(src.content_text)
       and m.embedding_provider = $1
       and m.embedding_model = $2
       and m.active
      where m.id is null
        and ($4::boolean = false or src.source_table = 'memory_event_occurrence')
      order by
        case src.source_table
          when 'logic_rule' then 1
          when 'recall_hint' then 2
          when 'query_observation' then 3
          when 'memory_event_occurrence' then 4
          when 'memory' then 4
          else 5
        end,
        case lower(coalesce(src.priority, ''))
          when 'critical' then 1
          when 'high' then 2
          when 'medium' then 3
          else 4
        end,
        src.event_ts desc nulls last
      limit $3
      `,
      [providerName, modelName, limit, occurrenceOnly],
    );

    await log(`selected=${selected.rowCount}`);
    let done = 0;
    for (let offset = 0; offset < selected.rows.length; offset += batchSize) {
      const batch = selected.rows.slice(offset, offset + batchSize);
      const texts = batch.map((row) => row.content_text.slice(0, textLimit));
      const started = Date.now();
      const vectors = await provider.embedBatch(texts);

      await client.query('begin');
      try {
        for (let i = 0; i < batch.length; i += 1) {
          const row = batch[i];
          const vec = vectors[i] || [];
          if (!vec.length) continue;
          await client.query(
            `
            insert into public.memory_ann_model_embeddings
              (source_type, source_key, embedding_provider, embedding_model,
               embedding_dim, embedding, content_hash, content_text, priority,
               event_ts, metadata, active, created_at, updated_at)
            values
              ($1, $2, $3, $4, $5, $6::vector, md5($7), $7, $8, $9,
               jsonb_build_object('backfill_job', 'model_ann_backfill_direct_search_mv',
                                  'source', 'zorg_memory_search_mv',
                                  'context_size', 512),
               true, now(), now())
            on conflict (source_type, source_key, embedding_provider, embedding_model, content_hash)
            do update set
              embedding_dim = excluded.embedding_dim,
              embedding = excluded.embedding,
              content_text = excluded.content_text,
              priority = excluded.priority,
              event_ts = excluded.event_ts,
              metadata = public.memory_ann_model_embeddings.metadata || excluded.metadata,
              active = true,
              updated_at = now()
            `,
            [
              sourceType(row.source_table),
              row.source_id,
              providerName,
              modelName,
              vec.length,
              vectorLiteral(vec),
              row.content_text,
              row.priority,
              row.event_ts,
            ],
          );
        }
        await client.query('commit');
      } catch (err) {
        await client.query('rollback');
        throw err;
      }
      done += batch.length;
      await log(`batch_done=${done}/${selected.rowCount} batch_ms=${Date.now() - started}`);
    }

    await client.query('analyze public.memory_ann_model_embeddings');
    await log(`complete inserted_or_updated=${done}`);
  } finally {
    await provider.close?.().catch(() => {});
    await client.end().catch(() => {});
  }
}

main().catch(async (err) => {
  await log(`error ${err.stack || err.message || String(err)}`).catch(() => {});
  process.exitCode = 1;
});
