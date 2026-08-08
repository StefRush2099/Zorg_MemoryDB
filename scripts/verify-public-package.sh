#!/usr/bin/env bash
set -euo pipefail

missing=0
mapfile -t public_source_files < <(
  git ls-files --cached --others --exclude-standard \
    | rg -v '^package/zorg/memory-3d/|^release/.*\.tar\.gz$|^scripts/verify-public-package\.sh$'
)
package_version="$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([0-9][0-9.]*\)".*/\1/p' package.json | head -1)"
lan_chat_version="$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([0-9][0-9.]*\)".*/\1/p' package/zorg/lan-command-chat/package.json | head -1)"
if [[ "$lan_chat_version" != "$package_version" ]]; then
  echo "LAN Command Chat version $lan_chat_version does not match GitHub package version $package_version" >&2
  exit 1
fi
node scripts/sync-lan-chat-release-version.mjs
if ! rg -q 'import packageMetadata from "\.\./\.\./\.\./package\.json"' package/zorg/lan-command-chat/src/app/chat/page.tsx \
  || ! rg -q 'data-lan-chat-gauge-version=\{LAN_CHAT_RELEASE_VERSION\}' package/zorg/lan-command-chat/src/app/chat/page.tsx \
  || ! rg -q 'v\{LAN_CHAT_RELEASE_VERSION\}' package/zorg/lan-command-chat/src/app/chat/page.tsx; then
  echo "LAN Command Chat gauge does not derive and render the canonical package version" >&2
  exit 1
fi
if [[ ! -f package/zorg/lan-command-chat/scripts/verify-live-version.mjs ]] \
  || ! rg -q 'data-lan-chat-gauge-version' package/zorg/lan-command-chat/scripts/verify-live-version.mjs; then
  echo "LAN Command Chat gauge-specific compiled/rendered verifier is missing" >&2
  exit 1
fi
release_archive="release/zorg-db-memory-v${package_version}.tar.gz"
for path in \
  "skills/zorg-db-memory/SKILL.md" \
  "package/zorg/README.md" \
  "README.md" \
  "docs/openclaw-base.md" \
  "docs/install.md" \
  "docs/source-and-test-boundary.md" \
  "docs/screenshots.md" \
  "release/v${package_version}.md"; do
  if [[ ! -e "$path" ]]; then
    echo "missing: $path" >&2
    missing=1
  fi
done

required_boundary='pending a separately supplied test host.'
if ! rg -Fq "$required_boundary" docs/source-and-test-boundary.md \
  || ! rg -Fq 'source/authoring OpenClaw system' docs/install.md \
  || ! rg -Fq "maintainer's active OpenClaw system" README.md \
  || ! rg -Fq "$required_boundary" "release/v${package_version}.md"; then
  echo "source-system protection or pending external-acceptance disclosure is missing" >&2
  exit 1
fi

if rg -n --glob '!verify-public-package.sh' \
  'openclaw plugins install .*--force|openclaw gateway restart' scripts package.json; then
  echo "release automation must not install the connector or restart OpenClaw on the source system" >&2
  exit 1
fi

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

privacy_scan_targets=(.)
if [[ -f "$release_archive" ]]; then
  privacy_scan_targets+=("$release_archive")
fi
python3 skills/zorg-db-memory/scripts/verify_public_rule_name_privacy.py \
  --self-test "${privacy_scan_targets[@]}"

if rg -n \
  '(cfat_[A-Za-z0-9]|gho_[A-Za-z0-9]|github_pat_[A-Za-z0-9]|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|SECRET_ACCESS_KEY=|AWS_SECRET_ACCESS_KEY=|CLOUDFLARE_API_TOKEN=)' \
  "${public_source_files[@]}"; then
  echo "possible secret found" >&2
  exit 1
fi

if printf '%s\n' "${public_source_files[@]}" \
    | rg '(^|/)(node_modules|__pycache__|\\.gradle|build|\\.next|tmp|browser-profile)(/|$)|(^|/)local\\.properties$|sql_memory_map\\.json$|\\.(pyc|dump|backup)$' \
  || printf '%s\n' "${public_source_files[@]}" \
    | rg '(^|/)dist(/|$)' \
    | rg -v '^skills/zorg-db-memory/plugin-src/dist/'; then
  echo "generated/private artifact path found" >&2
  exit 1
fi

if git ls-files --error-unmatch package/zorg/memory-3d >/dev/null 2>&1; then
  echo "retired package/zorg/memory-3d must not be tracked in the public release" >&2
  exit 1
fi

if [[ -f "$release_archive" ]]; then
  if tar -tzf "$release_archive" | rg '(^|/)(node_modules|__pycache__|\\.gradle|build|\\.next|tmp|browser-profile)(/|$)|(^|/)local\\.properties$|sql_memory_map\\.json$|\\.(pyc|dump|backup|tar\\.gz)$' \
    || tar -tzf "$release_archive" | rg '(^|/)dist(/|$)' | rg -v '^skills/zorg-db-memory/plugin-src/dist/'; then
    echo "generated/private artifact found inside release archive" >&2
    exit 1
  fi

  if tar -tzf "$release_archive" | rg -q '^package/zorg/memory-3d/'; then
    echo "retired package/zorg/memory-3d found inside release archive" >&2
    exit 1
  fi

  if tar -tzf "$release_archive" | rg -n 'daily-github-sync'; then
    echo "operator-only daily GitHub sync wording found inside public archive" >&2
    exit 1
  fi

  if tar -tzf "$release_archive" \
    | rg '\.(md|txt|json|sh|py|sql|cjs|mjs|ts|tsx|js|css|html|ya?ml)$' \
    | rg -v '^scripts/verify-public-package\.sh$' \
    | while IFS= read -r archive_path; do tar -xOzf "$release_archive" "$archive_path"; done \
    | rg -n 'daily GitHub sync|Once per day, all applied zorg-db-memory skill updates'; then
    echo "operator-only daily GitHub sync wording found inside public archive" >&2
    exit 1
  fi
fi

archive_release_count="$(tar -tzf "$release_archive" | rg -c '^release/v[^/]+\.md$' || true)"
if [[ "$archive_release_count" -ne 1 ]]; then
  echo "release archive must contain exactly one current release note" >&2
  exit 1
fi

echo "public package verification passed"
