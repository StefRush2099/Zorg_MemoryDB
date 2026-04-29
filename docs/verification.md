# Verification

## Secret/private-data scan

```bash
grep -RInE 'password|token|secret|oauth|credential|cookie|BEGIN (RSA|OPENSSH|PRIVATE)|[0-9]{1,3}(\.[0-9]{1,3}){3}|@' . \
  --exclude-dir=.git \
  --exclude='README.md' \
  --exclude='verification.md'
```

Review every match before publishing.

## Schema smoke test

```bash
createdb openclaw_memory_test
psql postgresql://USER:PASSWORD@127.0.0.1:5432/openclaw_memory_test -v ON_ERROR_STOP=1 -f db/schema.sql
```

## Tool smoke test

```bash
cp config/sql_memory_map.example.json sql_memory_map.json
# edit connection fields
python scripts/memory_sql_tool.py tables
python scripts/memory_sql_tool.py refresh
python scripts/memory_speed_test.py
```
