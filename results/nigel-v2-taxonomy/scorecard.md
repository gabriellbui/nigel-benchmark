# Nigel v2 (Taxonomy) — Quick Validation Scorecard

## Summary

| Metric | Value |
|---|---|
| **PRs Tested** | 3 (worst-performing from baseline) |
| **Golden Bugs** | 11 |
| **Caught** | 7 |
| **Quick Validation Recall** | **63.6%** |
| **Baseline Recall (same 3 PRs)** | 45.5% |
| **Improvement** | +2 bugs (+18.1pp) |
| **Total Time** | 211.4s (avg 70.5s per PR) |

## Projected Full Benchmark

- Baseline: 24/31 = 77.4%
- +2 new bugs (no regressions on tested PRs): 26/31 = **83.9%**
- Target was >= 85%: **NOT MET** (but close)

## Per-PR Results

### PR-10600 (2FA Backup Codes): 2/4 = 50% (was 25%)
- **NEW**: Caught error message wrong context (Low) — organic, not taxonomy-driven
- **STILL MISSED**: Case-sensitive indexOf (Medium) — Nigel flagged timing, not case
- **STILL MISSED**: TOCTOU race (High) — found related issue on wrong path
- Time: 99.4s (longer due to WebFetch for PR context)

### PR-14740 (Guest Management): 4/5 = 80% (was 60%)
- **NEW**: Caught email blacklist case bypass (High) — **taxonomy category 6a direct hit**
- **STILL MISSED**: Within-input dedup (Medium) — client Zod has uniqueness, server doesn't
- Time: 55.7s

### PR-22345 (InsightsBookingService): 1/2 = 50% (unchanged)
- **STILL MISSED**: Org member exclusion (Medium) — found array asymmetry, not data exclusion
- Time: 56.3s

## Taxonomy Effectiveness

Of 5 taxonomy-targeted bugs:
- **1 caught** (20%): Case sensitivity bypass in blacklist (6a)
- **4 missed** (80%): indexOf case (6a), TOCTOU race (6b), org exclusion (6c), dedup gap (6c)

The taxonomy helped on the most straightforward case (blacklist case comparison) but failed on bugs requiring deeper data flow tracing (TOCTOU, dedup, conditional exclusion). These bugs need **codebase context** that Nigel doesn't have from the diff alone.

## Key Insight

The taxonomy's 1/5 targeted hit rate suggests the checklist alone isn't enough for context-dependent bugs. The remaining 4 bugs require understanding:
- **Data models** (org members without teams, attendee dedup semantics)
- **Concurrent access patterns** (two requests hitting the same backup code)
- **Cross-file data flow** (which list gets passed to which function)

This is exactly what the multi-agent orchestrator is designed to provide — context agents that surface data models, git history, and surrounding code.

## Recommendation

- **Taxonomy alone**: Marginal improvement (+2 bugs), projected 83.9%
- **Run orchestrator test**: Context agents may catch the remaining 4 bugs
- **No regressions**: All previously-caught bugs still caught on tested PRs
