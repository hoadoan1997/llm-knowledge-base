---
skill: query-mode
trigger: "query: <question>"
description: "Use when answering a question from the wiki. Covers the Q&A procedure, context budget rules, session logging, and how to surface wiki update opportunities."
---

# Skill: query-mode

---

## Procedure

1. Read `wiki/_brief.md` — get overall wiki context
2. Run `tools/search.sh "<keywords>"` — find relevant files
3. Read relevant files — **context budget: ≤ 5 wiki files per query**
   - Prefer `_brief.md` + search hits
   - Do not read entire domain MOCs unless the question is specifically about domain structure
4. Answer based on wiki content — **do not answer from training knowledge if wiki has coverage**
5. If topic not covered → state clearly "The wiki does not cover this yet" → suggest `web-impute: <topic>`

---

## Session Logging

Append to `wiki/sessions/YYYY-MM.md` (create file if it doesn't exist):
```markdown
## YYYY-MM-DD — query: <first 60 chars of question>
**Files read**: wiki/_brief.md, wiki/concepts/...
**Answer summary**: [1 sentence]
**Follow-ups suggested**: [web-impute / file-back suggestions, or "none"]
```

---

## Wiki Update Opportunities

After every query response, append this block:
```
---
**Wiki update opportunity** *(if any)*:
- Concept X mentioned but not in wiki → `web-impute: X`
- Concept Y contradicted by this answer → update `wiki/concepts/Y.md`
- New connection found: [[A]] ↔ [[B]] → add to relations section
```
Skip only if genuinely no opportunities found.

---

## Gotchas

**Loading the domain MOC instead of specific concepts** — The domain MOC (e.g. `wiki/domains/ai.md`) is a navigation index, not content. Loading it uses up context budget without adding answer quality. Go directly to the concept files that search.sh returns.

**Answering from training data when wiki covers the topic** — If the wiki has a concept file on the subject, answer from that. Don't blend wiki content with external training knowledge — the point of the wiki is to be the authoritative source for this knowledge base.

**Skipping session logging** — `wiki/sessions/` exists precisely to track what was asked and what was found. If this is skipped, the session history is lost and there's no signal for which concepts need expansion.

**Forgetting the wiki update opportunity block** — This is how the wiki grows. If it's not appended, gaps never get flagged and the wiki stagnates. Even a "none found" is better than silence.

**Reading all 5 files before synthesizing** — Load one file, check if it answers the question. Load the next only if needed. The 5-file budget is a ceiling, not a target.
