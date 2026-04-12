# Long Document Strategies

Reference for Step 3–4 of compile-ingest when `scan.sh --info` shows a large file.

## Classification Thresholds

| File type | Word count | Strategy |
|-----------|-----------|----------|
| `.md` / `.txt` | < 4,000 | **Stuffing** |
| `.md` / `.txt` | 4,000–10,000 | **Refine** |
| `.md` / `.txt` | 10,000–25,000 | **Map-Reduce** |
| `.md` / `.txt` | > 25,000 | **Hierarchical Split** |
| `.pdf` / `.docx` / `.pptx` / `.xlsx` | any | **Convert first** → re-apply table |

---

## Strategy 1 — Stuffing (< 4K words)

Read entire file in one pass → create summary + concepts as normal. No special procedure needed.

---

## Strategy 2 — Refine (4K–10K words)

Best for long-form content with a coherent narrative (blog post, essay, report).

```
1. Read opening section (~500 words) → create a running summary
2. Read each subsequent section → refine: add new info, keep old context
3. File ends → running summary becomes the final summary
```

Advantage: preserves the through-line argument across the full document.

---

## Strategy 3 — Map-Reduce (10K–25K words)

Best for academic papers and technical reports.

```
Pass 1 — Abstract-first (always do this first):
  Read: Abstract + Introduction + Conclusion
  → Create skeleton summary (main arguments, contributions, results)

Pass 2 — Map:
  Chunk every ~4,000 words → chunk_summary_A, chunk_summary_B, …
  (Use PDF page separators `--- end of page=N ---` for natural chunking)

Pass 3 — Reduce:
  Synthesize skeleton + chunk summaries → final wiki summary
  → Delete wiki/.compile-progress.json when done
```

**Why Abstract-first**: Abstract + Conclusion contain ~80% of a paper's insight. Build the map before diving into sections.

**Progress persistence** — update `wiki/.compile-progress.json` before each pass so work survives context resets:
```json
{
  "file": "raw/papers/paper.pdf",
  "strategy": "map-reduce",
  "started": "2026-04-12T10:00",
  "chunks_done": ["chunk_A"],
  "chunks_remaining": ["chunk_B", "chunk_C"],
  "skeleton_summary": "Main thesis is...",
  "notes": "Methods section skipped — not relevant to wiki domain"
}
```
If a new session starts and this file exists → read it and resume.

---

## Strategy 4 — Hierarchical Split (> 25K words)

Best for books, theses, long technical documents.

```
Step 1 — Create part summaries:
  wiki/summaries/<name>-part1.md  (chapters 1–3)
  wiki/summaries/<name>-part2.md  (chapters 4–6)
  wiki/summaries/<name>-part3.md  (chapters 7–9)

Step 2 — Create synthesis:
  wiki/summaries/<name>-synthesis.md
  → Primary file; this is what index.md links to

Step 3 — Mark each part:
  ./tools/scan.sh --mark "raw/papers/<name>.pdf" --note "part1/3 done"
```

Use same `wiki/.compile-progress.json` format. Delete after synthesis is complete.

---

## General Notes

- Always prioritize high-density sections (abstract, conclusion, headings) first
- Extract concepts **only after the full summary is complete** — never per-chunk
- If a chunk is not relevant to the wiki's domain: note it, do not create a concept
- Methods sections in papers: skip unless implementation understanding is required
