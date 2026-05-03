# Feature development workflow

> **Patterns first, code second.** Before implementing any new feature or non-trivial refactor, consult [`.claude/skills/design-patterns/`](../skills/design-patterns/). The goal is to pick the simplest pattern that fits — *or none*.

## Required steps for every new feature

### 1. Understand the request

- Restate the requirement in one sentence. If you can't, ask the user.
- Identify the resource(s) involved (existing or new).
- Identify the side effects (DB writes, external calls, background work).

### 2. Consult patterns *before* writing code

Trigger the `design-patterns` skill mentally — or invoke `/find-pattern` — and answer:

- **Foundational principle check.** Can a simple dict, function, or `@dataclass` solve this? If yes, **stop** — no pattern needed. (See [`design-patterns/references/foundations.md`](../skills/design-patterns/references/foundations.md).)
- **Pattern check.** If a pattern fits naturally, name it. Common matches:
  - "Multiple algorithm variants behind a switch" → **Strategy** (or pass a callable).
  - "Cross-cutting behavior (cache, retry, audit)" → **Decorator** (function decorator first; object decorator if wrapping multiple methods).
  - "External service has the wrong shape" → **Adapter** in `app/integrations/`.
  - "Need to notify multiple consumers" → **Observer** (or `blinker`).
  - "Stateful workflow with branching transitions" → **State**.
  - "Undo / redo / replay" → **Command** + **Memento**.
  - "Complex query / request builder" → **Builder** (or just `@dataclass`).
- **Pythonic alternative.** If the GoF pattern fits, also check [`python-idioms.md`](../skills/design-patterns/references/python-idioms.md) — Python often has a one-liner.

### 3. Plan the layered implementation

Work top-down through the architecture (see [`architecture.md`](architecture.md)):

1. Sketch the route signature: path, method, request schema, response schema, auth requirements.
2. Sketch the service signature: what it takes, what it returns, what exceptions it raises.
3. Sketch the repository signature: what queries are needed.
4. Sketch the model: what columns are new, what indexes / relationships.

If the sketch breaks the layering rules, the design is wrong — fix it before coding.

### 4. TDD: write the test first

- Start with `tests/test_<resource>.py` — see [`testing.md`](testing.md).
- Cover: happy path, 404, validation error (422), authorization (401/403) where applicable.
- Run the test and confirm it **fails** for the right reason.

### 5. Implement bottom-up

Order: model → schema → repository → service → controller → route. Each layer should be < 50 lines per method. Run the test after each layer to keep the diagnostic surface small.

### 6. Wire and migrate

- Register the router in `app/routes/__init__.py`.
- Import the model in `app/db/database.py` (`import app.models.<r>  # noqa: F401`).
- Run `alembic revision --autogenerate -m "..."` and inspect the migration.
- Run `alembic upgrade head` against a clean DB.

### 7. Verify

```bash
bash .claude/skills/fastapi/scripts/validate.sh
ruff check .
pytest -q
```

All three must pass before the feature is "done".

### 8. Document the decision

If you applied a non-obvious pattern, add one or two lines in the commit message explaining *why this pattern, not the simpler alternative*. Example:

```
feat(notification): add NotificationDispatcher with Strategy

Picked Strategy over a callable because three notification channels
(email, sms, push) each carry their own connection state. Pure
callables would force every consumer to manage that state.
```

## Refactor / decoupling workflow

When the user asks to "refactor" or "decouple":

1. **Read the current code first.** Do not assume.
2. **Name the smell** in one sentence (tight coupling, fat handler, layering violation, premature abstraction, …).
3. **Run the principle table** in [`design-patterns/SKILL.md`](../skills/design-patterns/SKILL.md) — KISS, SRP, composition, rule of three, separation of concerns, DI.
4. **Pick the *minimum* change** that fixes the named smell. Don't bundle unrelated cleanups.
5. **Tests must still pass** after each step. If you don't have tests, write one for the current behavior *first*, then refactor.

## What NOT to do

- Do not invent a pattern for hypothetical future flexibility (YAGNI).
- Do not add a Strategy/Factory/etc. wrapper around a single concrete case.
- Do not refactor and add a feature in the same PR.
- Do not change the architecture (layering) unless the user explicitly authorizes it — that's a project-wide decision.
- Do not introduce new exception classes. Use `app/exception/`.
