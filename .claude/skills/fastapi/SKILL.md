---
name: fastapi
description: Use this skill when scaffolding a new FastAPI backend or adding a new resource (CRUD endpoint) to an existing FastAPI project. Enforces the team's layered architecture (routes → controllers → services → repositories → models), Pydantic v2 schemas, SQLAlchemy 2.0 ORM, JWT auth, Alembic migrations, and the project's exception hierarchy. Trigger on requests like "create a FastAPI project", "add a new resource", "scaffold backend for X", "add auth to FastAPI", or "wire up SQLAlchemy + Pydantic for a new module".
---

# FastAPI Backend Skill

This skill produces backend code that follows the team's standard layered architecture. Use it whenever the user wants to (a) bootstrap a new FastAPI service, or (b) add a new resource/feature to an existing service that uses these conventions.

## Layered architecture (mandatory)

Every resource flows through these five layers in this exact order. Skipping a layer is not allowed — even if the layer is a one-line passthrough.

```
HTTP request
   │
   ▼
routes/<resource>.py        # APIRouter + path operations only
   │ Depends(Controller)
   ▼
controllers/<resource>.py   # Thin orchestration; no business logic
   │ Depends(Service)
   ▼
services/<resource>.py      # Business logic, validation, side effects
   │ uses Repository
   ▼
repositories/<resource>.py  # All SQLAlchemy queries live here
   │ uses Model
   ▼
models/<resource>.py        # SQLAlchemy 2.0 ORM (Mapped, mapped_column)
```

Cross-layer rules:

- **Routes** import controllers only. They never touch services, repositories, or models directly.
- **Controllers** import services only. They never query the DB.
- **Services** raise domain exceptions (`NotFoundException`, `BadRequestException`, …) and return Pydantic response models — never raw ORM objects.
- **Repositories** are the only place that constructs SQLAlchemy queries. They return ORM instances; converting to Pydantic happens in the service layer via `Model.model_validate(orm_instance)`.
- **Models** define schema, relationships, and `@observes` hooks. No business logic.

## Project layout

When scaffolding a new project, produce exactly this tree:

```
.
├── alembic/
│   ├── env.py
│   ├── script.py.mako
│   └── versions/
├── alembic.ini
├── app/
│   ├── __init__.py
│   ├── controllers/__init__.py
│   ├── core/
│   │   ├── __init__.py
│   │   └── config.py
│   ├── db/
│   │   ├── __init__.py
│   │   └── database.py
│   ├── exception/
│   │   ├── __init__.py
│   │   └── httpexception.py
│   ├── lib/
│   │   ├── __init__.py
│   │   ├── bcrypto.py
│   │   └── token.py
│   ├── middlewares/
│   │   ├── __init__.py
│   │   └── authorization.py
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

`template.md` in this skill contains the canonical contents for `main.py`, `database.py`, `httpexception.py`, `config.py`, `base.py`, `token.py`, `bcrypto.py`, and `authorization.py` — copy them verbatim when bootstrapping.

## Workflow

### A) Bootstrap a new project

1. Confirm with the user: project name, package manager (pip/uv), DB engine (default Postgres), whether auth is needed.
2. Create the tree above. Copy boilerplate files verbatim from `template.md`.
3. Generate `.env.example` listing only the env vars the user confirmed are needed (do not invent integrations).
4. Generate `requirements.txt` with the **base set** below; add extras only when the user asks for them.
5. Run `bash scripts/validate.sh <project-root>` to verify the layout is correct.

**Base requirements (always include):**

```
fastapi
uvicorn[standard]
SQLAlchemy>=2.0
alembic
pydantic>=2
pydantic-settings
psycopg2-binary
python-dotenv
PyJWT
passlib[bcrypt]
python-multipart
python-slugify
```

**Add only when the user asks:**

- Cloud uploads → `cloudinary`
- HTML processing → `beautifulsoup4`
- WebSockets → `python-socketio`
- Vector / RAG features → `pgvector`, `lightrag-hku`, etc.

### B) Add a new resource (`<resource>` = singular noun, snake_case)

For every new resource, create or extend exactly six files, in this order:

1. `app/models/<resource>.py` — ORM model.
2. `app/schema/<resource>.py` — Pydantic `Create`, `Update`, `Response` classes.
3. `app/repositories/<resource>.py` — DB queries (`get_*`, `create_*`, `update_*`, `delete_*`).
4. `app/services/<resource>.py` — Business logic; raises `NotFoundException` etc.; converts ORM → Pydantic.
5. `app/controllers/<resource>.py` — Thin class; one method per endpoint; `Depends(Service)`.
6. `app/routes/<resource>.py` — `APIRouter(tags=['<resource>'])`; one path operation per controller method.

Then:

7. Register the router in `app/routes/__init__.py`:

   ```python
   RootRouter.include_router(<resource>Router, prefix='/api/<resources>')
   ```

8. Import the model module in `app/db/database.py` so SQLAlchemy registers the mapping:

   ```python
   import app.models.<resource>  # noqa: F401
   ```

9. Generate an Alembic migration:

   ```bash
   alembic revision --autogenerate -m "add <resource> table"
   ```

10. Write a pytest module at `tests/test_<resource>.py` covering: list, get-by-id (404 case included), create (happy + validation error), update, delete.

See `examples/sample.md` for a complete worked example (resource = `book`).

## Coding conventions

### Models (SQLAlchemy 2.0)

- Inherit from `Base` and `DateTime` (mixin from `app/models/base.py`).
- Use `Mapped[T]` + `mapped_column(...)` exclusively. No legacy `Column(...)` syntax.
- Foreign keys: `mapped_column(ForeignKey('<table>.id'), nullable=False)`.
- Soft-delete: include `deleted: Mapped[bool] = mapped_column(default=False, nullable=False)`.
- Use `relationship(..., back_populates=...)` on both sides.
- Use `@observes('field')` for derived fields like slugs (only set if not already provided).

### Schemas (Pydantic v2)

- Three classes per resource: `<Resource>Create`, `<Resource>Update`, `<Resource>Response`.
- `Response` schemas set `model_config = {'from_attributes': True}` so they accept ORM instances.
- Use `Optional[T]` and `Field(default_factory=list)` rather than `= []` for list defaults.
- `Update` schemas mark every field optional and use `model_dump(exclude_unset=True)` in services.

### Repositories

- Constructor takes `db: Session`. No `Depends` here — services own the session.
- Always filter soft-deleted rows: `.filter(<Model>.deleted.is_(False))`.
- Use `selectinload(...)` for relationships you'll serialize to avoid N+1 queries.
- Order lists by `desc(<Model>.created_at)` unless the caller asks otherwise.
- Return ORM instances or `None`; never raise HTTP exceptions from a repository.

### Services

- Constructor: `def __init__(self, db: Session = Depends(get_db))`. Build repositories inside `__init__`.
- Translate "not found" into `raise NotFoundException(message='<Resource> not found')`.
- Convert ORM → Pydantic at the service boundary: `return <Resource>Response.model_validate(orm)`.
- Long-running side effects (embeddings, external APIs) belong here, not in controllers.

### Controllers

- Constructor: `def __init__(self, <resource>_service: <Resource>Service = Depends())`.
- One public method per endpoint. Each method is a one-liner that delegates to the service.
- No `try/except`, no DB access, no Pydantic validation.

### Routes

- One `APIRouter` per resource: `<resource>Router = APIRouter(tags=['<resources>'])`.
- Every operation declares `response_model`, `summary`, and (for non-trivial endpoints) `description`.
- Authentication: add `current_user: UserResponse = Depends(get_current_user_dependency)` to mutating endpoints.
- Background work: inject `background_tasks: BackgroundTasks` and call `background_tasks.add_task(...)`.

### Exceptions

- Use the hierarchy in `app/exception/httpexception.py` (`BadRequestException`, `UnauthorizedException`, `ForbiddenException`, `NotFoundException`, `InternalServerErrorException`).
- Never raise raw `HTTPException`. Never `return JSONResponse(...)` from a service or controller.
- The global handler in `main.py` converts `HttpException` to JSON.

### Config

- All settings come from `app/core/config.py` via `pydantic-settings.BaseSettings`.
- Required secrets are declared without defaults so the app fails fast on missing env vars.
- Read settings via `get_settings()` (LRU-cached) — never import the module-level instance from inside a function.

## Required quality checks before finishing

Before reporting the task complete, ensure all of these pass:

- [ ] Every new file has type annotations on every function signature.
- [ ] No `print()` calls — use `logging.getLogger(__name__)` if logging is needed.
- [ ] No hardcoded secrets, URLs, or magic numbers — pull from `Settings`.
- [ ] No raw SQL strings in services or controllers.
- [ ] Tests exist and cover happy path + 404 + validation error for the new resource.
- [ ] `ruff check .` passes (run `scripts/validate.sh`).
- [ ] `alembic upgrade head` succeeds against a clean DB.

## What NOT to do

- Do not put business logic in routes or controllers.
- Do not query the DB from a service without going through a repository.
- Do not return ORM instances from a controller — always return Pydantic schemas (or `dict[str, str]` for `{'message': '...'}` responses).
- Do not use `from app.X import *`.
- Do not create new exception classes for one-off cases — reuse the five in `app/exception/`.
- Do not commit `.env` or any file containing real credentials.

## References

- `template.md` — canonical contents of every boilerplate file.
- `examples/sample.md` — full worked example: adding a `book` resource end-to-end.
- `scripts/validate.sh` — checks tree layout, runs `ruff`, runs tests.
