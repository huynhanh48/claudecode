# Foundational Principles

These principles decide *whether* you need a pattern at all. Run through them before reaching for a GoF construct — they catch most bad design at the cheapest stage.

---

## 1. KISS — Keep It Simple

Choose the simplest solution that works. Complexity must be justified by a concrete current requirement.

```python
# Over-engineered: registry/factory for a 3-line problem
class FormatterFactory:
    _formatters: dict[str, type] = {}

    @classmethod
    def register(cls, name: str):
        def decorator(formatter_cls):
            cls._formatters[name] = formatter_cls
            return formatter_cls
        return decorator

    @classmethod
    def create(cls, name: str):
        return cls._formatters[name]()


@FormatterFactory.register("json")
class JsonFormatter: ...


# Simple: a dict
FORMATTERS = {"json": JsonFormatter, "csv": CsvFormatter, "xml": XmlFormatter}

def get_formatter(name: str):
    if name not in FORMATTERS:
        raise ValueError(f"Unknown format: {name}")
    return FORMATTERS[name]()
```

**Rule of thumb:** if you can't name a *current* benefit of the abstraction, delete it.

---

## 2. Single Responsibility Principle

Each class/function has one reason to change.

```python
# BAD — handler does HTTP parsing, validation, SQL, response formatting
class UserHandler:
    async def create_user(self, request):
        data = await request.json()
        if not data.get("email"):
            return Response({"error": "email required"}, status=400)
        user = await db.execute(
            "INSERT INTO users (email, name) VALUES ($1, $2) RETURNING *",
            data["email"], data["name"],
        )
        return Response({"id": user.id, "email": user.email}, status=201)


# GOOD — three concerns, three units
class UserService:
    def __init__(self, repo: UserRepository) -> None:
        self._repo = repo

    async def create_user(self, data: CreateUserInput) -> User:
        user = User(email=data.email, name=data.name)
        return await self._repo.save(user)


class UserHandler:
    def __init__(self, service: UserService) -> None:
        self._service = service

    async def create_user(self, request) -> Response:
        data = CreateUserInput(**await request.json())
        user = await self._service.create_user(data)
        return Response(user.to_dict(), status=201)
```

**Symptoms of an SRP violation:** the class name has "and" in it; the test file imports both an HTTP client and a SQL fixture; you change the file for two unrelated reasons in the same week.

---

## 3. Separation of Concerns / Layering

Organize code into layers with clear, one-way dependencies.

```
┌─────────────────────────────────────────────────────┐
│  API / Presentation (handlers, routes)              │
│  - Parse requests, format responses                 │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│  Service (business logic)                            │
│  - Domain rules, validation, orchestration           │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│  Repository (data access)                            │
│  - SQL, external APIs, cache                         │
└─────────────────────────────────────────────────────┘
```

Each layer depends only on the one below. **Imports must flow downward.**

```python
# Repository
class UserRepository:
    async def get_by_id(self, user_id: str) -> User | None:
        row = await self._db.fetchrow("SELECT * FROM users WHERE id = $1", user_id)
        return User(**row) if row else None


# Service
class UserService:
    def __init__(self, repo: UserRepository) -> None:
        self._repo = repo

    async def get_user(self, user_id: str) -> User:
        user = await self._repo.get_by_id(user_id)
        if user is None:
            raise UserNotFoundError(user_id)
        return user


# Handler
@app.get("/users/{user_id}")
async def get_user(user_id: str) -> UserResponse:
    user = await user_service.get_user(user_id)
    return UserResponse.from_user(user)
```

**Test for layering violations:** `grep` for upward imports (e.g., `from app.services` inside `app/repositories`). Any hit is a smell.

---

## 4. Composition Over Inheritance

Build behavior by combining objects rather than extending classes.

```python
# Inheritance — rigid, hard to test, single dimension of variation
class EmailNotificationService(NotificationService):
    def __init__(self) -> None:
        super().__init__()
        self._smtp = SmtpClient()  # hard to mock

    def notify(self, user: User, message: str) -> None:
        self._smtp.send(user.email, message)


# Composition — flexible, testable, multi-channel
from typing import Protocol


class EmailSender(Protocol):
    async def send(self, to: str, msg: str) -> None: ...


class SmsSender(Protocol):
    async def send(self, to: str, msg: str) -> None: ...


class NotificationService:
    def __init__(
        self,
        email_sender: EmailSender,
        sms_sender: SmsSender | None = None,
    ) -> None:
        self._email = email_sender
        self._sms = sms_sender

    async def notify(self, user: User, message: str, channels: set[str] | None = None) -> None:
        channels = channels or {"email"}
        if "email" in channels:
            await self._email.send(user.email, message)
        if "sms" in channels and self._sms and user.phone:
            await self._sms.send(user.phone, message)
```

**Use inheritance only when:**
- The relationship is genuinely *is-a* (not *has-a* or *uses*),
- The base class is stable and small,
- Subclasses use *all* the inherited members,
- You're implementing a protocol/abstract base where the inheritance is one level deep.

---

## 5. Rule of Three

Wait until you've seen the same shape *three* times before abstracting.

```python
# Two functions that look similar — DON'T abstract yet
def process_orders(orders: list[Order]) -> list[Result]:
    out = []
    for o in orders:
        v = validate_order(o)
        out.append(process_validated_order(v))
    return out


def process_returns(returns: list[Return]) -> list[Result]:
    out = []
    for r in returns:
        v = validate_return(r)
        out.append(process_validated_return(v))
    return out

# These look the same shape — but the validation, processing,
# and error handling differ in subtle ways. Premature abstraction
# would force them to drift apart later via flags / kwargs / mixins.
# Duplication is cheaper than the wrong abstraction.
```

When the third instance arrives, *then* reconsider. Often you'll find the second one isn't actually the same — you've just been pattern-matching on shape, not semantics.

> **Wrong abstraction is more expensive than duplication.** It's much harder to *break apart* a bad abstraction than to *consolidate* honest duplication.

---

## 6. Function Size

Functions should be focused. Extract when:

- > 30–50 lines (varies by complexity),
- > 1 distinct purpose,
- > 3 levels of nesting,
- the name needs an "and" to describe it.

```python
# Too long — multiple concerns
def process_order(order: Order) -> Result:
    # 50 lines of validation
    # 30 lines of inventory check
    # 40 lines of payment processing
    # 20 lines of notification
    ...


# Composed of focused functions
def process_order(order: Order) -> Result:
    validate_order(order)
    reserve_inventory(order)
    payment = charge_payment(order)
    send_confirmation(order, payment)
    return Result(success=True, order_id=order.id)
```

---

## 7. Dependency Injection

Pass dependencies in, don't construct them inside.

```python
from typing import Protocol


class Logger(Protocol):
    def info(self, msg: str, **kw: object) -> None: ...
    def error(self, msg: str, **kw: object) -> None: ...


class Cache(Protocol):
    async def get(self, key: str) -> str | None: ...
    async def set(self, key: str, value: str, ttl: int) -> None: ...


class UserService:
    def __init__(self, repo: UserRepository, cache: Cache, logger: Logger) -> None:
        self._repo = repo
        self._cache = cache
        self._logger = logger

    async def get_user(self, user_id: str) -> User | None:
        cached = await self._cache.get(f"user:{user_id}")
        if cached is not None:
            self._logger.info("cache hit", user_id=user_id)
            return User.model_validate_json(cached)
        user = await self._repo.get_by_id(user_id)
        if user is not None:
            await self._cache.set(f"user:{user_id}", user.model_dump_json(), ttl=300)
        return user


# Production wiring
service = UserService(
    repo=PostgresUserRepository(db),
    cache=RedisCache(redis),
    logger=StructlogLogger(),
)


# Tests get fakes — no monkey-patching
service = UserService(repo=InMemoryUserRepository(), cache=FakeCache(), logger=NullLogger())
```

**FastAPI tip:** the `Depends(...)` system *is* DI — let it inject your services and repositories rather than constructing them in route handlers.

---

## 8. Common Anti-Patterns

### Don't expose internal types past the boundary

```python
# BAD — leaking the ORM model into the API
@app.get("/users/{id}")
def get_user(id: str) -> UserModel:           # SQLAlchemy model
    return db.query(UserModel).get(id)


# GOOD — Pydantic schema at the boundary
@app.get("/users/{id}")
def get_user(id: str) -> UserResponse:
    user = db.query(UserModel).get(id)
    return UserResponse.model_validate(user)
```

### Don't mix I/O with business logic

```python
# BAD — SQL inside a "calculate" function
def calculate_discount(user_id: str) -> float:
    user = db.query("SELECT * FROM users WHERE id = ?", user_id)
    orders = db.query("SELECT * FROM orders WHERE user_id = ?", user_id)
    if len(orders) > 10:
        return 0.15
    return 0.0


# GOOD — pure business logic, easy to test
def calculate_discount(user: User, order_history: list[Order]) -> float:
    if len(order_history) > 10:
        return 0.15
    return 0.0
```

### Don't write a class for what could be a function

If your "class" has only `__init__` and one method, you have a function with extra steps.

```python
# BAD
class TaxCalculator:
    def __init__(self, rate: float) -> None:
        self.rate = rate

    def calculate(self, amount: float) -> float:
        return amount * self.rate


# GOOD
def calculate_tax(amount: float, rate: float) -> float:
    return amount * rate

# Or, if you need to bind the rate:
from functools import partial
calculate_at_20pct = partial(calculate_tax, rate=0.20)
```

---

## Best-Practices Summary

1. **Keep it simple** — simpler beats clever.
2. **Single responsibility** — one reason to change per unit.
3. **Separate concerns** — layers with one-way dependencies.
4. **Compose, don't inherit** — combine, don't extend.
5. **Rule of three** — duplicate twice; abstract on the third.
6. **Small functions** — 30–50 lines, one purpose.
7. **Inject dependencies** — constructor parameters, not internal `import`.
8. **Delete before abstracting** — remove dead code, then reconsider patterns.
9. **Test each layer in isolation** — fakes at the boundary.
10. **Explicit over clever** — readable code beats elegant code.
