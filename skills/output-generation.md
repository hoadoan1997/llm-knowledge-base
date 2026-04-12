---
skill: output-generation
trigger: "report: · slides: · chart: · file-back: · fetch-repo: · fetch-pdf:"
description: "Use when generating reports, slides, charts, or filing outputs back into the wiki. Also covers fetch-repo and fetch-pdf ingestion commands."
---

# Skill: output-generation

---

## Reports → `outputs/reports/report-<topic>-YYYY-MM-DD.md`

- Plain Markdown, language per `.local-rules.md` (default: English)
- Required: executive summary, findings, connections, open questions
- **Always suggest file-back** after creating — list the specific insights worth filing

## Slides → `outputs/slides/slides-<topic>-YYYY-MM-DD.md`

- Marp format (template at `outputs/slides/_template.md`)
- Each slide: 3–5 bullet points max
- Slides separated by `---` on its own line

## Notes → `outputs/notes/note-<topic>-YYYY-MM-DD.md`

Quick capture, no strict format required.

---

## file-back Command

When receiving `file-back: <output-file>`:
1. Read the full output file
2. Identify **new** insights not yet in the wiki — look for specifics, not just themes
3. Update relevant wiki files:
   - Add insight to `wiki/concepts/<relevant>.md` (compiled truth section)
   - Or add section to `wiki/summaries/<relevant>.md`
   - Or create new concept if truly new macro idea
4. Run: `./tools/file-back.sh --mark <output-file> --note "<short note on what was added>"`
5. Update `wiki/_brief.md` if the insight is significant enough to affect the wiki's overall picture

---

## fetch-repo Command

```bash
./tools/fetch-repo.sh <owner/repo>         # README + metadata + file tree
./tools/fetch-repo.sh <owner/repo> --docs  # also fetch docs/ folder
```
After script completes → `compile raw/repos/<owner>-<repo>.md`

Examples:
```
fetch-repo: karpathy/nanoGPT
fetch-repo: https://github.com/anthropics/anthropic-sdk-python
```

## fetch-pdf Command

```bash
curl -L "<url>" -o "raw/papers/<name>.pdf"
./tools/scan.sh --info "raw/papers/<name>.pdf"
```
Then compile using the appropriate strategy from `skills/compile-ingest/references/long-doc-strategies.md`.

Examples:
```
fetch-pdf: https://arxiv.org/pdf/1706.03762 attention-is-all-you-need
```

## Chart Command

```bash
tools/.venv/bin/python3 tools/chart.py --type <type> --data '<json>' --title "<title>" --out <name>
```
Types: `timeline`, `bar`, `horizontal-bar`, `network`, `heatmap`, `pie`, `scatter`, `wiki-network`

Output → `outputs/charts/` — embed in reports with `![title](../../outputs/charts/name.png)`

---

## Gotchas

**Filing back by scanning headings only** — Don't skim the output file for section titles and assume you know what's new. Read the full content. Insights are often buried in examples or footnotes, not in section headers.

**Not updating `_brief.md` after a significant file-back** — If you added 3+ new concept updates, the brief is now stale. Update it so future Q&A queries get accurate context.

**Slides: missing `---` separator** — Marp requires `---` on its own line between slides. If separators are missing or merged with content, Marp renders the entire deck as one slide. Check the template.

**Not suggesting file-back after report creation** — The feedback loop: report → insights → wiki → better future reports. If you don't explicitly prompt the user to file back, the loop breaks and the wiki stagnates.

**fetch-repo without compiling** — The fetch script only creates the raw file. Nothing enters the wiki until you run `compile raw/repos/<owner>-<repo>.md`. Don't stop after the fetch.
