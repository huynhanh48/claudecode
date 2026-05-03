# Project conventions for Claude Code

This file is auto-loaded by Claude Code at the start of every session. It tells the assistant **how this project is organized** and **how the team works**. Keep it short — full details live in `.claude/rules/` and `.claude/skills/`.

## TL;DR for the assistant

1. **Architecture is non-negotiable.** Every feature flows: `routes → controllers → services → repositories → models`. Read [`.claude/rules/architecture.md`](.claude/rules/architecture.md) before writing or refactoring backend code.
2. **Patterns before implementation.** When asked to implement a new feature, first check [`.claude/skills/design-patterns/`](.claude/skills/design-patterns/) and [`.claude/rules/feature-development.md`](.claude/rules/feature-development.md). Pick the simplest pattern that fits — or none.
3. **Clean code, short and explicit.** No dead code, no speculative abstraction, no comments that just restate the code. Type hints on every function. See [`.claude/rules/coding-style.md`](.claude/rules/coding-style.md).
4. **Use Context7 for library docs.** Before using a third-party library API (FastAPI, SQLAlchemy, Pydantic, Alembic, etc.), invoke the `context7` MCP server to fetch current documentation — even for libraries you "know". See [`.claude/rules/using-context7.md`](.claude/rules/using-context7.md).
5. **Skills are first-class.** Skills under `.claude/skills/` activate automatically on matching prompts:
   - `fastapi` — scaffold a project / add a CRUD resource (layered template + validate script).
   - `design-patterns` — pick / apply a GoF pattern in idiomatic Python.
   - `creator-skill` — author a new skill.

## Project shape

- Python 3.10+, FastAPI, SQLAlchemy 2.0, Pydantic v2, Alembic, pytest.
- Layered backend in `app/`:
  ```
  app/
  ├── routes/         # APIRouter + path operations only
  ├── controllers/    # Thin orchestration; Depends(Service)
  ├── services/       # Business logic; raises domain exceptions
  ├── repositories/   # All SQLAlchemy queries
  ├── models/         # SQLAlchemy 2.0 ORM (Mapped, mapped_column)
  ├── schema/         # Pydantic Create/Update/Response
  ├── exception/      # Domain exception hierarchy
  ├── lib/            # JWT, bcrypt, etc.
  ├── core/           # Settings (pydantic-settings), session
  ├── db/             # engine, get_db
  └── middlewares/    # Auth middleware
  ```
- Migrations live in `alembic/versions/`.
- Tests live in `tests/` and use `pytest`.

## Decision rules

| Situation | What to do |
|-----------|------------|
| Adding a CRUD resource | Use the `fastapi` skill. Six files in this exact order: model → schema → repository → service → controller → route. Then wire `routes/__init__.py` and `db/database.py`. Add an Alembic migration. |
| Adding a new API endpoint to existing resource | Add method to existing controller + route only; do not touch service layout unless logic genuinely changes. |
| Cross-cutting concern (cache, audit log, retries) | Consider Decorator (object-level) or a function `@decorator`. See `.claude/skills/design-patterns/references/structural.md`. |
| Multiple algorithm variants behind a switch | Strategy — but in Python prefer passing a callable. See `.claude/skills/design-patterns/references/python-idioms.md`. |
| External service has the wrong shape | Adapter, in `app/integrations/`. |
| Hardcoding a setting / secret | Stop — put it in `app/core/config.py` (`Settings`). |
| Writing raw SQL anywhere outside a repository | Stop — move it into the repository for that resource. |

## What NOT to do

- Do not import services/repositories/models into routes — go through the controller.
- Do not raise raw `HTTPException` — use the `app/exception/` hierarchy (`NotFoundException`, `BadRequestException`, …).
- Do not return ORM instances from services or controllers — convert with `Response.model_validate(orm)`.
- Do not commit `.env`, `settings.local.json`, or anything containing real credentials.
- Do not skip tests, do not skip type hints, do not write `print()` in `app/` — use `logging`.
- Do not add a class when a function will do, or a pattern when duplication will do (Rule of Three).

## Where to look next

- [`.claude/rules/`](.claude/rules/) — the full rulebook (one short file per topic).
- [`.claude/skills/`](.claude/skills/) — auto-triggered, deeply documented skills.
- [`.claude/commands/`](.claude/commands/) — team slash commands (`/new-resource`, `/check-architecture`, `/find-pattern`).
- [`.claude/README.md`](.claude/README.md) — how the `.claude/` directory itself is organized + MCP setup.
