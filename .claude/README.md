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
├── agents/                   # custom subagents (e.g. python-pro)
└── skills/                   # auto-triggered skills
    ├── fastapi/              # scaffold a project / add a CRUD resource
    ├── design-patterns/      # GoF + foundational principles, Python
    └── creator-skill/        # how to author new skills
```

The MCP server definitions live in **`/.mcp.json`** at the repo root (Claude Code reads project MCPs from there, not from inside `.claude/`).

The companion **`/CLAUDE.md`** at the repo root is auto-loaded into every Claude Code session and links back to the rules and skills.

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
| [`rules/architecture.md`](rules/architecture.md) | Layered backend (routes → controllers → services → repositories → models) — non-negotiable. | editing `app/**/*.py`, `alembic/**`, `main.py`, `tests/**` |
| [`rules/coding-style.md`](rules/coding-style.md) | Type hints, naming, function size, no comments unless the *why* is non-obvious. | editing any `**/*.py` |
| [`rules/feature-development.md`](rules/feature-development.md) | Patterns-first workflow: consult `design-patterns` skill before coding. | always |
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
| `/new-resource <name> [field:type] ...` | Scaffold a CRUD resource end-to-end (model → schema → repository → service → controller → route + Alembic + tests) via the `fastapi` skill. |
| `/check-architecture` | Run `validate.sh` + `ruff` + `pytest` and report layered-architecture / style violations. |
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

Custom subagents. Currently:

- `agents/python-pro.md` — senior Python developer subagent for type-safe FastAPI / async / data-pipeline work.

Add more by dropping a markdown file with `---\nname: ...\ndescription: ...\ntools: ...\n---` frontmatter; Claude Code picks them up automatically.

### `skills/`

Auto-triggered, deeply documented capabilities.

| Skill | Activates on |
|-------|--------------|
| [`skills/fastapi/`](skills/fastapi/) | "scaffold a FastAPI project", "add a CRUD resource", … |
| [`skills/design-patterns/`](skills/design-patterns/) | "which pattern should I use", "refactor this code", "code smell", … |
| [`skills/git-commit-helper/`](skills/git-commit-helper/) | **Any git-related request**: "viết commit", "write a commit message", "open a PR", staged-diff review. Enforces `rules/git-workflow.md`. |
| [`skills/creator-skill/`](skills/creator-skill/) | "create a new skill", "tạo skill mới", … |

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
# PostgreSQL — point at your local dev DB
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
4. **Run `/check-architecture`** to confirm the project still satisfies the rules.

The skills (`fastapi`, `design-patterns`, `creator-skill`) work in any Python / FastAPI project. The rules assume the layered architecture; if a project genuinely needs a different shape, fork the rule file and document why.

---

## Memory and personal overrides

Claude Code has two memory layers — see [the official memory docs](https://docs.claude.com/en/memory).

### What's loaded into every session

1. **`CLAUDE.md`** at the repo root — team-shared, committed (this project's is ~65 lines).
2. **`.claude/rules/*.md`** — path-scoped rules (only the ones whose `paths:` glob matches files Claude opens).
3. **`MEMORY.md`** in `~/.claude/projects/-Users-huynhanh-sdt-solution/memory/` — auto-memory Claude maintains itself (first 200 lines / 25 KB).
4. **`CLAUDE.local.md`** at the repo root, *if you create it* — your personal, gitignored notes (sandbox URLs, test data, throwaway preferences). Already in `.gitignore` if you ran `/init`. To share personal notes across worktrees, import a file from your home dir instead: `@~/.claude/sdt-solution-prefs.md`.

### Inspect / edit memory in a session

- `/memory` — lists every CLAUDE.md / rules file currently loaded, lets you toggle auto memory, and opens the auto-memory folder.
- `/init` — bootstraps a CLAUDE.md from the codebase or proposes improvements to the existing one. Set `CLAUDE_CODE_NEW_INIT=1` for the interactive multi-phase flow.

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

## Settings precedence (highest → lowest)

1. `.claude/settings.local.json` — your personal overrides (gitignored)
2. `.claude/settings.json` — project-shared (committed)
3. `~/.claude/settings.json` — your global Claude Code settings
4. Built-in defaults

Permissions are **additive** — they extend, not replace, the higher-precedence layers. Hooks merge across layers (project hooks run alongside your global ones).

---

## Where to look next

- [`/CLAUDE.md`](../CLAUDE.md) — auto-loaded session preamble
- [`rules/`](rules/) — full rulebook
- [`skills/`](skills/) — auto-triggered capabilities
- [`commands/`](commands/) — team slash commands
- [Official Claude Code docs](https://docs.claude.com/en/docs/claude-code/) — settings, hooks, skills, MCP reference
