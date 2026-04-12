---
skill: lint-impute
trigger: "lint · web-impute: <topic>"
description: "Use when running a wiki health check or creating a new concept from web research. Covers lint workflow, impute procedure, and quality thresholds."
---

# Skill: lint-impute

---

## lint Command

1. `./tools/lint.sh --save` → saves report to `outputs/notes/lint-YYYY-MM-DD.md`
2. Read the report → identify **impute candidates** (broken links, missing concepts)
3. For each candidate: WebSearch → create concept file in `wiki/concepts/`
4. After imputing: update domain MOC + `_brief.md`

**Impute workflow:**
```
lint detects: MISSING CONCEPT "mixture-of-experts"
→ WebSearch: "mixture of experts LLM architecture"
→ Synthesize results
→ Create wiki/concepts/mixture-of-experts.md
→ Link into domain MOC
```

**Limits:**
- Max **5 concepts per lint run** — beyond this, quality degrades and hallucination compounds
- Always prioritize concepts with the most broken backlinks first

---

## web-impute Command

When receiving `web-impute: <topic>`:

1. **First**: `./tools/impute.sh "<topic>"` — creates skeleton with correct frontmatter
2. WebSearch the topic (2–3 sources minimum)
3. Fill the skeleton file with content
4. Source field: `source: "web search YYYY-MM-DD"`
5. Mark uncertain claims as `[needs verification]`
6. After verifying against an authoritative source → upgrade `confidence: low` → `medium` or `high`

To list concepts still needing verification: `./tools/impute.sh --list`

---

## Gotchas

**Writing concept content before running `impute.sh`** — If you write the file directly, you'll use the wrong frontmatter format and miss required fields. Always run `impute.sh` first to get the correct skeleton, then fill it in.

**Imputing more than 5 concepts per run** — Hallucination compounds when generating multiple concepts back-to-back without grounding. Stop at 5. Run lint again in a separate session if more are needed.

**Setting `confidence: high` after web search** — A web search result is not an authoritative source. Default to `confidence: medium` for anything web-researched. Upgrade to `high` only when you've verified against primary source (paper, official docs, original author).

**Not linking the new concept into the domain MOC** — After creating `wiki/concepts/<name>.md`, the concept exists but is orphaned. It won't appear in domain browsing and may be re-created by a future session. Always add the link to the relevant `wiki/domains/<domain>.md`.

**Fixing broken links by removing the reference** — If lint shows `[[concept-x]]` is broken, the fix is to create `wiki/concepts/concept-x.md`, not to delete the reference from the file that links to it. The reference exists because the concept is real — it just hasn't been compiled yet.
