# Project conventions for Claude Code

This file is auto-loaded by Claude Code at the start of every session. It tells the assistant **how this project is organized** and **how the team works**. Keep it short — full details live in `.claude/rules/` and `.claude/skills/`.

## TL;DR for the assistant

1. **Architecture is non-negotiable.** Every feature flows: `routes → services → repositories → models`. **Four layers, no separate Controller** — the FastAPI route handler is the controller. Read [`.claude/rules/architecture.md`](.claude/rules/architecture.md) before writing or refactoring backend code.
2. **No try/except for the unknown.** Service code does not wrap work in `try/except Exception` just to log and re-raise — `main.py` has a global `Exception` handler. Catch only specific exceptions you need to *transform* into a domain exception.
3. **Patterns before implementation.** When asked to implement a new feature, first check [`.claude/skills/design-patterns/`](.claude/skills/design-patterns/) and [`.claude/rules/feature-development.md`](.claude/rules/feature-development.md). Pick the simplest pattern that fits — or none.
4. **Clean code, short and explicit.** No dead code, no speculative abstraction, no comments that just restate the code. Type hints on every function. See [`.claude/rules/coding-style.md`](.claude/rules/coding-style.md).
5. **Use Context7 for library docs.** Before using a third-party library API (FastAPI, SQLAlchemy, Pydantic, Alembic, etc.), invoke the `context7` MCP server to fetch current documentation — even for libraries you "know". See [`.claude/rules/using-context7.md`](.claude/rules/using-context7.md).
6. **Skills are first-class.** Skills under `.claude/skills/` activate automatically on matching prompts:
   - `fastapi` — scaffold a project / add a CRUD resource (layered template + validate script).
   - `design-patterns` — pick / apply a GoF pattern in idiomatic Python; consult **before** any non-trivial feature or refactor.
   - `git-commit-helper` — **always invoke for any git task** (commit message, PR body, staged-diff review, splitting commits). Encodes `.claude/rules/git-workflow.md` as a runner.
   - `creator-skill` — author a new skill.
7. **Research before building.** For any new feature: (a) consult `design-patterns` for the simplest scalable pattern; (b) use the `context7` MCP for live library docs (FastAPI, SQLAlchemy 2.0, Pydantic v2, Alembic) — see [`.claude/rules/using-context7.md`](.claude/rules/using-context7.md); (c) use WebFetch / GitHub search to find adaptable open-source examples *before* hand-rolling. See [`.claude/rules/feature-development.md`](.claude/rules/feature-development.md).

## Project shape

- Python 3.10+, FastAPI, SQLAlchemy 2.0, Pydantic v2, Alembic, pytest.
- Layered backend in `app/`:
  ```
  app/
  ├── routes/         # APIRouter; calls Service via Depends
  ├── services/       # Business logic; raises domain exceptions; converts ORM → Pydantic
  ├── repositories/   # All SQLAlchemy queries
  ├── models/         # SQLAlchemy 2.0 ORM (Mapped, mapped_column)
  ├── schema/         # Pydantic Create/Update/Response
  ├── exception/      # Domain exception hierarchy
  ├── integrations/   # Adapters around third-party SDKs (LightRAG, Cloudinary, …)
  ├── lib/            # JWT, bcrypt, etc.
  ├── core/           # Settings (pydantic-settings)
  └── db/             # engine, get_db
  ```
- Migrations live in `alembic/versions/`.
- Tests live in `tests/` and use `pytest`.

## Decision rules

| Situation | What to do |
|-----------|------------|
| Adding a CRUD resource | Use the `fastapi` skill. **Five** files in this exact order: model → schema → repository → service → route. Then wire `routes/__init__.py` and `db/database.py`. Add an Alembic migration when Alembic is in use. |
| Adding a new API endpoint to existing resource | Add method to existing service + a new path operation in the route. |
| Cross-cutting concern (cache, audit log, retries) | Consider Decorator (object-level) or a function `@decorator`. See `.claude/skills/design-patterns/references/structural.md`. |
| Multiple algorithm variants behind a switch | Strategy — but in Python prefer passing a callable. See `.claude/skills/design-patterns/references/python-idioms.md`. |
| External service has the wrong shape | Adapter, in `app/integrations/`. Service depends on the adapter via `Depends`. |
| Hardcoding a setting / secret | Stop — put it in `app/core/config.py` (`Settings`). |
| Writing raw SQL anywhere outside a repository | Stop — move it into the repository for that resource. |
| Wrapping calls in `try/except Exception` to log + re-raise | Stop — let it propagate, `main.py`'s global handler returns 500. |

## What NOT to do

- Do not import repositories/models into routes — go through the service.
- Do not raise raw `HTTPException` — use the `app/exception/` hierarchy (`NotFoundException`, `BadRequestException`, …).
- Do not return ORM instances from services or routes — convert with `Response.model_validate(orm)`.
- Do not commit `.env`, `settings.local.json`, or anything containing real credentials.
- Do not skip tests, do not skip type hints, do not write `print()` in `app/` — use `logging`.
- Do not add a class when a function will do, or a pattern when duplication will do (Rule of Three).
- Do not re-introduce a separate `app/controllers/` layer — the FastAPI route is the controller.

## Where to look next

- [`.claude/rules/`](.claude/rules/) — the full rulebook. **Path-scoped**: each rule's `paths:` frontmatter restricts it to matching files, so the session context stays lean. Run `/memory` to see what's currently loaded.
- [`.claude/skills/`](.claude/skills/) — auto-triggered, deeply documented skills (`fastapi`, `design-patterns`, `git-commit-helper`, `creator-skill`).
- [`.claude/commands/`](.claude/commands/) — team slash commands (`/new-resource`, `/check-architecture`, `/find-pattern`, `/commit`, `/review`).
- [`.claude/README.md`](.claude/README.md) — how the `.claude/` directory itself is organized + MCP setup + memory / `CLAUDE.local.md` / `claudeMdExcludes`.
