# Nigel Benchmark

Benchmark suite for [Nigel](https://github.com/gabriellbui/nigel), our code review agent, evaluated against the [withmartian/code-review-benchmark](https://github.com/withmartian/code-review-benchmark) dataset.

## Dataset

- **Source**: withmartian Code Review Bench (Cal.com subset)
- **PRs**: 10 real-world Cal.com pull requests
- **Golden bugs**: 31 manually annotated bugs across severity levels
- **Methodology**: See [methodology.md](methodology.md) for full details

## Results

### Headline numbers

| Tool | Model | Recall | Critical+High Recall |
|------|-------|--------|----------------------|
| Greptile | Unknown | 82% | -- |
| **Nigel (avg)** | **Opus 4.6** | **75.8%** | **85.7%** |
| Cursor | Unknown | 58% | -- |
| Copilot | Unknown | 54% | -- |
| Code-Review Plugin | Sonnet 4.6 | 51.6% | 71.4% |
| CodeRabbit | Unknown | 44% | -- |
| Graphite | Unknown | 6% | -- |

Nigel's average recall (75.8%) is the mean of Run 1 (77.4%) and Run 2 (74.2%).

### Per-PR breakdown (Nigel Run 1)

| PR | Golden Bugs | Caught | Recall |
|----|-------------|--------|--------|
| pr-8087 | 2 | 2 | 100% |
| pr-10600 | 4 | 1 | 25% |
| pr-10967 | 5 | 4 | 80% |
| pr-22345 | 2 | 1 | 50% |
| pr-7232 | 2 | 2 | 100% |
| pr-8330 | 2 | 2 | 100% |
| pr-11059 | 5 | 5 | 100% |
| pr-14943 | 2 | 2 | 100% |
| pr-14740 | 5 | 3 | 60% |
| pr-22532 | 2 | 2 | 100% |
| **Total** | **31** | **24** | **77.4%** |

### Severity breakdown

| Severity | Total | Caught | Recall |
|----------|-------|--------|--------|
| Critical | 2 | 2 | 100% |
| High | 12 | 10 | 83.3% |
| Medium | 9 | 6 | 66.7% |
| Low | 8 | 6 | 75.0% |

### Reproducibility

Two independent runs showed 96.8% consistency — 30 of 31 bugs scored identically. The single difference was a Low-severity macOS sed syntax bug in pr-22532 that was caught in Run 1 but missed in Run 2.

| Metric | Run 1 | Run 2 |
|--------|-------|-------|
| Recall | 77.4% | 74.2% |
| Identical scores | 30/31 | 96.8% |

### Nigel vs Code-Review Plugin

Nigel outperformed the official Claude Code code-review plugin on 6 of 10 PRs, tied on 4, and lost on none. Overall recall delta: +25.8pp (77.4% vs 51.6%).

## Repo structure

```
ground-truth/         # Annotated golden bugs
diffs/                # Raw PR diffs (10 files)
results/
  nigel-baseline/     # Run 1 detailed results
  nigel-run2/         # Run 2 results
  code-review-plugin/ # Claude Code plugin results
  comparisons/        # Cross-tool comparisons
methodology.md        # Full benchmark methodology
```

## Running a new benchmark

1. Pick a tool/agent to evaluate
2. For each diff in `diffs/`, run the tool and capture its findings
3. Score each finding against `ground-truth/cal_dot_com.json` using the matching criteria in [methodology.md](methodology.md)
4. Record results in a new `results/<tool-name>/` directory
5. Compare against existing results using the CSV format from `results/comparisons/`
