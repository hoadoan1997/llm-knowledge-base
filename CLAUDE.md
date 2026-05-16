# CLAUDE.md — Cheat Sheet

> LLM-powered knowledge base. **LLM writes the wiki, you curate.**  
> Detailed behavior: `@AGENTS.md` | Skills: `skills/` | Full guide: `README.md`

@AGENTS.md

---

## Quick Commands

> **Skill Priority:** Commands below are **project-native** and take priority over system skills (BMAD, etc.).
> Colon syntax is canonical (`research: topic`) but natural-language forms also match (`research tôi muốn...`).

### Ingest
```
scan /raw                         # Compile all new files
compile raw/articles/foo.md       # Compile a specific file
fetch-repo: owner/repo            # Fetch GitHub repo → compile
fetch-pdf: <url> [name]           # Download PDF → compile
fetch-url: <url> [name]           # Fetch webpage → compile (auto JS fallback)
```

### Query & Output
```
query: <question>                 # Answer from wiki
report: <topic>                   # → outputs/reports/
slides: <topic>                   # → outputs/slides/ (Marp)
chart: <type> <topic>             # → outputs/charts/
html: <file.md>                   # → outputs/html/ (self-contained HTML, md2html skill)
```

### Research & Maintain
```
research: <topic>                 # ⚡ Parallel pipeline: 3 agents → wiki/summaries/ + wiki/concepts/
news: <topic>                     # 📰 Last-30-days news: Reddit, X, YouTube, HN, Polymarket → wiki/summaries/
file-back: outputs/reports/foo.md # File back loop (REQUIRED after output)
lint                              # Health check wiki
web-impute: <topic>               # Research + create concept from web
index / brief                     # Rebuild index.md / _brief.md
```

---

## CLI Tools — Quick Reference

```bash
# Scan & track
./tools/scan.sh --new                        # files not yet compiled
./tools/scan.sh --status                     # full status overview
./tools/scan.sh --info raw/papers/paper.pdf  # length, strategy
./tools/scan.sh --mark "raw/articles/foo.md" # mark as compiled

# Convert
./tools/convert.sh                           # auto-convert all PDF/DOCX/PPTX/XLSX in raw/
./tools/convert.sh raw/papers/foo.pdf        # convert a specific file
./tools/convert.sh --dry-run                 # preview, no conversion

# Compile automation & verification
./tools/finalize-compile.sh <file> "insight" # Auto mark + rebuild index
python3 ./tools/build-index.py               # Rebuild index.md & _brief.md manually

# Fetch
./tools/fetch-repo.sh owner/repo             # GitHub repo
./tools/fetch-repo.sh owner/repo --docs      # + docs/ folder
./tools/fetch-url.sh <url> [name]            # webpage → Markdown (static, Jina fallback)
./tools/fetch-url.sh <url> --force-jina      # force JS rendering via r.jina.ai
./tools/fetch-images.sh raw/articles/foo.md  # external images → local
./tools/save-image.sh <url> [name]           # single image

# File back
./tools/file-back.sh --list                  # pending outputs
./tools/file-back.sh --mark <file> --note "..." # mark manually
./tools/file-back.sh --verify <file>         # verify wiki was updated
./tools/file-back.sh --stats

# Lint
./tools/lint.sh                              # health check
./tools/lint.sh --save                       # save report → outputs/notes/
./tools/lint.sh --quick wiki/concepts/foo.md # fast single-file check

# Eval (run before/after upgrades to measure improvement)
./tools/eval-harness.sh                      # system-level: context budget, hooks, wiki health
./tools/eval-harness.sh --save               # save → outputs/notes/eval-harness-YYYY-MM-DD.md
./tools/eval-skills.sh                       # skill quality: frontmatter, gotchas, resolver paths
./tools/eval-skills.sh --save                # save → outputs/notes/eval-skills-YYYY-MM-DD.md

# Web-impute
./tools/impute.sh "<topic>"                  # create skeleton concept file
./tools/impute.sh "<topic>" --domain ai      # specify domain
./tools/impute.sh --list                     # concepts needing verification

# Search
./tools/search.sh "query"                    # full-text
./tools/search.sh "query" --fuzzy            # partial matches + variations
./tools/search.sh "query" --files            # file paths only
./tools/search.sh --related <slug>           # backlinks

# Serve & Charts
python3 tools/serve.py                       # Search UI → localhost:7337
tools/.venv/bin/python3 tools/chart.py --type wiki-network --out wiki-graph
tools/.venv/bin/python3 tools/chart.py --list-types
```

---

## Setup (one time)

1. Obsidian → "Open folder as vault" → select this folder
2. Install "Obsidian Web Clipper" on Chrome/Firefox → save location: `raw/articles/`
3. Tools are ready in `tools/` — see `README.md` for details

---

## Key Principles

1. **LLM writes the wiki, you curate** — do not edit wiki files manually
2. **File back is required** — every important output must be `file-back:`'d before ending the session
3. **No RAG needed at ~400K words** — LLM navigates via `_brief.md` + `index.md`
4. **Domains are not pre-designed** — create a MOC when ≥10 concepts share the same topic
5. `.lint-ignore-terms` (root) — allow-list for lint to skip false positives

---

## Wiki Workflow Invariants

After compiling or modifying wiki content, **ALWAYS** ensure:
1. Run `finalize-compile.sh` or `python3 tools/build-index.py` to update `index.md`, `_brief.md`, and domain MOCs
2. All `[[wikilinks]]` resolve to existing files
3. File-back any output before ending session (`file-back: <output-file>`)

> Enforced by hooks in `.claude/settings.json`:
> - **PreToolUse** — injects `.local-rules.md` before any wiki write
> - **PostToolUse** — auto-runs `build-index.py` + counts wiki edits (warns at 5)
> - **UserPromptSubmit** — auto-injects compile context when `compile raw/...` detected
> - **Stop** — shows pending file-backs + saves session state to `/tmp/`
> - **SessionStart** — restores session state after context compaction
>
> Hooks enforce invariants but don't replace the compile checklist. Never skip ancillary file updates from AGENTS.md.
