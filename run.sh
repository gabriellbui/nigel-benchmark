#!/usr/bin/env bash
set -euo pipefail

# Usage: bash run.sh <name> [--max-turns N] [--verbose] [--tool-prompt]
# Examples:
#   bash run.sh nigel-run-3
#   bash run.sh nigel-run-2 --max-turns 15 --verbose --tool-prompt

NAME="${1:?Usage: bash run.sh <name> [--max-turns N] [--verbose] [--tool-prompt]}"
shift

MAX_TURNS=1
VERBOSE=""
TOOL_PROMPT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --max-turns) MAX_TURNS="$2"; shift 2 ;;
        --verbose) VERBOSE="--verbose"; shift ;;
        --tool-prompt) TOOL_PROMPT=1; shift ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

unset CLAUDECODE 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results/$NAME/raw"
GROUND_TRUTH="$SCRIPT_DIR/ground-truth/cal_dot_com.json"
NIGEL_PERSONA="$HOME/Desktop/ai-stack/agents/nigel-code-critic.md"
DIFFS_DIR="$SCRIPT_DIR/diffs"
TIMINGS_FILE="$SCRIPT_DIR/results/$NAME/timings.csv"

mkdir -p "$RESULTS_DIR"

nigel_body=$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$NIGEL_PERSONA")

echo "pr_number,wall_clock_seconds" > "$TIMINGS_FILE"
total_start=$(date +%s)

echo "=== $NAME Benchmark (PARALLEL) ==="
echo "max-turns=$MAX_TURNS verbose=${VERBOSE:-off} tool-prompt=${TOOL_PROMPT:-off}"
echo ""

run_pr() {
    local pr_num="$1"
    local pr_title="$2"
    local pr_url="$3"
    local diff_file="$DIFFS_DIR/pr-${pr_num}.diff"
    local output_file="$RESULTS_DIR/pr-${pr_num}.txt"

    if [ ! -f "$diff_file" ]; then
        echo "[pr-${pr_num}] SKIP: diff not found"
        return
    fi

    if [ -f "$output_file" ]; then
        local size
        size=$(wc -c < "$output_file")
        if [ "$size" -gt 100 ]; then
            echo "[pr-${pr_num}] SKIP: already has output (${size} bytes)"
            return
        fi
        rm -f "$output_file"
    fi

    local diff_content
    diff_content=$(cat "$diff_file")

    local review_instruction="Review this PR:"
    if [ -n "$TOOL_PROMPT" ]; then
        review_instruction="Review this pull request. Use your tools to fetch source files from GitHub when you need more context about the code being changed."
    fi

    local prompt_file="/tmp/nigel-run-${NAME}-pr-${pr_num}.md"
    cat > "$prompt_file" <<PROMPT_EOF
<persona>
$nigel_body
</persona>

$review_instruction

<pr-info>
Title: $pr_title
URL: $pr_url
</pr-info>

<diff>
$diff_content
</diff>
PROMPT_EOF

    echo "[pr-${pr_num}] STARTED: $pr_title"
    local pr_start
    pr_start=$(date +%s)

    claude --print --max-turns "$MAX_TURNS" $VERBOSE < "$prompt_file" > "$output_file" 2>&1 || true

    local pr_end
    pr_end=$(date +%s)
    local pr_duration=$((pr_end - pr_start))

    if grep -q "hit your limit" "$output_file" 2>/dev/null; then
        echo "[pr-${pr_num}] RATE LIMITED after ${pr_duration}s"
        rm -f "$output_file"
    else
        local out_size
        out_size=$(wc -c < "$output_file")
        echo "[pr-${pr_num}] DONE in ${pr_duration}s (${out_size} bytes)"
        echo "${pr_num},${pr_duration}" >> "$TIMINGS_FILE"
    fi

    rm -f "$prompt_file"
}

export -f run_pr
export DIFFS_DIR RESULTS_DIR TIMINGS_FILE MAX_TURNS VERBOSE TOOL_PROMPT NAME nigel_body

pids=()
while IFS=$'\t' read -r pr_num pr_title pr_url; do
    run_pr "$pr_num" "$pr_title" "$pr_url" &
    pids+=($!)
done < <(python3 -c "
import json
with open('$GROUND_TRUTH') as f:
    data = json.load(f)
for pr in data:
    num = pr['url'].split('/')[-1]
    print(f'{num}\t{pr[\"pr_title\"]}\t{pr[\"url\"]}')
")

echo "Launched ${#pids[@]} parallel reviews. Waiting..."

for pid in "${pids[@]}"; do
    wait "$pid" || true
done

total_end=$(date +%s)
total_duration=$((total_end - total_start))

echo ""
echo "=== Complete ==="
echo "Total wall-clock: ${total_duration}s ($((total_duration / 60))m $((total_duration % 60))s)"
echo ""
ls -lh "$RESULTS_DIR"
echo ""
cat "$TIMINGS_FILE"
