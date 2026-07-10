#!/usr/bin/env bash
set -euo pipefail

version="${1:-1.2.61}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="$root/release"
mkdir -p "$out_dir"

archive="$out_dir/zorg-db-memory-v${version}.tar.gz"
rm -f "$archive"

tar \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='.next' \
  --exclude='tmp' \
  --exclude='*.env' \
  --exclude='sql_memory_map.json' \
  -czf "$archive" \
  -C "$root" \
  README.md CHANGELOG.md LICENSE package.json skills package docs scripts

echo "$archive"
