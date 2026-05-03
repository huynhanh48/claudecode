# Git workflow

> **Any time the user asks for help with a commit, PR, or staged-diff review, activate the [`git-commit-helper`](../skills/git-commit-helper/SKILL.md) skill first.** It encodes this file as an actionable checklist (pre-flight → draft → checklist → commit) and keeps drafts on-format. This file remains the source of truth for the rules; the skill is the runner.

## Commit message

```
<type>(<scope>): <imperative summary>

<optional body — what and why, not how>
```

- **Types**: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`, `build`, `style`.
- **Scope**: the resource or area touched (`post`, `auth`, `deploy`, `skills`).
- **Summary**: imperative, ≤ 72 chars, no trailing period.
- **Body**: explain *why* this change is needed, not *what* the diff already shows.

Examples:

```
feat(book): add CRUD endpoints for books
fix(auth): blacklist token on logout
refactor(post): extract HTML sanitizer to lib
```

## Branches

- One feature / fix per branch. Branch name mirrors the commit type:
  - `feat/book-crud`
  - `fix/auth-token-blacklist`
  - `refactor/post-html-sanitize`
- Rebase onto `main` before opening a PR. No merge commits in feature branches.

## Pull requests

A PR description must answer:

1. **Why** — link to the issue / ticket, or 1–2 sentences if standalone.
2. **What changed** — bullet list at file-tree granularity.
3. **Testing** — how to manually verify, and which tests cover this.
4. **Risk** — anything reviewers should look extra carefully at.

Title rules:

- Same format as a commit message (`feat(book): …`).
- ≤ 70 characters.

## Before pushing

- `ruff check .` — passes
- `ruff format --check .` — passes
- `pytest -q` — passes (with coverage ≥ 80%)
- `bash .claude/skills/fastapi/scripts/validate.sh` — passes
- No `print()` calls under `app/`
- No new `.env`, `*.local.json`, or credentials staged

## What NOT to do

- Do not amend a commit that has been pushed to a shared branch.
- Do not `git push --force` to `main` or any shared branch.
- Do not skip pre-commit hooks (`--no-verify`) unless the user explicitly asks.
- Do not bundle a refactor + a feature in one PR.
- Do not commit Claude-generated co-author trailers unless the user has set `includeCoAuthoredBy: true` in their Claude Code settings.
