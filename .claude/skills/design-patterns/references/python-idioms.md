# Python Idioms vs Classical GoF Patterns

Python's first-class functions, decorators, dataclasses, generators, context managers, and `Protocol` make several GoF patterns simpler — or unnecessary. This file is a cheat-sheet of "when not to write a class hierarchy".

---

## Quick Map

| GoF Pattern | Pythonic alternative | When the alternative wins |
|-------------|----------------------|----------------------------|
| **Singleton** | Module-level instance + `@lru_cache` | Always (the GoF version is almost never right). |
| **Factory Method** | `dict[str, Callable]` registry | Pure type-by-name lookup with no extra workflow. |
| **Abstract Factory** | `Protocol` + concrete factories | Always — `Protocol` removes the inheritance ceremony. |
| **Builder** | `@dataclass` with defaults | Plain data with optional fields. |
| **Strategy** | Pass a callable | The "strategy" is a single function. |
| **Observer** | `blinker` / list of callables / `asyncio.Event` | In-process pub/sub without persistence. |
| **Command** | Closure or `functools.partial` | Single-step operation, no undo. |
| **Decorator** (object) | `@decorator` syntax | Wrapping a callable, not a long-lived object. |
| **Iterator** | Generator (`yield`) | Always — Python iterators are built-in. |
| **Template Method** | Higher-order function | Skeleton + step is a function + callback. |
| **State** | `match` on `Enum` | Few states, simple transitions. |
| **Memento** | `@dataclass(frozen=True)` | Immutable snapshot of plain data. |

---

## Singleton → Module + `@lru_cache`

```python
# instead of a Singleton class
from functools import lru_cache
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    db_url: str
    secret: str


@lru_cache
def get_settings() -> Settings:
    return Settings()


# any module imports get_settings(); the cache makes it a singleton
```

A *module* is already a singleton. Pair it with `@lru_cache` and you have laziness, thread safety, and a single instance — all without a metaclass or `__new__` trick.

---

## Factory Method → Dict registry

```python
# instead of an abstract Creator + ConcreteCreators
HANDLERS: dict[str, Callable[..., Handler]] = {
    "csv": CSVHandler,
    "json": JSONHandler,
    "xml": XMLHandler,
}

def make_handler(kind: str, **kw) -> Handler:
    if kind not in HANDLERS:
        raise ValueError(f"unknown handler: {kind}")
    return HANDLERS[kind](**kw)
```

Reach for the GoF version only when subclasses must also override workflow around the creation step.

---

## Builder → `@dataclass`

```python
# instead of a HouseBuilder
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

If you also want immutability: `@dataclass(frozen=True)`. If you need validation: use `pydantic.BaseModel`.

Use the classical Builder only if construction has *side effects* (DB writes, network calls).

---

## Strategy → Pass a callable

```python
# instead of a PaymentStrategy hierarchy
from typing import Callable

PaymentFn = Callable[[float], None]


def credit_card(card: str) -> PaymentFn:
    def pay(amount: float) -> None:
        print(f"Paid ${amount} with card {card}")
    return pay


def checkout(amount: float, pay: PaymentFn) -> None:
    pay(amount)


checkout(500, credit_card("1234"))
checkout(500, lambda amt: print(f"Bartered for ${amt}"))
```

Reach for the class-based Strategy when:
- the strategy has *multiple* methods,
- the strategy carries non-trivial state,
- you need polymorphic dispatch beyond `isinstance` checks.

---

## Observer → `blinker` or simple callables

```python
# instead of EventManager + Observer/Subscriber hierarchy
from blinker import signal

post_saved = signal("post-saved")


@post_saved.connect
def index_post(sender, post):
    search_index.update(post)


@post_saved.connect
def email_subscribers(sender, post):
    email_service.notify(post.author.email, post)


# publisher
post_saved.send(post_service, post=post)
```

`blinker` handles weak references (no memory leaks), connection management, and decouples senders from receivers. For sync in-process pub/sub it beats hand-rolled observer code.

For async, consider `asyncio.Queue` or `aioreactive`.

---

## Iterator → Generator

```python
# instead of an Iterator class with __iter__/__next__
def paginate(items: list, size: int):
    for i in range(0, len(items), size):
        yield items[i : i + size]


for page in paginate(users, 100):
    process(page)
```

Generators are coroutines that *are* iterators. They handle state, cleanup (`finally`), and laziness with a fraction of the code.

---

## Template Method → Higher-order function

```python
# instead of an abstract base class with abstract steps
from typing import Callable


def mine_data(
    path: str,
    extract: Callable[[str], str],
    parse: Callable[[str], dict],
    analyze: Callable[[dict], str] = lambda d: "basic",
) -> None:
    with open(path) as f:
        raw = extract(f.read())
    data = parse(raw)
    print(f"Report: {analyze(data)}")


def extract_csv(s: str) -> str: return s
def parse_csv(s: str) -> dict: return {"rows": s.split("\n")}
def analyze_csv(d: dict) -> str: return f"{len(d['rows'])} rows"


mine_data("data.csv", extract_csv, parse_csv, analyze_csv)
```

Pass the steps as functions. Use the abstract-base-class version only when the steps need *shared state* across calls (which is rare).

---

## State → `match` on `Enum`

```python
# instead of a state hierarchy
from enum import Enum, auto


class Conn(Enum):
    DISCONNECTED = auto()
    CONNECTING = auto()
    CONNECTED = auto()
    ERROR = auto()


def transition(state: Conn, event: str) -> Conn:
    match (state, event):
        case (Conn.DISCONNECTED, "connect"): return Conn.CONNECTING
        case (Conn.CONNECTING, "ack"):       return Conn.CONNECTED
        case (Conn.CONNECTED, "disconnect"): return Conn.DISCONNECTED
        case (_, "error"):                   return Conn.ERROR
        case _:                              return state
```

Use the class-based State pattern when each state carries non-trivial behavior or its own collaborators.

---

## Decorator → `@decorator` syntax

For functions, **always** use the syntax:

```python
from functools import wraps
from time import perf_counter


def log_calls(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        start = perf_counter()
        try:
            return fn(*args, **kwargs)
        finally:
            print(f"{fn.__name__} took {perf_counter() - start:.4f}s")
    return wrapper


@log_calls
def fetch_user(user_id: int) -> dict: ...
```

Use the GoF object Decorator only when wrapping a *long-lived object* with multiple methods that all need consistent wrapping (e.g., a `DataSource` with `read`/`write`/`close`).

---

## Memento → `@dataclass(frozen=True)`

```python
from dataclasses import dataclass


@dataclass(frozen=True)
class CartSnapshot:
    items: tuple[str, ...]
    discount: float
    customer_id: str


# Originator
class Cart:
    def __init__(self) -> None:
        self.items: list[str] = []
        self.discount = 0.0
        self.customer_id = ""

    def save(self) -> CartSnapshot:
        return CartSnapshot(tuple(self.items), self.discount, self.customer_id)

    def restore(self, m: CartSnapshot) -> None:
        self.items = list(m.items)
        self.discount = m.discount
        self.customer_id = m.customer_id
```

`frozen=True` gives you a hashable, immutable snapshot for free. `tuple(...)` ensures the list isn't mutated through the snapshot reference.

---

## Rule of thumb

> **Try Python first.** If the dataclass / function / decorator / dict-registry version is simpler, use that.
> Reach for the GoF class hierarchy only when the language idiom genuinely doesn't fit — and write down *why* in a comment.

Patterns are tools, not goals. Use them when they help, and skip them when Python already gives you the answer.
