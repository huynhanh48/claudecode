---
description: Review the working tree (or a specific path) against the project's architecture, style, testing, and security rules.
argument-hint: "[path]"
---

# /review

Review changes against the project rules. If `$ARGUMENTS` is empty, review `git diff` of the working tree; if it names a path, review that path.

## Steps

1. Determine scope:
   - If `$ARGUMENTS` is empty: `git diff --staged` first, fall back to `git diff` if nothing is staged.
   - Otherwise: read the file or directory at `$ARGUMENTS`.
2. Apply the rule files in this order — flag violations with severity (CRITICAL / HIGH / MEDIUM / LOW):
   - `.claude/rules/architecture.md` (CRITICAL for layer / wiring violations)
   - `.claude/rules/coding-style.md` (HIGH for missing type hints, dead code, oversized functions)
   - `.claude/rules/security.md` (CRITICAL for hardcoded secrets, missing validation, raw `HTTPException`)
   - `.claude/rules/testing.md` (HIGH if a new resource has no test coverage)
   - `.claude/rules/git-workflow.md` (LOW for commit-message format)
3. For each violation, report: `severity · file:line · rule reference · one-sentence fix suggestion`.
4. Check whether a design pattern was applied — if yes, confirm it's the simplest one that fits (`design-patterns` skill).
5. End with a single-line verdict: `READY TO MERGE`, `NEEDS WORK`, or `BLOCKED`.

Do **not** apply fixes automatically — the goal is to surface issues for the user.
