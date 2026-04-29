#!/usr/bin/env python3
import argparse, json, os, subprocess, sys
from pathlib import Path
BASE = Path(os.environ.get("OPENCLAW_WORKSPACE", Path.cwd()))
TOOL = Path(os.environ.get("MEMORY_SQL_TOOL", BASE / "scripts" / "memory_sql_tool.py"))
def main():
    ap=argparse.ArgumentParser(description="DB-first structured recall router")
    ap.add_argument('query'); ap.add_argument('--limit', type=int, default=10)
    args=ap.parse_args()
    try:
        out=subprocess.check_output([sys.executable, str(TOOL), 'search', args.query, '--table', 'all', '--limit', str(args.limit)], cwd=str(BASE), text=True)
        print(json.dumps({'mode':'database-direct-structured','result':json.loads(out)}, indent=2))
    except Exception as e:
        print(json.dumps({'mode':'database-unavailable','error':str(e),'structured':[]}, indent=2))
if __name__=='__main__': main()
