# Behavioral Patterns (Python)

Patterns concerned with algorithms and the assignment of responsibilities between objects.

---

## Observer

**Problem:** Multiple objects must be notified about state changes in another object without tight coupling.

**When to Use:**
- Changes in one object require changing others, and the set is dynamic.
- GUI / domain events need fan-out (e.g., "post saved" → email, search index, audit log).
- Subscribers come and go at runtime.

**Structure:** `Publisher` keeps a subscriber list and notifies on state changes; `Subscriber` has an `update` method.

**Python Example (event manager with typed events):**

```python
from __future__ import annotations
from collections import defaultdict
from typing import Callable, Any


Subscriber = Callable[[Any], None]


class EventManager:
    def __init__(self) -> None:
        self._subs: dict[str, list[Subscriber]] = defaultdict(list)

    def subscribe(self, event: str, fn: Subscriber) -> None:
        self._subs[event].append(fn)

    def unsubscribe(self, event: str, fn: Subscriber) -> None:
        if fn in self._subs.get(event, []):
            self._subs[event].remove(fn)

    def notify(self, event: str, data: Any) -> None:
        for fn in list(self._subs.get(event, [])):
            fn(data)


class Editor:
    def __init__(self) -> None:
        self.events = EventManager()
        self._file: str | None = None

    def open_file(self, path: str) -> None:
        self._file = path
        self.events.notify("open", path)

    def save_file(self) -> None:
        if self._file is not None:
            self.events.notify("save", self._file)


def email_listener(path: str) -> None:
    print(f"Email: file {path} was saved")


def log_listener(path: str) -> None:
    print(f"Log: operation on {path}")


editor = Editor()
editor.events.subscribe("save", email_listener)
editor.events.subscribe("save", log_listener)
editor.open_file("test.txt")
editor.save_file()
```

**Pythonic alternative — `blinker`:** the `blinker` library gives you signals + weak references (no memory leaks) in three lines. For sync in-process pub/sub, prefer it over hand-rolled observer code.

**Async note:** for `asyncio`, expose the event manager as `async def notify` and call subscribers with `await`. Use `asyncio.create_task` for fire-and-forget; gather for ordered completion.

**Pros:** OCP for new subscribers; runtime relationships.
**Cons:** notification order is implicit; **memory leaks** if subscribers aren't unsubscribed (consider `weakref`); silent failures if a subscriber raises.

**Related:** Mediator (eliminates direct connections), Command/Chain of Responsibility (different sender-receiver shapes).

---

## Strategy

**Problem:** Multiple algorithm variants in one class create bloat and risky changes.

**When to Use:**
- Different variants of an algorithm must be swapped at runtime.
- A class has massive `if/elif` chains selecting between algorithms.
- You want to isolate business logic from implementation.

**Pythonic alternative — pass a callable:**

```python
from typing import Callable

PaymentFn = Callable[[float], None]


def credit_card(card: str) -> PaymentFn:
    def pay(amount: float) -> None:
        print(f"Paid ${amount} via credit card {card}")
    return pay


def paypal(email: str) -> PaymentFn:
    def pay(amount: float) -> None:
        print(f"Paid ${amount} via PayPal {email}")
    return pay


def checkout(amount: float, pay: PaymentFn) -> None:
    pay(amount)


checkout(500, credit_card("1234-5678-9012-3456"))
checkout(500, paypal("user@example.com"))
```

In Python, **a function *is* a strategy.** Reach for a class hierarchy only when the strategy has multiple methods or carries non-trivial state.

**Python Example (classical class-based strategy, when you need it):**

```python
from __future__ import annotations
from typing import Protocol


class PaymentStrategy(Protocol):
    def pay(self, amount: float) -> None: ...


class CreditCardPayment:
    def __init__(self, card: str) -> None:
        self.card = card

    def pay(self, amount: float) -> None:
        print(f"Paid ${amount} via credit card {self.card}")


class PayPalPayment:
    def __init__(self, email: str) -> None:
        self.email = email

    def pay(self, amount: float) -> None:
        print(f"Paid ${amount} via PayPal {self.email}")


class CryptoPayment:
    def __init__(self, wallet: str) -> None:
        self.wallet = wallet

    def pay(self, amount: float) -> None:
        print(f"Paid ${amount} via crypto wallet {self.wallet}")


class ShoppingCart:
    def __init__(self) -> None:
        self.items: list[str] = []
        self._strategy: PaymentStrategy | None = None

    def add_item(self, item: str) -> None:
        self.items.append(item)

    def set_payment_strategy(self, s: PaymentStrategy) -> None:
        self._strategy = s

    def checkout(self, amount: float) -> None:
        if self._strategy is None:
            raise RuntimeError("No payment strategy selected")
        self._strategy.pay(amount)


cart = ShoppingCart()
cart.add_item("Book")
cart.set_payment_strategy(CreditCardPayment("1234-5678-9012-3456"))
cart.checkout(500)
```

**Pros:** swap at runtime; OCP; composition over inheritance.
**Cons:** ceremony if you only have one strategy or the algorithm is one line.

**Related:** Command (operation as object), State (states aware of each other), Template Method (class-level vs object-level variation).

---

## Command

**Problem:** Tight coupling between *invokers* (buttons, hotkeys, queues) and *receivers* (business logic) blocks reuse and undo/redo.

**When to Use:**
- Parameterize objects with operations (queue, schedule, log, retry).
- Implement reversible operations (undo/redo).
- Persist or replay operations (event sourcing).

**Structure:** `Command` interface with `execute()` (and optionally `undo()`); `ConcreteCommand` stores the receiver and parameters; `Invoker` triggers commands; `Receiver` does the real work.

**Python Example (text editor with undo/redo):**

```python
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Protocol


class TextEditor:
    def __init__(self) -> None:
        self.text = ""

    def insert(self, s: str) -> None:
        self.text += s

    def delete(self, n: int) -> None:
        self.text = self.text[:-n]


class Command(Protocol):
    def execute(self) -> None: ...
    def undo(self) -> None: ...


@dataclass
class InsertText:
    editor: TextEditor
    text: str

    def execute(self) -> None:
        self.editor.insert(self.text)

    def undo(self) -> None:
        self.editor.delete(len(self.text))


@dataclass
class DeleteText:
    editor: TextEditor
    n: int
    _deleted: str = ""

    def execute(self) -> None:
        self._deleted = self.editor.text[-self.n:]
        self.editor.delete(self.n)

    def undo(self) -> None:
        self.editor.insert(self._deleted)


@dataclass
class CommandHistory:
    history: list[Command] = field(default_factory=list)
    cursor: int = -1

    def execute(self, cmd: Command) -> None:
        self.history = self.history[: self.cursor + 1]
        cmd.execute()
        self.history.append(cmd)
        self.cursor += 1

    def undo(self) -> None:
        if self.cursor >= 0:
            self.history[self.cursor].undo()
            self.cursor -= 1

    def redo(self) -> None:
        if self.cursor < len(self.history) - 1:
            self.cursor += 1
            self.history[self.cursor].execute()


editor = TextEditor()
history = CommandHistory()
history.execute(InsertText(editor, "Hello "))
history.execute(InsertText(editor, "World"))
print(editor.text)  # "Hello World"
history.undo()
print(editor.text)  # "Hello "
history.redo()
print(editor.text)  # "Hello World"
```

**Pros:** decouples invoker from performer; OCP; undo/redo; deferred execution; composable.
**Cons:** new layer between sender and receiver; storage cost for history.

**Related:** Memento (stores pre-execution state for undo), Strategy (operation as object but no history).

---

## State

**Problem:** Object behavior depends on state, leading to massive `if/elif` chains scattered through methods.

**When to Use:**
- Many states, frequent transitions, behavior diverges per state.
- Bulky conditionals on a `state` field.
- Similar states have duplicated code.

**Structure:** `Context` holds current `State`; each `ConcreteState` implements behavior for its state; states transition the context.

**Python Example (vending machine):**

```python
from __future__ import annotations
from typing import Protocol


class State(Protocol):
    def insert_coin(self) -> None: ...
    def eject_coin(self) -> None: ...
    def select_product(self) -> None: ...
    def dispense(self) -> None: ...


class VendingMachine:
    def __init__(self) -> None:
        self._state: State = NoCoinState(self)
        self._has_product = True

    def set_state(self, state: State) -> None:
        self._state = state

    def insert_coin(self) -> None: self._state.insert_coin()
    def eject_coin(self) -> None: self._state.eject_coin()
    def select_product(self) -> None: self._state.select_product()
    def dispense(self) -> None: self._state.dispense()

    @property
    def has_product(self) -> bool: return self._has_product

    def release_product(self) -> None:
        if self._has_product:
            print("Product dispensed")
            self._has_product = False


class NoCoinState:
    def __init__(self, m: VendingMachine) -> None: self.m = m
    def insert_coin(self) -> None:
        print("Coin inserted"); self.m.set_state(HasCoinState(self.m))
    def eject_coin(self) -> None: print("No coin to eject")
    def select_product(self) -> None: print("Insert coin first")
    def dispense(self) -> None: print("Insert coin first")


class HasCoinState:
    def __init__(self, m: VendingMachine) -> None: self.m = m
    def insert_coin(self) -> None: print("Coin already inserted")
    def eject_coin(self) -> None:
        print("Coin ejected"); self.m.set_state(NoCoinState(self.m))
    def select_product(self) -> None:
        print("Product selected"); self.m.set_state(DispensingState(self.m))
    def dispense(self) -> None: print("Select product first")


class DispensingState:
    def __init__(self, m: VendingMachine) -> None: self.m = m
    def insert_coin(self) -> None: print("Please wait")
    def eject_coin(self) -> None: print("Cannot eject — dispensing")
    def select_product(self) -> None: print("Already dispensing")
    def dispense(self) -> None:
        self.m.release_product()
        next_ = NoCoinState(self.m) if self.m.has_product else SoldOutState(self.m)
        self.m.set_state(next_)


class SoldOutState:
    def __init__(self, m: VendingMachine) -> None: self.m = m
    def insert_coin(self) -> None: print("Sold out")
    def eject_coin(self) -> None: print("No coin to eject")
    def select_product(self) -> None: print("Sold out")
    def dispense(self) -> None: print("Sold out")


m = VendingMachine()
m.insert_coin()
m.select_product()
m.dispense()
```

**Pros:** SRP per state; OCP for new states; eliminates bulky conditionals.
**Cons:** overkill for ≤ 3 states or 1-2 transitions — a `match` statement on an `Enum` is often clearer.

**Pythonic alternative for simple state machines:**

```python
from enum import Enum, auto

class Conn(Enum):
    DISCONNECTED = auto()
    CONNECTING = auto()
    CONNECTED = auto()

def step(state: Conn) -> Conn:
    match state:
        case Conn.DISCONNECTED: return Conn.CONNECTING
        case Conn.CONNECTING:   return Conn.CONNECTED
        case Conn.CONNECTED:    return Conn.CONNECTED
```

**Related:** Strategy (states aren't usually aware of each other; here they are), Bridge (structural cousin).

---

## Template Method

**Problem:** Multiple classes implement nearly the same algorithm with small variations, causing duplicate skeleton code.

**When to Use:**
- Several classes share an algorithm skeleton with minor differences.
- You want clients to override *steps*, not the whole flow.

**Structure:** `AbstractClass` defines the template (`run`) and abstract steps; `ConcreteClass` implements steps.

**Python Example (data miner):**

```python
from __future__ import annotations
from abc import ABC, abstractmethod
from typing import Any


class DataMiner(ABC):
    def mine(self, path: str) -> None:
        f = self._open(path)
        raw = self._extract(f)
        data = self._parse(raw)
        analysis = self._analyze(data)
        self._send_report(analysis)
        self._close(f)

    def _open(self, path: str) -> str:
        print(f"Opening file: {path}")
        return path

    def _close(self, f: str) -> None:
        print(f"Closing file: {f}")

    @abstractmethod
    def _extract(self, f: str) -> str: ...

    @abstractmethod
    def _parse(self, raw: str) -> Any: ...

    # Hook with default implementation — subclasses may override.
    def _analyze(self, data: Any) -> str:
        return "Basic analysis"

    def _send_report(self, analysis: str) -> None:
        print(f"Report: {analysis}")


class PDFDataMiner(DataMiner):
    def _extract(self, f: str) -> str:
        print("Extracting PDF"); return "PDF raw data"

    def _parse(self, raw: str) -> dict:
        return {"type": "PDF", "content": raw}


class CSVDataMiner(DataMiner):
    def _extract(self, f: str) -> str:
        print("Extracting CSV"); return "row1\nrow2\nrow3"

    def _parse(self, raw: str) -> dict:
        return {"type": "CSV", "rows": raw.split("\n")}

    def _analyze(self, data: dict) -> str:
        return f"CSV analysis: {len(data['rows'])} rows"


PDFDataMiner().mine("data.pdf")
CSVDataMiner().mine("data.csv")
```

**Pros:** clients override only specific steps; pulls duplicate skeleton up.
**Cons:** clients limited by the skeleton; can violate Liskov if subclasses change semantics; *inheritance-based* — favor Strategy when behavior is independent.

**Related:** Factory Method (a Template Method specialized for object creation), Strategy (composition-based, swappable at runtime).

**Note:** Template Method works at *class level* (static, decided by subclass choice); Strategy at *object level* (dynamic, can swap at runtime).

---

## Memento

**Problem:** Need to save and restore an object's state without breaking encapsulation.

**When to Use:**
- Undo/redo, snapshots, transaction rollback.
- Direct field access would expose internal details.

**Structure:** `Originator` creates and restores from `Memento`; `Memento` is an immutable snapshot; `Caretaker` decides when to save/restore.

**Python Example (immutable snapshots via `frozen=True`):**

```python
from __future__ import annotations
from dataclasses import dataclass


@dataclass(frozen=True)
class EditorMemento:
    content: str
    cursor: int


class TextEditor:
    def __init__(self) -> None:
        self._content = ""
        self._cursor = 0

    @property
    def content(self) -> str:
        return self._content

    def type_(self, text: str) -> None:
        self._content = self._content[: self._cursor] + text + self._content[self._cursor :]
        self._cursor += len(text)

    def set_cursor(self, pos: int) -> None:
        self._cursor = max(0, min(pos, len(self._content)))

    def save(self) -> EditorMemento:
        return EditorMemento(self._content, self._cursor)

    def restore(self, m: EditorMemento) -> None:
        self._content = m.content
        self._cursor = m.cursor


class History:
    def __init__(self) -> None:
        self._mementos: list[EditorMemento] = []
        self._idx = -1

    def push(self, m: EditorMemento) -> None:
        self._mementos = self._mementos[: self._idx + 1]
        self._mementos.append(m)
        self._idx += 1

    def undo(self) -> EditorMemento | None:
        if self._idx > 0:
            self._idx -= 1
            return self._mementos[self._idx]
        return None

    def redo(self) -> EditorMemento | None:
        if self._idx < len(self._mementos) - 1:
            self._idx += 1
            return self._mementos[self._idx]
        return None


editor = TextEditor()
history = History()
history.push(editor.save())
editor.type_("Hello "); history.push(editor.save())
editor.type_("World");  history.push(editor.save())
print(editor.content)               # "Hello World"
if (s := history.undo()): editor.restore(s)
print(editor.content)               # "Hello "
if (s := history.redo()): editor.restore(s)
print(editor.content)               # "Hello World"
```

**Pros:** snapshots without breaking encapsulation; clean separation between state and history management.
**Cons:** RAM cost grows with history; caretakers must manage lifecycle; large objects need delta or compression.

**Pythonic notes:**
- `dataclass(frozen=True)` gives you a hashable, immutable snapshot for free.
- For complex objects, `copy.deepcopy` plus a frozen wrapper is often enough.
- Don't `pickle` mementos to disk unless you control the schema — pickling is a footgun.

**Related:** Command + Memento for undo (Command runs the operation, Memento stores pre-state); Prototype for cheaper full clones; Iterator can use Memento to capture iteration state.
