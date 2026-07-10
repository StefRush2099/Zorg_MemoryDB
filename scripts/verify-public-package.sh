#!/usr/bin/env bash
set -euo pipefail

missing=0
for path in \
  "skills/zorg-db-memory/SKILL.md" \
  "package/zorg/README.md" \
  "README.md" \
  "docs/openclaw-base.md" \
  "docs/install.md" \
  "docs/screenshots.md" \
  "release/v1.2.68.md"; do
  if [[ ! -e "$path" ]]; then
    echo "missing: $path" >&2
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

if rg -n --hidden --glob '!.git/**' --glob '!release/*.tar.gz' --glob '!scripts/verify-public-package.sh' \
  '(cfat_[A-Za-z0-9]|gho_[A-Za-z0-9]|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|password\\s*=|SECRET_ACCESS_KEY=|AWS_SECRET_ACCESS_KEY=|CLOUDFLARE_API_TOKEN=)' .; then
  echo "possible secret found" >&2
  exit 1
fi

if rg --files --hidden --glob '!.git/**' | rg '(^|/)(node_modules|__pycache__|\\.next|dist|tmp|browser-profile)(/|$)|sql_memory_map\\.json$|\\.(pyc|dump|backup)$'; then
  echo "generated/private artifact path found" >&2
  exit 1
fi

if [[ -f release/zorg-db-memory-v1.2.68.tar.gz ]]; then
  if tar -tzf release/zorg-db-memory-v1.2.68.tar.gz | rg '(^|/)(node_modules|__pycache__|\\.next|dist|tmp|browser-profile)(/|$)|sql_memory_map\\.json$|\\.(pyc|dump|backup|tar\\.gz)$'; then
    echo "generated/private artifact found inside release archive" >&2
    exit 1
  fi

  if tar -tzf release/zorg-db-memory-v1.2.68.tar.gz | rg -n 'daily-github-sync|daily GitHub sync|once per day|StefRush2099/Zorg_MemoryDB'; then
    echo "operator-only daily GitHub sync wording found inside public archive" >&2
    exit 1
  fi
fi

echo "public package verification passed"
