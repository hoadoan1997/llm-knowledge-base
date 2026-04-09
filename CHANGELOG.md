# Changelog

All notable changes to this project will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
