# `.claude/` — portable Claude Code config for Python / FastAPI projects

This directory configures Claude Code for the team's standard FastAPI backend layout. It's designed to be **cloned into any new project** and work without modification — the only thing you set per-project is environment variables.

```
.claude/
├── README.md                 # this file
├── settings.json             # project-shared settings (committed)
├── settings.local.json       # per-developer overrides (gitignored)
├── rules/                    # short, opinionated rule files (one per topic)
├── commands/                 # team slash commands (/new-resource, /find-pattern, ...)
├── hooks/                    # automation scripts called by settings.json hooks
├── agents/                   # custom subagents (python-pro)
└── skills/                   # auto-triggered skills
    ├── fastapi/              # scaffold a project / add a CRUD resource
    ├── design-patterns/      # GoF + foundational principles, Python
    ├── git-commit-helper/    # commit message + pre-push gate
    └── creator-skill/        # how to author new skills
```

The MCP server definitions live in **`/.mcp.json`** at the repo root (Claude Code reads project MCPs from there, not from inside `.claude/`).

The companion **`/CLAUDE.md`** at the repo root is auto-loaded into every Claude Code session and links back to the rules and skills.

---

## Architecture this config enforces (TL;DR)

Every backend feature flows through **four layers** in this order:

```
routes → services → repositories → models
```

There is **no separate Controller layer.** The FastAPI route handler *is* the controller — it parses the request, runs the dependency tree, and shapes the response. Pattern follows [`zhanymkanov/fastapi-best-practices`](https://github.com/zhanymkanov/fastapi-best-practices) and the official `bigger-applications` tutorial. (If you're coming from NestJS / Spring, this is intentional — see `rules/architecture.md`.)

Sidecars (no layer-discipline rules):

- `app/schema/` — Pydantic Create / Update / Response.
- `app/integrations/` — Adapters around third-party SDKs (LightRAG, Cloudinary, OpenAI). Services depend on the adapter via `Depends(get_<vendor>_adapter)`.
- `app/exception/`, `app/lib/`, `app/core/`, `app/db/` — exception hierarchy, utilities (JWT, bcrypt), settings, DB session.

### Error handling: three global handlers, no defensive `try/except`

`main.py` registers three exception handlers (template in `skills/fastapi/template.md`):

| Handler | What it returns | Notes |
|---------|-----------------|-------|
| `@app.exception_handler(HttpException)` | `{"message": exc.message}` with the domain status code | Only place that surfaces a service-controlled message to the client. |
| `@app.exception_handler(SQLAlchemyError)` | 500 + generic `"Database error..."` | Logs server-side; never leaks SQL to the client. |
| `@app.exception_handler(Exception)` | 500 + generic `"Internal server error"` | Catch-all. Logs the traceback. **This is what makes `try/except Exception` in services redundant.** |

Hard rule: services do **not** wrap work in `try/except Exception` just to log + re-raise. Let unexpected errors propagate; the `Exception` handler will log and return 500. Catch only specific exceptions you need to *transform* into a domain exception (e.g. `IntegrityError` → `BadRequestException('Email already taken')`).

The `validate.sh` script will `warn` if `app/services/*.py` contains a broad `except Exception`.

---

## What each piece does

### `settings.json`

Project-shared, committed. Configures:

- **MCP servers**: enables all of `/.mcp.json` (postgresql, context7, github, fetch).
- **Hooks**:
  - `PreToolUse` on `Edit | Write | MultiEdit` runs `hooks/check_secrets.sh` — blocks edits that contain a JWT, AWS key, GitHub PAT, OpenAI key, or other obvious secret literal.
  - `PostToolUse` on `Edit | Write | MultiEdit` runs `hooks/format_python.sh` — auto-formats edited `.py` files with `ruff format` and applies safe `ruff --fix`.
- **Permissions**:
  - Auto-allow common safe operations (read, lint, test, alembic, file inspection).
  - Ask before `git push`, `git reset`, `curl`.
  - Deny reads of `.env`, credentials files, and any destructive shell (`rm -rf`, `git push --force`).
- `includeCoAuthoredBy: false` — keeps Claude trailers out of commits unless an individual developer turns them back on locally.

### `settings.local.json`

Gitignored. Each developer's personal overrides live here — extra permissions they want, environment-specific tweaks, etc. Settings here **add to** (not replace) the shared `settings.json`.

### `rules/`

The team's coding rulebook. One short file per topic. Every rule is < 200 lines and uses YAML frontmatter `paths:` to **load only when Claude is working with matching files** — see [Claude Code path-specific rules](https://docs.claude.com/en/memory#path-specific-rules). This keeps the session context lean.

| File | Topic | Loaded when… |
|------|-------|--------------|
| [`rules/architecture.md`](rules/architecture.md) | Layered backend (**routes → services → repositories → models**, no Controller) — non-negotiable. Includes the "no `try/except Exception`" rule and the global-handler contract. | editing `app/**/*.py`, `alembic/**`, `main.py`, `tests/**` |
| [`rules/coding-style.md`](rules/coding-style.md) | Type hints, naming, function size, no comments unless the *why* is non-obvious, error-boundary rule. | editing any `**/*.py` |
| [`rules/feature-development.md`](rules/feature-development.md) | Patterns-first workflow: consult `design-patterns` skill before coding. Implement bottom-up: model → schema → repository → service → route. | always |
| [`rules/testing.md`](rules/testing.md) | pytest, 80% coverage, TDD discipline. | editing `app/**`, `tests/**`, `main.py`, `pytest.ini`, `pyproject.toml` |
| [`rules/security.md`](rules/security.md) | Secrets, input validation, OWASP basics, stop-the-line list. | editing `app/**`, `alembic/**`, `main.py`, `tests/**`, `.env*`, `Dockerfile`, `docker-compose*.yml` |
| [`rules/git-workflow.md`](rules/git-workflow.md) | Conventional commits, branches, PR template. | always |
| [`rules/using-context7.md`](rules/using-context7.md) | When to use the `context7` MCP for live library docs. | always |

`/CLAUDE.md` (repo root) summarizes these for the assistant; the deeper detail lives here.

To add new path-scoped rules, drop a markdown file under `rules/` (or any subdirectory — discovery is recursive) with this header:

```yaml
---
paths:
  - "src/api/**/*.py"
---
```

Omit the frontmatter to load the rule unconditionally.

### `commands/`

Team slash commands. Each is a markdown file with frontmatter (`description`, `argument-hint`).

| Command | Use it for |
|---------|------------|
| `/new-resource <name> [field:type] ...` | Scaffold a CRUD resource end-to-end (**five files**: model → schema → repository → service → route + Alembic + tests) via the `fastapi` skill. |
| `/check-architecture` | Run `validate.sh` + `ruff` + `pytest` and report layered-architecture / style violations (incl. `app/controllers/` leftover guard and broad `except Exception` warning). |
| `/find-pattern <problem description>` | Recommend a pattern (or *no* pattern) using the `design-patterns` skill. |
| `/review [path]` | Review the working tree (or a path) against every rule file with severity-ranked findings. |
| `/commit [--all] [scope hint]` | Pre-commit gate + draft a Conventional-Commit message via `git-commit-helper`. |

### `hooks/`

Bash scripts invoked by the hooks declared in `settings.json`. Both:

- read the Claude Code hook payload from stdin (with a `jq`-free fallback so they work without extra deps),
- exit 0 on the success / no-op path so they never block work unnecessarily,
- use stderr + exit-code 2 only when they want Claude Code to refuse the tool call (the secret scanner does this).

| Script | Trigger | Purpose |
|--------|---------|---------|
| `hooks/format_python.sh` | PostToolUse on `Edit | Write | MultiEdit` | `ruff format` + safe `ruff --fix` on edited `.py` files. |
| `hooks/check_secrets.sh` | PreToolUse on `Edit | Write | MultiEdit` | Blocks edits that contain JWT / AWS / GitHub / OpenAI / Slack-shaped tokens. |

### `agents/`

Custom subagents.

- `agents/python-pro.md` — senior Python developer subagent for type-safe FastAPI / async work. Knows the 4-layer rule, the no-try-except rule, the wiring checklist (5 files), and the pre-commit gate.

Add more by dropping a markdown file with `---\nname: ...\ndescription: ...\ntools: ...\n---` frontmatter; Claude Code picks them up automatically.

### `skills/`

Auto-triggered, deeply documented capabilities.

| Skill | Activates on | Key contents |
|-------|--------------|--------------|
| [`skills/fastapi/`](skills/fastapi/) | "scaffold a FastAPI project", "add a CRUD resource" | `SKILL.md` (4-layer architecture, scaling-pattern table); `template.md` (boilerplate for `main.py` with 3 global handlers, config A/B for SQLite/Postgres, per-resource templates); `examples/sample.md` (worked `book` resource, 5 files); `scripts/validate.sh` (layout + layer-discipline + leftover-`controllers/` + broad-`except Exception` checks). |
| [`skills/design-patterns/`](skills/design-patterns/) | "which pattern should I use", "refactor this code", "code smell" | Foundational principles (KISS, SRP, Rule of Three, composition); GoF catalog (creational, structural, behavioral); Pythonic alternatives. |
| [`skills/git-commit-helper/`](skills/git-commit-helper/) | **Any git-related request**: "viết commit", "write a commit message", "open a PR", staged-diff review | Conventional Commits format; layer-aware commits (single feature = all 5 files in one commit); pre-push gate. |
| [`skills/creator-skill/`](skills/creator-skill/) | "create a new skill", "tạo skill mới" | Scaffolds a SKILL.md from a description. |

---

## Architectural decisions baked in

These are the choices the config makes for you. If your project genuinely needs a different shape, fork the rule file and document why.

### 1. Four layers, not five

| Layer | Imports from | Returns |
|-------|--------------|---------|
| `routes/<r>.py` | `services` only | `response_model` shape |
| `services/<r>.py` | `repositories`, other `services`, `integrations` | Pydantic Response (`<R>Response.model_validate(orm)`) |
| `repositories/<r>.py` | `models`, `schema` | ORM instance or `None` |
| `models/<r>.py` | (leaf) | — |

The FastAPI route handler is the controller. Routes inject the service directly via `service: <R>Service = Depends()`. **`validate.sh` warns if `app/controllers/` exists** — this guard catches devs who clone the config on top of an old 5-layer project.

### 2. Errors propagate, services don't `try/except Exception`

Three global handlers in `main.py`:

```python
@app.exception_handler(HttpException)        # domain exceptions → status + message
@app.exception_handler(SQLAlchemyError)      # DB errors → 500 + generic message
@app.exception_handler(Exception)            # catch-all → 500 + log traceback
```

Service code only catches *specific* exceptions when it needs to *transform* them into a domain exception:

```python
# OK — transforming a known error
try:
    self.repository.create(data)
except IntegrityError as exc:
    raise BadRequestException(message='Email already taken') from exc

# NOT OK — log + reraise
try:
    await self.adapter.query(...)
except Exception:
    logger.exception('failed')         # ← global handler does this already
    raise InternalServerErrorException(message='oops')
```

`validate.sh` warns when it finds `except Exception` under `app/services/`.

### 3. Third-party SDKs go behind an Adapter

`app/integrations/<vendor>.py` exposes a project-shaped interface; services depend on it via `Depends(get_<vendor>_adapter)`. This keeps SDK quirks (async lifecycle, weird config, version-specific signatures) out of your business logic. Example: `app/integrations/lightrag_adapter.py`.

### 4. Modern Python typing (3.10+)

Boilerplate uses `X | None`, `list[X]`, `dict[K, V]` — not `Optional[X]` / `List[X]`. Ruff enforces this via `UP006` / `UP045`.

### 5. SQLite by default, Postgres on demand

`template.md` ships **two** `Settings` flavors:

- **A) SQLite-friendly** — `DATABASE_URL = 'sqlite:///./app.db'` default. Suits local-file deployments (e.g. RAG / single-tenant tools).
- **B) Postgres** — composes `postgresql+psycopg2://...` from `POSTGRES_*` env vars. Pick this for prod / multi-tenant.

`database.py` adds `connect_args={'check_same_thread': False}` automatically when the URL starts with `sqlite`.

---

## MCP servers configured

`.mcp.json` (at repo root) registers four servers. None of them hardcode secrets — they read from your shell environment:

| Server | Package | Required env var | Purpose |
|--------|---------|------------------|---------|
| `postgresql` | `@modelcontextprotocol/server-postgres` | `POSTGRES_CONNECTION_STRING` | Query the project's PostgreSQL database from Claude. |
| `context7` | `@upstash/context7-mcp@latest` | `CONTEXT7_API_KEY` | Live, version-pinned library docs. |
| `github` | `@modelcontextprotocol/server-github` | `GITHUB_PERSONAL_ACCESS_TOKEN` | Repo, issue, PR, review operations. |
| `fetch` | `mcp-server-fetch` (via `uvx`) | _(none)_ | Fetch arbitrary URLs. Requires [`uv`](https://docs.astral.sh/uv/) installed. |

`settings.json` lists all four under `enabledMcpjsonServers` so they boot automatically.

---

## One-time setup (per developer)

### 1. Export env vars in your shell

Add to `~/.zshrc` (or `~/.bashrc`) and reload (`exec $SHELL -l`). **Never commit real values.**

```sh
# PostgreSQL — point at your local dev DB (skip if your project uses SQLite)
export POSTGRES_CONNECTION_STRING="postgresql://USER:PASSWORD@localhost:5432/DBNAME"

# Context7 — get a key at https://context7.com (or skip; the MCP will degrade gracefully)
export CONTEXT7_API_KEY="ctx7sk_..."

# GitHub — fine-grained PAT with the minimum scopes you need
export GITHUB_PERSONAL_ACCESS_TOKEN="github_pat_..."
```

### 2. Verify Claude Code picks them up

```sh
claude mcp list
```

All four should show **connected**. If one is `error`, the env var isn't exported in the shell from which you launched Claude Code.

### 3. Per-user overrides

Server only for yourself? Add it via:

```sh
claude mcp add --scope user <name> <command>
```

That writes to `~/.claude.json`, which is private to your machine.

---

## Reusing this config in another project

This config is intentionally portable. To clone it into a new FastAPI / Python project:

```sh
# from the new project root
git clone --depth 1 https://github.com/<your-org>/<this-repo>.git /tmp/claude-template
cp -R /tmp/claude-template/.claude .
cp /tmp/claude-template/.mcp.json .
cp /tmp/claude-template/CLAUDE.md .
chmod +x .claude/hooks/*.sh
```

Then:

1. **Add to `.gitignore`** (if not already):
   ```
   .claude/settings.local.json
   .env
   .env.*
   ```
2. **Adjust `permissions` in `.claude/settings.json`** if your project uses a different package manager (e.g., add `"Bash(uv *)"` or `"Bash(poetry *)"`).
3. **Update `/CLAUDE.md`** if your `app/` layout differs from the team default — but ideally adopt the layout instead, so all the rules and skills work unchanged.
4. **If migrating from a 5-layer project**: delete `app/controllers/` and have routes call services directly — see the migration table at the bottom of this README.
5. **Run `/check-architecture`** to confirm the project still satisfies the rules.

The skills (`fastapi`, `design-patterns`, `git-commit-helper`, `creator-skill`) work in any Python / FastAPI project. The rules assume the layered architecture; if a project genuinely needs a different shape, fork the rule file and document why.

---

## Memory and personal overrides

Claude Code has two memory layers — see [the official memory docs](https://docs.claude.com/en/memory).

### What's loaded into every session

1. **`CLAUDE.md`** at the repo root — team-shared, committed (this project's is ~70 lines).
2. **`.claude/rules/*.md`** — path-scoped rules (only the ones whose `paths:` glob matches files Claude opens).
3. **`MEMORY.md`** in `~/.claude/projects/<project-slug>/memory/` — auto-memory Claude maintains itself (first 200 lines / 25 KB).
4. **`CLAUDE.local.md`** at the repo root, *if you create it* — your personal, gitignored notes (sandbox URLs, test data, throwaway preferences). Already in `.gitignore` if you ran `/init`. To share personal notes across worktrees, import a file from your home dir instead: `@~/.claude/<project>-prefs.md`.

### Inspect / edit memory in a session

- `/memory` — lists every CLAUDE.md / rules file currently loaded, lets you toggle auto memory, and opens the auto-memory folder.
- `/init` — bootstraps a CLAUDE.md from the codebase or proposes improvements to the existing one.

### Debug "why isn't Claude following this rule?"

Use the `InstructionsLoaded` hook to log exactly which instruction files load and when. Add to `.claude/settings.json` under `hooks` if you suspect a rule isn't matching. See the [official hook reference](https://docs.claude.com/en/hooks#instructionsloaded).

### Monorepo / ancestor-CLAUDE.md noise

If a parent directory has a `CLAUDE.md` from another team that shouldn't apply here, exclude it via `claudeMdExcludes` in `settings.local.json` (so the exclusion stays per-developer):

```json
{
  "claudeMdExcludes": [
    "/Users/<you>/some-monorepo/other-team/.claude/rules/**"
  ]
}
```

Managed-policy CLAUDE.md files (`/Library/Application Support/ClaudeCode/CLAUDE.md` on macOS) cannot be excluded.

### Subagents

Subagents (e.g. `agents/python-pro.md`) can keep their own auto memory across sessions if persistent memory is enabled — see the [subagent memory docs](https://docs.claude.com/en/sub-agents#enable-persistent-memory).

---

## Settings precedence (highest → lowest)

1. `.claude/settings.local.json` — your personal overrides (gitignored)
2. `.claude/settings.json` — project-shared (committed)
3. `~/.claude/settings.json` — your global Claude Code settings
4. Built-in defaults

Permissions are **additive** — they extend, not replace, the higher-precedence layers. Hooks merge across layers (project hooks run alongside your global ones).

---

## Migrating from the 5-layer config (if applicable)

This config used to mandate `routes → controllers → services → repositories → models`. The Controller layer was removed because it was a one-method-per-endpoint passthrough — the FastAPI route handler already does that job. If you have a project on the old shape:

| Step | What to do |
|------|------------|
| 1. Delete `app/controllers/` | Each `<R>Controller` was a wrapper around `<R>Service`. The service has every method already. |
| 2. Update routes | Replace `controller: <R>Controller = Depends()` → `service: <R>Service = Depends()`. Calls `controller.foo(...)` → `service.foo(...)`. |
| 3. Drop redundant `try/except Exception` in services | Add the third handler `@app.exception_handler(Exception)` to `main.py` (template in `skills/fastapi/template.md`), then strip log-and-reraise blocks from services. |
| 4. Run `/check-architecture` | `validate.sh` will flag any leftovers. |
| 5. Update commit conventions | Layered-feature commits now touch **5** files, not 6. The `git-commit-helper` skill knows the new shape. |

The `validate.sh` script ships a guard that prints `[FAIL] app/controllers/ still exists — the project uses 4 layers (route → service → repository → model). Remove app/controllers/.` so you can't forget step 1.

---

## Where to look next

- [`/CLAUDE.md`](../CLAUDE.md) — auto-loaded session preamble
- [`rules/`](rules/) — full rulebook
- [`skills/`](skills/) — auto-triggered capabilities
- [`commands/`](commands/) — team slash commands
- [`agents/python-pro.md`](agents/python-pro.md) — the senior-Python subagent
- [Official Claude Code docs](https://docs.claude.com/en/docs/claude-code/) — settings, hooks, skills, MCP reference
