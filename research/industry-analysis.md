# Industry Analysis: AI Code Review Tools

## Overview

Analysis of 4 agentic code review systems to inform Nigel improvements. Key architectural patterns extracted from each.

## BugBot (Greptile)

### Evolution
- **v1**: 8 parallel prompts, each reviewing the diff from a different angle
- **v2**: Single agentic agent with tool access (Glob, Grep, Read, git)

### Architecture
- Originally used majority voting across 8 passes to reduce false positives
- Evolved to single agent because depth > breadth: one agent that can investigate beats 8 that skim
- "Aggressive prompts that encouraged the agent to investigate every suspicious pattern"
- Resolution rate: 52% → 70% after agentic shift

### Key Insights
- Multi-pass with voting was abandoned — too shallow, missed context-dependent bugs
- Tool access (codebase search, file reading) was the biggest single improvement
- "Aggressive" here means "investigate everything", not "flag everything"

## Greptile v3

### Architecture
- Single agentic loop with recursive codebase search
- Multi-hop reasoning: follows function calls, checks git history, compares patterns
- Can recursively explore the codebase to build understanding

### Results
- 82% recall on Cal.com benchmark (best in class)
- 3x more bugs than v2's rigid pipeline
- Achieved this through depth, not more agents

### Key Insights
- The winning pattern is "follow leads" — when something looks suspicious, trace it
- Codebase context is critical: knowing what a function does elsewhere reveals bugs in the diff
- Git history reveals intent: "this was changed because..." informs whether a new change regresses

## Code-Review Plugin (Official Claude Code)

### Architecture
- Step 1: Haiku eligibility check
- Step 2: Haiku finds CLAUDE.md files
- Step 3: Haiku summarizes the PR
- Step 4: 5 parallel Sonnet agents, each reviewing from a different angle:
  - CLAUDE.md compliance
  - Shallow bug scan (no extra context)
  - Git blame/history context
  - Previous PR comments
  - Code comment compliance
- Step 5: Haiku confidence scoring per finding (0-100 scale)
- Step 6: Filter to >= 80 confidence only
- Step 7: Post comment on PR

### Results
- 51.6% recall on Cal.com benchmark
- 71.4% critical+high recall
- High precision (aggressive filtering removes many true positives)

### Key Insights
- **Context separation works** — dedicated agents for CLAUDE.md, git history, etc.
- **Sonnet is too weak** for deep bug analysis — misses subtle bugs
- **Shallow scan + no extra context** (Agent #2) catches obvious bugs only
- **Confidence filtering at 80 is too aggressive** — kills true positives
- **No agentic depth** — agents can't follow leads or investigate further

### Lessons for Nigel
- Adopt the context-separation pattern (CLAUDE.md, git history, codebase context)
- Use Opus (not Sonnet) for the deep review pass
- Don't filter findings — let the reviewer decide
- Give the deep reviewer tool access for investigation

## Qodo (Multi-Agent)

### Architecture
- Specialized agents per concern:
  - Security agent
  - Concurrency agent
  - Dependencies agent
  - General quality agent
- Each agent gets full attention on its domain

### Key Insights
- Single-agent reviews "compress" concerns as scope grows — security gets less attention when the agent is also checking style
- Specialized agents avoid this compression
- But this adds latency and cost proportional to number of agents

### Lessons for Nigel
- The bug taxonomy addresses this without extra agents — a structured checklist ensures each concern gets attention
- Cheaper than spawning specialized agents, similar effect

## Architectural Patterns Summary

| Pattern | Used By | Evidence | Nigel's Approach |
|---|---|---|---|
| Agentic depth (tool access) | BugBot v2, Greptile v3 | BugBot: 52%→70%, Greptile: 3x improvement | Nigel already has Glob/Grep/Read tools |
| Context feeding | Code-review plugin, Greptile v3 | Context agents improve review quality | New orchestrator: 3 Haiku context agents |
| Structured bug checklist | Qodo (per-agent) | Prevents concern compression | New taxonomy: 3 bug categories |
| Aggressive investigation | BugBot v2 | Higher resolution rate | Taxonomy says "actively look — absence means you checked" |
| Confidence filtering | Code-review plugin | Hurts recall (51.6%) | Not adopted — trust Nigel's judgment |
| Multi-pass voting | BugBot v1 (abandoned) | Abandoned for agentic depth | Not adopted |

## Sources

- BugBot blog: https://www.greptile.com/blog/bugbot
- Greptile v3: https://www.greptile.com/blog
- Qodo multi-agent: https://www.qodo.ai/blog
- Code-review plugin source: `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/code-review/commands/code-review.md`
