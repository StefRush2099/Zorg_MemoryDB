#!/usr/bin/env python3
"""Sync Google People/Contacts data into private Zorg MemoryDB CRM tables.

This script stores private contact data locally. Do not publish live output.
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import psycopg2
import psycopg2.extras

WORKSPACE = Path(os.environ.get("OPENCLAW_WORKSPACE", "/home/openclaw/.openclaw/workspace"))
ENV_PATH = Path(os.environ.get("GOOGLE_OAUTH_ENV", "/home/openclaw/.openclaw/credentials/zorg_gmail_oauth.env"))
SKILL_ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = (SKILL_ROOT / "config" / "sql_memory_map.json").resolve()
PERSON_FIELDS = ",".join([
    "names",
    "nicknames",
    "emailAddresses",
    "phoneNumbers",
    "addresses",
    "organizations",
    "biographies",
    "birthdays",
    "events",
    "urls",
    "photos",
    "metadata",
    "memberships",
    "relations",
    "imClients",
    "userDefined",
])


def load_env(path: Path):
    if not path.exists():
        raise RuntimeError(f"missing oauth env file: {path}")
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ[k.strip()] = v.strip().strip('"').strip("'")


def token_refresh():
    for k in ["GOOGLE_OAUTH_CLIENT_ID", "GOOGLE_OAUTH_CLIENT_SECRET", "GOOGLE_OAUTH_REFRESH_TOKEN"]:
        if not os.environ.get(k):
            raise RuntimeError(f"missing {k}")
    payload = urllib.parse.urlencode({
        "client_id": os.environ["GOOGLE_OAUTH_CLIENT_ID"],
        "client_secret": os.environ["GOOGLE_OAUTH_CLIENT_SECRET"],
        "refresh_token": os.environ["GOOGLE_OAUTH_REFRESH_TOKEN"],
        "grant_type": "refresh_token",
    }).encode()
    req = urllib.request.Request("https://oauth2.googleapis.com/token", data=payload, headers={"Content-Type": "application/x-www-form-urlencoded"})
    with urllib.request.urlopen(req, timeout=30) as r:
        tok = json.loads(r.read().decode())
    if not tok.get("access_token"):
        raise RuntimeError("token refresh failed")
    return tok["access_token"]


def api_get_json(url, access):
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {access}"})
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.loads(r.read().decode())


def fetch_connections(access):
    people = []
    token = None
    while True:
        params = {"personFields": PERSON_FIELDS, "pageSize": 1000}
        if token:
            params["pageToken"] = token
        url = "https://people.googleapis.com/v1/people/me/connections?" + urllib.parse.urlencode(params)
        data = api_get_json(url, access)
        people.extend(data.get("connections", []) or [])
        token = data.get("nextPageToken")
        if not token:
            break
        time.sleep(0.15)
    return people


def primary(items, value_key):
    if not items:
        return None
    for item in items:
        md = item.get("metadata") or {}
        if md.get("primary") and item.get(value_key):
            return item.get(value_key)
    for item in items:
        if item.get(value_key):
            return item.get(value_key)
    return None


def normalize_email(v):
    return (v or "").strip().lower()


def normalize_phone(v):
    return re.sub(r"[^0-9+]+", "", v or "")


def build_search_text(p, fields):
    chunks = []
    for val in fields.values():
        if val:
            chunks.append(str(val))
    for key in ["names", "nicknames", "emailAddresses", "phoneNumbers", "addresses", "organizations", "urls", "birthdays", "events", "relations", "memberships", "userDefined", "biographies"]:
        val = p.get(key)
        if val:
            chunks.append(json.dumps(val, ensure_ascii=False, sort_keys=True))
    return "\n".join(chunks)


def extract_fields(p):
    names = p.get("names") or []
    name0 = names[0] if names else {}
    orgs = p.get("organizations") or []
    org0 = orgs[0] if orgs else {}
    emails = p.get("emailAddresses") or []
    phones = p.get("phoneNumbers") or []
    nicknames = p.get("nicknames") or []
    biographies = p.get("biographies") or []
    notes = "\n".join([b.get("value", "") for b in biographies if b.get("value")]) or None
    fields = {
        "source": "google_people_api",
        "source_resource_name": p.get("resourceName"),
        "source_etag": p.get("etag"),
        "display_name": name0.get("displayName"),
        "given_name": name0.get("givenName"),
        "family_name": name0.get("familyName"),
        "middle_name": name0.get("middleName"),
        "nickname": primary(nicknames, "value"),
        "company": org0.get("name"),
        "job_title": org0.get("title"),
        "department": org0.get("department"),
        "email_primary": normalize_email(primary(emails, "value")),
        "phone_primary": normalize_phone(primary(phones, "value")),
        "timezone": None,
        "notes": notes,
        "names": json.dumps(names),
        "email_addresses": json.dumps(emails),
        "phone_numbers": json.dumps(phones),
        "addresses": json.dumps(p.get("addresses") or []),
        "organizations": json.dumps(orgs),
        "urls": json.dumps(p.get("urls") or []),
        "birthdays": json.dumps(p.get("birthdays") or []),
        "events": json.dumps(p.get("events") or []),
        "relations": json.dumps(p.get("relations") or []),
        "memberships": json.dumps(p.get("memberships") or []),
        "user_defined": json.dumps(p.get("userDefined") or []),
        "photos": json.dumps(p.get("photos") or []),
        "raw_person": json.dumps(p),
    }
    fields["search_text"] = build_search_text(p, fields)
    if not fields["source_resource_name"]:
        raise RuntimeError("contact missing resourceName")
    return fields


def load_db_config():
    cfg = json.loads(MAP_PATH.read_text())["postgres"]
    return cfg


def upsert_people(conn, people):
    cur = conn.cursor()
    cur.execute("insert into public.zorg_contact_sync_runs(status, metadata) values ('running', %s) returning id", (json.dumps({"source": "google_people_api"}),))
    run_id = cur.fetchone()[0]
    seen = upserted = points = 0
    try:
        for p in people:
            seen += 1
            f = extract_fields(p)
            cols = list(f.keys())
            vals = [psycopg2.extras.Json(json.loads(f[c])) if c in {"names","email_addresses","phone_numbers","addresses","organizations","urls","birthdays","events","relations","memberships","user_defined","photos","raw_person"} else f[c] for c in cols]
            set_clause = ", ".join([f"{c}=excluded.{c}" for c in cols if c not in {"source", "source_resource_name"}]) + ", last_synced_at=now(), updated_at=now(), active=true"
            sql = f"""
                insert into public.zorg_contacts_crm ({', '.join(cols)})
                values ({', '.join(['%s']*len(cols))})
                on conflict (source, source_resource_name) do update set {set_clause}
                returning id
            """
            cur.execute(sql, vals)
            contact_id = cur.fetchone()[0]
            upserted += 1
            # Refresh normalized contact points for this contact.
            cur.execute("delete from public.zorg_contact_points_crm where contact_id=%s", (contact_id,))
            point_rows = []
            for item in p.get("emailAddresses") or []:
                value = item.get("value")
                if value:
                    point_rows.append((contact_id, "email", item.get("type"), value, normalize_email(value), bool((item.get("metadata") or {}).get("primary")), json.dumps(item)))
            for item in p.get("phoneNumbers") or []:
                value = item.get("value")
                if value:
                    point_rows.append((contact_id, "phone", item.get("type"), value, normalize_phone(value), bool((item.get("metadata") or {}).get("primary")), json.dumps(item)))
            for item in p.get("urls") or []:
                value = item.get("value")
                if value:
                    point_rows.append((contact_id, "url", item.get("type"), value, value.strip().lower(), bool((item.get("metadata") or {}).get("primary")), json.dumps(item)))
            for row in point_rows:
                cur.execute("""
                    insert into public.zorg_contact_points_crm(contact_id, point_type, label, value, value_norm, primary_flag, metadata)
                    values (%s,%s,%s,%s,%s,%s,%s)
                    on conflict (contact_id, point_type, value_norm) do update set
                      label=excluded.label, value=excluded.value, primary_flag=excluded.primary_flag,
                      metadata=excluded.metadata, updated_at=now()
                """, (row[0], row[1], row[2], row[3], row[4], row[5], psycopg2.extras.Json(json.loads(row[6]))))
                points += 1
        # Rebuild the non-destructive canonical CRM/distilled contact layer when available.
        try:
            cur.execute("select * from public.zorg_distill_contacts_crm()")
            distilled = cur.fetchone()
        except Exception:
            distilled = None
            cur.execute("select public.zorg_refresh_memory_search()")
        metadata = {"distilled": list(distilled) if distilled else None}
        cur.execute("""
            update public.zorg_contact_sync_runs
            set status='ok', finished_at=now(), contacts_seen=%s, contacts_upserted=%s, contact_points_upserted=%s, metadata=metadata || %s::jsonb
            where id=%s
        """, (seen, upserted, points, json.dumps(metadata), run_id))
    except Exception as e:
        cur.execute("update public.zorg_contact_sync_runs set status='error', finished_at=now(), error_text=%s, contacts_seen=%s, contacts_upserted=%s, contact_points_upserted=%s where id=%s", (str(e), seen, upserted, points, run_id))
        raise
    return {"sync_run_id": str(run_id), "contacts_seen": seen, "contacts_upserted": upserted, "contact_points_upserted": points}


def main():
    load_env(ENV_PATH)
    access = token_refresh()
    people = fetch_connections(access)
    conn = psycopg2.connect(**load_db_config())
    try:
        with conn:
            result = upsert_people(conn, people)
    finally:
        conn.close()
    # Print counts only, never contact data.
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
