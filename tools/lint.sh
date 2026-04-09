#!/usr/bin/env bash
# lint.sh — Wiki health check + generate impute candidates
# Usage:
#   ./tools/lint.sh              # full check, print to terminal
#   ./tools/lint.sh --save       # save report to outputs/notes/lint-YYYY-MM-DD.md
#   ./tools/lint.sh --impute     # list missing topics suitable for web search imputation
#   ./tools/lint.sh --quick <file>  # fast single-file check (frontmatter, links, domain)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WIKI="$ROOT/wiki"
DATE=$(date '+%Y-%m-%d')
ISSUES=0
IMPUTE_CANDIDATES=()

_section() { echo ""; echo "--- $1 ---"; }

run_checks() {

  _section "1. Files missing frontmatter"
  while IFS= read -r -d '' f; do
    if ! head -1 "$f" | grep -q "^---"; then
      echo "  NO FRONTMATTER: ${f#$ROOT/}"
      ((ISSUES++)) || true
    fi
  done < <(find "$WIKI" -name "*.md" -not -name "index.md" -not -name "_brief.md" -not -name "_about-domains.md" -print0)

  _section "2. Orphaned files (no incoming links)"
  while IFS= read -r -d '' f; do
    name="$(basename "$f" .md)"
    incoming=$(grep -rE "\[\[(concepts/|topics/|summaries/)?$name[]|#\]]" "$WIKI" --include="*.md" -l 2>/dev/null | grep -v "$(basename "$f")" | wc -l | tr -d ' ') || incoming=0
    if [[ "$incoming" -eq 0 ]]; then
      echo "  ORPHAN: ${f#$ROOT/}"
      ((ISSUES++)) || true
    fi
  done < <(find "$WIKI/concepts" "$WIKI/topics" -name "*.md" -print0 2>/dev/null)

  _section "3. Broken wikilinks"
  while IFS= read -r -d '' f; do
    while IFS= read -r link; do
      link_clean="${link%%|*}"
      link_clean="${link_clean%%#*}"
      link_clean="${link_clean##*/}"   # strip path prefix for leaf name
      if ! find "$WIKI" -name "${link_clean}.md" 2>/dev/null | grep -q .; then
        echo "  BROKEN [[${link_clean}]] in ${f#$ROOT/}"
        ((ISSUES++)) || true
        # Collect as impute candidate
        IMPUTE_CANDIDATES+=("$link_clean")
      fi
    done < <(grep -oE '\[\[[^]]+\]\]' "$f" 2>/dev/null | sed 's/\[\[//;s/\]\]//')
  done < <(find "$WIKI" -name "*.md" -print0)

  _section "4. Concepts mentioned inline (not yet created)"
  # Find **bold** terms in concepts/topics that don't have their own file
  # Filters applied to reduce false positives:
  #   - slug length 5–35 chars (too short = abbreviation, too long = sentence)
  #   - skip if contains punctuation: : , ( ) ! ? / 0-9 at start
  #   - skip if term contains no latin chars after slug conversion (slug would be empty)
  #   - skip if matches .lint-ignore-terms allow-list at project root

  IGNORE_FILE="$ROOT/.lint-ignore-terms"
  # Build grep pattern from ignore file if it exists
  IGNORE_PATTERN=""
  if [[ -f "$IGNORE_FILE" ]]; then
    # Each line in ignore file is a term to exclude (case-insensitive)
    IGNORE_PATTERN=$(grep -v '^#' "$IGNORE_FILE" 2>/dev/null | grep -v '^[[:space:]]*$' | tr '\n' '|' | sed 's/|$//')
  fi

  while IFS= read -r -d '' f; do
    while IFS= read -r term; do
      # Heuristic 1: Skip if term contains sentence-level punctuation
      if echo "$term" | grep -qE '[,;():!?/]|^\d|^[0-9]'; then
        continue
      fi

      # Heuristic 2: Skip if term starts with a number or numbered list
      if echo "$term" | grep -qE '^[0-9]+[\.\)]'; then
        continue
      fi

      # Convert to slug
      slug=$(echo "$term" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | sed 's/-*$//' | sed 's/^-*//')

      # Heuristic 3: Slug length between 5 and 35 chars
      # (too short = common word or abbreviation, too long = sentence fragment)
      if [[ ${#slug} -lt 5 || ${#slug} -gt 35 ]]; then
        continue
      fi

      # Heuristic 4: Skip if slug has <3 latin chars (purely non-latin/special chars term)
      latin_count=$(echo "$slug" | tr -cd 'a-z' | wc -c | tr -d ' ')
      if [[ $latin_count -lt 3 ]]; then
        continue
      fi

      # Heuristic 5: Check against allow-list / ignore file
      if [[ -n "$IGNORE_PATTERN" ]] && echo "$term" | grep -qiE "$IGNORE_PATTERN"; then
        continue
      fi

      # Only report if concept file doesn't exist
      if ! find "$WIKI/concepts" -name "${slug}.md" 2>/dev/null | grep -q .; then
        echo "  MISSING CONCEPT: \"$term\" (slug: $slug) in ${f#$ROOT/}"
        IMPUTE_CANDIDATES+=("$term")
      fi
    done < <(grep -oE '\*\*[^*]{4,60}\*\*' "$f" 2>/dev/null | sed 's/\*\*//g' | while IFS= read -r term; do
      # Pre-filter: original term must be ≥60% ASCII printable chars
      # This catches mixed-Latin text (e.g. non-ASCII languages) → mostly non-ASCII
      total_chars=$(echo -n "$term" | wc -c | tr -d ' ')
      ascii_chars=$(echo -n "$term" | tr -cd '[:print:]' | tr -cd 'a-zA-Z0-9 ._-' | wc -c | tr -d ' ')
      if [[ $total_chars -gt 0 ]]; then
        # Use awk for float comparison
        ratio=$(awk "BEGIN {printf \"%.0f\", ($ascii_chars / $total_chars) * 100}")
        [[ $ratio -lt 60 ]] && continue
      fi
      # Pre-filter: term word count ≤ 5 (longer = sentence, not concept name)
      word_count=$(echo "$term" | wc -w | tr -d ' ')
      [[ $word_count -gt 5 ]] && continue
      echo "$term"
    done | sort -u)
  done < <(find "$WIKI/concepts" "$WIKI/topics" -name "*.md" -print0 2>/dev/null)

  _section "5. Domains with no concepts"
  while IFS= read -r -d '' f; do
    domain=$(basename "$f" .md)
    [[ "$domain" == _* ]] && continue
    count=$(grep -c '\[\[concepts/' "$f" 2>/dev/null) || count=0
    if [[ "$count" -eq 0 ]]; then
      echo "  EMPTY DOMAIN: $domain — no concepts yet"
      ((ISSUES++)) || true
    elif [[ "$count" -lt 3 ]]; then
      echo "  THIN DOMAIN: $domain — only $count concept(s)"
    fi
  done < <(find "$WIKI/domains" -name "*.md" -print0 2>/dev/null)

  _section "6. Domain stats — concepts per domain"
  declare -A domain_count
  while IFS= read -r -d '' f; do
    dom=$(grep -m1 "^domain:" "$f" 2>/dev/null | sed 's/domain: *//' | tr -d '[:space:]') || true
    if [[ -n "$dom" ]]; then
      domain_count["$dom"]=$(( ${domain_count["$dom"]:-0} + 1 ))
    else
      domain_count["(unassigned)"]=$(( ${domain_count["(unassigned)"]:-0} + 1 ))
      echo "  NO DOMAIN FIELD: ${f#$ROOT/}"
      ((ISSUES++)) || true
    fi
  done < <(find "$WIKI/concepts" -name "*.md" -print0 2>/dev/null)
  for dom in $(echo "${!domain_count[@]}" | tr ' ' '\n' | sort); do
    cnt="${domain_count[$dom]}"
    moc="$WIKI/domains/${dom}.md"
    if [[ "$dom" == "(unassigned)" ]]; then
      echo "  ⚠️  (unassigned): $cnt concepts missing domain: field"
    elif [[ -f "$moc" ]]; then
      echo "  ✅ $dom: $cnt concepts → domains/${dom}.md exists"
    else
      if [[ "$cnt" -ge 10 ]]; then
        echo "  🆕 $dom: $cnt concepts — ≥10 reached → CREATE domains/${dom}.md"
        ((ISSUES++)) || true
      else
        echo "  📂 $dom: $cnt concepts — not enough for domain MOC yet (need $((10 - cnt)) more)"
      fi
    fi
  done

  _section "7. Tag clusters — potential domain detection"
  declare -A tag_count
  while IFS= read -r -d '' f; do
    tags_line=$(grep -m1 "^tags:" "$f" 2>/dev/null || true)
    if [[ -n "$tags_line" ]]; then
      # Handle both inline [a, b] and multiline - item formats
      tags=$(echo "$tags_line" | grep -oE '[a-z][a-z0-9-]+' | grep -vE '^(tags|domain|type|source|created|updated|title)$' || true)
    fi
    # Also capture multiline tags (- item format)
    ml_tags=$(awk '/^tags:/,/^[a-z]/' "$f" 2>/dev/null | grep '^\s*-' | sed 's/.*- *//' | tr -d '"' || true)
    for tag in $tags $ml_tags; do
      [[ ${#tag} -gt 3 ]] && tag_count["$tag"]=$(( ${tag_count["$tag"]:-0} + 1 ))
    done
  done < <(find "$WIKI/concepts" -name "*.md" -print0 2>/dev/null)
  echo "  Top tags (≥3 concepts, potential domain candidates):"
  found_cluster=0
  for tag in $(echo "${!tag_count[@]}" | tr ' ' '\n' | sort); do
    cnt="${tag_count[$tag]}"
    if [[ "$cnt" -ge 3 ]]; then
      moc="$WIKI/domains/${tag}.md"
      if [[ ! -f "$moc" ]]; then
        echo "  📌 [$cnt concepts] tag: $tag → no domain MOC yet"
        found_cluster=1
      fi
    fi
  done
  [[ $found_cluster -eq 0 ]] && echo "  (no new tag clusters above threshold)"

  _section "8. Stale domain MOCs — concepts not listed in domain file"
  while IFS= read -r -d '' f; do
    name="$(basename "$f" .md)"
    dom=$(grep -m1 "^domain:" "$f" 2>/dev/null | sed 's/domain: *//' | tr -d '[:space:]') || true
    [[ -z "$dom" || "$dom" == "meta" ]] && continue
    moc="$WIKI/domains/${dom}.md"
    if [[ -f "$moc" ]] && ! grep -q "\[\[concepts/$name\]\]" "$moc" 2>/dev/null; then
      echo "  STALE MOC: [[concepts/$name]] (domain: $dom) not listed in domains/${dom}.md"
      ((ISSUES++)) || true
    fi
  done < <(find "$WIKI/concepts" -name "*.md" -print0 2>/dev/null)

  _section "9. Bridge note candidates (concepts appearing in ≥2 domains)"
  declare -A concept_domains
  while IFS= read -r -d '' df; do
    domain=$(basename "$df" .md)
    [[ "$domain" == _* ]] && continue
    while IFS= read -r link; do
      link_clean="${link%%|*}"
      link_name="${link_clean##*/}"
      concept_domains["$link_name"]+="$domain "
    done < <(grep -oE '\[\[concepts/[^]|#]+' "$df" 2>/dev/null | sed 's/\[\[concepts\///')
  done < <(find "$WIKI/domains" -name "*.md" -print0 2>/dev/null)
  found_bridge=0
  for concept in "${!concept_domains[@]}"; do
    domains="${concept_domains[$concept]}"
    count=$(echo "$domains" | wc -w | tr -d ' ')
    if [[ "$count" -ge 2 ]]; then
      echo "  BRIDGE CANDIDATE: [[concepts/$concept]] → domains: $domains"
      found_bridge=1
    fi
  done
  [[ $found_bridge -eq 0 ]] && echo "  (none yet — need more content)"

  _section "10. Potential duplicate concepts (tag overlap ≥60%)"
  declare -A concept_tags_arr
  while IFS= read -r -d '' f; do
    name="$(basename "$f" .md)"
    tags_line=$(grep -m1 "^tags:" "$f" 2>/dev/null || true)
    if [[ -n "$tags_line" ]]; then
      tags=$(echo "$tags_line" | tr -d '[]"' | sed 's/tags://' | tr ',' '\n' | sed 's/^ *//' | grep -E '^[a-z]' | sort -u | tr '\n' ',' | sed 's/,$//')
      concept_tags_arr["$name"]="$tags"
    fi
  done < <(find "$WIKI/concepts" -name "*.md" -print0 2>/dev/null)

  found_dup=0
  names=("${!concept_tags_arr[@]}")
  for ((i=0; i<${#names[@]}; i++)); do
    for ((j=i+1; j<${#names[@]}; j++)); do
      a="${names[$i]}"
      b="${names[$j]}"
      IFS=',' read -ra ta <<< "${concept_tags_arr[$a]}"
      IFS=',' read -ra tb <<< "${concept_tags_arr[$b]}"
      overlap=0
      for x in "${ta[@]}"; do
        for y in "${tb[@]}"; do
          [[ "$x" == "$y" ]] && ((overlap++)) || true
        done
      done
      min_t=${#ta[@]}
      [[ ${#tb[@]} -lt $min_t ]] && min_t=${#tb[@]}
      if [[ $min_t -ge 3 && $overlap -ge 3 ]]; then
        pct=$((overlap * 100 / min_t))
        if [[ $pct -ge 60 ]]; then
          echo "  OVERLAP ($pct%): $a ↔ $b (shared $overlap of min $min_t tags)"
          ((ISSUES++)) || true
          found_dup=1
        fi
      fi
    done
  done
  [[ $found_dup -eq 0 ]] && echo "  (no suspicious overlaps found)"
}

# --- QUICK mode (single-file evaluator) ---
if [[ "${1:-}" == "--quick" ]]; then
  TARGET="${2:-}"
  if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 --quick <wiki-file>"
    echo "Example: $0 --quick wiki/summaries/attention-is-all-you-need.md"
    exit 1
  fi
  FULL="$ROOT/$TARGET"
  if [[ ! -f "$FULL" ]]; then
    echo "File not found: $FULL"
    exit 1
  fi

  QUICK_ISSUES=0
  echo "=== QUICK LINT: $TARGET ==="

  # Check 1: Frontmatter exists
  if ! head -1 "$FULL" | grep -q "^---"; then
    echo "  ❌ MISSING FRONTMATTER"
    ((QUICK_ISSUES++)) || true
  else
    # Check required frontmatter fields
    for field in title domain tags created source confidence; do
      if ! awk '/^---$/{n++; next} n==1' "$FULL" | grep -q "^${field}:"; then
        echo "  ⚠️  MISSING FIELD: $field"
        ((QUICK_ISSUES++)) || true
      fi
    done
  fi

  # Check 2: Broken wikilinks
  while IFS= read -r link; do
    link_clean="${link%%|*}"
    link_clean="${link_clean%%#*}"
    link_clean="${link_clean##*/}"
    if ! find "$WIKI" -name "${link_clean}.md" 2>/dev/null | grep -q .; then
      echo "  ❌ BROKEN LINK: [[${link_clean}]]"
      ((QUICK_ISSUES++)) || true
    fi
  done < <(grep -oE '\[\[[^]]+\]\]' "$FULL" 2>/dev/null | sed 's/\[\[//;s/\]\]//')

  # Check 3: Domain field value has a corresponding MOC (warning only)
  dom=$(grep -m1 "^domain:" "$FULL" 2>/dev/null | sed 's/domain: *//' | tr -d '[:space:]"' || true)
  if [[ -n "$dom" && "$dom" != "meta" && ! -f "$WIKI/domains/${dom}.md" ]]; then
    echo "  ⚠️  DOMAIN '$dom' has no MOC file (domains/${dom}.md)"
  fi

  if [[ $QUICK_ISSUES -eq 0 ]]; then
    echo "  ✅ All checks passed"
  else
    echo "  → $QUICK_ISSUES issue(s) found"
  fi
  exit 0
fi

# --- IMPUTE mode ---
if [[ "${1:-}" == "--impute" ]]; then
  echo "=== IMPUTE CANDIDATES — use web search to fill gaps ==="
  echo ""
  echo "Run this command in Claude Code to impute each topic:"
  echo ""
  run_checks 2>/dev/null | grep -E "BROKEN|MISSING CONCEPT" | while read -r line; do
    term=$(echo "$line" | grep -oE '"[^"]+"|\[\[[^]]+' | head -1 | tr -d '"[' | sed 's/\[\[//')
    [[ -n "$term" ]] && echo "  web-impute: $term"
  done
  exit 0
fi

# --- SAVE mode ---
if [[ "${1:-}" == "--save" ]]; then
  OUTFILE="$ROOT/outputs/notes/lint-$DATE.md"
  {
    echo "---"
    echo "title: \"Lint Report $DATE\""
    echo "tags: [lint, meta]"
    echo "created: $DATE"
    echo "---"
    echo ""
    echo "# Wiki Lint Report — $DATE"
    echo ""
    run_checks
    echo ""
    echo "## Impute Queue"
    echo ""
    echo "The following topics have no content yet — Claude should use web search to impute:"
    echo ""
    # Deduplicate
    printf '%s\n' "${IMPUTE_CANDIDATES[@]}" 2>/dev/null | sort -u | while read -r c; do
      [[ -n "$c" ]] && echo "- [ ] \`web-impute: $c\`"
    done
    echo ""
    echo "---"
    echo "Total issues: $ISSUES"
  } > "$OUTFILE"
  echo "Saved: $OUTFILE"
  exit 0
fi

# --- DEFAULT: terminal output ---
echo "=== WIKI LINT — $DATE ==="
run_checks
echo ""
echo "=== TOTAL: $ISSUES issues ==="
[[ $ISSUES -eq 0 ]] && echo "Wiki is clean."
echo ""
echo "Run with --save to save report, --impute to see the web search queue"
