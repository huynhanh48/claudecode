---
name: git-commit-helper
description: "Generate descriptive commit messages and run the project's pre-push checklist. **Use whenever the user asks anything git-related**: writing a commit, reviewing staged changes, splitting a commit, opening a PR, or asking 'what should I write here'. Output follows `.claude/rules/git-workflow.md` (Conventional Commits, 72-char summary, project type list)."
---

# Git Commit Helper

Authoritative source for this skill: **`.claude/rules/git-workflow.md`** in this repo. If anything below conflicts with that file, the rule file wins.

## When to invoke

Trigger on any of:

- "viết commit message", "write a commit message", "commit this"
- "what should I write in the commit?"
- "review the staged diff"
- "open a PR / create pull request"
- the user runs `git add` / `git commit` / `git push` / `gh pr create` and asks for help

## Pre-flight (run first, every time)

```bash
git status --short
git diff --staged
# if nothing staged:
git diff
git log --oneline -10
```

Inspect the diff yourself before drafting the message. Don't rely on the file list alone — the *content* of the change determines the type and scope.

## Commit message format (project convention)

```
<type>(<scope>): <imperative summary ≤ 72 chars, no trailing period>

<body — what changed and why, not how. Wrap at 72.>
```

### Allowed types (from `rules/git-workflow.md`)

| Type | Use when |
|------|----------|
| `feat` | A new user-visible capability |
| `fix` | Bug fix |
| `refactor` | Internal restructuring with no behavior change |
| `perf` | Performance improvement |
| `docs` | Docs only |
| `test` | Tests only |
| `chore` | Tooling, deps, housekeeping |
| `ci` | CI / GitHub Actions changes |
| `build` | Build system, Docker, requirements pinning |
| `style` | Formatting only — no logic |

Pick exactly one. If the diff genuinely spans two types, the commit is too big — split it.

### Scope

The resource or area touched. For this project, prefer one of:

- A resource name: `post`, `auth`, `category`, `topic`, `contact`, `chatbox`, `document`, `setting`, `view`, `service`, `admin`
- A layer or area: `repo`, `service`, `route`, `model`, `migration`, `deploy`, `config`, `skills`, `rules`, `agents`
- A toolchain: `ruff`, `alembic`, `pytest`, `docker`

Keep it ≤ 12 chars. Skip the parens entirely if no scope fits — `feat: add audit logging middleware` is fine.

### Summary

- Imperative mood: "add", not "added" / "adds".
- ≤ 72 chars total *including* the `<type>(<scope>):` prefix.
- No trailing period.
- Lowercase first letter (project preference; see existing log).

### Body (optional but encouraged for non-trivial diffs)

- One blank line between summary and body.
- Wrap at 72 cols.
- Explain **why**, not what — the diff already shows the what.
- Reference issues / PRs at the bottom: `Refs #123`, `Closes #456`.

## Project-shaped examples

Drawn from this repo's history and conventions:

```
feat(book): add CRUD endpoints for books
```

```
fix(auth): blacklist token on logout

Logout was clearing the cookie but leaving the JWT valid until expiry,
so an attacker with the stolen token could keep using it for up to an
hour. Insert the token jti into BlacklistedTokenRepository on logout
and check it in get_current_user_dependency.
```

```
refactor(post): extract HTML sanitizer to lib

PostService had grown a 60-line BeautifulSoup allowlist inline. Moved
to app/lib/html_sanitize.py so chatbox and document services can reuse
it. No behavior change.
```

```
chore(deploy): clean server sync and add google verification
```

```
build(docker): add multi-stage build for prod image
```

## Layering-aware commits

Because the codebase is strictly layered (routes → services → repositories → models), a feature commit usually touches **all five** files (model, schema, repository, service, route). That's still one commit if the change is one feature.

Don't split a layered feature into "feat(model): ...", "feat(repo): ...", "feat(service): ..." — that produces five broken intermediate commits. The whole vertical slice ships together.

## Checklist before `git commit`

```bash
ruff check .
ruff format --check .
pytest --cov=app --cov-report=term-missing --cov-fail-under=80 -q
bash .claude/skills/fastapi/scripts/validate.sh
```

If any fails, fix before committing — don't `--no-verify`.

## Pre-push gate (`.claude/rules/git-workflow.md`)

Before `git push`:

- [ ] Branch name matches commit type (`feat/...`, `fix/...`, `refactor/...`)
- [ ] Rebased onto `main`, no merge commits in feature branch
- [ ] All four commands above pass
- [ ] No `print()` calls under `app/`
- [ ] No new `.env`, `*.local.json`, or credential files staged
- [ ] No Claude `Co-Authored-By:` trailer (project sets `includeCoAuthoredBy: false`)

## Common mistakes to catch

| Smell | Fix |
|------|-----|
| `chore: update files` | Vague — name the type and the *why* |
| `feat(post): added new endpoint and fixed bug` | Two types — split into `feat` + `fix` |
| `Update README.md` | Wrong format — `docs(readme): clarify setup steps` |
| Summary > 72 chars | Move detail to the body |
| Long paragraph in summary, no body | Split: ≤ 72-char summary + wrapped body |
| Past tense ("fixed login") | Imperative ("fix login") |
| Includes `Co-Authored-By: Claude` | Strip — the repo has it disabled |
| `git commit --amend` on a pushed commit | Don't — create a new commit |

## Pull-request body (when the user asks for one)

Same title format as the commit. Body answers:

1. **Why** — link to ticket or 1–2 sentences if standalone.
2. **What changed** — file-tree-level bullets.
3. **Testing** — `pytest -q` output summary, plus manual steps if applicable.
4. **Risk** — anything reviewers should look at carefully (migrations, auth, perf-sensitive paths).

## What to do, step by step

1. Run pre-flight commands and read the diff.
2. Identify the **single** type that fits the change. If two fit, propose splitting.
3. Pick a scope from the table above.
4. Draft `<type>(<scope>): <summary>` ≤ 72 chars.
5. If non-trivial, draft a 1–3 sentence body explaining *why*.
6. Show the message to the user before running `git commit`. Use a HEREDOC so newlines survive:

   ```bash
   git commit -m "$(cat <<'EOF'
   feat(book): add CRUD endpoints for books

   Five-layer scaffold (model → schema → repo → service → route) plus
   alembic migration and pytest coverage for the standard 404/422/200/auth
   cases.
   EOF
   )"
   ```

7. After commit, run `git status` to confirm.

## Hard don'ts

- Never `git commit --no-verify` unless the user explicitly asks.
- Never `git push --force` to `main` or any shared branch.
- Never `git reset --hard` or destructive ops without confirmation.
- Never amend a commit that has already been pushed.
- Never bundle a refactor + a feature in one commit / PR.
