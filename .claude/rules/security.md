---
paths:
  - "app/**/*.py"
  - "alembic/**/*.py"
  - "main.py"
  - "tests/**/*.py"
  - ".env*"
  - "Dockerfile"
  - "docker-compose*.yml"
---

# Security

## Secrets

- **Never** hardcode secrets. All secrets come from `app/core/config.py` (`Settings`, `pydantic-settings`).
- Required secrets have **no default** — the app must fail fast on missing env vars.
- `.env` is gitignored. `.env.example` lists every variable name (no values).
- Do not commit `settings.local.json`, `~/.lobehub-market/credentials.json`, or anything under `.claude/` containing tokens.
- Rotate any secret that has been seen in a logs / screenshot / chat / commit.

## Secret scanning

- `.claude/hooks/check_secrets.sh` runs on every `Edit`/`Write` and blocks edits that look like a token, key, or password.
- For repo-wide scans use `gitleaks` or `trufflehog` before pushing a branch.

## Input validation

- Validate at every system boundary: HTTP (Pydantic schemas), DB (SQLAlchemy types + constraints), file I/O (allowlists for extensions and MIME types), shell (never `shell=True` with untrusted input).
- Trust nothing from `request.body`, headers, query params, file names, or external API responses until validated.
- Use `pydantic.Field(ge=, le=, min_length=, max_length=, pattern=)` to enforce bounds.

## Authentication and authorization

- Authentication: `Depends(get_current_user_dependency)` on every mutating route.
- Role checks: `Depends(get_admin_user_dependency)` for admin-only endpoints. Don't reinvent role logic in routes.
- Tokens: JWT signed with `JWT_SECRET_KEY` (≥ 32 bytes random). Algorithm pinned via `JWT_ALGORITHM`. Expiry < 24h.
- Logout blacklists the token (`BlacklistedTokenRepository`).

## Database

- Always parameterized queries (SQLAlchemy ORM does this for you).
- Soft-delete (`deleted=True`) for user-facing data; hard-delete only via explicit admin action.
- No raw SQL strings in services or controllers — see `architecture.md`.
- Migrations are reviewed: never `DROP TABLE` or `ALTER COLUMN ... TYPE` without a documented reason.

## HTTP responses

- Error responses go through the `HttpException` handler in `main.py`. They contain `{"message": "..."}` only — never internal stack traces, SQL, or PII.
- Don't leak `User.password` or hashed passwords. `UserResponse` must omit them.

## Dependency hygiene

- `pip-audit` (or `safety`) before each release.
- Pin versions in `requirements.txt`.
- Subscribe to security advisories for FastAPI, SQLAlchemy, Pydantic, PyJWT.

## File uploads

- Allowlist extensions (`DOCUMENT_ALLOWED_EXTENSIONS`).
- Enforce max size (`DOCUMENT_MAX_FILE_SIZE_MB`).
- Sanitize file names (`secure_filename` or equivalent).
- Store outside the web root; serve via a controlled endpoint that re-checks ownership.

## Logging

- Log auth events (login success / failure / logout) with user id and source IP.
- Never log secrets, tokens, full request bodies, or PII (emails are PII in some jurisdictions).
- Use structured logging (`extra={...}`) for searchability.

## Stop-the-line list

If any of these are true, stop and tell the user before proceeding:

- A secret was committed, even briefly.
- An endpoint accepts user input and forwards it to `eval`, `exec`, `subprocess.run(..., shell=True)`, `os.system`, or `pickle.load(...)`.
- Authentication can be bypassed by a header, a missing header, or a known-default JWT secret.
- A migration drops or rewrites a production-shaped table.

See [`security-reviewer`](https://docs.claude.com/en/docs/claude-code/agents) — invoke that subagent before any auth/crypto/PII change merges.
