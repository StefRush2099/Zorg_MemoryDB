#!/usr/bin/env python3
import argparse, json, re, uuid
from pathlib import Path
import psycopg2
from psycopg2.extras import RealDictCursor

BASE = Path(os.environ.get('OPENCLAW_WORKSPACE', '/home/openclaw/.openclaw/workspace'))
SKILL_ROOT = Path(__file__).resolve().parents[1]
CFG = json.loads((SKILL_ROOT / 'config' / 'sql_memory_map.json').read_text())


def conn():
    p = CFG['postgres']
    return psycopg2.connect(host=p['host'], port=p['port'], dbname=p['database'], user=p['user'], password=p['password'])


def normalize(text:str)->str:
    return re.sub(r'\s+', ' ', text.strip().lower())


def score_categories(text:str, categories):
    t = normalize(text)
    results = []
    for c in categories:
        score = 0
        hits = []
        key = c['category_key']
        if key in t:
            score += 3; hits.append(key)
        for alias in (c['aliases'] or []):
            a = alias.lower()
            if a in t:
                score += 2; hits.append(alias)
        for token in key.split('_'):
            if len(token) > 2 and token in t:
                score += 1
        if score > 0:
            results.append({
                'category_key': c['category_key'],
                'name': c['name'],
                'description': c['description'],
                'confidence': score,
                'reason': ', '.join(hits[:6])
            })
    results.sort(key=lambda x: (-x['confidence'], x['category_key']))
    return results[:5]


def record_request(text:str, session_hint:str|None, matched):
    req_id = str(uuid.uuid4())
    with conn() as db:
        with db.cursor() as cur:
            cur.execute(
                "INSERT INTO memory_request_intake (id, request_text, normalized_text, session_hint) VALUES (%s,%s,%s,%s)",
                (req_id, text, normalize(text), session_hint),
            )
            for m in matched:
                cur.execute(
                    "INSERT INTO memory_request_category_map (id, request_id, category_key, confidence, reason) VALUES (%s,%s,%s,%s,%s)",
                    (str(uuid.uuid4()), req_id, m['category_key'], m['confidence'], m['reason']),
                )
    return req_id


def main():
    ap = argparse.ArgumentParser(description='Categorize an incoming request into SQL-backed categories')
    ap.add_argument('text')
    ap.add_argument('--session-hint')
    ap.add_argument('--record', action='store_true')
    args = ap.parse_args()
    with conn() as db:
        with db.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT category_key,name,description,aliases FROM memory_categories WHERE active=true ORDER BY category_key")
            categories = cur.fetchall()
    matched = score_categories(args.text, categories)
    req_id = record_request(args.text, args.session_hint, matched) if args.record else None
    print(json.dumps({'request_id': req_id, 'categories': matched}, indent=2, default=str))

if __name__ == '__main__':
    main()
