# Creational Patterns (Python)

Patterns that handle object creation. Each entry shows the GoF version in idiomatic Python, then a **Pythonic alternative** when the language has a simpler answer.

---

## Factory Method

**Problem:** Creating objects without specifying exact classes causes tight coupling between creator and concrete types.

**When to Use:**
- You don't know exact types beforehand.
- You want extension points for library users.
- You need to reuse existing objects instead of rebuilding them.

**Structure:** `Creator` declares `create_product()`; `ConcreteCreator` overrides it; `Product` is the interface; `ConcreteProduct` implements it.

**Python Example (classical, with `ABC`):**

```python
from __future__ import annotations
from abc import ABC, abstractmethod


class Transport(ABC):
    @abstractmethod
    def deliver(self) -> None: ...


class Truck(Transport):
    def deliver(self) -> None:
        print("Deliver by land in a box")


class Ship(Transport):
    def deliver(self) -> None:
        print("Deliver by sea in a container")


class Logistics(ABC):
    @abstractmethod
    def create_transport(self) -> Transport: ...

    def plan_delivery(self) -> None:
        transport = self.create_transport()
        transport.deliver()


class RoadLogistics(Logistics):
    def create_transport(self) -> Transport:
        return Truck()


class SeaLogistics(Logistics):
    def create_transport(self) -> Transport:
        return Ship()


RoadLogistics().plan_delivery()
```

**Pythonic alternative — registry dict:**

```python
TRANSPORTS: dict[str, type[Transport]] = {"road": Truck, "sea": Ship}

def deliver_by(kind: str) -> None:
    TRANSPORTS[kind]().deliver()
```

For most "select-by-name" cases the dict is clearer and shorter. Reach for the GoF Factory Method only when subclasses also need to *override surrounding workflow* (`plan_delivery`), not just object creation.

**Pros:** decouples creator from products; SRP; OCP for new variants.
**Cons:** subclass explosion; ceremony for what's often a single line in Python.

**Related:** evolves to Abstract Factory, Prototype, or Builder.

---

## Abstract Factory

**Problem:** Need to create *families* of related objects guaranteed to work together, without depending on concrete classes.

**When to Use:**
- Code must work with several families of related products (e.g., `Light`/`Dark` UI themes, `Postgres`/`MySQL` drivers).
- Variants are not predictable at design time.
- A class accumulates several factory methods that obscure its main job.

**Python Example (using `typing.Protocol` for structural typing):**

```python
from __future__ import annotations
from typing import Protocol


class Button(Protocol):
    def render(self) -> None: ...


class Checkbox(Protocol):
    def render(self) -> None: ...


class WindowsButton:
    def render(self) -> None: print("Render Windows button")


class WindowsCheckbox:
    def render(self) -> None: print("Render Windows checkbox")


class MacButton:
    def render(self) -> None: print("Render Mac button")


class MacCheckbox:
    def render(self) -> None: print("Render Mac checkbox")


class GUIFactory(Protocol):
    def create_button(self) -> Button: ...
    def create_checkbox(self) -> Checkbox: ...


class WindowsFactory:
    def create_button(self) -> Button: return WindowsButton()
    def create_checkbox(self) -> Checkbox: return WindowsCheckbox()


class MacFactory:
    def create_button(self) -> Button: return MacButton()
    def create_checkbox(self) -> Checkbox: return MacCheckbox()


def render_ui(factory: GUIFactory) -> None:
    factory.create_button().render()
    factory.create_checkbox().render()


render_ui(WindowsFactory() if PLATFORM == "Windows" else MacFactory())
```

**Pythonic note:** `Protocol` lets the concrete classes stay free of inheritance — they only need to *quack* like the interface. This is usually preferable to `ABC` in Python.

**Pros:** guarantees product compatibility; OCP for new variants.
**Cons:** lots of new types; the family grows whenever you add a product kind.

**Related:** often grows out of Factory Method; Builder/Prototype can implement individual products.

---

## Builder

**Problem:** Constructing a complex object with many optional parameters leads to telescoping constructors or subclass explosion.

**When to Use:**
- Constructor would have > 5–6 parameters, many optional.
- You need different *representations* of the same product (e.g., a `User` for an HTTP response vs. for an event payload).
- Constructing trees / composite objects step-by-step.

**Pythonic alternative — `@dataclass` with defaults *almost always wins* for plain data:**

```python
from dataclasses import dataclass, field

@dataclass
class House:
    walls: str = "brick"
    doors: int = 1
    windows: int = 4
    roof: str = "tile"
    garage: bool = False
    extras: list[str] = field(default_factory=list)


h = House(walls="wood", windows=8, garage=True)
```

**Use the classical Builder** only when:
- Construction has *steps with side effects* (DB calls, HTTP requests),
- Or the same builder produces multiple representations,
- Or you want a fluent chained API for a domain-specific use case.

**Python Example (fluent builder for a SQL-like query):**

```python
from __future__ import annotations
from dataclasses import dataclass, field


@dataclass
class Query:
    table: str
    columns: list[str] = field(default_factory=list)
    filters: list[str] = field(default_factory=list)
    limit_: int | None = None


class QueryBuilder:
    def __init__(self, table: str) -> None:
        self._q = Query(table=table)

    def select(self, *cols: str) -> "QueryBuilder":
        self._q.columns.extend(cols)
        return self

    def where(self, expr: str) -> "QueryBuilder":
        self._q.filters.append(expr)
        return self

    def limit(self, n: int) -> "QueryBuilder":
        self._q.limit_ = n
        return self

    def build(self) -> Query:
        if not self._q.columns:
            self._q.columns = ["*"]
        return self._q


q = QueryBuilder("users").select("id", "email").where("deleted = false").limit(10).build()
```

**Pros:** step-by-step construction; reuses construction code across representations; SRP.
**Cons:** more code than a `@dataclass`; only worth it when steps are non-trivial.

**Related:** Composite (when building trees), Abstract Factory.

---

## Singleton

**Problem:** Need exactly one instance with a global access point.

**When to Use:**
- A single shared resource (DB engine, config) needs controlled access.
- ⚠️ **Use sparingly — usually wrong.** Singletons hide dependencies and break tests.

**Pythonic alternative — module-level instance (the right answer 95% of the time):**

```python
# config.py
from functools import lru_cache
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    db_url: str
    secret: str


@lru_cache
def get_settings() -> Settings:
    return Settings()
```

A module is already a singleton in Python. Combine it with `@lru_cache` (or DI) and you have a thread-safe, testable single instance — without the GoF ceremony.

**Classical Singleton (only when you really need it):**

```python
from __future__ import annotations
from threading import Lock


class Database:
    _instance: "Database | None" = None
    _lock: Lock = Lock()

    def __new__(cls) -> "Database":
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._connect()
        return cls._instance

    def _connect(self) -> None:
        self.connection = "Connected"

    def query(self, sql: str) -> None:
        print(f"Executing: {sql}")


db1 = Database()
db2 = Database()
assert db1 is db2
```

**Pros:** guarantees single instance; lazy init; global access.
**Cons:** violates SRP; hides dependencies; pain to mock; thread-safety must be explicit.

**Better alternative:** dependency injection. Accept the resource as a constructor parameter — easy to test, easy to swap.

**Related:** Facade often *should not* be a Singleton even though tutorials make it one.

**⚠️ Warning:** if you find yourself writing `Singleton` patterns, ask:
1. Could this be a module-level instance + `@lru_cache`?
2. Could the consumers receive it via DI?
3. Is the "globalness" actually a hidden coupling problem?
