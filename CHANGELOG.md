# Changelog

All notable changes to this project will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
