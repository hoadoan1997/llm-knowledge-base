#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <raw_file_path> [key_insight] [--model model_name]"
    exit 1
fi

RAW_FILE="$1"
INSIGHT=""
MODEL_FLAG=""

shift
while [ $# -gt 0 ]; do
    case "$1" in
        --model) MODEL_FLAG="$2"; shift 2 ;;
        *) [ -z "$INSIGHT" ] && INSIGHT="$1"; shift ;;
    esac
done

MARK_ARGS="--mark \"$RAW_FILE\""
[ -n "$MODEL_FLAG" ] && MARK_ARGS="$MARK_ARGS --model $MODEL_FLAG"

echo "[1/4] Building wiki indexes..."
python3 ./tools/build-index.py

echo "[2/4] Quick lint on compiled output..."
BASE=$(basename "$RAW_FILE" | sed 's/\.[^.]*$//')
SLUG=$(echo "$BASE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
SUMMARY="wiki/summaries/${SLUG}.md"
LINT_OK=1
if [ -f "$SUMMARY" ]; then
    ./tools/lint.sh --quick "$SUMMARY" || LINT_OK=0
else
    echo "  (summary file not found at $SUMMARY — skipping quick lint)"
fi

echo "[3/4] Marking file as compiled..."
eval ./tools/scan.sh $MARK_ARGS

if [ -n "$INSIGHT" ]; then
    echo "[4/4] Appending key insight to _brief.md..."
    perl -i -pe "s|<!-- BUILD_INDEX:INSIGHTS_END -->|- $INSIGHT\n<!-- BUILD_INDEX:INSIGHTS_END -->|" wiki/_brief.md
else
    echo "[4/4] No key insight provided. Skipping."
fi

if [ $LINT_OK -eq 0 ]; then
    echo "⚠️  Lint found issues — review and fix above warnings."
fi

echo "✅ Compile pipeline finished successfully."
