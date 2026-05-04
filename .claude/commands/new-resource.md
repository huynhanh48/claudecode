---
description: Scaffold a new CRUD resource end-to-end (model → schema → repository → service → route + wiring + Alembic + tests).
argument-hint: "<resource-singular> [field1:type] [field2:type] ..."
---

# /new-resource

Scaffold a new layered backend resource following the team's architecture.

**Argument**: `$ARGUMENTS` — e.g. `book title:str author:str year:int summary:str?`

## Steps

1. Activate the `fastapi` skill at `.claude/skills/fastapi/SKILL.md`.
2. Treat `$ARGUMENTS` as `<resource> [<field>:<type>]...`. The first token is the resource name (singular, snake_case). Remaining tokens are fields. Trailing `?` on a type means optional.
3. Produce **exactly five** new files in this order:
   1. `app/models/<resource>.py`
   2. `app/schema/<resource>.py`
   3. `app/repositories/<resource>.py`
   4. `app/services/<resource>.py`
   5. `app/routes/<resource>.py`
4. Wire it up:
   - Add `<resource>Router` import + `RootRouter.include_router(...)` to `app/routes/__init__.py` under `/api/<resources>`.
   - Add `import app.models.<resource>  # noqa: F401` to `app/db/database.py`.
5. Generate the Alembic migration (when Alembic is in use): `alembic revision --autogenerate -m "add <resources> table"`.
6. Write `tests/test_<resource>.py` covering: list, get-by-id (incl. 404), create (happy + 422 validation), update, delete.
7. Run validation:
   - `bash .claude/skills/fastapi/scripts/validate.sh`
   - `ruff check .`
   - `pytest -q tests/test_<resource>.py`
8. Report the file list, migration revision id (if generated), and test result.

If the resource already exists, stop and ask the user how to proceed (extend vs. abort).
