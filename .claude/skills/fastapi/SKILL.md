---
name: fastapi
description: Use this skill when scaffolding a new FastAPI backend or adding a new resource (CRUD endpoint) to an existing FastAPI project. Enforces the team's layered architecture (routes → services → repositories → models), Pydantic v2 schemas, SQLAlchemy 2.0 ORM, JWT auth, Alembic migrations, and the project's exception hierarchy. Trigger on requests like "create a FastAPI project", "add a new resource", "scaffold backend for X", "add auth to FastAPI", or "wire up SQLAlchemy + Pydantic for a new module".
---

# FastAPI Backend Skill

This skill produces backend code that follows the team's standard layered architecture. Use it whenever the user wants to (a) bootstrap a new FastAPI service, or (b) add a new resource/feature to an existing service that uses these conventions.

## Before you write any code

Run this preflight sequence — in order — for any non-trivial feature:

1. **Read the existing layer.** Open at least one comparable resource end-to-end (e.g. `app/{models,schema,repositories,services,routes}/post.py`) to mirror the actual codebase style. Do not rely on this skill alone — code is the source of truth.
2. **Consult `design-patterns`.** Open `.claude/skills/design-patterns/SKILL.md` and run the foundational check (KISS / SRP / Rule of Three / composition). For scale concerns, see the `Scaling patterns` table below — pick the simplest pattern that solves the *named* problem, not a hypothetical future one.
3. **Fetch live library docs via Context7** for any non-trivial library API you're about to call (FastAPI dependency tree, SQLAlchemy 2.0 query API, Pydantic v2 validators, Alembic autogenerate quirks). See `.claude/rules/using-context7.md`. Two-step: `resolve-library-id` → `query-docs`.
4. **Look for adaptable open-source examples** with WebFetch / GitHub code search before hand-rolling something non-trivial (rate limiting, S3 upload, OAuth, vector search, websocket presence). Prefer a battle-tested library; prefer porting a proven approach over inventing one.

## Layered architecture (mandatory)

Every resource flows through these four layers in this exact order. Skipping a layer is not allowed — even if the layer is a one-line passthrough.

```
HTTP request
   │
   ▼
routes/<resource>.py        # APIRouter + path operations only
   │ Depends(Service)
   ▼
services/<resource>.py      # Business logic, validation, side effects, HTTP-aware orchestration
   │ uses Repository (and/or Integration)
   ▼
repositories/<resource>.py  # All SQLAlchemy queries live here
   │ uses Model
   ▼
models/<resource>.py        # SQLAlchemy 2.0 ORM (Mapped, mapped_column)
```

**No separate Controller layer.** In FastAPI the route handler *is* the controller — it parses the request, runs the dependency tree, and shapes the response. Adding a one-method-per-endpoint Controller class on top is pure boilerplate. Pattern follows [`zhanymkanov/fastapi-best-practices`](https://github.com/zhanymkanov/fastapi-best-practices) and the official `bigger-applications` tutorial.

Cross-layer rules:

- **Routes** import services only. Never repositories or models. Declare `response_model` and `summary` on every operation; inject auth via `Depends(get_current_user_dependency)` on mutating routes.
- **Services** raise domain exceptions (`NotFoundException`, `BadRequestException`, …) and return Pydantic response models — never raw ORM objects. May inject other services or `Integration` adapters.
- **Repositories** are the only place that constructs SQLAlchemy queries. They return ORM instances; converting to Pydantic happens in the service layer via `Model.model_validate(orm_instance)`.
- **Models** define schema, relationships, and `@observes` hooks. No business logic.

## Project layout

When scaffolding a new project, produce exactly this tree:

```
.
├── alembic/                       # optional — only when you need real migrations
│   ├── env.py
│   ├── script.py.mako
│   └── versions/
├── alembic.ini
├── app/
│   ├── __init__.py
│   ├── core/
│   │   ├── __init__.py
│   │   └── config.py
│   ├── db/
│   │   ├── __init__.py
│   │   └── database.py
│   ├── exception/
│   │   ├── __init__.py
│   │   └── httpexception.py
│   ├── integrations/__init__.py   # adapters around 3rd-party SDKs (LightRAG, Cloudinary, …)
│   ├── lib/
│   │   ├── __init__.py
│   │   ├── bcrypto.py
│   │   └── token.py
│   ├── models/
│   │   ├── __init__.py
│   │   └── base.py
│   ├── repositories/__init__.py
│   ├── routes/__init__.py
│   ├── schema/__init__.py
│   └── services/__init__.py
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   └── test_<resource>.py
├── .env.example
├── main.py
├── requirements.txt
└── ruff.toml
```

`template.md` in this skill contains the canonical contents for `main.py`, `database.py`, `httpexception.py`, `config.py`, `base.py`, `token.py`, and `bcrypto.py` — copy them verbatim when bootstrapping.

## Workflow

### A) Bootstrap a new project

1. Confirm with the user: project name, package manager (pip/uv), DB engine (SQLite for local-file deployments, Postgres otherwise), whether auth is needed, third-party integrations.
2. Create the tree above. Copy boilerplate files verbatim from `template.md`.
3. Generate `.env.example` listing only the env vars the user confirmed are needed (do not invent integrations).
4. Generate `requirements.txt` with the **base set** below; add extras only when the user asks for them.
5. Run `bash scripts/validate.sh <project-root>` to verify the layout is correct.

**Base requirements (always include):**

```
fastapi
uvicorn[standard]
SQLAlchemy>=2.0
pydantic>=2
pydantic-settings
python-dotenv
PyJWT
passlib[bcrypt]
python-multipart
```

**Add only when the user asks:**

- Postgres → `psycopg2-binary`
- Migrations → `alembic`
- Cloud uploads → `cloudinary`
- HTML processing → `beautifulsoup4`
- WebSockets → `python-socketio`
- Vector / RAG features → `pgvector`, `lightrag-hku`, etc.

### B) Add a new resource (`<resource>` = singular noun, snake_case)

For every new resource, create or extend exactly five files, in this order:

1. `app/models/<resource>.py` — ORM model.
2. `app/schema/<resource>.py` — Pydantic `Create`, `Update`, `Response` classes.
3. `app/repositories/<resource>.py` — DB queries (`get_*`, `create_*`, `update_*`, `delete_*`).
4. `app/services/<resource>.py` — Business logic; raises `NotFoundException` etc.; converts ORM → Pydantic.
5. `app/routes/<resource>.py` — `APIRouter(tags=['<resources>'])`; path operations call the service via `Depends(<R>Service)` directly.

Then:

6. Register the router in `app/routes/__init__.py`:

   ```python
   RootRouter.include_router(<resource>Router, prefix='/api/<resources>')
   ```

7. Import the model module in `app/db/database.py` so SQLAlchemy registers the mapping:

   ```python
   import app.models.<resource>  # noqa: F401
   ```

8. Generate an Alembic migration (when Alembic is in use):

   ```bash
   alembic revision --autogenerate -m "add <resource> table"
   ```

9. Write a pytest module at `tests/test_<resource>.py` covering: list, get-by-id (404 case included), create (happy + validation error), update, delete.

See `examples/sample.md` for a complete worked example (resource = `book`).

## Coding conventions

### Models (SQLAlchemy 2.0)

- Inherit from `Base` and `DateTime` (mixin from `app/models/base.py`). Drop `DateTime` only when you genuinely don't need timestamps (rare).
- Use `Mapped[T]` + `mapped_column(...)` exclusively. No legacy `Column(...)` syntax.
- Foreign keys: `mapped_column(ForeignKey('<table>.id'), nullable=False)`. For self-referential parents, see `app/models/category.py` (`parent = relationship('Category', remote_side=[id], backref='children')`).
- **Soft-delete by default**: include `deleted: Mapped[bool] = mapped_column(default=False, nullable=False)`. Hard-delete is opt-in — only choose it when GDPR / cascade requirements demand it; document the choice in the commit body.
- Forward-referenced relationships: `Mapped['User'] = relationship('User', back_populates='posts')  # noqa: F821`.
- Use `@observes('field')` (from `sqlalchemy_utils`) for derived fields like slugs. **Guard with "only set if not already provided"** to avoid clobbering custom slugs.
- One-to-one: `relationship(..., uselist=False)`. Cascade for owned children: `cascade='all, delete-orphan'`.

### Schemas (Pydantic v2)

- Three classes per resource: `<Resource>Create`, `<Resource>Update`, `<Resource>Response`.
- `Response` schemas set `model_config = {'from_attributes': True}` so they accept ORM instances.
- Use `X | None` (PEP 604) and `Field(default_factory=list)` rather than `= []` for list defaults.
- `Update` schemas mark every field optional and use `model_dump(exclude_unset=True)` in services.

### Repositories

- Constructor takes `db: Session`. No `Depends` here — services own the session.
- If the model has `deleted`, *every* default reader filters it: `.filter(<Model>.deleted.is_(False))`. Hard-delete tail is exposed as separate methods (`get_deleted_*`, `restore_*`, `hard_delete_*`).
- Use `selectinload(...)` for any relationship the caller will serialize. Pre-loading every column-then-relation avoids the N+1 trap.
- Order lists by `desc(<Model>.created_at)` unless the caller asks otherwise.
- For partial-text search use `.ilike(f'%{value.strip()}%')` after a `(value or '').strip()` guard, so empty queries don't return everything by accident.
- Return ORM instances or `None`; never raise HTTP exceptions from a repository.
- Pagination: accept `skip: int = 0, limit: int = 100`; let the caller apply Pydantic-validated bounds.

### Services

- Constructor: `def __init__(self, db: Session = Depends(get_db))`. Build repositories inside `__init__` (`self.repo = <Resource>Repository(db=self.db)`).
- For services that wrap an integration (no DB), constructor is `def __init__(self, adapter: <Vendor>Adapter = Depends(get_<vendor>_adapter))`.
- Translate "not found" into `raise NotFoundException(message='<Resource> not found')`. Reuse the five exception classes — never invent a new one for a one-off case.
- Convert ORM → Pydantic at the service boundary: `return <Resource>Response.model_validate(orm)`. **Do not return ORM instances.**
- For collections: `[<Resource>Response.model_validate(item) for item in self.repo.get_all(...)]`.
- Long-running side effects (embeddings, external APIs, ML inference) belong here. Wrap them in a private `_method` and call from a public method that also returns the response.
- When you need another resource's logic, inject another *service* via `Depends`, not its repository directly.
- **No `try/except Exception` just to log + re-raise.** Let exceptions propagate — `main.py` has a global handler that logs the traceback and returns a generic 500. Catch only specific exceptions you need to *transform* into a domain exception (e.g. `IntegrityError → BadRequestException`).

### Routes

- One `APIRouter` per resource. Use the explicit-name form: `<resource>Router = APIRouter(tags=['<resources>'])`, then `from app.routes.<resource> import <resource>Router` in `routes/__init__.py`.
- Every operation declares `response_model`, `summary`, and (for non-trivial endpoints) `description`.
- Inject the service directly: `service: <R>Service = Depends()`. The route body is a one-liner that calls a service method.
- Authentication: import `from app.routes.auth import get_current_user_dependency`. Add `current_user: UserResponse = Depends(get_current_user_dependency)` to every mutating endpoint.
- Admin-only: use `Depends(get_admin_user_dependency)` (same module). Don't re-implement role checks inside the route body.
- Background work: inject `background_tasks: BackgroundTasks` and call `background_tasks.add_task(fn, *args)`. Avoid bare `asyncio.create_task` from a request handler — the task can outlive the response and crash silently.
- Avoid eager top-level side effects in route modules (e.g. `cloudinary.config(...)` at import time). Move config to `app/core/` and call from inside the function that needs it.

### Exceptions

- Use the hierarchy in `app/exception/httpexception.py` (`BadRequestException`, `UnauthorizedException`, `ForbiddenException`, `NotFoundException`, `InternalServerErrorException`).
- Never raise raw `HTTPException`. Never `return JSONResponse(...)` from a service or route.
- `main.py` has three global handlers: `HttpException` → JSON with the message; `SQLAlchemyError` → 500 with a generic message; `Exception` → 500 with a generic message + log traceback. Trust them.

### Config

- All settings come from `app/core/config.py` via `pydantic-settings.BaseSettings`.
- Required secrets are declared without defaults so the app fails fast on missing env vars.
- Read settings via `get_settings()` (LRU-cached) — never import the module-level instance from inside a function.

## Required quality checks before finishing

Before reporting the task complete, ensure all of these pass:

- [ ] Every new file has type annotations on every function signature.
- [ ] No `print()` calls — use `logging.getLogger(__name__)` if logging is needed.
- [ ] No hardcoded secrets, URLs, or magic numbers — pull from `Settings`.
- [ ] No raw SQL strings in services or routes.
- [ ] No `try/except Exception` in services that just logs + re-raises.
- [ ] Tests exist and cover happy path + 404 + validation error for the new resource.
- [ ] `ruff check .` passes (run `scripts/validate.sh`).
- [ ] `alembic upgrade head` succeeds against a clean DB (when Alembic is in use).

## Scaling patterns (pick the simplest one that solves a *named* problem)

Before introducing any of these, run the principle check from `.claude/skills/design-patterns/SKILL.md` (KISS / SRP / Rule of Three / composition). If duplication < 3 cases or no concrete pain point exists, **don't** introduce the pattern.

| Pain point in this project | Pattern (simplest first) | Where it lives |
|---|---|---|
| Same query path is hot and dominates DB load | `@functools.lru_cache` on a pure helper, *or* a small `Cache` decorator wrapping the **service** method | `app/services/<r>.py` (decorator from `app/lib/`) |
| External integration (Cloudinary, LightRAG, OpenAI) has wrong shape | **Adapter** in `app/integrations/<vendor>.py` exposing a project-shaped interface; service depends on the adapter | `app/integrations/` |
| Multiple variants of "send a notification" / "process a payment" | **Strategy** as a `Protocol`, or — preferred in Python — a callable injected via `Depends` | `app/services/<r>.py` |
| Request-scoped cross-cutting (audit log, request id, timing) | **FastAPI dependency** that yields a value; or a Starlette **middleware** for things that span the full request | `Depends(...)` or middleware |
| Heavy IO that must not block the response (embeddings, image variants) | **`BackgroundTasks`** (in-process); promote to a queue (Celery / arq / RQ) only when retries / multi-host become real needs | route → service |
| Workflow with branching states (chat session, document ingest) | **State** machine — class per state, transitions return the next state | `app/services/<r>.py` |
| One-call wrapper around a 50-method SDK (e.g. boto3) | **Facade** in `app/integrations/<vendor>.py` | `app/integrations/` |
| Complex search filter object | `@dataclass(frozen=True)` query spec passed into the repo (Builder is overkill for typical CRUD) | `app/repositories/<r>.py` arg type |
| One observer per side effect grows to many | Promote the side-effect notification to **Observer** via `blinker`, *only when* you have ≥ 3 subscribers and ordering doesn't matter | `app/lib/signals.py` |
| Recurring "find resource or 404" | Stay duplicated. Service-level `_get_or_404` is fine; do not invent a generic `EntityFinder<T>` framework | — |

### When in doubt

Default order of preference: **plain function** → **`@dataclass`** → **`Protocol` + injection** → **decorator** → **GoF pattern**. A new GoF participant inside `app/` should be justified in the commit body (per `.claude/rules/feature-development.md`).

## What NOT to do

- Do not put business logic in routes.
- Do not query the DB from a service without going through a repository.
- Do not return ORM instances from a route — always return Pydantic schemas (or `dict[str, str]` for `{'message': '...'}` responses).
- Do not re-introduce a separate `app/controllers/` layer — the FastAPI route is the controller.
- Do not use `from app.X import *`.
- Do not create new exception classes for one-off cases — reuse the five in `app/exception/`.
- Do not commit `.env` or any file containing real credentials.

## References

- `template.md` — canonical contents of every boilerplate file.
- `examples/sample.md` — full worked example: adding a `book` resource end-to-end.
- `scripts/validate.sh` — checks tree layout, runs `ruff`, runs tests.
