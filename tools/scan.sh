#!/usr/bin/env bash
# scan.sh — Track and list raw files that need processing
#
# Usage:
#   ./tools/scan.sh              # show all raw files + wiki status
#   ./tools/scan.sh --new        # only files not yet compiled
#   ./tools/scan.sh --status     # full table: processed / unprocessed / modified
#   ./tools/scan.sh --log        # view scan log
#   ./tools/scan.sh --mark <file> [--note "text"]  # mark file as compiled
#   ./tools/scan.sh --info <file> # check file length + suggest compile strategy
#   ./tools/scan.sh --start <file> # start the timer for processing

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RAW="$ROOT/raw"
LOG="$ROOT/wiki/.scan-log"

# Create log file if it doesn't exist
touch "$LOG"

_hash() {
  # Hash file content to detect changes
  md5 -q "$1" 2>/dev/null || md5sum "$1" 2>/dev/null | awk '{print $1}'
}

_all_raw() {
  find "$RAW" -type f \( -name "*.md" -o -name "*.txt" -o -name "*.pdf" -o -name "*.docx" -o -name "*.pptx" -o -name "*.xlsx" \) \
    -not -path "*/archived/*" -not -name ".gitkeep" | sort
}

case "${1:-}" in

  --start)
    target="${2:-}"
    if [[ -z "$target" ]]; then
      echo "Usage: $0 --start <relative-path>"
      exit 1
    fi
    full="$ROOT/$target"
    if [[ ! -f "$full" ]]; then
      echo "File does not exist: $full"
      exit 1
    fi
    h=$(_hash "$full")
    echo "$(date +%s)" > "/tmp/.scan_start_$h"
    echo "⏱️  Timer started for $target"
    ;;

  --new)
    echo "=== FILES NOT YET COMPILED ==="
    count=0
    while IFS= read -r f; do
      rel="${f#$ROOT/}"
      # Check log: no entry or hash has changed
      current_hash=$(_hash "$f")
      logged=$(grep "^$rel|" "$LOG" 2>/dev/null | tail -1 || true)
      if [[ -z "$logged" ]]; then
        echo "  [NEW]      $rel"
        if [[ "$rel" =~ \.(pdf|docx|pptx|xlsx)$ ]]; then
          echo "             ⚠️  File not yet converted — run ./tools/convert.sh first"
        fi
        ((count++)) || true
      else
        logged_hash=$(echo "$logged" | cut -d'|' -f2)
        if [[ "$current_hash" != "$logged_hash" ]]; then
          echo "  [MODIFIED] $rel"
          if [[ "$rel" =~ \.(pdf|docx|pptx|xlsx)$ ]]; then
            echo "             ⚠️  File not yet converted — run ./tools/convert.sh first"
          fi
          ((count++)) || true
        fi
      fi
    done < <(_all_raw)

    if [[ $count -eq 0 ]]; then
      echo "  All files already compiled. Nothing new."
    else
      echo ""
      echo "  → Total: $count file(s) pending"
      echo "  → Run 'scan /raw' in Claude Code to compile"
    fi
    ;;

  --status)
    echo "=== SCAN STATUS ==="
    printf "%-55s %-12s %-16s %-7s\n" "File" "Status" "Compiled at" "Cost($)"
    printf "%-55s %-12s %-16s %-7s\n" "----" "------" "-----------" "-------"
    while IFS= read -r f; do
      rel="${f#$ROOT/}"
      current_hash=$(_hash "$f")
      logged=$(grep "^$rel|" "$LOG" 2>/dev/null | tail -1 || true)
      if [[ -z "$logged" ]]; then
        printf "%-55s %-12s %-16s %-7s\n" "$rel" "⚪ NEW" "-" "-"
      else
        logged_hash=$(echo "$logged" | cut -d'|' -f2)
        logged_date=$(echo "$logged" | cut -d'|' -f3)
        f_count=$(echo "$logged" | awk -F'|' '{print NF}')
        cost=$( [[ $f_count -ge 7 ]] && echo "$logged" | cut -d'|' -f7 || echo "-" )
        if [[ "$current_hash" != "$logged_hash" ]]; then
          printf "%-55s %-12s %-16s %-7s\n" "$rel" "🟡 MODIFIED" "${logged_date:0:10}" "-"
        else
          printf "%-55s %-12s %-16s %-7s\n" "$rel" "✅ DONE" "${logged_date:0:10}" "${cost:0:6}"
        fi
      fi
    done < <(_all_raw)

    echo ""
    total=$(_all_raw | wc -l | tr -d ' ')
    done_count=$(grep -c '^' "$LOG" 2>/dev/null | tr -d ' ' || echo 0)
    echo "Total: $total files | Compiled: $done_count entries in log"
    echo ""
    echo "=== WIKI ==="
    echo "Concepts : $(find "$ROOT/wiki/concepts" -name "*.md" | wc -l | tr -d ' ')"
    echo "Topics   : $(find "$ROOT/wiki/topics" -name "*.md" | wc -l | tr -d ' ')"
    echo "Summaries: $(find "$ROOT/wiki/summaries" -name "*.md" | wc -l | tr -d ' ')"
    echo "Domains  : $(find "$ROOT/wiki/domains" -name "*.md" -not -name "_*" | wc -l | tr -d ' ')"
    ;;

  --log)
    echo "=== SCAN LOG (wiki/.scan-log) ==="
    if [[ ! -s "$LOG" ]]; then
      echo "  (empty — no files compiled yet)"
    else
      printf "%-55s %-12s %-17s %-6s %-7s\n" "File" "Hash" "Date" "Time" "Cost($)"
      printf "%-55s %-12s %-17s %-6s %-7s\n" "----" "----" "----" "----" "-------"
      while IFS='|' read -r file hash date time in_t out_t cost note; do
        if [[ -z "$time" ]] || [[ "$time" == *[a-zA-Z]* && "$time" != "N/A" ]]; then
          printf "%-55s %-12s %-17s %-6s %-7s\n" "$file" "${hash:0:8}..." "$date" "-" "-"
        else
          printf "%-55s %-12s %-17s %-6s %-7s\n" "$file" "${hash:0:8}..." "$date" "${time}s" "${cost:0:6}"
        fi
      done < "$LOG"
      
      echo ""
      total_cost=$(awk -F'|' '{sum+=$7} END{printf "%.4f", sum}' "$LOG" 2>/dev/null || echo "0")
      echo "Total Estimated Cost: \$$total_cost"
    fi
    ;;

  --mark)
    # Mark file as compiled — call after Claude finishes processing
    # Usage: ./tools/scan.sh --mark "raw/articles/foo.md" [--note "part 1/3 done"]
    target="${2:-}"
    if [[ -z "$target" ]]; then
      echo "Usage: $0 --mark <relative-path> [--note \"text\"]"
      echo "Example: $0 --mark 'raw/articles/foo.md'"
      echo "Example: $0 --mark 'raw/papers/big.pdf' --note 'part 1/3 done'"
      exit 1
    fi
    # Parse optional --note and --model
    note=""
    model_flag=""
    shift 2 2>/dev/null || true
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --note) note="$2"; shift 2 ;;
        --model) model_flag="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    full="$ROOT/$target"
    if [[ ! -f "$full" ]]; then
      echo "File does not exist: $full"
      exit 1
    fi
    h=$(_hash "$full")
    ts=$(date '+%Y-%m-%d %H:%M')
    
    time_taken="-"
    if [[ -f "/tmp/.scan_start_$h" ]]; then
      start_ts=$(cat "/tmp/.scan_start_$h")
      end_ts=$(date +%s)
      time_taken=$((end_ts - start_ts))
      rm -f "/tmp/.scan_start_$h"
    fi
    
    in_tokens="0"; out_tokens="0"; cost="0"; density="0"; model="-"
    if [[ -x "$ROOT/tools/metrics.py" ]]; then
      model_arg=""
      [[ -n "$model_flag" ]] && model_arg="--model $model_flag"
      m_out=$("$ROOT/tools/metrics.py" "$full" $model_arg 2>/dev/null || true)
      if [[ -n "$m_out" ]] && [[ "$m_out" == "{"* ]]; then
        in_tokens=$(echo "$m_out" | grep -o '"in_tokens": [0-9]*' | awk '{print $2}' || echo "0")
        out_tokens=$(echo "$m_out" | grep -o '"out_tokens": [0-9]*' | awk '{print $2}' || echo "0")
        cost=$(echo "$m_out" | grep -o '"cost": [0-9.]*' | awk '{print $2}' || echo "0")
        density=$(echo "$m_out" | grep -o '"density": [0-9.]*' | awk '{print $2}' || echo "0")
        model=$(echo "$m_out" | awk -F'"model": "' '{print $2}' | awk -F'"' '{print $1}' || echo "-")
      fi
    fi
    
    echo "${target}|${h}|${ts}|${time_taken}|${in_tokens}|${out_tokens}|${cost}|${note}" >> "$LOG"
    
    msg="✅ Marked: $target (time: ${time_taken}s, cost: \$$cost [$model])"
    if [[ -n "$note" ]]; then
       msg+=" - Note: $note"
    fi
    echo "$msg"
    if [[ "$density" != "0" ]]; then
       echo "📊 Knowledge Density: $density (Out: $out_tokens / In: $in_tokens)"
    fi
    ;;

  --info)
    # Check file length and suggest compile strategy
    # Usage: ./tools/scan.sh --info raw/papers/paper.pdf
    target="${2:-}"
    if [[ -z "$target" ]]; then
      echo "Usage: $0 --info <relative-path>"
      echo "Example: $0 --info raw/papers/attention-paper.pdf"
      exit 1
    fi
    full="$ROOT/$target"
    if [[ ! -f "$full" ]]; then
      echo "File does not exist: $full"
      exit 1
    fi
    ext="${target##*.}"
    ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    echo "=== FILE INFO: $target ==="
    size=$(du -sh "$full" | cut -f1)
    echo "Size      : $size"

    # Check status in log
    rel="$target"
    current_hash=$(_hash "$full")
    logged=$(grep "^$rel|" "$LOG" 2>/dev/null | tail -1 || true)
    if [[ -z "$logged" ]]; then
      echo "Status     : ⚪ NEW — not yet compiled"
    else
      logged_hash=$(echo "$logged" | cut -d'|' -f2)
      logged_date=$(echo "$logged" | cut -d'|' -f3)
      logged_note=$(echo "$logged" | cut -d'|' -f4)
      if [[ "$current_hash" != "$logged_hash" ]]; then
        echo "Status     : 🟡 MODIFIED (compiled at $logged_date)"
      else
        echo "Status     : ✅ DONE (compiled at $logged_date${logged_note:+ — $logged_note})"
      fi
    fi

    echo ""

    case "$ext_lower" in
      pdf|docx|pptx|xlsx)
        echo "Type       : $ext_lower (Binary/Office Format)"
        echo "Strategy   : ⚠️ CONVERT FIRST (run: ./tools/convert.sh)"
        echo "  → After converting to .md, use AI to read using the Text/Markdown file thresholds."
        ;;
      md|txt)
        words=$(wc -w < "$full" | tr -d ' ')
        echo "Type       : Text / Markdown"
        echo "Word count : ~$words words"
        echo ""
        if [[ "$words" -lt 4000 ]]; then
          echo "Suggested strategy: STUFFING"
          echo "  → Read entire file at once, compile as normal"
        elif [[ "$words" -le 10000 ]]; then
          echo "Suggested strategy: REFINE"
          echo "  → Read sequentially by section, maintain a running summary"
          echo "  → Estimated ~$((words / 500 + 1)) reads (each chunk ~500 words)"
        elif [[ "$words" -le 25000 ]]; then
          echo "Suggested strategy: MAP-REDUCE"
          echo "  → Spawn parallel agents per section, combine chunk summaries into final summary"
          echo "  → Token cost: ~3-4x sequential — use only when context overflow is a real risk"
          echo ""
          # Extract section boundaries to guide chunking
          headings=$(grep -n "^## " "$full" 2>/dev/null || true)
          if [[ -n "$headings" ]]; then
            echo "  Section map (chunk by these boundaries, NOT by line count):"
            prev_line=1
            prev_title=""
            while IFS= read -r h; do
              line_num=$(echo "$h" | awk -F: '{print $1}' | tr -d '[:space:]')
              title=$(echo "$h" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/\*\*//g' | tr -d '\r')
              # Strip leading #/spaces before skip check
              clean_title=$(echo "$title" | sed 's/^#*[[:space:]]*//')
              lower_title=$(echo "$clean_title" | tr '[:upper:]' '[:lower:]')
              if echo "$lower_title" | grep -qE "^(references?|appendix|proofs?|proof of)"; then
                if [[ -n "$prev_title" ]]; then
                  span=$(( line_num - prev_line ))
                  echo "    [lines ${prev_line}-$((line_num-1))] ${prev_title} (${span} lines)"
                fi
                echo "    [SKIP line ${line_num}+] ${clean_title} (references/proofs -- not needed)"
                prev_title=""
                break
              fi
              if [[ -n "$prev_title" ]]; then
                span=$(( line_num - prev_line ))
                echo "    [lines ${prev_line}-$((line_num-1))] ${prev_title} (${span} lines)"
              fi
              prev_line=$line_num
              prev_title="$clean_title"
            done <<< "$headings"
            if [[ -n "$prev_title" ]]; then
              echo "    [lines ${prev_line}-end] ${prev_title}"
            fi
            echo ""
            echo "  Suggested chunk grouping for parallel agents:"
            # Re-run to suggest merged chunks targeting ~150-200 lines each
            chunk_start=0
            chunk_label=""
            chunk_lines=0
            chunk_idx=1
            while IFS= read -r h; do
              line_num=$(echo "$h" | awk -F: '{print $1}' | tr -d '[:space:]')
              raw_title=$(echo "$h" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/\*\*//g' | tr -d '\r')
              clean=$(echo "$raw_title" | sed 's/^#*[[:space:]]*//')
              lower=$(echo "$clean" | tr '[:upper:]' '[:lower:]')
              if echo "$lower" | grep -qE "^(references?|appendix|proofs?|proof of)"; then
                if [[ $chunk_start -gt 0 ]]; then
                  span=$(( line_num - chunk_start ))
                  echo "    Chunk ${chunk_idx}: lines ${chunk_start}-$((line_num-1)) (${span} lines) -- ${chunk_label}"
                fi
                echo "    [stop here -- skip ${clean} and beyond]"
                break
              fi
              if [[ $chunk_start -eq 0 ]]; then
                chunk_start=$line_num
                chunk_label="$clean"
                chunk_lines=0
              else
                span=$(( line_num - chunk_start ))
                if [[ $span -ge 150 ]]; then
                  echo "    Chunk ${chunk_idx}: lines ${chunk_start}-$((line_num-1)) (${span} lines) -- ${chunk_label}"
                  chunk_idx=$(( chunk_idx + 1 ))
                  chunk_start=$line_num
                  chunk_label="$clean"
                  chunk_lines=0
                fi
              fi
            done <<< "$headings"
          else
            echo "  No ## headings found -- fall back to ~200-line chunks"
          fi
        else
          echo "Suggested strategy: HIERARCHICAL SPLIT"
          echo "  → Document too long. Create per-section summaries, then synthesize."
          echo ""
          headings=$(grep -n "^## " "$full" 2>/dev/null || true)
          if [[ -n "$headings" ]]; then
            echo "  Section map:"
            while IFS= read -r h; do
              line_num=$(echo "$h" | awk -F: '{print $1}' | tr -d '[:space:]')
              title=$(echo "$h" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/\*\*//g' | tr -d '\r')
              lower_title=$(echo "$title" | tr '[:upper:]' '[:lower:]')
              if echo "$lower_title" | grep -qE "^(references|appendix|proofs?|proof of)"; then
                echo "    [SKIP line ${line_num}+] ${title}"
                break
              fi
              echo "    [line ${line_num}] ${title}"
            done <<< "$headings"
          fi
        fi
        ;;
      *)
        echo "Type       : $ext_lower"
        echo "Strategy   : Read directly (no special handling needed)"
        ;;
    esac
    echo ""
    ;;

  *)
    # Default: show all + wiki status
    echo "=== ALL RAW FILES ==="
    _all_raw | while read -r f; do
      echo "  ${f#$ROOT/}"
    done

    echo ""
    echo "=== WIKI STATUS ==="
    echo "Concepts : $(find "$ROOT/wiki/concepts" -name "*.md" | wc -l | tr -d ' ')"
    echo "Topics   : $(find "$ROOT/wiki/topics" -name "*.md" | wc -l | tr -d ' ')"
    echo "Summaries: $(find "$ROOT/wiki/summaries" -name "*.md" | wc -l | tr -d ' ')"
    echo "Domains  : $(find "$ROOT/wiki/domains" -name "*.md" -not -name "_*" | wc -l | tr -d ' ')"
    echo ""
    echo "Run './tools/scan.sh --status' to see per-file status"
    ;;
esac
