# Testing

## Framework

- `pytest` is the only test runner.
- Tests live in `tests/`, mirror the package layout (`tests/test_<resource>.py`).
- Use `pytest.mark` to categorize: `@pytest.mark.unit`, `@pytest.mark.integration`, `@pytest.mark.e2e`.

## TDD discipline

1. Write the failing test first (RED).
2. Run it — confirm it fails for the **right reason**.
3. Implement the minimum code to pass (GREEN).
4. Refactor (IMPROVE) — tests still green.
5. Repeat.

## Coverage

- Target: **80%** lines, **80%** branches.
- Run: `pytest --cov=app --cov-report=term-missing --cov-fail-under=80`.
- Don't game coverage. If a line is hard to test, that's a design smell.

## What to cover for each new resource

| Test | Why |
|------|-----|
| List endpoint returns recently created items | Happy path |
| GET-by-id returns 404 when missing | Service raises `NotFoundException` |
| POST returns 422 on invalid payload | Pydantic validation |
| POST returns 200/201 with the created body | Happy path + `Response` schema |
| PUT partial update keeps untouched fields | `model_dump(exclude_unset=True)` works |
| DELETE soft-deletes (subsequent GET → 404) | Repository sets `deleted=True` |
| Auth-protected endpoint returns 401 without token | `get_current_user_dependency` works |
| Auth-protected endpoint returns 403 for wrong role | `get_admin_user_dependency` works |

## Fixtures

- `tests/conftest.py` provides:
  - `client` — FastAPI `TestClient` with `get_db` overridden to a SQLite in-memory or fresh schema per test.
  - Schema reset autouse fixture (`Base.metadata.drop_all` + `create_all`).
- Per-resource fixtures (`book_factory`, `authenticated_client`) live in module-level conftests when reused across files.

## Mocking guidance

- Mock at the *boundary*: HTTP, time (`freezegun`), randomness, external SDKs.
- Don't mock the DB — tests should hit a real SQLAlchemy session against SQLite (or a Postgres test container for queries that need PG-only features).
- Don't mock the system under test. If you need to, the design is wrong (see `coding-style.md` — inject collaborators).

## Async tests

- Use `pytest-asyncio` and mark tests with `@pytest.mark.asyncio`.
- Configure `asyncio_mode = "auto"` in `pytest.ini` to skip the marker on every test.

## Run before every commit

```bash
ruff check . && ruff format --check . && pytest -q
```

A pre-commit hook is configured in `.claude/hooks/` — see `.claude/settings.json`.
