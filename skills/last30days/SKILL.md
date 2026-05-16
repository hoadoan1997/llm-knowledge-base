---
skill: last30days
trigger: "news: <topic>"
description: "Research any topic across Reddit, X, YouTube, TikTok, Hacker News, Polymarket and web for the last 30 days. Synthesizes findings into a wiki summary. Best for news, trends, recent events, and social sentiment."
---

# Skill: last30days (News & Trends Pipeline)

Wraps the global `last30days` skill and extends it with a **wiki filing phase** so findings are persisted into the knowledge base.

---

## Phase 1 — Parse & Announce

Before running any tools, display:

```
Researching: {TOPIC} across Reddit, X, YouTube, HN, Polymarket, and the web (last 30 days).
Parsed intent:
- TOPIC = {TOPIC}
- QUERY_TYPE = {NEWS | RECOMMENDATIONS | COMPARISON | GENERAL}
Starting research — typically 2–5 minutes.
```

Classify QUERY_TYPE:
- **NEWS** — "what's happening with X", "X news", "latest on X", "tin tức X"
- **RECOMMENDATIONS** — "best X", "top X", "recommended X"
- **COMPARISON** — "X vs Y", "X so với Y"
- **GENERAL** — anything else

---

## Phase 2 — Run last30days Research

Find the script — look in project-local first, then fall back to global plugin paths:

```bash
# Project-local (preferred — copy scripts/ here after installing the plugin)
PROJECT_LOCAL="skills/last30days/scripts/last30days.py"

for dir in \
  "$([ -f "$PROJECT_LOCAL" ] && dirname "$PROJECT_LOCAL")" \
  "${CLAUDE_PLUGIN_ROOT:-}" \
  "$HOME/.claude/plugins/marketplaces/last30days-skill" \
  "$HOME/.claude/plugins/cache/last30days-skill/last30days/2.9.5"; do
  [ -n "$dir" ] && [ -f "$dir/scripts/last30days.py" ] && SKILL_ROOT="$dir" && break
done

# Project-local shortcut (avoids nested scripts/ path issue above)
if [ -z "${SKILL_ROOT:-}" ] && [ -f "skills/last30days/scripts/last30days.py" ]; then
  SKILL_ROOT="skills/last30days"
fi

if [ -z "${SKILL_ROOT:-}" ]; then
  echo "ERROR: last30days script not found." >&2
  echo "Install the last30days-skill plugin, then copy its scripts/ folder to skills/last30days/scripts/" >&2
  exit 1
fi

python3 "${SKILL_ROOT}/scripts/last30days.py" {TOPIC} --emit=compact --no-native-web \
  --save-dir=~/Documents/Last30Days
```

Use a timeout of **300000ms** (5 minutes). Read the FULL output — it contains Reddit, X, YouTube, TikTok, HN, Polymarket, and web sections.

After the script completes, do **WebSearch** to supplement:
- `{TOPIC} news 2026`
- `{TOPIC} announcement update`
- Exclude reddit.com, x.com from results

---

## Phase 3 — Synthesize & Display

Produce the standard last30days output:

**What I learned:**
- 3–5 key findings, each attributed to a source (`per @handle`, `per r/sub`, `per HN`, `per Polymarket`)
- Lead with cross-platform signals (strongest evidence)
- Quote top Reddit comments and YouTube transcript highlights directly

**Stats block** (copy exactly, omit lines with 0 results):
```
---
✅ Research complete!
├─ 🟠 Reddit: {N} threads │ {N} upvotes │ {N} comments
├─ 🔵 X: {N} posts │ {N} likes │ {N} reposts
├─ 🔴 YouTube: {N} videos │ {N} views │ {N} with transcripts
├─ 🟡 HN: {N} stories │ {N} points │ {N} comments
├─ 📊 Polymarket: {N} markets │ {summary of key odds}
├─ 🌐 Web: {N} pages — Source Name, Source Name
└─ 🗣️ Top voices: @{handle} ({N} likes) │ r/{sub}
---
```

---

## Phase 4 — Wiki Filing (Knowledge Base Integration)

After displaying findings, automatically file results into the wiki:

### 4a. Create wiki summary

Write `wiki/summaries/news-{topic-slug}-{YYYY-MM-DD}.md`:

```markdown
---
title: "News: {TOPIC} (Last 30 Days)"
domain: news
tags: [news, trends, {topic-tags}]
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
source: "last30days research pipeline {YYYY-MM-DD}"
confidence: high
---

## Summary

{3–5 bullet points of top findings with source attributions}

## Key Signals

{Cross-platform signals — things appearing across Reddit + X + HN}

## Sentiment

{Overall community sentiment: positive / mixed / negative, based on upvote/like signals}

## Prediction Markets

{If Polymarket had relevant markets — include odds and movement}

## Sources

{Top Reddit threads, X handles, YouTube channels, HN stories with engagement numbers}

## Open Questions

{Unanswered questions, conflicts between sources, what to watch next}

## Related Concepts

{[[wikilinks]] to existing wiki concepts related to this topic}
```

### 4b. Update or create concept file (if topic has lasting relevance)

If findings reveal durable knowledge (not just ephemeral news), create/update the appropriate concept file in `wiki/concepts/`. Only create if the topic has structural, long-term significance — not for one-off news events.

### 4c. Finalize

Run:
```bash
./tools/finalize-compile.sh "wiki/summaries/news-{topic-slug}-{date}.md" \
  "Last 30 days: {one-line key insight}" --model claude-sonnet-4-6
```

---

## Checklist

```
[ ] Script found and ran successfully (or graceful error if not installed)
[ ] WebSearch supplement done
[ ] "What I learned" synthesis displayed to user
[ ] Stats block displayed (no 0-result lines)
[ ] wiki/summaries/news-*.md created with required frontmatter
[ ] [[wikilinks]] resolve to existing concepts
[ ] finalize-compile.sh run with --model flag
```

---

## Gotchas

**Script not found** — The `last30days-skill` plugin must be installed via Claude Code marketplace. After installing, copy the scripts folder into this project:
```bash
cp -r ~/.claude/plugins/cache/last30days-skill/last30days/*/scripts skills/last30days/scripts
```
`skills/last30days/scripts/` is gitignored (plugin license). If missing, the skill falls back to WebSearch only and still answers the question.

**Interactive mode** — last30days normally waits for a follow-up prompt. In this wiki-integrated mode, continue to Phase 4 **before** waiting for user input. After filing to wiki, then offer follow-up invitation.

**News vs durable knowledge** — A news event ("GPT-5 launched today") goes in `wiki/summaries/`. A structural insight ("OpenAI's release cadence has shifted to quarterly") goes in `wiki/concepts/`. Don't create a concept for every news item.

**Available sources without extra API keys** (default setup): Reddit, YouTube (via yt-dlp), Hacker News, Polymarket — these 4 work out of the box. X/Twitter requires AUTH_TOKEN+CT0 or XAI_API_KEY. TikTok/Instagram require SCRAPECREATORS_API_KEY. Run `--diagnose` to see current source availability. The skill still provides useful research with 4 sources — inform the user which sources were active.
