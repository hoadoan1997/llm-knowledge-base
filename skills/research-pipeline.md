---
skill: research-pipeline
trigger: "research: <topic>"
description: "Use when a topic requires parallel web research across multiple angles before compiling into the wiki. Spawns 3 parallel sub-agents then synthesizes into standard wiki format."
---

# Skill: research-pipeline

---

## Phase 1 — Parallel Research

Spawn 3 sub-agents **simultaneously** using the Agent tool in a single message:

- **Agent A (Web)**: WebSearch for official docs, announcements, changelogs, release notes
- **Agent B (Wiki)**: Search existing wiki for related concepts that may need updating — use `search.sh`, Grep, Read. Return a list of relevant existing files.
- **Agent C (Analysis)**: WebSearch for expert analysis, critiques, comparisons, alternative perspectives

---

## Phase 2 — Compile

Wait for all 3 agents to complete, then synthesize findings. Follow the AGENTS.md compile checklist:

- Create `wiki/summaries/<topic-slug>.md` with all required sections
- Create/update concept files (max 3 macro concepts, each with `domain:`)
- Cross-reference with existing concepts found by Agent B — update their compiled truth sections if new evidence changes understanding

---

## Phase 3 — Mandatory Checklist

```
[ ] Summary has all required sections (Executive Summary, Deep Analysis, Key Insights)
[ ] Concepts ≤ 3 macro, each has domain: field
[ ] finalize-compile.sh run with --model flag
[ ] Cross-references added to related existing concepts from Agent B's list
[ ] [[wikilinks]] all resolve
```

---

## Gotchas

**Running agents sequentially** — The entire point of this pipeline is parallelism. If you run Agent A, wait, then run Agent B, wait, then run Agent C, you've just done 3× sequential research with no benefit. All 3 must be spawned in a single Agent tool message.

**Treating agent output as final wiki content** — Raw research output is input to Phase 2, not the output. Agent findings still need to be synthesized through the compile checklist — with proper summary structure, concept extraction limits, and finalize-compile.sh.

**Skipping Agent B's existing wiki check** — If Agent B finds that `wiki/concepts/transformer-architecture.md` already covers part of what you're researching, you should update that file rather than create a duplicate. Agent B's list is the first thing to review in Phase 2.

**Agent context overflow in Phase 2** — If each agent returns 2,000+ words of raw material, synthesizing all three will exhaust the context budget. Brief agents to return structured findings (key claims, source URLs, contradictions) rather than raw excerpts.
