---
allowed-tools: Bash(gh pr diff:*), Bash(gh pr view:*), Bash(git log:*), Bash(git diff:*)
description: Deep code review using Nigel with codebase context
user-invocable: true
---

Provide a thorough code review for the given changes.

Follow these steps:

1. **Gather context** — Launch 3 parallel Haiku agents:

   a. **CLAUDE.md agent**: Find and read the root CLAUDE.md and any
      CLAUDE.md files in directories the diff touches. Return a summary
      of relevant project conventions and rules.

   b. **Codebase context agent**: For each file in the diff, read the
      full file (not just changed lines) plus any files it imports or
      references. Identify data models, type definitions, and related
      functions. Return a summary of the surrounding codebase context
      that would help a reviewer understand the changes.

   c. **Git history agent**: For each modified file, check recent git
      history (last 10 commits). Identify why the code was written this
      way, any related PRs or issues, and patterns in how this area of
      the codebase evolves. Return a brief history summary.

2. **Deep review** — Launch 1 Opus agent (@nigel) with the diff AND
   all context from step 1. The agent should:
   - Review the changes for design quality, abstraction quality, and
     system coherence (Nigel's core strengths)
   - Run the systematic bug hunt checklist (string comparison, concurrency,
     data integrity)
   - Use the codebase context to understand data models and conventions
   - Use the git history to understand intent and spot regressions
   - Investigate anything suspicious using Glob/Grep/Read tools

3. **Output** — Present Nigel's review as the final result. Do not
   filter or remove findings. Include a note at the end with the total
   time spent on the review (wall clock from start to finish).
