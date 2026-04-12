#!/usr/bin/env bash
# search.sh — LLM-friendly full-text search over /wiki
# Designed to be called by Claude as a CLI tool during Q&A sessions
#
# Usage:
#   ./tools/search.sh "<query>"                    # full-text search, returns snippets
#   ./tools/search.sh "<query>" --files            # return matching file paths only
#   ./tools/search.sh "<query>" --concept          # search concepts/ only
#   ./tools/search.sh "<query>" --topic            # search topics/ only
#   ./tools/search.sh "<query>" --summary          # search summaries/ only
#   ./tools/search.sh --list-all                   # list all wiki files with titles
#   ./tools/search.sh --list-concepts              # list all concept files
#   ./tools/search.sh --list-topics                # list all topic files
#   ./tools/search.sh --related "<file>"           # find files linked from a given file

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WIKI="$ROOT/wiki"

MODE="search"
SCOPE="$WIKI"
QUERY=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --files)       MODE="files"; shift ;;
    --fuzzy)       MODE="fuzzy"; shift ;;
    --concept)     SCOPE="$WIKI/concepts"; shift ;;
    --topic)       SCOPE="$WIKI/topics"; shift ;;
    --summary)     SCOPE="$WIKI/summaries"; shift ;;
    --list-all)    MODE="list-all"; shift ;;
    --list-concepts) MODE="list-concepts"; shift ;;
    --list-topics)   MODE="list-topics"; shift ;;
    --related)     MODE="related"; shift ;;
    *)             QUERY="$1"; shift ;;
  esac
done

case "$MODE" in

  list-all)
    echo "=== ALL WIKI FILES ==="
    find "$WIKI" -name "*.md" -not -name "index.md" | sort | while read -r f; do
      title=$(grep -m1 "^title:" "$f" 2>/dev/null | sed 's/title: *//;s/"//g' || basename "$f" .md)
      echo "  $(basename "$f" .md) — $title   [${f#$ROOT/}]"
    done
    ;;

  list-concepts)
    echo "=== CONCEPTS ==="
    find "$WIKI/concepts" -name "*.md" | sort | while read -r f; do
      title=$(grep -m1 "^title:" "$f" 2>/dev/null | sed 's/title: *//;s/"//g' || basename "$f" .md)
      tags=$(grep -m1 "^tags:" "$f" 2>/dev/null | sed 's/tags: *//' || echo "")
      echo "  $(basename "$f" .md) — $title  $tags"
    done
    ;;

  list-topics)
    echo "=== TOPICS ==="
    find "$WIKI/topics" -name "*.md" | sort | while read -r f; do
      title=$(grep -m1 "^title:" "$f" 2>/dev/null | sed 's/title: *//;s/"//g' || basename "$f" .md)
      echo "  $(basename "$f" .md) — $title"
    done
    ;;

  related)
    if [[ -z "$QUERY" ]]; then echo "Usage: $0 --related <filename>"; exit 1; fi
    TARGET=$(find "$WIKI" -name "${QUERY}.md" -o -name "$QUERY" 2>/dev/null | head -1)
    if [[ -z "$TARGET" ]]; then echo "File not found: $QUERY"; exit 1; fi
    echo "=== LINKS FROM: $QUERY ==="
    grep -oE '\[\[([^]|#]+)' "$TARGET" | sed 's/\[\[//' | sort -u | while read -r link; do
      found=$(find "$WIKI" -name "${link}.md" 2>/dev/null | head -1)
      if [[ -n "$found" ]]; then
        echo "  ✓ $link  [${found#$ROOT/}]"
      else
        echo "  ✗ $link  (not yet created)"
      fi
    done
    ;;

  files)
    if [[ -z "$QUERY" ]]; then echo "Usage: $0 <query> --files"; exit 1; fi
    echo "=== FILES MATCHING: $QUERY ==="
    RESULTS=$(grep -ril "$QUERY" "$SCOPE" --include="*.md" 2>/dev/null | sort | sed "s|$ROOT/||")
    echo "$RESULTS"
    # Query logging
    QUERY_LOG="$ROOT/wiki/.query-log.jsonl"
    HIT_COUNT=$(echo "$RESULTS" | grep -c "." 2>/dev/null || echo 0)
    MISS=$([ "$HIT_COUNT" -eq 0 ] && echo "true" || echo "false")
    printf '{"date":"%s","mode":"files","query":"%s","hits":%s,"miss":%s}\n' \
      "$(date +%Y-%m-%d)" "$(echo "$QUERY" | tr '"' "'")" "$HIT_COUNT" "$MISS" \
      >> "$QUERY_LOG" 2>/dev/null || true
    ;;

  search)
    if [[ -z "$QUERY" ]]; then echo "Usage: $0 <query>"; exit 1; fi
    echo "=== SEARCH: $QUERY ==="
    echo ""
    RESULTS=$(grep -rin "$QUERY" "$SCOPE" --include="*.md" \
      --color=never -A 2 -B 1 \
      | sed "s|$ROOT/||" \
      | head -80)
    echo "$RESULTS"
    # Query logging
    QUERY_LOG="$ROOT/wiki/.query-log.jsonl"
    HIT_COUNT=$(echo "$RESULTS" | grep -c "." 2>/dev/null || echo 0)
    MISS=$([ "$HIT_COUNT" -eq 0 ] && echo "true" || echo "false")
    printf '{"date":"%s","mode":"search","query":"%s","hits":%s,"miss":%s}\n' \
      "$(date +%Y-%m-%d)" "$(echo "$QUERY" | tr '"' "'")" "$HIT_COUNT" "$MISS" \
      >> "$QUERY_LOG" 2>/dev/null || true
    ;;

  fuzzy)
    # Fuzzy search: find partial matches and common variations
    if [[ -z "$QUERY" ]]; then echo "Usage: $0 <query> --fuzzy"; exit 1; fi
    echo "=== FUZZY SEARCH: $QUERY ==="
    echo "(includes variations, case-insensitive)"
    echo ""

    # Build fuzzy pattern: match query + common suffixes
    Q="$QUERY"
    # Escape special regex chars in query first
    Q_ESC=$(echo "$Q" | sed 's/[.^$*+?()\[\]{}|\\]/\\&/g')
    # Pattern: match the root word with optional common suffixes
    FUZZY_PATTERN="${Q_ESC}(s|ed|ing|ion|ly|ment|er|est|tion|ity|al)?"

    if command -v rg &>/dev/null; then
      # ripgrep available: faster, better output
      RESULTS=$(rg -i "$FUZZY_PATTERN" "$SCOPE" --glob "*.md" \
        --color=never -A 1 -B 1 \
        | sed "s|$ROOT/||" \
        | head -80)
    else
      # fallback: grep with extended regex
      RESULTS=$(grep -rEin "$FUZZY_PATTERN" "$SCOPE" --include="*.md" \
        --color=never -A 1 -B 1 \
        | sed "s|$ROOT/||" \
        | head -80)
    fi
    echo "$RESULTS"
    # Query logging
    QUERY_LOG="$ROOT/wiki/.query-log.jsonl"
    HIT_COUNT=$(echo "$RESULTS" | grep -c "." 2>/dev/null || echo 0)
    MISS=$([ "$HIT_COUNT" -eq 0 ] && echo "true" || echo "false")
    printf '{"date":"%s","mode":"fuzzy","query":"%s","hits":%s,"miss":%s}\n' \
      "$(date +%Y-%m-%d)" "$(echo "$QUERY" | tr '"' "'")" "$HIT_COUNT" "$MISS" \
      >> "$QUERY_LOG" 2>/dev/null || true
    ;;

esac
