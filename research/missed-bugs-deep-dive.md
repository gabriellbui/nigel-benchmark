# Missed Bugs Deep Dive

## Summary

7 of 31 golden bugs missed. 5 are addressable via bug taxonomy. 2 are low-severity nits.

| # | PR | Severity | Bug | Category | Addressable? |
|---|---|---|---|---|---|
| 1 | 10600 | Low | Wrong error message text | Domain-specific | No |
| 2 | 10600 | Medium | Case-sensitive indexOf on backup codes | String comparison | Yes — taxonomy 6a |
| 3 | 10600 | High | TOCTOU race on backup code use | Concurrency | Yes — taxonomy 6b |
| 4 | 10967 | Low | Redundant optional chaining | Nit | No |
| 5 | 22345 | Medium | Org members excluded by guard | Data integrity | Yes — taxonomy 6c |
| 6 | 14740 | High | Case sensitivity bypass in blacklist | String comparison | Yes — taxonomy 6a |
| 7 | 14740 | Medium | No dedup within input | Data integrity | Yes — taxonomy 6c |

## Detailed Analysis

### Bug 1: Wrong error message text (pr-10600, Low)

**What**: Error message says "backup code login" but the endpoint is for disabling 2FA.

**Why Nigel missed it**: This is a domain-specific text accuracy issue. The error message is technically functional — it just references the wrong user action. Requires understanding the specific endpoint's purpose and comparing it to the error text.

**Sibling bug**: None — this is unique in the benchmark.

**Taxonomy coverage**: Not addressed. This is a domain-knowledge gap, not a pattern-based bug. Would require semantic understanding of endpoint purpose vs error message content.

**Expected impact of change**: None. Not worth targeting.

---

### Bug 2: Case-sensitive indexOf on backup codes (pr-10600, Medium)

**What**: `userBackupCodes.indexOf(usedCode)` is case-sensitive. If codes are generated in uppercase but user types lowercase (or vice versa), valid codes fail.

**Why Nigel missed it**: No explicit check for case-sensitivity in string comparisons. Nigel reviews for design and logic but doesn't systematically scan for case-sensitivity mismatches.

**Sibling bug Nigel caught**: PR 8330, `===` on dayjs objects — same class of "wrong comparison operator for the data type."

**Taxonomy coverage**: Category 6a — "Case-sensitive comparisons on user input where case-insensitive is expected (indexOf, includes, === on emails, tokens, codes, slugs)."

**Expected impact**: High. The taxonomy explicitly calls out `indexOf` on codes. Direct match.

---

### Bug 3: TOCTOU race on backup codes (pr-10600, High)

**What**: Backup code validation reads codes from DB, checks in memory, then writes back. Two concurrent requests with the same code both read before either writes, both succeed.

**Why Nigel missed it**: The read-then-write pattern spans multiple operations. Nigel checks for design issues but doesn't systematically look for concurrent access patterns on shared state.

**Sibling bug Nigel caught**: PR 14943, stale `retryCount + 1` — same class of "read current value, increment in application code, write back" without atomicity.

**Taxonomy coverage**: Category 6b — "Read-then-write without atomicity (TOCTOU on shared state, stale counter increments)."

**Expected impact**: Moderate-high. The taxonomy calls out TOCTOU explicitly. The backup code flow is a read-check-mutate-write cycle — classic TOCTOU.

---

### Bug 4: Redundant optional chaining (pr-10967, Low)

**What**: `mainHostDestinationCalendar?.integration` uses optional chaining but the variable is guaranteed to be defined at that point.

**Why Nigel missed it**: This is a low-priority nit. The code works correctly — it's just unnecessarily defensive.

**Sibling bug**: None — Nigel typically flags under-defensive code, not over-defensive code.

**Taxonomy coverage**: Not addressed. This is the opposite of a bug — it's extra safety that's unnecessary. Not worth adding a "redundant safety" category.

**Expected impact**: None. Not worth targeting.

---

### Bug 5: Org members excluded by guard (pr-22345, Medium)

**What**: `userIdsFromOrg` is only fetched when `teamsFromOrg.length > 0`. Organizations with zero teams but direct members get no user IDs, excluding those members from insights.

**Why Nigel missed it**: The conditional guard looks reasonable at first glance — "only fetch org users if there are teams." But the data model allows org members without team membership, and the guard excludes them.

**Sibling bug Nigel caught**: PR 14943, `deleteMany` with missing filter — same class of "conditional logic that unintentionally excludes valid data."

**Taxonomy coverage**: Category 6c — "Conditional guards that unintentionally exclude valid data (e.g., only querying related data when a parent array is non-empty, excluding entities with zero children)."

**Expected impact**: High. The taxonomy example matches this bug almost exactly: "only querying related data when a parent array is non-empty."

---

### Bug 6: Case sensitivity bypass in email blacklist (pr-14740, High)

**What**: Email blacklist check uses exact string comparison. Attacker can bypass by changing case (e.g., `Bad@Email.COM` vs `bad@email.com`).

**Why Nigel missed it**: Same as Bug 2 — no systematic check for case-sensitivity in comparisons. Nigel caught the `&&` vs `||` auth bug in the same PR but missed the case-sensitivity issue.

**Sibling bug Nigel caught**: PR 14740, `&&` vs `||` — Nigel found a different bug in the same file's security logic, proving it analyzed the code but didn't check for case sensitivity.

**Taxonomy coverage**: Category 6a — "Case-sensitive comparisons on user input where case-insensitive is expected (indexOf, includes, === on emails, tokens, codes, slugs)."

**Expected impact**: High. The taxonomy explicitly mentions emails. Direct match.

---

### Bug 7: No dedup within input (pr-14740, Medium)

**What**: `uniqueGuests` deduplicates against existing attendees but not within the input array itself. If a user submits `["a@b.com", "a@b.com"]`, both pass the uniqueness check and `createMany` inserts duplicate rows.

**Why Nigel missed it**: The dedup logic looks correct at first glance — it filters against existing data. But the within-input duplication is a separate concern that's easy to overlook.

**Sibling bug Nigel caught**: PR 14740, "wrong list passed to sendAddGuestsEmails" — Nigel traced the data flow through the same function but focused on which list was passed to the email sender, not whether the list itself could contain duplicates.

**Taxonomy coverage**: Category 6c — "Deduplication that filters against existing data but not within the input itself."

**Expected impact**: High. The taxonomy describes this exact pattern. Direct match.

---

## Pattern Clustering

### String & Comparison (2 bugs, both addressable)
- Bug 2: indexOf case sensitivity
- Bug 6: Blacklist case sensitivity

Common thread: comparing user-provided strings without normalization.

### Concurrency (1 bug, addressable)
- Bug 3: TOCTOU on backup codes

Common thread: read-then-write on shared state without atomicity.

### Data Integrity (2 bugs, both addressable)
- Bug 5: Conditional guard excludes valid data
- Bug 7: No within-input deduplication

Common thread: data validation that handles one dimension (existing data, non-empty arrays) but misses another.

### Not Addressable (2 bugs)
- Bug 1: Domain-specific error text (Low)
- Bug 4: Redundant optional chaining (Low)

Both are low-severity and not pattern-based.

## Expected Recall Impact

### Taxonomy only (conservative estimate)
- Baseline: 24/31 = 77.4%
- Best case: +5 bugs → 29/31 = 93.5%
- Expected: +3-4 bugs → 27-28/31 = 87-90%
  - High confidence: Bug 2 (indexOf), Bug 6 (email blacklist), Bug 7 (dedup) — direct pattern matches
  - Moderate confidence: Bug 5 (conditional guard), Bug 3 (TOCTOU) — require following data flow

### Orchestrator (additive, on top of taxonomy)
- Context agents provide data model knowledge that helps with Bug 5 (org members)
- Git history may reveal the TOCTOU pattern for Bug 3 (if prior commits show concurrent access concerns)
- Expected: +0-2 bugs beyond taxonomy alone

### Combined target: >= 85% (26+/31)

## Time Impact

The bug taxonomy adds a structured pass through the diff — estimated +30-60 seconds per review.
The orchestrator adds context gathering (Haiku agents ~10-15s) + deeper Nigel review with context (~30-60s additional).

**Estimates:**
- Baseline Nigel: ~60-90s per review
- Taxonomy only: ~90-150s per review (+30-60s)
- Full orchestrator: ~120-210s per review (+60-120s)

Time tracking during benchmark will provide actual numbers.
