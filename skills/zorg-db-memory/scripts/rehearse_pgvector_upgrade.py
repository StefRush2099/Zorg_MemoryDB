#!/usr/bin/env python3
"""Rehearse pgvector upgrade readiness without changing the live extension."""
import json, os, subprocess, tempfile
from pathlib import Path
TARGET=os.environ.get("PGVECTOR_TARGET_VERSION","0.8.6"); UPSTREAM="https://github.com/pgvector/pgvector.git"
result={"target":TARGET,"upstream":UPSTREAM,"live_changed":False}
with tempfile.TemporaryDirectory(prefix="zorg-pgvector-rehearsal-") as td:
 root=Path(td); src=root/"pgvector"; headers=root/"headers"; pkg=root/"packages"; pkg.mkdir()
 clone=subprocess.run(["git","clone","--depth","1","--branch",f"v{TARGET}",UPSTREAM,str(src)],text=True,capture_output=True)
 result["clone_ok"]=clone.returncode==0
 download=subprocess.run(["apt","download","postgresql-server-dev-18"],cwd=pkg,text=True,capture_output=True)
 deb=next(pkg.glob("postgresql-server-dev-18_*.deb"),None)
 extract=subprocess.run(["dpkg-deb","-x",str(deb),str(headers)],text=True,capture_output=True) if deb else None
 server=headers/"usr/include/postgresql/18/server"; internal=headers/"usr/include/postgresql/internal"
 result["headers_staged"]=bool(extract and extract.returncode==0 and (server/"postgres.h").exists())
 if result["clone_ok"] and result["headers_staged"]:
  build=subprocess.run(["make",f"PG_CPPFLAGS=-I{server} -I{internal}","with_llvm=no","-j2"],cwd=src,text=True,capture_output=True)
  result["build_ok"]=build.returncode==0; result["build_error"]=build.stderr[-1000:] if build.returncode else ""
 else: result["build_ok"]=False
 chain=["0.8.1--0.8.2","0.8.2--0.8.3","0.8.3--0.8.4","0.8.4--0.8.5","0.8.5--0.8.6"]
 result["upgrade_chain"]={step:(src/"sql"/f"vector--{step}.sql").exists() for step in chain}
 result["control_present"]=(src/"vector.control").exists()
result["rehearsal_ok"]=result["clone_ok"] and result["headers_staged"] and result["build_ok"] and result["control_present"] and all(result["upgrade_chain"].values())
result["privileged_install_required"]=True
result["apply_outline"]=[f"install official pgvector v{TARGET} extension files as administrator","create and verify private PostgreSQL backup",f"ALTER EXTENSION vector UPDATE TO '{TARGET}' as extension owner","run exact/HNSW/cognitive/LAN/3D acceptance suite"]
result["rollback_outline"]=["restore prior pgvector extension files","restore verified private PostgreSQL backup if required","rerun full acceptance suite"]
print(json.dumps(result,sort_keys=True)); raise SystemExit(0 if result["rehearsal_ok"] else 1)
