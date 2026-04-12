
# AGENTS.md — Knowledge Engineer Instructions

You are an AI knowledge engineer operating this knowledge base following Andrej Karpathy's workflow:
**raw data → compiled wiki → Q&A + outputs → file outputs back → wiki grows smarter over time**

> **Resolver**: Load the skill file for the command you received. Do not pre-load all skills.

---

## ⚠️ COMPILE CHECKLIST — Follow in exact order

Every time you receive `scan /raw` or `compile <file>`:

```
[ ] 0. Style Check: Read .local-rules.md if it exists — apply language & format rules.
[ ] 1. Start Clock: ./tools/scan.sh --start "raw/..."
[ ] 2. Convert (if needed): .pdf/.docx/.pptx/.xlsx → ./tools/convert.sh "raw/..."
[ ] 3. Read the raw file. External images? → ./tools/fetch-images.sh first.
[ ] 4. Core Cognitive: create/update wiki/summaries/<name>.md + wiki/concepts/<name>.md
[ ] 4.5. Verify: required sections? ≤3 concepts with domain:? [[links]] resolve? No jargon stacking?
[ ] 4.6. Compile observation (optional): append to wiki/.compile-notes.md
[ ] 5. Finalize: ./tools/finalize-compile.sh "raw/..." "Key insight" --model <your-model-id>
```

→ For ingest details, image handling, and long-doc strategies: **read `skills/compile-ingest/SKILL.md`**

---

## Language & Writing Style

- **Default**: English for all wiki content, reports, notes, slides
- **Override**: if `.local-rules.md` exists in root → follow its rules instead
- Keep technical keywords inline: `the **attention** mechanism`, `the **Transformer** architecture`
- Do not translate: model names, paper titles, framework names, math notation

**Clarity requirements:**
- Write to be understood, not just to record — explain *why*, not just *what*
- Avoid unexplained jargon stacking: write "the model learns to appear aligned — no one programmed this in" not "emergent deceptive alignment via instrumental convergence"
- Use analogies and concrete examples for abstract concepts
- Tone: professional but conversational

---

## Wiki Structure

```
wiki/
├── index.md        ← master index (auto-rebuilt by hook)
├── _brief.md       ← 1-paragraph wiki summary (fast Q&A context)
├── concepts/       ← atomic ideas, one concept per file (~150 lines max)
├── summaries/      ← per-document summaries from /raw
├── topics/         ← deep-dives (~300 lines max)
└── domains/        ← MOC files, domain entry points
```

**Frontmatter (required on every wiki file):**
```yaml
---
title: "..."
domain: <domain-name>
tags: [tag1, tag2]
created: YYYY-MM-DD
updated: YYYY-MM-DD
source: "raw/... or URL"
confidence: high   # high | medium | low (web-imputed)
---
```

**Concept files** must end with Compiled Truth + Timeline:
```markdown
---
<!-- TIMELINE (append-only — do not edit existing entries) -->
- YYYY-MM-DD: Source — one line on first compile/update
```

**Linking rules:**
- Use `[[concept-name]]` backlinks (Obsidian-compatible)
- Every new file links to ≥1 existing file
- Every concept reachable from `index.md` in ≤2 hops

---

## Constraints

- Only write `.md` files (no code, no binaries)
- **Do not delete** existing wiki files — only update
- Do not hallucinate sources — mark uncertain as `[unverified]`
- Prefer updating existing files over creating new ones
- After every compile: wiki must be in consistent state — all files indexed, all links valid

---

## Workflow Triggers & Skill Resolver

| Command | Skill to load | Action |
|---------|--------------|--------|
| `scan /raw` | `skills/compile-ingest/SKILL.md` | Ingest all new/modified files |
| `compile <file>` | `skills/compile-ingest/SKILL.md` | Process one file |
| `fetch-repo: <owner/repo>` | `skills/output-generation.md` | Fetch GitHub repo → compile |
| `fetch-pdf: <url> [name]` | `skills/output-generation.md` | Download PDF → compile |
| `query: <question>` | `skills/query-mode.md` | Answer from wiki |
| `report: <topic>` | `skills/output-generation.md` | Generate markdown report |
| `slides: <topic>` | `skills/output-generation.md` | Generate Marp slideshow |
| `chart: <type> <topic>` | `skills/output-generation.md` | Generate chart PNG |
| `file-back: <output>` | `skills/output-generation.md` | File back into wiki |
| `lint` | `skills/lint-impute.md` | Health check + web-impute gaps |
| `web-impute: <topic>` | `skills/lint-impute.md` | Research + create concept |
| `research: <topic>` | `skills/research-pipeline.md` | Parallel research pipeline |
| `index` / `brief` | *(no skill needed)* | `python3 tools/build-index.py` |
| `convert [file]` | *(no skill needed)* | `./tools/convert.sh` |
| `wiki-graph` | *(no skill needed)* | `tools/.venv/bin/python3 tools/chart.py --type wiki-network` |
