# Using Context7 for library documentation

> **Default:** when the user asks about a library, framework, SDK, API, CLI tool, or cloud service — even one you "know" — fetch fresh docs from the `context7` MCP server before answering. Training data drifts; APIs don't wait.

## When to use Context7

| Trigger | Action |
|---------|--------|
| User asks about FastAPI / SQLAlchemy / Pydantic / Alembic / etc. API syntax | Fetch from Context7 first. |
| User asks how to configure a tool (ruff, pytest, alembic) | Fetch from Context7 first. |
| You're about to write code that calls a library you haven't touched in this session | Fetch from Context7 first. |
| Version migration question (Pydantic v1 → v2, SQLAlchemy 1.x → 2.0) | Fetch from Context7 — these are the *exact* cases where training data is wrong. |
| User pastes a deprecation warning or unfamiliar error message | Fetch from Context7. |

## When NOT to use Context7

- Refactoring, code review, or debugging *your own* business logic.
- Writing scripts from scratch in a language (no library lookup needed).
- General programming concepts, algorithms, system design.
- The user explicitly said "don't look it up, just answer".

## How to invoke

Two-step protocol enforced by the MCP server:

```
1. resolve-library-id   → get the canonical /org/project ID
2. query-docs           → ask the question against that ID
```

Example reasoning trace:

> User asks: "How do I configure SQLAlchemy 2.0 connection pool size with asyncpg?"
> → `resolve-library-id` for "SQLAlchemy" → `/sqlalchemy/sqlalchemy`
> → `query-docs` against `/sqlalchemy/sqlalchemy` with the connection-pool question
> → Cite the result and link if relevant.

## Failure modes

- **502 / quota exceeded**: degrade gracefully — answer from training data, but tell the user the live docs were unavailable so they know to double-check.
- **No canonical match**: pick the closest result; mention which one you used.
- **Result contradicts your training**: trust the live docs. Note the discrepancy in your answer.

## What to do with the result

- Cite version numbers when the answer is version-specific.
- Do not paste 100 lines of doc into the chat. Summarize, then link.
- If the doc shows a deprecated API, prefer the current one and explain why.

## Library ID hints for this project

Common shortcuts (still resolve first to get the latest version pin):

| Library | Likely ID |
|---------|-----------|
| FastAPI | `/tiangolo/fastapi` |
| SQLAlchemy | `/sqlalchemy/sqlalchemy` |
| Pydantic | `/pydantic/pydantic` |
| Pydantic Settings | `/pydantic/pydantic-settings` |
| Alembic | `/sqlalchemy/alembic` |
| pytest | `/pytest-dev/pytest` |
| ruff | `/astral-sh/ruff` |

## Other doc sources (when Context7 is wrong tool)

- **Claude Code itself** (settings, hooks, skills, commands): see `/Users/<user>/.claude/CLAUDE.md` if local, or the official docs at `https://docs.claude.com/en/docs/claude-code/` — Context7 doesn't always cover dev tooling docs.
- **Refactoring.Guru** (design patterns): linked from `.claude/skills/design-patterns/`.
- **Project's own code**: read it. Don't guess from memory.
