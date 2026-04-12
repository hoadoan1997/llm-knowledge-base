---
skill: compile-ingest
trigger: "scan /raw · compile <file> · fetch-repo: · fetch-pdf:"
description: "Use when ingesting any raw file into the wiki. Covers what the AGENTS.md compile checklist steps actually mean, image handling, concept extraction rules, and when to apply which long-doc strategy."
---

# Skill: compile-ingest

Follow the compile checklist in AGENTS.md. This skill fills in the *what* behind each step.

---

## Step 3 — Image Handling (before reading)

Check for external images first: `grep -c 'https://' "raw/articles/file.md"`

If count > 0 → run `./tools/fetch-images.sh "raw/articles/file.md"` before reading.
Without this, external images show as broken URLs — Claude cannot see them and will write wiki content with missing visual context.

**Image triage when writing wiki:**
- HIGH VALUE (diagrams, flowcharts, architecture, data charts) → describe in detail + embed `![name](../../raw/images/name.png)`
- LOW VALUE (banners, avatars, stock photos) → ignore completely, do not mention

---

## Step 4 — Core Cognitive

### Summary format (`wiki/summaries/<name>.md`)

Required sections in this order:
1. **Executive Summary** — 1–2 paragraphs: context, problem, main thesis
2. **Deep Analysis** — logical breakdown with sub-headings
3. **Key Insights** — 2–5 bullets of the most novel/counter-intuitive findings
4. *(optional)* **Limitations & Open Questions**
5. **Concepts** + **Relations** — wikilinks at the end

Write to be understood, not just to record. Explain *why* something matters, not just *what* it is.

### Concept extraction (`wiki/concepts/<name>.md`)

**Hard limit: 1–3 MACRO concepts per document.** Minor terms and sub-concepts must be grouped under a parent macro — do not give them their own files.

Required frontmatter: `domain:` field is non-negotiable. Use the domain MOC slug (`ai`, `product`, `meta`...). If no MOC exists yet: use a short slug, lint will detect it.

**Compiled Truth + Timeline format** — every concept file ends with:
```markdown
---
<!-- TIMELINE (append-only — do not edit existing entries) -->
- YYYY-MM-DD: Source — one line on how/why compiled or updated
```
- Above `---` = compiled truth (rewrite when evidence changes)
- Below `---` = timeline (append-only, never edit existing entries, only add new)

### Long document strategy

Run `./tools/scan.sh --info <file>` → check word count → load the strategy:

→ **Read `references/long-doc-strategies.md`** for the 4 strategies and thresholds.

---

## Step 4.5 — Verify before finalizing

- [ ] Summary has all required sections?
- [ ] Concepts ≤ 3 macro, each with `domain:`?
- [ ] All `[[wikilinks]]` point to files that exist (or will exist after this compile)?
- [ ] No unexplained jargon stacking?

If any check fails → fix first, then proceed to Step 5.

---

## Step 5 — finalize-compile.sh

```bash
./tools/finalize-compile.sh "raw/path/to/file" "One-line key insight" --model claude-sonnet-4-6
```

`--model` is required — pass your actual model ID. Supported IDs: see `tools/metrics.py`.

If no domain MOC exists yet and ≥10 concepts exist → manually create MOC following `wiki/domains/_about-domains.md`.

---

## Gotchas

**Concept explosion** — The most common mistake. After reading an interesting document, the instinct is to create a concept for every interesting term. Resist. Ask: "Is this a MACRO idea that stands on its own, or a sub-concept that belongs under an existing concept?" When in doubt, group it.

**Missing `--model` flag** — `finalize-compile.sh` runs silently without it but cost tracking is broken. The flag is not optional; it's required for metrics.

**Editing TIMELINE entries** — The `<!-- TIMELINE -->` section is append-only. Never edit existing dated entries, even to fix typos. Only add new dated lines at the bottom.

**Skipping fetch-images.sh** — If you read a raw `.md` file before downloading its images, external URLs appear as broken links. You'll write wiki content without seeing the actual diagrams. Always grep for `https://` first.

**Choosing strategy without `scan.sh --info`** — Don't guess the word count. A "short article" might be 12,000 words. Running `scan.sh --info` takes 2 seconds and determines the right strategy.

**Concept file > 150 lines** — If you're going over, the concept is doing too much. Split into parent + sub-concept, or move examples to a summary instead.

**Not verifying `[[wikilinks]]` before finalizing** — Orphaned links will fail lint. Check that every `[[linked-concept]]` either exists already or will be created in this same compile session.
