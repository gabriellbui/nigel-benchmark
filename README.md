# Nigel Benchmark

Benchmark suite for [Nigel](https://github.com/vendurehq/ai-stack/tree/main/plugins/nigel), our code review agent, evaluated against the [withmartian/code-review-benchmark](https://github.com/withmartian/code-review-benchmark) dataset.

## Dataset

- **Source**: withmartian Code Review Bench (Cal.com subset)
- **PRs**: 10 real-world Cal.com pull requests
- **Golden bugs**: 31 manually annotated bugs across severity levels
- **Methodology**: See [methodology.md](methodology.md) for full details

## Results

### Headline numbers

| Tool                     | Model        | Recall    | Critical+High Recall |
| ------------------------ | ------------ | --------- | -------------------- |
| Greptile                 | Unknown      | 82%       | --                   |
| **Nigel (baseline avg)** | **Opus 4.6** | **65.6%** | **71.4%**            |
| Cursor                   | Unknown      | 58%       | --                   |
| Copilot                  | Unknown      | 54%       | --                   |
| Code-Review Plugin       | Sonnet 4.6   | 51.6%     | 71.4%                |
| CodeRabbit               | Unknown      | 44%       | --                   |
| Graphite                 | Unknown      | 6%        | --                   |

Nigel's baseline recall (65.6%) is the mean of 3 isolated runs (run-1–run-3), scored with the extract→judge pipeline (pairwise matching, stricter than single-pass). The orchestrated run uses the review orchestrator for multi-pass analysis.

### Summary across runs

| Run              | Recall    | Caught      | Critical     | High           | Medium      | Low         |
| ---------------- | --------- | ----------- | ------------ | -------------- | ----------- | ----------- |
| run-1            | 61.3%     | 19/31       | 100.0% (2/2) | 50.0% (6/12)   | 66.7% (6/9) | 62.5% (5/8) |
| run-2            | 71.0%     | 22/31       | 100.0% (2/2) | 83.3% (10/12)  | 66.7% (6/9) | 50.0% (4/8) |
| run-3            | 64.5%     | 20/31       | 100.0% (2/2) | 66.7% (8/12)   | 66.7% (6/9) | 50.0% (4/8) |
| **Baseline avg** | **65.6%** | **20.3/31** | **100.0%**   | **66.7%**      | **66.7%**   | **54.2%**   |
| orchestrated-1   | 87.1%     | 27/31       | 100.0% (2/2) | 100.0% (12/12) | 77.8% (7/9) | 75.0% (6/8) |

### Per-PR breakdown (run-1)

| PR        | Golden Bugs | Caught | Recall    |
| --------- | ----------- | ------ | --------- |
| pr-8087   | 2           | 1      | 50.0%     |
| pr-10600  | 4           | 1      | 25.0%     |
| pr-10967  | 5           | 3      | 60.0%     |
| pr-22345  | 2           | 1      | 50.0%     |
| pr-7232   | 2           | 2      | 100.0%    |
| pr-8330   | 2           | 2      | 100.0%    |
| pr-11059  | 5           | 2      | 40.0%     |
| pr-14943  | 2           | 1      | 50.0%     |
| pr-14740  | 5           | 4      | 80.0%     |
| pr-22532  | 2           | 2      | 100.0%    |
| **Total** | **31**      | **19** | **61.3%** |

### Per-PR breakdown (run-2)

| PR        | Golden Bugs | Caught | Recall    |
| --------- | ----------- | ------ | --------- |
| pr-8087   | 2           | 1      | 50.0%     |
| pr-10600  | 4           | 1      | 25.0%     |
| pr-10967  | 5           | 4      | 80.0%     |
| pr-22345  | 2           | 1      | 50.0%     |
| pr-7232   | 2           | 2      | 100.0%    |
| pr-8330   | 2           | 2      | 100.0%    |
| pr-11059  | 5           | 5      | 100.0%    |
| pr-14943  | 2           | 2      | 100.0%    |
| pr-14740  | 5           | 3      | 60.0%     |
| pr-22532  | 2           | 1      | 50.0%     |
| **Total** | **31**      | **22** | **71.0%** |

### Per-PR breakdown (run-3)

| PR        | Golden Bugs | Caught | Recall    |
| --------- | ----------- | ------ | --------- |
| pr-8087   | 2           | 1      | 50.0%     |
| pr-10600  | 4           | 1      | 25.0%     |
| pr-10967  | 5           | 3      | 60.0%     |
| pr-22345  | 2           | 1      | 50.0%     |
| pr-7232   | 2           | 2      | 100.0%    |
| pr-8330   | 2           | 2      | 100.0%    |
| pr-11059  | 5           | 5      | 100.0%    |
| pr-14943  | 2           | 1      | 50.0%     |
| pr-14740  | 5           | 3      | 60.0%     |
| pr-22532  | 2           | 1      | 50.0%     |
| **Total** | **31**      | **20** | **64.5%** |

### Per-PR breakdown (orchestrated-run-1)

| PR        | Golden Bugs | Caught | Recall    |
| --------- | ----------- | ------ | --------- |
| pr-8087   | 2           | 2      | 100.0%    |
| pr-10600  | 4           | 4      | 100.0%    |
| pr-10967  | 5           | 4      | 80.0%     |
| pr-22345  | 2           | 1      | 50.0%     |
| pr-7232   | 2           | 2      | 100.0%    |
| pr-8330   | 2           | 2      | 100.0%    |
| pr-11059  | 5           | 5      | 100.0%    |
| pr-14943  | 2           | 2      | 100.0%    |
| pr-14740  | 5           | 3      | 60.0%     |
| pr-22532  | 2           | 2      | 100.0%    |
| **Total** | **31**      | **27** | **87.1%** |

### Severity breakdown

| Severity | Total | run-1        | run-2         | run-3        | Baseline Avg |
| -------- | ----- | ------------ | ------------- | ------------ | ------------ |
| Critical | 2     | 100.0% (2/2) | 100.0% (2/2)  | 100.0% (2/2) | 100.0%       |
| High     | 12    | 50.0% (6/12) | 83.3% (10/12) | 66.7% (8/12) | 66.7%        |
| Medium   | 9     | 66.7% (6/9)  | 66.7% (6/9)   | 66.7% (6/9)  | 66.7%        |
| Low      | 8     | 62.5% (5/8)  | 50.0% (4/8)   | 50.0% (4/8)  | 54.2%        |

## Running a new benchmark

1. Pick a tool/agent to evaluate
2. For each diff in `diffs/`, run the tool and capture its findings
3. Score each finding against `ground-truth/cal_dot_com.json` using the matching criteria in [methodology.md](methodology.md)
4. Record results in a new `results/<tool-name>/` directory
5. Compare against existing results using the CSV format from `results/comparisons/`
