#!/usr/bin/env bash
set -euo pipefail

# Usage: bash score.sh <name>
# Examples:
#   bash score.sh nigel-run-3
#   bash score.sh nigel-run-2

NAME="${1:?Usage: bash score.sh <name>}"
LOGFILE="results/${NAME}/score.log"

unset CLAUDECODE 2>/dev/null || true

mkdir -p "results/${NAME}"
echo "=== Scoring $NAME Benchmark ==="
echo "Logging to $LOGFILE"

python3 -u - "$NAME" << 'PYEOF'
import json, os, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor, as_completed
from collections import defaultdict

NAME = sys.argv[1]
LOGFILE = f"results/{NAME}/score.log"
RAW_DIR = f"results/{NAME}/raw"
JUDGE_DIR = f"results/{NAME}/judge"
GROUND_TRUTH = "ground-truth/cal_dot_com.json"

_logfh = open(LOGFILE, "w")
_orig_print = print
def print(*args, **kwargs):
    _orig_print(*args, **kwargs, flush=True)
    _orig_print(*args, **{**kwargs, "file": _logfh}, flush=True)

os.makedirs(JUDGE_DIR, exist_ok=True)

with open(GROUND_TRUTH) as f:
    data = json.load(f)

_call_count = 0
_call_lock = __import__("threading").Lock()

def call_claude(prompt, retries=2):
    global _call_count
    with _call_lock:
        _call_count += 1
        call_id = _call_count
    prompt_file = f"/tmp/nigel-score-{os.getpid()}-{call_id}.md"
    for attempt in range(retries + 1):
        try:
            with open(prompt_file, "w") as f:
                f.write(prompt)
            env = os.environ.copy()
            env.pop("CLAUDECODE", None)
            with open(prompt_file) as stdin_f:
                result = subprocess.run(
                    ["claude", "--print", "--max-turns", "1"],
                    stdin=stdin_f,
                    capture_output=True, text=True, env=env,
                    timeout=180,
                )
            output = result.stdout.strip()
            if "hit your limit" in output or "hit your limit" in result.stderr:
                raise RuntimeError("RATE LIMITED")
            if result.returncode != 0 and not output:
                raise RuntimeError(f"claude exited {result.returncode}: {result.stderr[:200]}")
            return output
        except subprocess.TimeoutExpired:
            if attempt < retries:
                print(f"  [call {call_id}] timeout, retrying ({attempt+1}/{retries})...")
                continue
            raise RuntimeError(f"claude timed out after {retries+1} attempts")
        finally:
            if os.path.exists(prompt_file):
                os.remove(prompt_file)

def parse_json_response(text):
    text = text.strip()
    if text.startswith("```"):
        lines = text.split("\n")
        lines = lines[1:]  # skip ```json
        end = next((i for i, l in enumerate(lines) if l.strip() == "```"), len(lines))
        text = "\n".join(lines[:end])
    return json.loads(text)

# ===== Judge: one call per golden bug against the raw review =====
print("\n--- Judging: each golden bug vs raw review ---")

def judge_bug(pr_num, bug_idx, bug_text, bug_severity, review_text):
    prompt = f"""You are a strict code review evaluator.

Given a golden bug (a known real defect) and the full text of a code review, determine if the review identifies this specific defect.

<golden-bug severity="{bug_severity}">
{bug_text}
</golden-bug>

<review>
{review_text}
</review>

Rules:
- The review must identify the SAME specific root cause or defect as the golden bug
- General area similarity is NOT sufficient — the review must describe the same problem
- A different diagnosis of the same code area is NOT a match (e.g. "dead code" vs "wrong comparison" are different even if about the same line)
- If the diagnosis differs, it is NOT a match even if the code area overlaps
- Vague mentions of the area without identifying the specific problem do NOT count
- When in doubt, say no — only match when the review clearly identifies the same defect

Return JSON only, no markdown fences:
{{"match": true/false, "confidence": <0.0-1.0>, "evidence": "quote or paraphrase from the review that matches, or empty string if no match", "reasoning": "one sentence"}}"""

    try:
        resp = call_claude(prompt)
        parsed = parse_json_response(resp)
        return {
            "bug_idx": bug_idx,
            "match": bool(parsed.get("match", False)),
            "confidence": float(parsed.get("confidence", 0.0)),
            "evidence": parsed.get("evidence", ""),
            "reasoning": parsed.get("reasoning", ""),
        }
    except RuntimeError:
        raise
    except Exception as e:
        return {
            "bug_idx": bug_idx,
            "match": False,
            "confidence": 0.0,
            "evidence": "",
            "reasoning": f"PARSE ERROR: {e}",
        }

# Collect all judge tasks
all_judge_tasks = []
for pr in data:
    pr_num = pr["url"].split("/")[-1]
    raw_file = os.path.join(RAW_DIR, f"pr-{pr_num}.txt")
    judge_file = os.path.join(JUDGE_DIR, f"pr-{pr_num}.json")

    if not os.path.exists(raw_file):
        print(f"[pr-{pr_num}] SKIP: no raw review")
        continue

    if os.path.exists(judge_file):
        try:
            with open(judge_file) as f:
                d = json.load(f)
            if "matches" in d and len(d["matches"]) > 0:
                print(f"[pr-{pr_num}] SKIP: already judged ({len(d['matches'])} bugs)")
                continue
        except (json.JSONDecodeError, KeyError):
            pass

    with open(raw_file) as f:
        review_text = f.read()

    for bi, bug in enumerate(pr["comments"]):
        all_judge_tasks.append((pr_num, bi, bug, review_text, judge_file))

total_calls = len(all_judge_tasks)
print(f"Launching {total_calls} judge calls across {len(data)} PRs...")

# Fire all bug judgments in parallel
all_futures = {}
with ThreadPoolExecutor(max_workers=3) as executor:
    for pr_num, bi, bug, review_text, judge_file in all_judge_tasks:
        f = executor.submit(judge_bug, pr_num, bi, bug["comment"], bug["severity"], review_text)
        all_futures[f] = (pr_num, bi)

    done_count = 0
    error_count = 0
    pr_results = defaultdict(list)
    for future in as_completed(all_futures):
        pr_num, bi = all_futures[future]
        try:
            result = future.result()
            pr_results[pr_num].append(result)
        except Exception as e:
            error_count += 1
            if error_count <= 5:
                print(f"ERROR pr-{pr_num} bug={bi}: {e}")
        done_count += 1
        if done_count % 10 == 0 or done_count == total_calls:
            print(f"  {done_count}/{total_calls} bugs judged ({error_count} errors)")

# Save results per PR
pr_bug_counts = {}
for pr in data:
    pr_num = pr["url"].split("/")[-1]
    pr_bug_counts[pr_num] = len(pr["comments"])

for pr_num, results in pr_results.items():
    judge_file = os.path.join(JUDGE_DIR, f"pr-{pr_num}.json")
    expected = pr_bug_counts.get(pr_num, 0)
    if len(results) < expected:
        print(f"[pr-{pr_num}] INCOMPLETE: {len(results)}/{expected} bugs — skipping save")
        continue

    with open(judge_file, "w") as f:
        json.dump({"matches": results, "bugs": expected}, f, indent=2)

    matched = sum(1 for r in results if r["match"])
    print(f"[pr-{pr_num}] Done: {matched}/{expected} bugs matched")

# ===== Generate CSVs + print summary =====
print("\n--- Generating CSVs ---")

golden_rows = []
summary_rows = []

for pr in data:
    pr_num = pr["url"].split("/")[-1]
    pr_title = pr["pr_title"]
    judge_file = os.path.join(JUDGE_DIR, f"pr-{pr_num}.json")
    bugs = pr["comments"]

    if not os.path.exists(judge_file):
        print(f"WARN: No judge output for PR #{pr_num}")
        for bug in bugs:
            golden_rows.append({
                "pr_number": pr_num, "pr_title": pr_title,
                "bug": bug["comment"][:100], "severity": bug["severity"],
                "caught": "UNKNOWN", "evidence": "", "confidence": 0.0,
            })
        summary_rows.append({
            "pr_number": pr_num, "pr_title": pr_title,
            "total_bugs": len(bugs), "caught": 0,
            "missed": len(bugs), "recall": "0.0%",
        })
        continue

    with open(judge_file) as f:
        judge_data = json.load(f)

    matches = judge_data.get("matches", [])
    caught_count = 0

    for bi, bug in enumerate(bugs):
        entry = next((r for r in matches if r["bug_idx"] == bi), None)
        is_match = entry.get("match", False) if entry else False

        if is_match:
            caught_count += 1
            golden_rows.append({
                "pr_number": pr_num, "pr_title": pr_title,
                "bug": bug["comment"][:100], "severity": bug["severity"],
                "caught": "YES", "evidence": entry.get("evidence", "")[:120],
                "confidence": entry.get("confidence", 0.0),
            })
        else:
            golden_rows.append({
                "pr_number": pr_num, "pr_title": pr_title,
                "bug": bug["comment"][:100], "severity": bug["severity"],
                "caught": "NO", "evidence": "", "confidence": 0.0,
            })

    total = len(bugs)
    recall = f"{caught_count/total*100:.1f}%" if total > 0 else "N/A"

    summary_rows.append({
        "pr_number": pr_num, "pr_title": pr_title,
        "total_bugs": total, "caught": caught_count,
        "missed": total - caught_count, "recall": recall,
    })

# Write golden-bugs.csv
golden_csv = f"results/{NAME}/golden-bugs.csv"
with open(golden_csv, "w") as f:
    f.write("pr_number,pr_title,bug_description,severity,caught,evidence,confidence\n")
    for r in golden_rows:
        bug_esc = r["bug"].replace('"', '""')
        title_esc = r["pr_title"].replace('"', '""')
        ev_esc = r["evidence"].replace('"', '""')
        f.write(f'{r["pr_number"]},"{title_esc}","{bug_esc}",{r["severity"]},{r["caught"]},"{ev_esc}",{r["confidence"]}\n')

# Write summary.csv
summary_csv = f"results/{NAME}/summary.csv"
with open(summary_csv, "w") as f:
    f.write("pr_number,pr_title,total_bugs,caught,missed,recall\n")
    for r in summary_rows:
        title_esc = r["pr_title"].replace('"', '""')
        f.write(f'{r["pr_number"]},"{title_esc}",{r["total_bugs"]},{r["caught"]},{r["missed"]},{r["recall"]}\n')
    total_bugs = sum(r["total_bugs"] for r in summary_rows)
    total_caught = sum(r["caught"] for r in summary_rows)
    overall_recall = f"{total_caught/total_bugs*100:.1f}%" if total_bugs > 0 else "N/A"
    f.write(f'TOTAL,"All PRs",{total_bugs},{total_caught},{total_bugs - total_caught},{overall_recall}\n')

# Write severity breakdown CSV
severity_csv = f"results/{NAME}/severity-breakdown.csv"
sev_stats = defaultdict(lambda: {"total": 0, "caught": 0})
for r in golden_rows:
    sev = r["severity"]
    sev_stats[sev]["total"] += 1
    if r["caught"] == "YES":
        sev_stats[sev]["caught"] += 1

with open(severity_csv, "w") as f:
    f.write("severity,total,caught,missed,recall\n")
    for sev in ["Critical", "High", "Medium", "Low"]:
        s = sev_stats.get(sev, {"total": 0, "caught": 0})
        if s["total"] == 0:
            continue
        missed = s["total"] - s["caught"]
        recall = f"{s['caught']/s['total']*100:.1f}%"
        f.write(f'{sev},{s["total"]},{s["caught"]},{missed},{recall}\n')
    all_total = sum(v["total"] for v in sev_stats.values())
    all_caught = sum(v["caught"] for v in sev_stats.values())
    all_recall = f"{all_caught/all_total*100:.1f}%" if all_total > 0 else "N/A"
    f.write(f'TOTAL,{all_total},{all_caught},{all_total - all_caught},{all_recall}\n')

# Read timings
timings = {}
timings_file = f"results/{NAME}/timings.csv"
if os.path.exists(timings_file):
    with open(timings_file) as f:
        for line in f:
            if line.startswith("pr_number"):
                continue
            parts = line.strip().split(",")
            if len(parts) == 2:
                timings[parts[0]] = parts[1]

# Print summary
print(f"\n{'='*70}")
print(f"RESULTS: {NAME}")
print(f"{'='*70}")
print(f"{'PR':<10} {'Caught':>8} {'Total':>8} {'Recall':>8} {'Time':>8}")
print(f"{'-'*10} {'-'*8} {'-'*8} {'-'*8} {'-'*8}")
for r in summary_rows:
    t = timings.get(r["pr_number"], "?")
    print(f"#{r['pr_number']:<9} {r['caught']:>8} {r['total_bugs']:>8} {r['recall']:>8} {t:>7}s")
print(f"{'-'*10} {'-'*8} {'-'*8} {'-'*8} {'-'*8}")
print(f"{'TOTAL':<10} {total_caught:>8} {total_bugs:>8} {overall_recall:>8}")

print(f"\nSeverity Breakdown:")
print(f"{'Severity':<10} {'Caught':>8} {'Total':>8} {'Recall':>8}")
print(f"{'-'*10} {'-'*8} {'-'*8} {'-'*8}")
for sev in ["Critical", "High", "Medium", "Low"]:
    s = sev_stats.get(sev, {"total": 0, "caught": 0})
    if s["total"] == 0:
        continue
    r = f"{s['caught']/s['total']*100:.1f}%"
    print(f"{sev:<10} {s['caught']:>8} {s['total']:>8} {r:>8}")

print(f"\nCSVs written:")
print(f"  {golden_csv}")
print(f"  {summary_csv}")
print(f"  {severity_csv}")
PYEOF
