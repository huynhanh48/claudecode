---
paths:
  - "app/**/*.py"
  - "alembic/**/*.py"
  - "main.py"
  - "tests/**/*.py"
---

# Architecture rule

> **Every backend feature flows through five layers in this exact order. Skipping a layer is a defect, even if the layer is one line.**

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
repositories/<resource>.py  # All SQLAlchemy queries
  │ uses Model
  ▼
models/<resource>.py        # SQLAlchemy 2.0 ORM (Mapped, mapped_column)
```

## Hard rules

1. **Routes** import controllers only. Never services, repositories, or models.
2. **Controllers** import services only. Never query the DB. One method per endpoint.
3. **Services** raise domain exceptions (from `app/exception/`) and return Pydantic schemas (`X.model_validate(orm)`). Never return ORM instances.
4. **Repositories** are the *only* place that constructs SQLAlchemy queries. They return ORM instances or `None`. Never raise HTTP exceptions.
5. **Models** define schema, relationships, and `@observes` hooks. No business logic.

## Cross-cutting

- **Schemas** (`app/schema/<resource>.py`) come in three flavors per resource: `<R>Create`, `<R>Update`, `<R>Response`. `Response` sets `model_config = {'from_attributes': True}`.
- **Exceptions** are the five in `app/exception/` (`BadRequest`, `Unauthorized`, `Forbidden`, `NotFound`, `InternalServerError`). Don't add new ones for one-off cases.
- **Config** comes from `app/core/config.py` (`Settings`, `pydantic-settings`). Required secrets have **no default** so the app fails fast.
- **Authentication** uses `Depends(get_current_user_dependency)` on mutating routes. Don't reinvent it.
- **Background work** uses FastAPI `BackgroundTasks` injected into the route, not threads.

## Wiring checklist (every new resource)

1. `app/models/<r>.py` — ORM model.
2. `app/schema/<r>.py` — Create / Update / Response.
3. `app/repositories/<r>.py` — DB queries.
4. `app/services/<r>.py` — business logic; converts ORM → Pydantic.
5. `app/controllers/<r>.py` — `Depends(Service)`; one method per endpoint.
6. `app/routes/<r>.py` — `APIRouter(tags=['<r>s'])`; `response_model`, `summary` on every operation.
7. `app/routes/__init__.py` — register router under `/api/<r>s`.
8. `app/db/database.py` — `import app.models.<r>  # noqa: F401`.
9. `alembic revision --autogenerate -m "add <r> table"`.
10. `tests/test_<r>.py` — list, get-by-id (incl. 404), create (happy + validation error), update, delete.

The `fastapi` skill (`.claude/skills/fastapi/`) automates steps 1–7 from a resource description; step 11 below verifies them.

11. Run `bash .claude/skills/fastapi/scripts/validate.sh` — checks layout, layer discipline, hardcoded secrets, missing wiring.

## Layering smells

| Smell | Where to look |
|-------|---------------|
| `from app.repositories` inside `app/routes/` | route doing too much |
| `from app.services` inside `app/repositories/` | upward import — fix immediately |
| `db.query(...)` inside a controller or service | SQL in the wrong layer |
| `raise HTTPException(...)` outside `main.py` | use `app/exception/` instead |
| Returning a model instance from a route | missing `<R>Response.model_validate(...)` |
| `JSONResponse(...)` outside `main.py` exception handlers | the global handler should format errors |
