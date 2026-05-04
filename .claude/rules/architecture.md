---
paths:
  - "app/**/*.py"
  - "alembic/**/*.py"
  - "main.py"
  - "tests/**/*.py"
---

# Architecture rule

> **Every backend feature flows through four layers in this exact order. Skipping a layer is a defect, even if the layer is one line.**

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
repositories/<resource>.py  # All SQLAlchemy queries
  │ uses Model
  ▼
models/<resource>.py        # SQLAlchemy 2.0 ORM (Mapped, mapped_column)
```

> **Why no separate Controller layer.** In FastAPI the route handler *is* the controller — it parses the request, validates types, calls the dependency tree, and shapes the response. Adding a one-method-per-endpoint Controller class on top is pure boilerplate. Business logic lives in `Service`, HTTP wiring lives in `Route`, the two collapse cleanly. Pattern follows [`fastapi-best-practices`](https://github.com/zhanymkanov/fastapi-best-practices) and the official `bigger-applications` tutorial.

## Hard rules

1. **Routes** import services only. Never repositories or models. They declare `response_model`, `summary`, and inject auth via `Depends(get_current_user_dependency)` on mutating endpoints.
2. **Services** raise domain exceptions (from `app/exception/`) and return Pydantic schemas (`X.model_validate(orm)`). Never return ORM instances. May inject other services or `Integration` adapters via `Depends`.
3. **Repositories** are the *only* place that constructs SQLAlchemy queries. They return ORM instances or `None`. Never raise HTTP exceptions.
4. **Models** define schema, relationships, and `@observes` hooks. No business logic.

## No try/except for unknown errors

- Service code does not wrap calls in `try/except Exception` to log + re-raise. Let unexpected exceptions propagate — `main.py` has a global `Exception` handler that logs the traceback and returns a generic 500.
- Use `try/except` only when you need to **transform** a *specific* exception into a domain exception (e.g. catch `IntegrityError` → raise `BadRequestException('Email already taken')`). Catching `Exception` in a service is almost always wrong.

## Cross-cutting

- **Schemas** (`app/schema/<resource>.py`) come in three flavors per resource: `<R>Create`, `<R>Update`, `<R>Response`. `Response` sets `model_config = {'from_attributes': True}`.
- **Exceptions** are the five in `app/exception/` (`BadRequest`, `Unauthorized`, `Forbidden`, `NotFound`, `InternalServerError`). Don't add new ones for one-off cases.
- **Integrations** (`app/integrations/<vendor>.py`) wrap third-party SDKs (LightRAG, Cloudinary, …) behind a project-shaped interface. Services depend on the adapter via `Depends(get_<vendor>_adapter)`.
- **Config** comes from `app/core/config.py` (`Settings`, `pydantic-settings`). Required secrets have **no default** so the app fails fast.
- **Authentication** uses `Depends(get_current_user_dependency)` on mutating routes. Don't reinvent it.
- **Background work** uses FastAPI `BackgroundTasks` injected into the route, not threads.

## Wiring checklist (every new resource)

1. `app/models/<r>.py` — ORM model.
2. `app/schema/<r>.py` — Create / Update / Response.
3. `app/repositories/<r>.py` — DB queries.
4. `app/services/<r>.py` — business logic; converts ORM → Pydantic.
5. `app/routes/<r>.py` — `APIRouter(tags=['<r>s'])`; `response_model`, `summary` on every operation; `Depends(<R>Service)` directly.
6. `app/routes/__init__.py` — register router under `/api/<r>s`.
7. `app/db/database.py` — `import app.models.<r>  # noqa: F401`.
8. `alembic revision --autogenerate -m "add <r> table"` (when Alembic is in use).
9. `tests/test_<r>.py` — list, get-by-id (incl. 404), create (happy + validation error), update, delete.
10. Run `bash .claude/skills/fastapi/scripts/validate.sh` — checks layout, layer discipline, hardcoded secrets, missing wiring.

The `fastapi` skill (`.claude/skills/fastapi/`) automates steps 1–6.

## Layering smells

| Smell | Where to look |
|-------|---------------|
| `from app.repositories` inside `app/routes/` | route doing too much — go through service |
| `from app.services` inside `app/repositories/` | upward import — fix immediately |
| `db.query(...)` inside a route or service | SQL in the wrong layer |
| `raise HTTPException(...)` outside `main.py` | use `app/exception/` instead |
| Returning a model instance from a route | missing `<R>Response.model_validate(...)` |
| `JSONResponse(...)` outside `main.py` exception handlers | the global handler should format errors |
| `try/except Exception` in a service that just logs and re-raises | redundant — let `main.py`'s global handler take it |
