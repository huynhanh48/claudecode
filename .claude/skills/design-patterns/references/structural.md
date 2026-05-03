# Structural Patterns (Python)

Patterns that explain how to assemble objects and classes into larger structures while keeping them flexible and efficient.

---

## Adapter

**Problem:** Incompatible interfaces prevent objects from working together (e.g., a JSON-based vendor SDK in an XML-based application).

**When to Use:**
- You must use an existing class with an incompatible interface.
- You're integrating a third-party library that doesn't match your domain interface.
- You want to reuse subclasses lacking common functionality.

**Structure:** `Target` is the interface the client expects; `Adapter` implements `Target` and delegates to `Adaptee`; `Adaptee` is the existing incompatible class.

**Python Example (composition-based adapter, using `Protocol`):**

```python
from __future__ import annotations
from typing import Protocol


class MediaPlayer(Protocol):
    def play(self, filename: str) -> None: ...


class AudioPlayer:
    def play(self, filename: str) -> None:
        if filename.endswith(".mp3"):
            print(f"Playing MP3 file: {filename}")
        else:
            print("Format not supported")


class AdvancedMediaPlayer:
    def play_vlc(self, filename: str) -> None:
        print(f"Playing VLC file: {filename}")

    def play_mp4(self, filename: str) -> None:
        print(f"Playing MP4 file: {filename}")


class MediaAdapter:
    def __init__(self) -> None:
        self._advanced = AdvancedMediaPlayer()

    def play(self, filename: str) -> None:
        if filename.endswith(".vlc"):
            self._advanced.play_vlc(filename)
        elif filename.endswith(".mp4"):
            self._advanced.play_mp4(filename)
        else:
            raise ValueError(f"Unsupported format: {filename}")


class EnhancedAudioPlayer:
    def __init__(self) -> None:
        self._adapter = MediaAdapter()

    def play(self, filename: str) -> None:
        if filename.endswith(".mp3"):
            print(f"Playing MP3 file: {filename}")
        elif filename.endswith((".vlc", ".mp4")):
            self._adapter.play(filename)
        else:
            print(f"Invalid format: {filename}")


player = EnhancedAudioPlayer()
player.play("song.mp3")
player.play("video.mp4")
player.play("movie.vlc")
```

**Pythonic note:** `Protocol` makes the `MediaPlayer` interface implicit — adapters and concrete players don't need to inherit. Composition is preferred over multiple inheritance.

**Pros:** SRP separates conversion from business logic; OCP for new adapters.
**Cons:** adds indirection; sometimes simpler to fork or modify the adaptee.

**Related:**
- **Bridge** — designed up-front, not retrofitted.
- **Decorator** — same shape, but adds behavior; doesn't change the interface.
- **Facade** — a simpler entry point to a *subsystem*, not a single object.

---

## Decorator

**Problem:** Need to add behaviors to objects dynamically without an explosion of subclasses.

**When to Use:**
- Add cross-cutting behavior (logging, caching, retries, encryption) to existing objects.
- Inheritance is impractical (e.g., final/sealed classes, or behavior must be combined orthogonally).
- Multiple optional behaviors must be combined freely.

**Structure:** `Component` is the interface; `ConcreteComponent` is the basic implementation; `Decorator` is a base wrapping a component; `ConcreteDecorator` adds behavior.

**Python Example (object-level decorator for a data source):**

```python
from __future__ import annotations
from base64 import b64decode, b64encode
from typing import Protocol


class DataSource(Protocol):
    def write_data(self, data: str) -> None: ...
    def read_data(self) -> str: ...


class FileDataSource:
    def __init__(self, filename: str) -> None:
        self.filename = filename
        self._data = ""

    def write_data(self, data: str) -> None:
        print(f"Writing to file: {self.filename}")
        self._data = data

    def read_data(self) -> str:
        print(f"Reading from file: {self.filename}")
        return self._data


class DataSourceDecorator:
    def __init__(self, wrappee: DataSource) -> None:
        self._wrappee = wrappee

    def write_data(self, data: str) -> None:
        self._wrappee.write_data(data)

    def read_data(self) -> str:
        return self._wrappee.read_data()


class EncryptionDecorator(DataSourceDecorator):
    def write_data(self, data: str) -> None:
        super().write_data(b64encode(data.encode()).decode())

    def read_data(self) -> str:
        return b64decode(super().read_data().encode()).decode()


class CompressionDecorator(DataSourceDecorator):
    def write_data(self, data: str) -> None:
        super().write_data(f"compressed({data})")

    def read_data(self) -> str:
        return super().read_data().removeprefix("compressed(").removesuffix(")")


source: DataSource = FileDataSource("data.txt")
source = EncryptionDecorator(source)
source = CompressionDecorator(source)
source.write_data("Hello World")
print(source.read_data())
```

**Pythonic note — function decorators:** Python's `@decorator` syntax is the *language-level* version of this pattern for callables:

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

For function-level cross-cutting behavior, *always* use `@decorator` syntax. Reserve the GoF object decorator for cases where the wrapped *object* has multiple methods that all need wrapping.

**Pros:** add/remove behavior at runtime; combine behaviors flexibly; SRP.
**Cons:** order matters; debugging deep stacks is painful; harder to remove a specific decorator.

**Related:** Adapter (changes interface), Proxy (controls access), Composite (treats one + many uniformly).

---

## Facade

**Problem:** Working with a complex subsystem requires extensive initialization, dependency wiring, and correct call ordering.

**When to Use:**
- A library has 50 classes but you only need a handful of high-level operations.
- You want a stable, simple entry point hiding subsystem volatility.
- Layered architecture: each layer exposes a facade to the layer above.

**Structure:** `Facade` provides a simple interface; `Subsystem` classes do the work and don't know about the facade.

**Python Example:**

```python
from __future__ import annotations


class CPU:
    def freeze(self) -> None: print("CPU: Freezing")
    def jump(self, position: int) -> None: print(f"CPU: Jumping to {position}")
    def execute(self) -> None: print("CPU: Executing")


class Memory:
    def load(self, position: int, data: str) -> None:
        print(f'Memory: Loading "{data}" at {position}')


class HardDrive:
    def read(self, sector: int, size: int) -> str:
        print(f"HardDrive: Reading {size} bytes from sector {sector}")
        return "boot data"


class ComputerFacade:
    def __init__(self) -> None:
        self._cpu = CPU()
        self._memory = Memory()
        self._hd = HardDrive()

    def start(self) -> None:
        print("Starting computer...")
        self._cpu.freeze()
        boot_data = self._hd.read(0, 1024)
        self._memory.load(0, boot_data)
        self._cpu.jump(0)
        self._cpu.execute()
        print("Computer started!")


ComputerFacade().start()
```

**Pythonic note — a module is often the facade.** A `package/__init__.py` that re-exports a small public API is the simplest form of this pattern — clients write `from mypackage import boot_computer` without seeing the subsystem.

**Pros:** isolates clients from subsystem complexity; clean simple interface.
**Cons:** can become a god object coupled to *all* subsystem classes; tempting to grow indefinitely.

**Related:**
- **Adapter** — wraps a single object; **Facade** wraps a subsystem.
- **Abstract Factory** — hides creation; **Facade** hides usage.
- **Mediator** — centralizes communication *between* subsystem objects.

**Note:** Facade defines a *new* interface; Adapter makes existing interfaces compatible.
