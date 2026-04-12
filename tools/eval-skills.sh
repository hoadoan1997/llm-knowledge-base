#!/usr/bin/env bash
# eval-skills.sh — Evaluate skill files against Claude Code best practices
# Usage: ./tools/eval-skills.sh [--save]

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$ROOT/skills"
AGENTS_FILE="$ROOT/AGENTS.md"

PASS=0; FAIL=0; WARN=0

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; RESET='\033[0m'; BOLD='\033[1m'
pass() { printf "${GREEN}  ✅ PASS${RESET} %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "${RED}  ❌ FAIL${RESET} %s\n" "$1"; FAIL=$((FAIL+1)); }
warn() { printf "${YELLOW}  ⚠️  WARN${RESET} %s\n" "$1"; WARN=$((WARN+1)); }
header() { printf "\n${BOLD}%s${RESET}\n" "$1"; }

printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${BOLD}  Skills Eval — %s${RESET}\n" "$(date +%Y-%m-%d)"
printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"

# Collect all skill files: flat .md files in skills/ and SKILL.md in subdirs
FLAT_SKILLS=$(find "$SKILLS_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | sort)
FOLDER_SKILLS=$(find "$SKILLS_DIR" -mindepth 2 -name "SKILL.md" 2>/dev/null | sort)
ALL_SKILLS="$FLAT_SKILLS
$FOLDER_SKILLS"
ALL_SKILLS=$(echo "$ALL_SKILLS" | grep -v '^$')

echo "  Flat skills:   $(echo "$FLAT_SKILLS" | grep -c '.md' || true)"
echo "  Folder skills: $(echo "$FOLDER_SKILLS" | grep -c 'SKILL.md' || true)"

# ─── CHECK 1: Folder structure ───────────────────────────────────────────────
header "CHECK 1 — Folder structure (progressive disclosure)"

while IFS= read -r f; do
  [ -z "$f" ] && continue
  skill_name=$(basename "$(dirname "$f")")
  ref_dir="$(dirname "$f")/references"
  if [ -d "$ref_dir" ] && [ -n "$(ls -A "$ref_dir" 2>/dev/null)" ]; then
    pass "$skill_name/ — folder with references/ (progressive disclosure ✓)"
  else
    warn "$skill_name/ — folder but no references/ yet"
  fi
done <<EOF
$FOLDER_SKILLS
EOF

while IFS= read -r f; do
  [ -z "$f" ] && continue
  skill_name=$(basename "$f" .md)
  lines=$(wc -l < "$f" | tr -d ' ')
  if [ "$lines" -gt 100 ]; then
    warn "$skill_name.md — $lines lines; consider folder+references/ if content is conditional"
  else
    pass "$skill_name.md — flat file OK ($lines lines, no conditional content)"
  fi
done <<EOF
$FLAT_SKILLS
EOF

# ─── CHECK 2: Frontmatter ────────────────────────────────────────────────────
header "CHECK 2 — Frontmatter (skill + trigger + description)"

while IFS= read -r f; do
  [ -z "$f" ] && continue
  rel="${f#$ROOT/}"
  has_skill=$(grep -c "^skill:" "$f" 2>/dev/null || true)
  has_trigger=$(grep -c "^trigger:" "$f" 2>/dev/null || true)
  has_desc=$(grep -c "^description:" "$f" 2>/dev/null || true)

  if [ "$has_skill" -gt 0 ] && [ "$has_trigger" -gt 0 ] && [ "$has_desc" -gt 0 ]; then
    desc=$(grep "^description:" "$f" | head -1)
    if echo "$desc" | grep -qiE '"Use when|"Load when'; then
      pass "$rel — frontmatter complete, description is trigger condition ✓"
    else
      warn "$rel — frontmatter present but description may not be a trigger condition"
    fi
  else
    [ "$has_skill" -eq 0 ]   && fail "$rel — missing 'skill:' field"
    [ "$has_trigger" -eq 0 ] && fail "$rel — missing 'trigger:' field"
    [ "$has_desc" -eq 0 ]    && fail "$rel — missing 'description:' field"
  fi
done <<EOF
$ALL_SKILLS
EOF

# ─── CHECK 3: Gotchas section ────────────────────────────────────────────────
header "CHECK 3 — Gotchas section (highest-signal content per article)"

while IFS= read -r f; do
  [ -z "$f" ] && continue
  rel="${f#$ROOT/}"
  has_gotchas=$(grep -c "^## Gotchas" "$f" 2>/dev/null || true)
  if [ "$has_gotchas" -gt 0 ]; then
    count=$(awk '/^## Gotchas/{found=1} found && /^\*\*/{c++} END{print c+0}' "$f")
    if [ "$count" -ge 3 ]; then
      pass "$rel — Gotchas section with $count entries ✓"
    else
      warn "$rel — Gotchas section exists but only $count entries (aim for ≥3)"
    fi
  else
    fail "$rel — missing Gotchas section"
  fi
done <<EOF
$ALL_SKILLS
EOF

# ─── CHECK 4: No railroading ─────────────────────────────────────────────────
header "CHECK 4 — No railroading (not duplicating AGENTS.md checklist)"

while IFS= read -r f; do
  [ -z "$f" ] && continue
  rel="${f#$ROOT/}"
  # Look for numbered step lists or checkbox checklists that mirror AGENTS.md
  checklist_lines=$(grep -cE "^\[ \] [0-9]+\.|^[0-9]+\. \*\*Check which|^\- \[ \] [0-9]" "$f" 2>/dev/null || true)
  if [ "$checklist_lines" -ge 3 ]; then
    fail "$rel — contains $checklist_lines checklist lines that may duplicate AGENTS.md"
  else
    pass "$rel — no checklist duplication detected"
  fi
done <<EOF
$ALL_SKILLS
EOF

# ─── CHECK 5: Resolver paths ─────────────────────────────────────────────────
header "CHECK 5 — AGENTS.md resolver paths exist"

while IFS= read -r line; do
  path=$(echo "$line" | grep -oE 'skills/[^` |]+' | head -1 | sed 's/[`| ]//g')
  [ -z "$path" ] && continue
  full="$ROOT/$path"
  if [ -f "$full" ]; then
    pass "$path ✓"
  else
    fail "$path — NOT FOUND (broken resolver link)"
  fi
done < <(grep "skills/" "$AGENTS_FILE" 2>/dev/null || true)

# ─── CHECK 6: Line count ─────────────────────────────────────────────────────
header "CHECK 6 — Line count (target ≤ 120 per file)"

while IFS= read -r f; do
  [ -z "$f" ] && continue
  rel="${f#$ROOT/}"
  lines=$(wc -l < "$f" | tr -d ' ')
  if [ "$lines" -le 120 ]; then
    pass "$rel — $lines lines ✓"
  else
    warn "$rel — $lines lines (over 120; consider splitting)"
  fi
done <<EOF
$ALL_SKILLS
EOF

# ─── CHECK 7: References linked in SKILL.md exist ───────────────────────────
header "CHECK 7 — References linked from SKILL.md files exist on disk"

while IFS= read -r f; do
  [ -z "$f" ] && continue
  rel="${f#$ROOT/}"
  dir=$(dirname "$f")
  # Only match bare references/ (local), not cross-skill paths like skills/foo/references/
  refs=$(grep -oE '[^/a-z]references/[a-z0-9_-]+\.md' "$f" 2>/dev/null | grep -oE 'references/[a-z0-9_-]+\.md' || true)
  if [ -z "$refs" ]; then
    pass "$rel — no references/ links (n/a)"
    continue
  fi
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    if [ -f "$dir/$ref" ]; then
      pass "$rel → $ref exists ✓"
    else
      fail "$rel → references '$ref' but file NOT FOUND"
    fi
  done <<REFS
$refs
REFS
done <<EOF
$ALL_SKILLS
EOF

# ─── SUMMARY ─────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL + WARN))
printf "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${BOLD}  RESULTS${RESET}  total=%d  ${GREEN}pass=%d${RESET}  ${RED}fail=%d${RESET}  ${YELLOW}warn=%d${RESET}\n" \
  "$TOTAL" "$PASS" "$FAIL" "$WARN"
printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"

if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
  printf "${GREEN}  All checks passed.${RESET}\n"
elif [ "$FAIL" -eq 0 ]; then
  printf "${YELLOW}  No hard failures. %d warning(s) to review.${RESET}\n" "$WARN"
else
  printf "${RED}  %d failure(s) require attention.${RESET}\n" "$FAIL"
fi

if [ "${1:-}" = "--save" ]; then
  DATE=$(date +%Y-%m-%d)
  OUT="$ROOT/outputs/notes/eval-skills-$DATE.md"
  mkdir -p "$(dirname "$OUT")"
  printf -- "---\ntitle: \"Skills Eval — %s\"\ncreated: %s\n---\n\n# Skills Eval — %s\n\n**PASS=%d  FAIL=%d  WARN=%d  TOTAL=%d**\n\nRun: \`./tools/eval-skills.sh\`\n" \
    "$DATE" "$DATE" "$DATE" "$PASS" "$FAIL" "$WARN" "$TOTAL" > "$OUT"
  printf "  Saved → %s\n" "$OUT"
fi

exit "$FAIL"
