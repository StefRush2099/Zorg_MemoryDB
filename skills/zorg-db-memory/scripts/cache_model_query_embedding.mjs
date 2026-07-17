import { createRequire } from 'node:module';
import { readFile, readdir } from 'node:fs/promises';
import { stdin } from 'node:process';
import { pathToFileURL } from 'node:url';

// OpenClaw bundle filenames are content-hashed and change on upgrades. Find
// the installed embeddings module instead of pinning yesterday's hash.
async function loadLocalEmbeddingProvider() {
  const dist = '/home/openclaw/.npm-global/lib/node_modules/openclaw/dist';
  const candidates = (await readdir(dist))
    .filter((name) => /^embeddings-[^/]+\.js$/.test(name))
    .sort();
  for (const name of candidates) {
    try {
      const mod = await import(pathToFileURL(`${dist}/${name}`).href);
      if (typeof mod.n === 'function') return mod.n;
    } catch {
      // Some bundles are helpers; continue until the provider bundle is found.
    }
  }
  throw new Error('OpenClaw local embeddings provider bundle not found');
}

const require = createRequire('/home/openclaw/.openclaw/workspace/lan-chat/package.json');
const { Client } = require('pg');

const WORKSPACE = '/home/openclaw/.openclaw/workspace';
const SKILL_ROOT = new URL('..', import.meta.url).pathname;
const CONFIG_PATH = `${SKILL_ROOT}/config/sql_memory_map.json`;
const PROVIDER = 'local';
const MODEL = 'embeddinggemma-300m-qat-q8_0';
const TEXT_LIMIT = Number.parseInt(process.env.MODEL_ANN_QUERY_TEXT_LIMIT || '1000', 10);

function vectorLiteral(vec) {
  return `[${vec.map((v) => (Number.isFinite(v) ? Number(v).toPrecision(9) : '0')).join(',')}]`;
}

async function readStdin() {
  let text = '';
  for await (const chunk of stdin) {
    text += chunk;
  }
  return text;
}

async function main() {
  const query = (await readStdin()).trim();
  if (!query) return;

  const cfg = JSON.parse(await readFile(CONFIG_PATH, 'utf8')).postgres;
  const client = new Client({
    host: cfg.host,
    port: cfg.port,
    database: cfg.database,
    user: cfg.user,
    password: cfg.password,
  });

  await client.connect();
  try {
    const existing = await client.query(
      `
      select id
      from public.memory_query_embedding_cache
      where active
        and query_hash = md5(lower(btrim($1)))
        and embedding_provider = $2
        and embedding_model = $3
      limit 1
      `,
      [query, PROVIDER, MODEL],
    );
    if (existing.rowCount > 0) return;

    const createLocalEmbeddingProviderInProcess = await loadLocalEmbeddingProvider();
    const provider = await createLocalEmbeddingProviderInProcess({
      model: MODEL,
      local: { contextSize: 512 },
    });
    try {
      const vector = await provider.embedQuery(query.slice(0, TEXT_LIMIT));
      if (!vector?.length) throw new Error('local embedding provider returned an empty vector');
      await client.query(
        'select public.memory_cache_query_embedding($1, $2::vector, $3, $4, $5::jsonb)',
        [
          query,
          vectorLiteral(vector),
          PROVIDER,
          MODEL,
          JSON.stringify({ source: 'memory_recall_router', text_limit: TEXT_LIMIT }),
        ],
      );
    } finally {
      await provider.close?.().catch(() => {});
    }
  } finally {
    await client.end().catch(() => {});
  }
}

main().catch((err) => {
  process.stderr.write(`${err.stack || err.message || String(err)}\n`);
  process.exitCode = 1;
});
