# Improvement Rationale

## Why These Two Changes

Two improvement vectors, both evidence-backed:

1. **Bug taxonomy** — Direct fix for 5/7 missed bugs
2. **Multi-agent orchestrator** — Context-feeding agents enable deeper review

### Why Bug Taxonomy

The strongest evidence: Nigel already catches same-class bugs elsewhere in the benchmark. The misses aren't capability gaps — they're attention gaps. A structured checklist forces dedicated attention to each bug category.

**Sibling-bug evidence table:**

| Missed Bug | Same-Class Bug Nigel Caught |
|---|---|
| Case-sensitive `indexOf` on backup codes (pr-10600) | `===` on dayjs objects — reference vs value comparison (pr-8330) |
| Email blacklist case bypass (pr-14740) | `&&` vs `\|\|` auth check — logical operator bug (pr-14740) |
| TOCTOU race on backup codes (pr-10600) | Stale `retryCount + 1` — read-then-write race (pr-14943) |
| Org members excluded by guard (pr-22345) | `deleteMany` missing filter — data integrity (pr-14943) |
| No dedup within input (pr-14740) | Wrong list to `sendAddGuestsEmails` — data flow (pr-14740) |

5 of 7 misses have a sibling bug Nigel caught in the same or another PR. The remaining 2 (wrong error message text, redundant optional chaining) are low-severity nits not worth targeting.

### Why These 3 Categories

The 5 addressable missed bugs cluster into exactly 3 patterns:

1. **String & comparison edge cases** (2 bugs): Case-sensitive indexOf, case-sensitive blacklist check
2. **Concurrency & race conditions** (1 bug): TOCTOU on backup codes
3. **Data integrity & validation gaps** (2 bugs): Conditional guard excluding valid data, missing input dedup

### Why Multi-Agent Orchestrator

Industry evidence shows the biggest gains come from **depth through context**, not more passes:

| Tool | Architecture Change | Impact |
|---|---|---|
| BugBot | 8 parallel passes → single agentic agent with tools | 52% → 70% resolution rate |
| Greptile v3 | Static pipeline → agentic loop with recursive search | 3x more bugs than v2 |
| Code-review plugin | 5 parallel Sonnet agents | 51.6% recall (shallow = weak) |

The pattern: context-gathering agents (cheap) feed a deep reviewer (expensive) who can follow leads. This is exactly what the orchestrator does — 3 Haiku agents gather CLAUDE.md conventions, codebase context, and git history, then Nigel reviews with all that context.

### What Was Filtered Out

| Technique | Why Not |
|---|---|
| Personality priming ("you are the world's best bug finder") | No evidence this improves structured technical analysis |
| Adversarial pass ("assume every line has a bug") | Risk of false positive explosion; BugBot abandoned this |
| Few-shot examples | Benchmark diffs vary too much; examples could anchor on wrong patterns |
| Structured output (JSON findings) | Constrains Nigel's natural reasoning; markdown is fine |
| Confidence scoring + filtering | Code-review plugin uses this and gets 51.6% recall; filtering kills true positives |
| More than 3 taxonomy categories | Diminishing returns; remaining 2 misses are domain-specific nits |

## Metrics to Track

Beyond recall and precision, each benchmark run should record:

| Metric | Why It Matters |
|---|---|
| **Recall** (golden bugs caught / total) | Primary metric — are we finding more bugs? |
| **Precision** (valid findings / total findings) | Secondary — are we generating noise? |
| **Wall-clock time per review** | Cost metric — how much slower is each approach? |
| **Time-to-recall ratio** | Efficiency — recall per minute of review time |
| **Regressions** | Safety — all 24 previously-caught bugs still caught |
| **New true positives** | Bonus — valid findings beyond the golden set |

Time tracking is critical because the taxonomy adds a structured pass (+30-60s estimated) and the orchestrator adds context gathering + deeper review (+60-120s estimated). If recall doesn't improve enough to justify the time cost, the change isn't worth shipping.

## Sources

- [withmartian Code Review Bench methodology](https://www.withmartian.com/blog/code-review-bench)
- [Greptile v3 blog post on agentic code review](https://www.greptile.com/blog)
- [BugBot evolution from multi-pass to agentic](https://www.greptile.com/blog/bugbot)
- [Qodo multi-agent code review comparison](https://www.qodo.ai/blog)
