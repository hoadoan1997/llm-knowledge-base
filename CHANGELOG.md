# Changelog

All notable changes to this project will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-05-16

### Added — `html:` command (Markdown → self-contained HTML)

New command for converting any Markdown document into a polished, self-contained HTML page — ideal for sharing reports externally.

**Problem solved**: Markdown reports are unreadable outside a code editor. `html:` converts them into a single `.html` file with TOC sidebar, Mermaid diagrams, step timelines, callouts, comparison cards, light/dark theme, and print-to-PDF support. Zero install for the recipient — open the file in any browser.

**`skills/md2html/`** (new — bundled from [haidang1810/md2html](https://github.com/haidang1810/md2html), MIT):
- `SKILL.md` — full instructions: language detection, component mapping, placeholder replacement
- `template.html` — self-contained HTML skeleton with embedded CSS (Claude orange theme), Mermaid CDN, theme toggle, TOC sidebar, scroll progress, print stylesheet
- `components.md` — catalog of HTML snippets (timelines, callouts, pros-cons, comparison cards, collapsibles, key-point highlights, Mermaid blocks)
- `examples/` — reference pairs for output calibration
- Multi-language auto-detection: EN, VI, ZH, JA, KO, ES, FR, DE (UI labels translated automatically)
- WCAG AA compliant: contrast, touch targets, reduced-motion, focus-visible, skip-to-content

**`AGENTS.md`**: `html:` resolver updated from "system skill" to `skills/md2html/SKILL.md` (project-local, no global dependency).

**`CLAUDE.md`**: added `html: <file.md>` to Quick Commands.

**`outputs/html/`**: new output directory (gitignored, `.gitkeep` tracked).

---

### Changed — `skills/last30days/` (project-native, was global-only)

Before: `skills/last30days/SKILL.md` Phase 2 hardcoded global plugin paths at `~/.claude/plugins/`.  
After: Phase 2 checks `skills/last30days/scripts/` first (project-local), then falls back to global paths.

- `skills/last30days/scripts/` is gitignored (proprietary marketplace plugin, cannot redistribute)
- Setup instructions added to SKILL.md Gotchas: `cp -r ~/.claude/plugins/cache/last30days-skill/last30days/*/scripts skills/last30days/scripts`
- Users without the plugin still get WebSearch-only fallback — skill degrades gracefully

---

### Added — `news:` command (last-30-days social research pipeline)

New command for researching recent news, trends, and social sentiment across Reddit, YouTube, Hacker News, and Polymarket — with automatic wiki filing.

**Problem solved**: `research:` builds timeless, structured knowledge from docs and papers. It doesn't capture ephemeral social signals — what people are discussing on Reddit right now, what's trending on HN, what Polymarket is pricing. `news:` fills this gap for time-sensitive topics.

**`skills/last30days/SKILL.md`** (new):
- Wraps the global `last30days` plugin (v2.9.5 by mvanhorn) already installed at `~/.claude/plugins/`
- **Phase 1**: Parse topic + classify QUERY_TYPE (NEWS / RECOMMENDATIONS / COMPARISON / GENERAL)
- **Phase 2**: Run `last30days.py` script → Reddit, YouTube, HN, Polymarket (available without extra API keys); X/Twitter and TikTok available with optional API keys
- **Phase 3**: Synthesize "What I learned" + stats block with source attributions and engagement metrics
- **Phase 4 (wiki filing)**: Auto-creates `wiki/summaries/news-{topic}-{date}.md` + runs `finalize-compile.sh` — research persisted into knowledge base
- Source availability: Reddit ✅, YouTube ✅ (yt-dlp), HN ✅, Polymarket ✅ | X ❌ (needs AUTH_TOKEN/XAI_API_KEY), TikTok/Instagram ❌ (needs SCRAPECREATORS_API_KEY)

**`AGENTS.md`**: added `news: <topic>` and `news <topic>` (no-colon natural-language form) rows to Workflow Triggers table.

**`CLAUDE.md`**: added `news: <topic>` to Research & Maintain commands section.

**Design distinction from `research:`**:
- `research:` → parallel 3-agent wiki build, timeless structured knowledge, outputs `wiki/concepts/` + `wiki/summaries/`
- `news:` → social pulse + recent events, time-sensitive, outputs `wiki/summaries/news-*`

---

### Added — `fetch-url:` command (web content extraction)

New tool for fetching web pages directly into the compile pipeline, replacing the Obsidian Web Clipper for JS-heavy or data-rich pages.

**Problem solved**: Obsidian Web Clipper is a static HTML parser — it cannot execute JavaScript. Any content rendered by React/Vue (benchmark tables, tabbed charts, dynamic data) is invisible to it. Discovered when the Claude Opus 4.7 announcement article was missing the full benchmark table and 28 early-access tester quotes after clipping.

**`tools/fetch-url.sh` + `tools/fetch-url.py`** (new):
- **Auto-strategy**: try static fetch (`requests` + `markdownify`) first; if word count < 200 → fall back to `r.jina.ai` (handles JS-rendered pages). No manual decision needed.
- **URL rewriting**: decodes Next.js `/_next/image?url=<encoded>` wrappers → direct CDN URLs. Relative paths → absolute. SVG logos stripped.
- **Strip footer noise**: removes "Related content", "Related articles", footer link sections from markdown output.
- **Auto-chain `fetch-images.sh`**: runs automatically after save — no manual step needed.
- **Filter decorative images**: after download, drops images < 80KB (banners, icons, logos). Charts and data tables are typically 100KB+. Logs kept vs. dropped count.
- **Zero new dependencies**: uses `markdownify`, `bs4`, `lxml`, `requests` already in `tools/.venv`.
- Flags: `--force-jina` (skip static, use Jina directly), `--dry-run` (preview without saving).

**`AGENTS.md`**: added `fetch-url: <url> [name]` row to Workflow Triggers table.

**`CLAUDE.md`**: added `fetch-url:` to Quick Commands (Ingest section) and CLI Tools reference.

**`skills/compile-ingest/SKILL.md`**: added `fetch-url:` to trigger line + new section explaining strategy selection and flags.

**Result on Anthropic product pages** (benchmark):
- Obsidian clip: ~1,400 words, 0 chart images readable
- `fetch-url`: ~3,000 words, benchmark table + data charts downloaded and readable by Claude vision

---

## [Unreleased] — MAP-REDUCE compile improvements

### Changed — `scan.sh --info` (MAP-REDUCE + HIERARCHICAL strategies)

Before: output only generic text ("Split into parallel chunks of ~4000 words each").  
After: output includes two new blocks derived from the actual file:

**Section map** — `grep -n "^## "` extracts every top-level heading with exact line range and line count. Headings are stripped of markdown formatting (`**`, leading `#`). First heading whose cleaned title matches `^(references?|appendix|proofs?|proof of)` triggers a `[SKIP line N+]` marker and stops the map — prevents LLM from chunking into boilerplate sections.

**Suggested chunk grouping** — second pass over the same headings merges consecutive sections until the running span hits 150 lines, then emits a `Chunk N: lines A-B` suggestion. Stops at the same skip boundary. Gives parallel agents ready-to-use `offset`/`limit` values instead of asking them to guess.

Bug fixes in the new shell code:
- **En-dash `–` removed** from echo strings — multi-byte UTF-8 in double-quoted `$var–...` caused bash to emit `varname▒: unbound variable` under `set -u` on some locales. Replaced with ASCII `-`.
- **CRLF safety** — `line_num` extracted via `awk -F: '{print $1}' | tr -d '[:space:]'` instead of bare `cut -d: -f1`; prevents `\r` from corrupting variable values and arithmetic.
- **Skip pattern fixed** — skip check now runs on `clean_title` (after stripping `^#*[[:space:]]*`) so `## References` is correctly caught by `^references?`; previously the `##` prefix caused the pattern to miss.
- **Token cost note added** — output now states "~3-4x sequential" so LLM can make an informed strategy choice.

### Changed — `skills/compile-ingest/SKILL.md` (long document strategy section)

Before: single line pointing to `references/long-doc-strategies.md` (file did not exist).  
After: inline strategy table (4 rows: STUFFING / REFINE / MAP-REDUCE / HIERARCHICAL with word-count thresholds), followed by a MAP-REDUCE step-by-step that specifies:
1. Run `scan.sh --info` — use its section map output, not manual line counting
2. Chunk by section boundaries from the map; skip References/Appendix/Proofs
3. Each agent produces structured notes (not a full summary)
4. REDUCE: combine notes into final summary + concepts
5. Cost trade-off documented inline (~3-4x sequential)

### Context — what prompted this

Experiment: compiled same ~21K-word paper twice — once sequential read, once 6-agent MAP-REDUCE — then compared quality and token cost. Findings:
- MAP-REDUCE cost ~121K tokens in subagents vs ~30-40K total for sequential (≈ 3.5x)
- Chunk boundary mismatch (line-count chunks ≠ section boundaries) caused 2 of 6 agents to read wrong sections, requiring a fill read in main context
- v2 (MAP-REDUCE) captured more sub-section detail (free-entry regimes, surplus decomposition); v1 (sequential) had better cross-section examples
- Conclusion: sequential is preferred for ≤25K words unless context overflow is a real risk; MAP-REDUCE justified at ≥15K dense technical text with `scan.sh --info` guiding chunk boundaries

### Still pending (for next version)
- Chunk label in grouping output shows start-section only; ideally shows "Section X → Section Y" range label
- `_so the wedge is 1._` (a proposition continuation captured as a heading) appears as a spurious section — could filter headings that look like partial sentences
- No test coverage for the new `--info` shell logic

---

## [0.5.0] - 2026-04-12

### Added — Eval-Driven Harness Upgrade
_Inspired by studying agentic harness patterns (claudekit-engineer). Each change gated by before/after eval comparison._

#### Eval Framework (new)
- `tools/eval-harness.sh` — system-level eval: 10 checks covering context budget, hook presence/correctness, resolver paths, research skill quality, compile tools, wiki structure, concept file sizes, lint snapshot. Run `--save` to snapshot results to `outputs/notes/`.
- `tools/eval-skills.sh` — skill quality eval: 43 checks across all 5 skill files (frontmatter, gotchas, resolver paths). Pair with eval-harness.sh for full before/after upgrade comparison.

#### Skills Directory (new)
- `skills/compile-ingest/SKILL.md` — compile and ingest skill (extracted from AGENTS.md)
- `skills/lint-impute.md` — lint and web-impute skill
- `skills/output-generation.md` — report, slides, chart, file-back skill
- `skills/query-mode.md` — query answering skill
- `skills/research-pipeline.md` — parallel research pipeline with structured output template and explicit search limits (max 5 WebSearch calls per agent)

#### 5-Hook Lifecycle (`.claude/settings.json`)
- **SessionStart hook** (new) — on `startup|compact`: resets edit counter + injects session state for compact recovery. After context compaction, active compile file and pending file-backs are restored automatically.
- **UserPromptSubmit hook** (new) — detects `compile raw/...` pattern; auto-injects compile context (source path, summary target, scan.sh info) before each compile — saves ~200 tokens of manual derivation.
- **PostToolUse edit counter** (new, extends existing hook) — tracks wiki edits in `/tmp/llm-kb-wiki-edits`; warns after 5 edits to run lint before ending session.
- **Stop session state** (new, extends existing hook) — persists active compile file + pending file-back count to `/tmp/llm-kb-session-state.md` for compact recovery.

#### Query Intelligence
- `search.sh` — all modes (`search`, `files`, `fuzzy`) now log queries + hit/miss status to `wiki/.query-log.jsonl`
- `lint.sh` Section 11 — surfaces query blind spots: reads `.query-log.jsonl`, reports total queries, miss count, and top missed terms as impute candidates

### Changed
- `AGENTS.md` — condensed from ~400 lines to 113 lines using **resolver pattern**: always-loaded context ≤ 250 lines (~1,550 tokens); skill details loaded on-demand from `skills/` directory
- `CLAUDE.md` — added `# Eval` section (eval-harness.sh + eval-skills.sh commands); added `lint.sh --quick`; updated hooks description to accurately list all 5 hooks
- `README.md` — added `plans/` to directory structure; added eval-harness.sh and eval-skills.sh to tools listing
- `.gitignore` — replaced useless `eval/` entry with `wiki/.query-log.jsonl` (personal search history)

---

## [0.4.0] - 2026-04-09

### Added — Harness Pattern Upgrades
_Inspired by [12 Agentic Harness Patterns from Claude Code](https://generativeprogrammer.com/p/12-agentic-harness-patterns-from). Each change maps to a specific pattern._

#### Lifecycle Hooks (Pattern #12: Deterministic Lifecycle Hooks)
- **PostToolUse hook** — auto-reminds to update `index.md`/`_brief.md` when wiki files are edited (`.claude/settings.json`, local-only)
- **Stop hook fixed** — was pointing to wrong directory (`LLM-knowledge-base-system`); now uses `$CLAUDE_PROJECT_DIR` with fallback. Also fixed grep pattern (`'Tổng:'` → `'pending file-back'`)

#### Tiered Memory auto-population (Pattern #3: Tiered Memory)
- `build-index.py` now **auto-generates** "What This Wiki Covers" overview and "Key Concepts" ranking
- **Backlink counting** — concepts ranked by how many other wiki files reference them (most-linked = most important)
- Added `BUILD_INDEX` markers for `OVERVIEW`, `KEY_CONCEPTS`, and `INSIGHTS` sections in `_brief.md`
- **Silent bug fix**: `finalize-compile.sh` was appending insights to `<!-- BUILD_INDEX:INSIGHTS_END -->` but the marker didn't exist → all insights were silently lost

#### Dream Consolidation lite (Pattern #4: Dream Consolidation)
- `lint.sh` section 10: **duplicate concept detection** — compares tags between all concept file pairs, flags when ≥60% overlap with ≥3 shared tags

#### Compile pipeline hardening (Pattern #10: Command Risk Classification)
- `finalize-compile.sh` reordered: **lint runs before mark** (was: mark → index → lint). Prevents bad data from being marked as "compiled" before validation
- Added step 4.5 **pre-finalize verification checklist** in AGENTS.md (required sections, concept limits, link validity, jargon check)
- `lint.sh --quick <file>` single-file evaluator for fast post-compile checks

#### Research Pipeline (Pattern #7 + #8: Subagents + Fork-Join)
- New `research: <topic>` command in AGENTS.md §12 — parallel sub-agent workflow for multi-source research
- 3 phases: Parallel Research (web + wiki + analysis agents) → Compile → Mandatory Checklist

#### Persistent Instructions (Pattern #1: Persistent Instruction File)
- `CLAUDE.md` new section "Wiki Workflow Invariants" — 3 mandatory rules enforced by hooks + prompt
- AGENTS.md: context budget for Q&A (≤5 wiki files per query), clean state constraint, progress persistence via `.compile-progress.json`

### Changed
- `finalize-compile.sh` pipeline order: `index → lint → mark → insight` (was `mark → index → insight → lint`)
- `build-index.py` template for new projects now includes all `BUILD_INDEX` markers
- `.gitignore` now excludes `wiki/.compile-progress.json`

---

## [0.3.0] - 2026-04-06

### Added
- `tools/metrics.py` — token counting (tiktoken) + cost estimation for Claude 4.5/4.6, GPT-5.x, o3/o4-mini, Gemini models
- `scan.sh --start <file>` — timer to track compile duration
- `scan.sh --mark --model <id>` — pass model ID for accurate cost calculation
- Time and Cost columns in `scan.sh --status` and `scan.sh --log` with running total
- `finalize-compile.sh --model <id>` — propagate model through the pipeline
- `tiktoken>=0.7.0` to requirements.txt
- Compile checklist Step 0: Style Check — read `.local-rules.md` if present, skip if absent
- Compile checklist Step 1: Start Clock — track compile time per file
- `--model` instruction block in AGENTS.md (required for cost tracking)

### Changed
- Compile checklist renumbered: 0-3 → 0-5 (added Style Check + Start Clock)
- Summary format: unified "Universal Summary Structure" for all strategies (Stuffing through Hierarchical)
- Concept limit tightened: 3-5 core concepts → 1-3 MACRO concepts per document
- Concept file requirements expanded: now requires Definition, Source Context, Sub-concepts, Examples, See also
- scan.sh log format: 4 fields → 8 fields (`file|hash|date|time|in_tokens|out_tokens|cost|note`)

### Fixed
- Example wiki files restored to English (template repo must stay language-neutral)

---

## [0.2.0] - 2026-04-06

### Added
- `.local-rules.md` localization override — users can set language and formatting rules without committing to repo
- `tools/test.sh` — integration test suite for all CLI tools (46 tests)

### Fixed
- `.gitignore` now excludes personal wiki data: `index.md`, `_brief.md`, domain MOCs
- `.gitignore` excludes `tools/test.sh` (local-only, not ready for public release)
- `.lint-ignore-terms` reset to universal defaults (English comments)

---

## [0.1.0] - 2026-04-05

### Added
- Initial release: LLM-powered knowledge base framework
- Compile pipeline: `scan.sh`, `convert.sh`, `finalize-compile.sh`, `build-index.py`
- Wiki structure: concepts, summaries, topics, domains with Obsidian backlinks
- CLI tools: `search.sh`, `lint.sh`, `impute.sh`, `fetch-repo.sh`, `fetch-images.sh`, `save-image.sh`, `file-back.sh`
- Output generation: reports, slides (Marp), charts (`chart.py`), search UI (`serve.py`)
- Long document strategies: Stuffing, Refine, Map-Reduce, Hierarchical Split
- `AGENTS.md` — full knowledge engineer instructions
- `CLAUDE.md` — quick-reference cheat sheet
- Example wiki files: `transformer-architecture.md`, `attention-is-all-you-need.md`
