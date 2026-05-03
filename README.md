# claudecode

Reusable [Claude Code](https://claude.com/claude-code) configuration for **Python / FastAPI** backend projects. Drop it into a new project, set three env vars, and the assistant inherits the team's architecture, coding rules, design-pattern guidance, MCP servers, slash commands, and quality hooks.

## What's inside

```
.
├── CLAUDE.md                              # auto-loaded session preamble
├── .mcp.json                              # MCP servers (postgres, context7, github, fetch)
└── .claude/
    ├── README.md                          # full guide
    ├── settings.json                      # MCP enables + hooks + permissions (committed)
    ├── rules/                             # short, opinionated rule files
    │   ├── architecture.md                #   layered backend (routes → ... → models)
    │   ├── coding-style.md                #   type hints, naming, function size
    │   ├── feature-development.md         #   patterns-first workflow
    │   ├── testing.md                     #   pytest + 80% coverage + TDD
    │   ├── security.md                    #   secrets, validation, OWASP basics
    │   ├── git-workflow.md                #   conventional commits + PR template
    │   └── using-context7.md              #   when to fetch live library docs
    ├── commands/                          # team slash commands
    │   ├── new-resource.md                #   /new-resource <name> [field:type] ...
    │   ├── check-architecture.md          #   /check-architecture
    │   ├── find-pattern.md                #   /find-pattern <problem>
    │   └── review.md                      #   /review [path]
    ├── hooks/                             # automation called from settings.json
    │   ├── format_python.sh               #   PostToolUse: ruff format + safe --fix
    │   └── check_secrets.sh               #   PreToolUse: blocks JWT/AWS/PAT/OpenAI tokens
    ├── agents/                            # custom subagents
    │   └── python-pro.md
    └── skills/                            # auto-triggered, deeply documented skills
        ├── fastapi/                       #   scaffold project / add CRUD resource
        ├── design-patterns/               #   GoF + Pythonic alternatives
        └── creator-skill/                 #   author new skills
```

## Install into a new project

From the new project root:

```sh
git clone --depth 1 https://github.com/huynhanh48/claudecode.git /tmp/claudecode-template
cp -R /tmp/claudecode-template/.claude .
cp /tmp/claudecode-template/.mcp.json .
cp /tmp/claudecode-template/CLAUDE.md .
chmod +x .claude/hooks/*.sh
```

Add to your project's `.gitignore`:

```
.claude/settings.local.json
.env
.env.*
```

Then export the three env vars in your shell (`~/.zshrc` / `~/.bashrc`):

```sh
export POSTGRES_CONNECTION_STRING="postgresql://USER:PASSWORD@localhost:5432/DBNAME"
export CONTEXT7_API_KEY="ctx7sk_..."          # https://context7.com — optional, MCP degrades gracefully
export GITHUB_PERSONAL_ACCESS_TOKEN="github_pat_..."
```

Verify:

```sh
claude mcp list
```

All four MCP servers should report **connected**.

## Customizing per project

- The rules and skills assume the layered FastAPI architecture (`app/` → `routes/controllers/services/repositories/models`). If your project has a different shape, fork the affected rule file and document why.
- If your project uses `uv` / `poetry` / `pdm` instead of `pip`, add the matching pattern to `.claude/settings.json` `permissions.allow` (e.g. `"Bash(uv *)"`).
- Per-developer overrides go in `.claude/settings.local.json` (gitignored).

## What this is *not*

- Not a Python project template (no `app/`, no `requirements.txt`, no `pyproject.toml`). It only configures Claude Code.
- Not framework-locked. The architecture rules are FastAPI-flavored, but the design-patterns skill, hooks, and most rule files apply to any Python codebase.
- Not a substitute for `gitleaks` / `trufflehog`. The `check_secrets.sh` hook is a fast, low-precision *editor*-time guard, not a repo-wide scanner.

## License

MIT. Bundled `creator-skill/` ships with its own `LICENSE.txt` from upstream.
