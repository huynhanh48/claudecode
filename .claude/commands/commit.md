---
description: Draft a Conventional-Commit message for staged changes (or stage them) and run the project's pre-commit gate before committing.
argument-hint: "[--all] [scope hint]"
---

# /commit

Drive a clean commit through the project's git workflow.

## Steps

1. Activate the [`git-commit-helper`](../skills/git-commit-helper/SKILL.md) skill.
2. Pre-flight:
   - `git status --short`
   - `git diff --staged` (fall back to `git diff` if nothing is staged)
   - `git log --oneline -5`
3. If `$ARGUMENTS` contains `--all`, stage all tracked changes via `git add -u` (never `git add -A` — risk of pulling in `.env` or local artifacts).
4. Run the pre-commit gate from `.claude/rules/git-workflow.md`:
   - `ruff check .`
   - `ruff format --check .`
   - `pytest -q --cov=app --cov-report=term-missing --cov-fail-under=80`
   - `bash .claude/skills/fastapi/scripts/validate.sh`
   If any fails, **stop** and surface the failure — do not commit.
5. Draft the message: `<type>(<scope>): <≤72-char imperative summary>` plus an optional wrapped body explaining *why*.
   - Type list: `feat | fix | refactor | perf | docs | test | chore | ci | build | style`.
   - Pick scope from this project's resource list (`post`, `auth`, `category`, `topic`, `contact`, `chatbox`, `document`, `setting`, `view`, `service`, `admin`) or area (`repo`, `service`, `route`, `model`, `migration`, `deploy`, `config`, `skills`, `rules`).
   - If the diff genuinely spans two types, propose splitting the commit instead of bundling.
   - Use `$ARGUMENTS` (excluding `--all`) as a scope/topic hint when present.
6. Show the drafted message to the user. Wait for confirmation before running `git commit`.
7. Commit using a HEREDOC so multi-line bodies survive intact.
8. Report `git status` after the commit.

## Don'ts

- Do not `--no-verify`.
- Do not amend pushed commits.
- Do not stage `.env`, `*.local.json`, or anything matching `**/credentials*`.
- Do not include `Co-Authored-By: Claude` (project sets `includeCoAuthoredBy: false`).
