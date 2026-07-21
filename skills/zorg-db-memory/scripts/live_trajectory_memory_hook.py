#!/usr/bin/env python3
"""Thin live bridge: watches OpenClaw's real runtime trajectory files and sends
changed files through the canonical idempotent typed ingester. The DB remains the
source of truth; this process owns no cursor or policy."""
import glob,os,subprocess,time
from pathlib import Path
BASE=Path(os.environ.get('OPENCLAW_WORKSPACE','/home/openclaw/.openclaw/workspace'))
PY=BASE/'.venv-sqlmem/bin/python'; ING=BASE/'skills/zorg-db-memory/scripts/backfill_typed_runtime_events.py'
ROOT=Path.home()/'.openclaw/agents/main/sessions'; seen={}
while True:
    names=glob.glob(str(ROOT/'*.trajectory.jsonl'))
    for pointer in glob.glob(str(ROOT/'*.trajectory-path.json')):
        try:
            import json
            target=json.loads(Path(pointer).read_text()).get('runtimeFile')
            if target: names.append(target)
        except Exception: pass
    for name in set(names):
        try: stamp=os.stat(name).st_mtime_ns
        except FileNotFoundError: continue
        if seen.get(name)==stamp: continue
        subprocess.run([str(PY),str(ING),'--glob',name],check=False,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        seen[name]=stamp
    time.sleep(5)
