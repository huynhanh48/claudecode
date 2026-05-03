# Rules

One file per topic. Each rule is short, opinionated, and points to the deeper reference (skill, script, or doc) when needed.

| File | Topic | When it applies |
|------|-------|-----------------|
| [`architecture.md`](architecture.md) | Layered backend architecture | Any change to `app/` |
| [`coding-style.md`](coding-style.md) | Clean code, naming, comments, function size | Every Python file |
| [`feature-development.md`](feature-development.md) | Patterns-first feature workflow | Any new feature or refactor |
| [`testing.md`](testing.md) | pytest, coverage, TDD | Every code change |
| [`security.md`](security.md) | Secrets, input validation, OWASP | Anything touching auth, env, DB, user input |
| [`git-workflow.md`](git-workflow.md) | Commit message, PR, review | Every commit / PR |
| [`using-context7.md`](using-context7.md) | When to fetch library docs via Context7 | Before using a library API |

Rules that conflict — specific overrides general (file-level beats this README).
