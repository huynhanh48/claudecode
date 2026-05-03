# Coding style

> **Short, explicit, and boring.** Reading speed beats writing cleverness.

## Type hints

- Type-annotate every function signature and every dataclass / Pydantic field.
- Use `from __future__ import annotations` in any file with forward references.
- Prefer `X | None` over `Optional[X]`.
- Use `Protocol` for structural interfaces; reserve `ABC` for inheritance hierarchies.

## Naming

- `snake_case` for functions, methods, variables, modules.
- `PascalCase` for classes.
- `UPPER_SNAKE` for module-level constants.
- Private helpers: leading underscore (`_helper`).
- Names should be specific (`user_repository`, not `repo`; `get_user_by_email`, not `lookup`).

## Files and functions

- Files: 200–400 lines typical, 800 hard cap. Split by *feature*, not by *kind*.
- Functions: ≤ 50 lines (lower is better). One distinct purpose. ≤ 3 levels of nesting.
- Classes: one reason to change (SRP). If you can name two responsibilities, split.

## Comments

- **Default to no comments.** Names should explain *what*. Code should explain *how*.
- Write a comment only when the *why* is non-obvious: a hidden constraint, a workaround for a specific bug, a subtle invariant.
- Never write comments that just restate the code.
- Never write comments that reference history (`# was X, now Y`) or callers (`# used by foo`). That belongs in commit messages.

## Imports

- Order: stdlib, third-party, local — separated by blank lines (`isort`/`ruff` does this).
- No `from X import *`.
- No upward imports (see [`architecture.md`](architecture.md)).
- Imports inside functions only to break circular imports — and document why.

## Errors

- Never silently swallow errors (`except Exception: pass`).
- Catch the narrowest exception that matches.
- Re-raise with context (`raise NotFoundException(...) from exc`) when you transform.
- At the boundary (route / handler) the global exception handler in `main.py` formats responses — don't do it inline.

## Logging

- Use `logging.getLogger(__name__)`. Never `print()` in `app/`.
- Log at the right level: `debug` (developer detail) / `info` (lifecycle) / `warning` (suspicious but recoverable) / `error` (failed operation) / `critical` (process-affecting).
- Log structured data via `extra={...}`, not by interpolating into the message.

## Mutability

- Default to immutable data: `@dataclass(frozen=True)` or `tuple` over `list` when data won't change.
- Don't mutate function arguments.
- Use `copy()` / `model_copy(update={...})` instead of in-place edits.

## Dependencies

- Inject collaborators through constructors. Never instantiate inside a class for DB / cache / HTTP clients.
- FastAPI's `Depends(...)` *is* dependency injection — use it for services and repositories.

## Formatting

- `ruff format` is the source of truth (see `ruff.toml`).
- 100-char lines (line-length is enforced by ruff).
- Single quotes for strings, double for docstrings (project preference; see `ruff.toml`).

## What NOT to do

- No `Any` unless you genuinely cannot type it; if you do, write a comment explaining why.
- No premature abstraction. Wait for **three** concrete cases (Rule of Three).
- No flag arguments (`do_thing(x, dry_run=True, fast=False)` — split into two functions).
- No god objects. A `Service` that touches five repositories is a smell.
- No backwards-compat shims unless the user explicitly asks; just change the code.
