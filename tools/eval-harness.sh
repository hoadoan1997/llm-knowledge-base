#!/usr/bin/env bash
# eval-harness.sh — System-level harness eval: context budget, hooks, wiki health
# Usage: ./tools/eval-harness.sh [--save]
# Run before/after upgrades to measure improvement. Compare outputs to track regressions.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS="$ROOT/.claude/settings.json"
AGENTS_FILE="$ROOT/AGENTS.md"
CLAUDE_FILE="$ROOT/CLAUDE.md"

PASS=0; FAIL=0; WARN=0

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; RESET='\033[0m'; BOLD='\033[1m'
pass() { printf "${GREEN}  ✅ PASS${RESET} %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "${RED}  ❌ FAIL${RESET} %s\n" "$1"; FAIL=$((FAIL+1)); }
warn() { printf "${YELLOW}  ⚠️  WARN${RESET} %s\n" "$1"; WARN=$((WARN+1)); }
info() { printf "       ℹ️  %s\n" "$1"; }
header() { printf "\n${BOLD}%s${RESET}\n" "$1"; }

printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${BOLD}  Harness Eval — %s${RESET}\n" "$(date +%Y-%m-%d)"
printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"

# ─── CHECK 1: Context budget ────────────────────────────────────────────────
header "CHECK 1 — Context budget (always-loaded files ≤ 250 lines)"

CLAUDE_LINES=$(wc -l < "$CLAUDE_FILE" | tr -d ' ')
AGENTS_LINES=$(wc -l < "$AGENTS_FILE" | tr -d ' ')
TOTAL_LINES=$((CLAUDE_LINES + AGENTS_LINES))

info "CLAUDE.md:  $CLAUDE_LINES lines"
info "AGENTS.md:  $AGENTS_LINES lines"
info "Total:      $TOTAL_LINES lines"

if [ "$TOTAL_LINES" -le 250 ]; then
  pass "Context budget OK — $TOTAL_LINES lines (≤ 250 target)"
elif [ "$TOTAL_LINES" -le 350 ]; then
  warn "Context budget elevated — $TOTAL_LINES lines (target ≤ 250)"
else
  fail "Context budget exceeded — $TOTAL_LINES lines (target ≤ 250)"
fi

# ─── CHECK 2: Hook presence ──────────────────────────────────────────────────
header "CHECK 2 — Hook presence (PreToolUse, PostToolUse, Stop required)"

if [ ! -f "$SETTINGS" ]; then
  fail "settings.json not found at $SETTINGS"
else
  has_pre=$(grep -c '"PreToolUse"' "$SETTINGS" || true)
  has_post=$(grep -c '"PostToolUse"' "$SETTINGS" || true)
  has_stop=$(grep -c '"Stop"' "$SETTINGS" || true)
  has_session=$(grep -c '"SessionStart"' "$SETTINGS" || true)
  has_userprompt=$(grep -c '"UserPromptSubmit"' "$SETTINGS" || true)

  [ "$has_pre"  -gt 0 ] && pass "PreToolUse hook present"  || fail "PreToolUse hook MISSING"
  [ "$has_post" -gt 0 ] && pass "PostToolUse hook present" || fail "PostToolUse hook MISSING"
  [ "$has_stop" -gt 0 ] && pass "Stop hook present"        || fail "Stop hook MISSING"
  [ "$has_session" -gt 0 ] && pass "SessionStart hook present (compact recovery)" \
                            || warn "SessionStart hook MISSING — no compact recovery"
  [ "$has_userprompt" -gt 0 ] && pass "UserPromptSubmit hook present (compile context injection)" \
                               || warn "UserPromptSubmit hook MISSING — no compile context injection"
fi

# ─── CHECK 3: Hook correctness ───────────────────────────────────────────────
header "CHECK 3 — Hook correctness (key behaviors wired)"

if [ -f "$SETTINGS" ]; then
  # PreToolUse should inject .local-rules.md for wiki writes
  if grep -q "local-rules" "$SETTINGS"; then
    pass "PreToolUse — .local-rules.md injection wired"
  else
    warn "PreToolUse — no .local-rules.md injection (style rules won't auto-inject)"
  fi

  # PostToolUse should run build-index.py after wiki edits
  if grep -q "build-index" "$SETTINGS"; then
    pass "PostToolUse — build-index.py wired (index auto-rebuilds)"
  else
    fail "PostToolUse — build-index.py NOT wired (index will drift)"
  fi

  # Stop hook should check pending file-backs
  if grep -q "file-back" "$SETTINGS"; then
    pass "Stop hook — file-back.sh check wired"
  else
    warn "Stop hook — no file-back.sh check (pending outputs may be missed)"
  fi

  # Stop or SessionStart should save/restore session state
  if grep -q "session-state\|llm-kb-session\|compile-progress" "$SETTINGS"; then
    pass "Session state persistence wired (compact recovery)"
  else
    warn "Session state NOT persisted — context compaction loses active compile context"
  fi

  # PostToolUse should track wiki edit count for mid-session lint reminder
  if grep -q "llm-kb-wiki-edits\|wiki-edits\|edit.*counter\|COUNT.*wiki" "$SETTINGS"; then
    pass "PostToolUse — wiki edit counter wired (mid-session lint reminder)"
  else
    warn "PostToolUse — no edit counter (no mid-session lint reminder after 5 edits)"
  fi

  # UserPromptSubmit should inject compile context
  if grep -q "Compile Context\|compile raw\|scan.*info" "$SETTINGS"; then
    pass "UserPromptSubmit — compile context injection wired"
  else
    warn "UserPromptSubmit — no compile context injection"
  fi
fi

# ─── CHECK 4: Resolver integrity ─────────────────────────────────────────────
header "CHECK 4 — Resolver paths in AGENTS.md exist on disk"

while IFS= read -r line; do
  path=$(echo "$line" | grep -oE 'skills/[^` |)]+' | head -1 | sed 's/[`| )]//g')
  [ -z "$path" ] && continue
  full="$ROOT/$path"
  if [ -f "$full" ]; then
    pass "$path ✓"
  else
    fail "$path — NOT FOUND (broken resolver link)"
  fi
done < <(grep "skills/" "$AGENTS_FILE" 2>/dev/null || true)

# ─── CHECK 5: Research skill quality ─────────────────────────────────────────
header "CHECK 5 — Research skill quality (template + limits)"

RESEARCH_SKILL="$ROOT/skills/research-pipeline.md"
if [ ! -f "$RESEARCH_SKILL" ]; then
  fail "research-pipeline.md not found"
else
  # Structured output template
  if grep -qiE "Executive Summary|executive summary|## Output Format|## Report" "$RESEARCH_SKILL"; then
    pass "research-pipeline.md — structured output template present"
  else
    warn "research-pipeline.md — no structured output template (agents return freeform dumps)"
  fi

  # Max search limits
  if grep -qiE "max [0-9]|maximum [0-9]|≤ [0-9]+ search|limit.*search|search.*limit" "$RESEARCH_SKILL"; then
    pass "research-pipeline.md — explicit search limits defined"
  else
    warn "research-pipeline.md — no max search limits (agents may run unbounded WebSearch)"
  fi

  # Agent output format brief
  if grep -qiE "Agent.*Output|Output.*Format|structured.*finding|key claims" "$RESEARCH_SKILL"; then
    pass "research-pipeline.md — agent output format specified"
  else
    warn "research-pipeline.md — agent output format not specified (context overflow risk)"
  fi
fi

# ─── CHECK 6: Compile pipeline ───────────────────────────────────────────────
header "CHECK 6 — Compile pipeline tools exist"

TOOLS="scan.sh finalize-compile.sh build-index.py lint.sh impute.sh file-back.sh"
for t in $TOOLS; do
  if [ -f "$ROOT/tools/$t" ]; then
    pass "tools/$t ✓"
  else
    fail "tools/$t — NOT FOUND"
  fi
done

# ─── CHECK 7: Wiki structure ─────────────────────────────────────────────────
header "CHECK 7 — Wiki structure (required dirs + files)"

for d in wiki/concepts wiki/summaries wiki/domains; do
  if [ -d "$ROOT/$d" ]; then
    count=$(ls "$ROOT/$d"/*.md 2>/dev/null | wc -l | tr -d ' ')
    pass "$d/ exists ($count files)"
  else
    fail "$d/ missing"
  fi
done

for f in wiki/index.md wiki/_brief.md; do
  if [ -f "$ROOT/$f" ]; then
    pass "$f exists"
  else
    warn "$f missing (run: python3 tools/build-index.py)"
  fi
done

# ─── CHECK 8: .cjs hooks syntax ──────────────────────────────────────────────
header "CHECK 8 — Hook file syntax (any .cjs hooks)"

CJS_COUNT=0
while IFS= read -r f; do
  CJS_COUNT=$((CJS_COUNT+1))
  if node --check "$f" 2>/dev/null; then
    pass "$(basename "$f") — syntax OK"
  else
    fail "$(basename "$f") — syntax ERROR"
  fi
done < <(find "$ROOT/.claude/hooks" -name "*.cjs" 2>/dev/null || true)

[ "$CJS_COUNT" -eq 0 ] && pass "No .cjs hooks (bash-only — OK for current scale)"

# ─── CHECK 9: Wiki concept line limits ───────────────────────────────────────
header "CHECK 9 — Wiki concept file sizes (≤ 150 lines)"

CONCEPTS_DIR="$ROOT/wiki/concepts"
OVER=0; TOTAL_CONCEPTS=0
if [ -d "$CONCEPTS_DIR" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    lines=$(wc -l < "$f" | tr -d ' ')
    TOTAL_CONCEPTS=$((TOTAL_CONCEPTS+1))
    if [ "$lines" -gt 150 ]; then
      warn "$(basename "$f") — $lines lines (over 150 limit)"
      OVER=$((OVER+1))
    fi
  done < <(find "$CONCEPTS_DIR" -name "*.md" 2>/dev/null | sort)
  WITHIN=$((TOTAL_CONCEPTS - OVER))
  pass "$WITHIN/$TOTAL_CONCEPTS concept files within 150-line limit"
  info "$TOTAL_CONCEPTS total concepts in wiki"
fi

# ─── CHECK 10: Lint quick snapshot ───────────────────────────────────────────
header "CHECK 10 — Lint snapshot (random concept spot-check)"

CONCEPTS_DIR="$ROOT/wiki/concepts"
if [ -d "$CONCEPTS_DIR" ]; then
  SAMPLE=$(find "$CONCEPTS_DIR" -name "*.md" 2>/dev/null | sort | head -1)
  if [ -n "$SAMPLE" ] && [ -f "$ROOT/tools/lint.sh" ]; then
    rel="${SAMPLE#$ROOT/}"
    result=$(cd "$ROOT" && bash tools/lint.sh --quick "$rel" 2>/dev/null | tail -3)
    if echo "$result" | grep -q "PASS\|OK\|pass\|0 issue"; then
      pass "Lint spot-check — $(basename "$SAMPLE") clean"
    elif echo "$result" | grep -q "WARN\|warn"; then
      warn "Lint spot-check — $(basename "$SAMPLE") has warnings"
    elif [ -z "$result" ]; then
      warn "Lint spot-check — no output from lint.sh --quick (may not support --quick flag yet)"
    else
      warn "Lint spot-check — $(basename "$SAMPLE"): $result"
    fi
  else
    warn "Lint spot-check skipped — no concepts found or lint.sh missing"
  fi
fi

# ─── SUMMARY ─────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL + WARN))
printf "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${BOLD}  RESULTS${RESET}  total=%d  ${GREEN}pass=%d${RESET}  ${RED}fail=%d${RESET}  ${YELLOW}warn=%d${RESET}\n" \
  "$TOTAL" "$PASS" "$FAIL" "$WARN"
printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"

if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
  printf "${GREEN}  All checks passed.${RESET}\n"
elif [ "$FAIL" -eq 0 ]; then
  printf "${YELLOW}  No hard failures. %d warning(s) = upgrade targets.${RESET}\n" "$WARN"
else
  printf "${RED}  %d failure(s) require attention before upgrades.${RESET}\n" "$FAIL"
fi

if [ "${1:-}" = "--save" ]; then
  DATE=$(date +%Y-%m-%d)
  OUT="$ROOT/outputs/notes/eval-harness-$DATE.md"
  mkdir -p "$(dirname "$OUT")"
  printf -- "---\ntitle: \"Harness Eval — %s\"\ncreated: %s\n---\n\n# Harness Eval — %s\n\n**PASS=%d  FAIL=%d  WARN=%d  TOTAL=%d**\n\nRun: \`./tools/eval-harness.sh\`\n\n## Upgrade Targets (WARNs)\n\nWARNs in this baseline = items targeted by v0.5.0 upgrade plan.\nRe-run after each phase to track progress.\n" \
    "$DATE" "$DATE" "$DATE" "$PASS" "$FAIL" "$WARN" "$TOTAL" > "$OUT"
  printf "  Saved → %s\n" "$OUT"
fi

exit "$FAIL"
