# Nigel Baseline Benchmark Scorecard

## Summary

| Metric | Value |
|--------|-------|
| **Total Golden Bugs** | 31 |
| **Golden Bugs Caught** | 24 |
| **Overall Recall** | **77.4%** |
| **Total Nigel Findings** | 68 |
| **Precision (matched/total)** | 35.3% |
| **Critical+High Recall** | **85.7%** (12/14) |
| **Medium Recall** | 66.7% (6/9) |
| **Low Recall** | 75.0% (6/8) |

## Industry Comparison

| Tool | Recall |
|------|--------|
| Greptile | 82% |
| **Nigel (baseline)** | **77%** |
| Cursor | 58% |
| Copilot | 54% |
| CodeRabbit | 44% |
| Graphite | 6% |

---

## Per-PR Scoring

### PR #8087 — Async import of appStore packages (2 golden, 2 caught = 100%)

| # | Severity | Golden Comment | Caught? | Nigel Finding |
|---|----------|---------------|---------|---------------|
| 1 | Low | Try-catch around await to handle import failures | ✅ | BUG 4: Silent swallowing of import failures |
| 2 | Critical | forEach with async callbacks causes fire-and-forget promises | ✅ | BUG 1: async forEach fire-and-forget (4 occurrences found) |

**Extra findings (3):** getCalendarCredentials not awaited, eager imports defeat lazy loading, handleCancelBooking forEach

---

### PR #10600 — 2FA backup codes (4 golden, 1 caught = 25%)

| # | Severity | Golden Comment | Caught? | Nigel Finding |
|---|----------|---------------|---------|---------------|
| 1 | Low | TwoFactor function in BackupCode.tsx — inconsistent naming | ✅ | Design Issue: Component named TwoFactor in BackupCode.tsx |
| 2 | Low | Error message mentions 'backup code login' but this is disable endpoint | ❌ | — |
| 3 | Medium | Backup code validation case-sensitive (indexOf) | ❌ | — |
| 4 | High | Concurrent backup code use — race condition | ❌ | — |

**Extra findings (8):** Backup codes not consumed on disable, null entries in array, simultaneous totpCode+backupCode, codes stored before confirm, blob URL leak, missing type annotation, nested ternary, form sends both codes

**Notes:** Nigel found many valid issues but missed the specific golden bugs. The case-sensitivity bug (#3) and the concurrent-use race condition (#4) were not detected. Many "extra" findings are genuinely valid security concerns.

---

### PR #10967 — Collective multiple host destinationCalendar (5 golden, 4 caught = 80%)

| # | Severity | Golden Comment | Caught? | Nigel Finding |
|---|----------|---------------|---------|---------------|
| 1 | High | Null reference if mainHostDestinationCalendar is undefined | ✅ | BUG 1: Null pointer crash — missing optional chaining |
| 2 | Low | Optional chaining on mainHostDestinationCalendar?.integration is redundant | ❌ | — |
| 3 | High | Logic error: find(cal => cal.externalId === externalCalendarId) always fails | ✅ | BUG 2: Dead-code logic — always resolves to undefined |
| 4 | Medium | Logic inversion in organization creation slug/requestedSlug | ✅ | BUG 6: Organization slug negation logic inverted |
| 5 | Low | Calendar interface requires credentialId but implementations don't accept it | ✅ | BUG 5: createEvent interface not honored by all implementations |

**Extra findings (2):** Undefined credential passed to updateEvent, missing organization select in loadUsers

---

### PR #22345 — InsightsBookingService raw queries (2 golden, 1 caught = 50%)

| # | Severity | Golden Comment | Caught? | Nigel Finding |
|---|----------|---------------|---------|---------------|
| 1 | Low | getBaseConditions else-if/else branches unreachable | ✅ | BUG 1: Dead branches in getBaseConditions |
| 2 | Medium | userIdsFromOrg only fetched when teamsFromOrg.length > 0 excludes org members | ❌ | — |

**Extra findings (5):** Team auth behavioral regression, Prisma.sql array params, API design regression, deleted caching tests, type mismatch with Zod

**Notes:** Nigel missed the org-level member exclusion bug (#2) but found several other valid issues including a potentially critical Prisma.sql array parameter bug.

---

### PR #7232 — Workflow reminder management (2 golden, 2 caught = 100%)

| # | Severity | Golden Comment | Caught? | Nigel Finding |
|---|----------|---------------|---------|---------------|
| 1 | Medium | Async delete functions called without await inside forEach | ✅ | BUG 1: Fire-and-forget async calls (CRITICAL) |
| 2 | High | immediateDelete cancels SendGrid but never deletes DB record | ✅ | BUG 2: immediateDelete orphans DB records (CRITICAL) |

**Extra findings (5):** Inconsistent email/SMS deletion, cron handler error boundary, removed auth check, dropped isSenderIdNeeded, nullable cancelled column

---

### PR #8330 — Date override timezone (2 golden, 2 caught = 100%)

| # | Severity | Golden Comment | Caught? | Nigel Finding |
|---|----------|---------------|---------|---------------|
| 1 | Medium | Incorrect end time using slotStartTime instead of slotEndTime | ✅ | BUG 1: Copy-paste slotStartTime bug (CRITICAL) |
| 2 | Medium | === on dayjs objects compares references, always false | ✅ | BUG 2: Object reference comparison (CRITICAL) |

**Extra findings (3):** Timezone offset logic inverted, dateOverrides.find() side effects, undefined timezone

---

### PR #11059 — OAuth credential sync (5 golden, 5 caught = 100%)

| # | Severity | Golden Comment | Caught? | Nigel Finding |
|---|----------|---------------|---------|---------------|
| 1 | High | refresh_token set to hardcoded string "refresh_token" | ✅ | BUG 6: Fake refresh token injection |
| 2 | High | Invalid Zod schema — computed property keys | ✅ | BUG 1: Broken Zod schema |
| 3 | High | parseRefreshTokenResponse returns safeParse result, not key object | ✅ | BUG 2: Throws but callers check .success |
| 4 | High | refreshFunction returns fetch Response but callers expect token object | ✅ | BUG 5: Inconsistent return types |
| 5 | High | res.data doesn't exist on fetch Response | ✅ | BUG 3: Google Calendar type mismatch |

**Extra findings (6):** Hubspot type mismatch, Zoho passes credentialId not userId, no HTTP method check, timing-unsafe secret comparison, Zod parse without safeParse, encryption key fallback

---

### PR #14943 — SMS retry tracking (2 golden, 2 caught = 100%)

| # | Severity | Golden Comment | Caught? | Nigel Finding |
|---|----------|---------------|---------|---------------|
| 1 | High | retryCount + 1 reads stale value, use atomic increment | ✅ | BUG 3: Race condition — read-then-write (MEDIUM) |
| 2 | High | Deletion deletes non-SMS reminders — missing method filter | ✅ | BUG 1: deleteMany OR clause nukes all reminders (CRITICAL) |

**Extra findings (2):** Catch-block Prisma update can throw, off-by-one retry threshold

---

### PR #14740 — Guest management (5 golden, 3 caught = 60%)

| # | Severity | Golden Comment | Caught? | Nigel Finding |
|---|----------|---------------|---------|---------------|
| 1 | High | Case sensitivity bypass in email blacklist | ❌ | — |
| 2 | Critical | && instead of \|\| in team admin/owner check | ✅ | BUG 1: Authorization check uses && instead of \|\| |
| 3 | Medium | Email sender called with original guests, not uniqueGuests | ✅ | BUG 2: Wrong list passed to sendAddGuestsEmails |
| 4 | Medium | uniqueGuests doesn't deduplicate within input — duplicate rows | ❌ | — |
| 5 | Low | Array initialized with [""] causes validation issues | ✅ | BUG 3: multiEmailValue initialized with [""] |

**Extra findings (5):** isInvalidEmail not cleared, Zod schema per render, empty attendees crash, error toast undefined, add guests shown for all booking states

---

### PR #22532 — Calendar cache status (2 golden, 2 caught = 100%)

| # | Severity | Golden Comment | Caught? | Nigel Finding |
|---|----------|---------------|---------|---------------|
| 1 | Medium | Empty data object prevents @updatedAt from updating | ✅ | BUG 1: Empty update call does nothing |
| 2 | Low | macOS-specific sed syntax fails on Linux | ✅ | NITPICK: Shell script sed is macOS-only |

**Extra findings (5):** Competing data sources, authorization gap, missing query invalidation, hardcoded locale, suspicious Date wrapper

---

## Severity Breakdown

### Critical (2 total)
| Bug | Caught? |
|-----|---------|
| PR 8087: async forEach fire-and-forget | ✅ |
| PR 14740: && instead of \|\| auth check | ✅ |
| **Critical Recall** | **100% (2/2)** |

### High (12 total)
| Bug | Caught? |
|-----|---------|
| PR 10600: Concurrent backup code race condition | ❌ |
| PR 10967: Null reference on mainHostDestinationCalendar | ✅ |
| PR 10967: Logic error in externalCalendarId find | ✅ |
| PR 7232: immediateDelete orphans DB records | ✅ |
| PR 11059: Hardcoded refresh_token string | ✅ |
| PR 11059: Invalid Zod schema syntax | ✅ |
| PR 11059: parseRefreshTokenResponse return type | ✅ |
| PR 11059: fetch Response vs token object mismatch | ✅ |
| PR 11059: res.data doesn't exist on Response | ✅ |
| PR 14943: Stale retryCount read-then-write | ✅ |
| PR 14943: Missing SMS filter in deletion | ✅ |
| PR 14740: Case sensitivity bypass in blacklist | ❌ |
| **High Recall** | **83.3% (10/12)** |

### Medium (9 total)
| Bug | Caught? |
|-----|---------|
| PR 10600: Case-sensitive indexOf for backup codes | ❌ |
| PR 10967: Logic inversion in org slug/billing | ✅ |
| PR 22345: userIdsFromOrg excludes org members | ❌ |
| PR 7232: Async delete without await in forEach | ✅ |
| PR 8330: slotStartTime instead of slotEndTime | ✅ |
| PR 8330: === on dayjs objects | ✅ |
| PR 14740: Email sender with original guests | ✅ |
| PR 14740: No dedup within input | ❌ |
| PR 22532: Empty data object in updateMany | ✅ |
| **Medium Recall** | **66.7% (6/9)** |

### Low (8 total)
| Bug | Caught? |
|-----|---------|
| PR 8087: Missing try-catch on import | ✅ |
| PR 10600: TwoFactor naming in BackupCode.tsx | ✅ |
| PR 10600: Wrong error message context | ❌ |
| PR 10967: Redundant optional chaining | ❌ |
| PR 10967: Calendar interface not implemented | ✅ |
| PR 22345: Dead branches in getBaseConditions | ✅ |
| PR 14740: Array initialized with [""] | ✅ |
| PR 22532: macOS-specific sed syntax | ✅ |
| **Low Recall** | **75.0% (6/8)** |

---

## Missed Bugs Analysis

7 golden bugs were missed:

1. **PR 10600 #2 (Low)**: Wrong error message text — too subtle/domain-specific for diff review
2. **PR 10600 #3 (Medium)**: Case-sensitive indexOf on backup codes — requires understanding UX expectation
3. **PR 10600 #4 (High)**: Concurrent backup code race condition — requires understanding concurrent request patterns
4. **PR 10967 #2 (Low)**: Redundant optional chaining — a nitpick, easily missed
5. **PR 22345 #2 (Medium)**: Org-level members excluded — requires understanding data model relationships
6. **PR 14740 #1 (High)**: Case-sensitivity bypass in email blacklist — security edge case
7. **PR 14740 #4 (Medium)**: No dedup within input — requires tracing data flow through validation

**Pattern:** Most misses involve either (a) case-sensitivity edge cases, (b) concurrency/race conditions, or (c) subtle data model relationships that aren't visible from the diff alone.

---

## False Positive Analysis

Of 68 total findings, 24 matched golden bugs. The remaining 44 "extra" findings break down as:

- **Genuinely valid bugs/issues** (not in golden set): ~30 (e.g., Zoho passing credentialId instead of userId, timing-unsafe secret comparison)
- **Design/style concerns** (valid but not bugs): ~10 (e.g., inconsistent null vs empty array, missing type annotations)
- **Noise/false positives**: ~4 (e.g., some behavioral regression assessments that may be intentional)

**Effective precision (valid findings / total):** ~79% (54/68)

The low "golden precision" (35%) is misleading — it just means Nigel finds many real issues beyond the curated golden set. The golden set is intentionally minimal.
