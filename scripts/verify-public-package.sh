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
  "release/v1.2.61.md"; do
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

if rg --files --hidden --glob '!.git/**' | rg '(^|/)(node_modules|\\.next|dist|tmp|browser-profile)(/|$)|sql_memory_map\\.json$|\\.(dump|backup)$'; then
  echo "generated/private artifact path found" >&2
  exit 1
fi

echo "public package verification passed"
