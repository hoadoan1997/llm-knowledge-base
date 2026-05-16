#!/usr/bin/env bash
# fetch-url.sh — Fetch any URL → clean Markdown → raw/articles/
#
# Strategy:
#   1. Static fetch (requests + markdownify) — fast, zero JS overhead
#   2. Auto-fallback to r.jina.ai if word count < 200 (JS-rendered page)
#
# Usage:
#   ./tools/fetch-url.sh <url>                    # auto-slug from URL
#   ./tools/fetch-url.sh <url> <name>             # custom output name
#   ./tools/fetch-url.sh <url> --dry-run          # preview, no save
#   ./tools/fetch-url.sh <url> --force-jina       # skip static, use Jina

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON="$ROOT/tools/.venv/bin/python3"

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <url> [name] [--dry-run] [--force-jina]"
  echo ""
  echo "Examples:"
  echo "  $0 https://www.anthropic.com/news/claude-opus-4-7"
  echo "  $0 https://example.com/article my-article"
  echo "  $0 https://example.com/article --dry-run"
  echo "  $0 https://example.com/article --force-jina   # force JS rendering"
  exit 1
fi

exec "$PYTHON" "$ROOT/tools/fetch-url.py" "$@"
