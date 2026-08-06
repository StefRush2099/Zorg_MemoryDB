#!/usr/bin/env python3
"""Dispatch PostgreSQL-owned LLM scheduled jobs through OpenClaw.

PostgreSQL owns timing, prompts, delivery metadata, queue rows, and run records.
This process is intentionally a single listener, not a per-job cron scheduler:
it wakes from LISTEN/NOTIFY and claims due rows from memory_llm_job_queue.
"""
from __future__ import annotations

import json
import os
import select
import socket
import subprocess
import sys
import time
from pathlib import Path

import psycopg2
import psycopg2.extras

WORKSPACE = Path(os.environ.get("OPENCLAW_WORKSPACE", Path(__file__).resolve().parents[3])).resolve()
SKILL_ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = (SKILL_ROOT / "config" / "sql_memory_map.json").resolve()
OPENCLAW_BIN = os.environ.get("OPENCLAW_BIN", "/home/openclaw/.npm-global/bin/openclaw")
WORKER_ID = f"llm-db-dispatcher@{socket.gethostname()}:{os.getpid()}"


def load_cfg() -> dict[str, object]:
    cfg = json.loads(MAP_PATH.read_text())
    p = cfg["postgres"]
    return {
        "host": p["host"],
        "port": p["port"],
        "dbname": p["database"],
        "user": p["user"],
        "password": p["password"],
    }


def connect():
    conn = psycopg2.connect(**load_cfg())
    conn.autocommit = True
    return conn


def claim(conn):
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("select * from public.memory_llm_claim_job(%s)", (WORKER_ID,))
        return cur.fetchone()


def finish(conn, queue_id, status, summary="", stdout="", stderr="", error=""):
    with conn.cursor() as cur:
        cur.execute(
            "select public.memory_llm_finish_job(%s,%s,%s,%s,%s,%s)",
            (queue_id, status, summary, stdout, stderr, error),
        )


def build_command(row: dict) -> list[str]:
    snapshot = row["payload_snapshot"]
    payload = snapshot.get("payload") or {}
    delivery = row["delivery_snapshot"] or {}
    prompt_text = str(payload.get("text") or "").strip()
    prompt_message = str(payload.get("message") or "").strip()
    if prompt_text and prompt_message and prompt_message != prompt_text:
        message = f"{prompt_text}\n\n{prompt_message}"
    else:
        message = prompt_text or prompt_message
    if not message:
        raise ValueError(f"job {row['job_key']} has empty payload.text and payload.message")

    cmd = [
        OPENCLAW_BIN,
        "agent",
        "--agent",
        str(snapshot.get("agent_id") or "main"),
        "--message",
        message,
        "--session-key",
        f"db-cron:{row['job_key']}",
        "--json",
    ]

    model = payload.get("model")
    if model:
        cmd.extend(["--model", str(model)])
    thinking = payload.get("thinking")
    if thinking:
        cmd.extend(["--thinking", str(thinking)])
    timeout = payload.get("timeoutSeconds")
    if timeout:
        cmd.extend(["--timeout", str(int(timeout))])

    if delivery.get("mode") == "announce":
        cmd.append("--deliver")
        channel = delivery.get("channel")
        target = delivery.get("to")
        account = delivery.get("accountId")
        if channel:
            cmd.extend(["--reply-channel", str(channel)])
        if target:
            cmd.extend(["--reply-to", str(target)])
        if account:
            cmd.extend(["--reply-account", str(account)])

    return cmd


def run_one(conn, row: dict) -> None:
    queue_id = row["queue_id"]
    try:
        cmd = build_command(row)
        proc = subprocess.run(
            cmd,
            cwd=str(WORKSPACE),
            text=True,
            capture_output=True,
            timeout=7200,
            env={**os.environ, "OPENCLAW_WORKSPACE": str(WORKSPACE)},
        )
        status = "done" if proc.returncode == 0 else "failed"
        summary = "openclaw agent run completed" if proc.returncode == 0 else f"openclaw agent exited {proc.returncode}"
        finish(conn, queue_id, status, summary, proc.stdout, proc.stderr, "" if proc.returncode == 0 else summary)
    except Exception as exc:
        finish(conn, queue_id, "failed", "dispatcher exception", "", "", repr(exc))


def drain(conn) -> int:
    count = 0
    while True:
        row = claim(conn)
        if not row:
            return count
        run_one(conn, row)
        count += 1


def main() -> int:
    while True:
        try:
            conn = connect()
            with conn.cursor() as cur:
                cur.execute("LISTEN memory_llm_job_queue")
            drain(conn)
            while True:
                if select.select([conn], [], [], 60) == ([], [], []):
                    drain(conn)
                    continue
                conn.poll()
                while conn.notifies:
                    conn.notifies.pop(0)
                drain(conn)
        except KeyboardInterrupt:
            return 0
        except Exception as exc:
            print(f"{WORKER_ID} error: {exc!r}", file=sys.stderr, flush=True)
            time.sleep(10)


if __name__ == "__main__":
    raise SystemExit(main())
