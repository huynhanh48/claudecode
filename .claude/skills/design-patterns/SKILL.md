---
name: design-patterns
version: 2.0.0
description: "Guidance on when and how to apply design patterns in Python. Use when: (1) asking which pattern to use, (2) refactoring code, (3) discussing code smells, (4) need to decouple components, (5) building extensible systems, (6) deciding between abstraction and duplication."
license: MIT
metadata:
  domains: [design-patterns, architecture, refactoring, oop, python-idioms]
  source: https://refactoring.guru/design-patterns/catalog
  language: python
  python_version: ">=3.10"
---

# Design Patterns (Python)

Expert guidance on applying Gang of Four design patterns **and** the foundational principles (KISS, SRP, composition, separation of concerns) that decide *whether* a pattern is even appropriate. Every example is idiomatic Python; where a pattern has a more Pythonic alternative (functions, decorators, dataclasses, `typing.Protocol`), it is shown alongside the classical version.

## Triggers

- `which pattern should I use` — pattern selection guidance
- `refactor this code` — identify and apply patterns to improve existing code
- `how to decouple` — find patterns to reduce coupling
- `design pattern for ...` — specific pattern recommendations
- `code smells` — identify problems that patterns can solve
- `should I abstract this?` — apply the *Rule of Three* before reaching for a pattern
- `composition vs inheritance` — choose the right structural approach

## Quick Reference

| Input | Output | Duration |
|-------|--------|----------|
| Code smell or design issue | Principle check + pattern recommendation + Python example | 2–5 min |
| Existing code | Refactoring plan grounded in SOLID + concrete pattern | 5–10 min |
| Pattern name | Idiomatic Python implementation + Pythonic alternative | 1–2 min |

## Agent Behavior Contract

1. **Principles before patterns.** Always check whether a *foundational principle* (KISS, SRP, composition, rule of three) already solves the problem. Many "pattern" requests are really duplication or coupling problems that need refactoring, not a GoF construct.
2. **Analyze first.** Read the existing code before recommending anything.
3. **Identify the problem.** Name the code smell or design issue explicitly.
4. **Don't over-engineer.** Apply patterns only when they solve a real, concrete problem in the current code — not for hypothetical future flexibility.
5. **Prefer Python idioms over classical patterns.** A first-class function often replaces Strategy. A module replaces Singleton. A `@dataclass` replaces Builder. Use the GoF version only when the language idiom doesn't fit.
6. **Explain trade-offs.** Always discuss pros, cons, and the cost of the abstraction.
7. **Show working Python.** Examples must use type hints, dataclasses where appropriate, and Python ≥ 3.10 syntax.
8. **Consider alternatives.** Mention 1–2 related or alternative patterns.

## Foundational Principles (apply *before* any GoF pattern)

| Principle | Question to ask | If yes, the answer is usually... |
|-----------|----------------|---------------------------------|
| **KISS** | Does a 5-line dict / function solve this? | Use the dict / function. No pattern. |
| **SRP** | Does this class change for more than one reason? | Split it. Don't add a pattern around the union. |
| **Rule of Three** | Have I seen this exact shape *three* times? | If <3, duplicate. If ≥3, *then* consider abstracting. |
| **Composition over inheritance** | Am I reaching for `class X(Y)` for code reuse? | Inject `Y` as a collaborator instead. |
| **Separation of concerns** | Is HTTP, business logic, or SQL bleeding across layers? | Layer the code (handler → service → repository). |
| **Dependency injection** | Am I instantiating a collaborator inside a class? | Take it as a constructor argument. |

Detailed treatment of each principle, with Python examples and anti-patterns, lives in [`references/foundations.md`](references/foundations.md).

## Pattern Selection Decision Tree

### Object Creation Problems?

```
├─ Need to create objects without specifying concrete classes?
│  └─→ Factory Method  (or: a dict {name: cls} registry — usually simpler)
│
├─ Need families of related objects to work together?
│  └─→ Abstract Factory  (or: pass a Protocol with multiple factory methods)
│
├─ Complex object with many optional parameters?
│  └─→ Builder  (or: @dataclass with defaults — much simpler in Python)
│
└─ Need exactly one instance with global access?
   └─→ Singleton (⚠️ usually wrong — use a module-level instance or DI)
```

### Behavior / Algorithm Problems?

```
├─ Need to swap algorithms at runtime?
│  └─→ Strategy  (or: pass a callable — Python has first-class functions)
│
├─ Behavior changes based on internal state?
│  └─→ State
│
├─ Need to notify multiple objects of changes?
│  └─→ Observer  (or: blinker / asyncio.Event / simple list of callables)
│
├─ Want to queue, log, or undo operations?
│  └─→ Command
│
├─ Need to save/restore object state (undo/redo, snapshots)?
│  └─→ Memento  (or: @dataclass(frozen=True) for immutable snapshots)
│
└─ Define algorithm skeleton, let subclasses override steps?
   └─→ Template Method
```

### Structure / Interface Problems?

```
├─ Incompatible interfaces need to work together?
│  └─→ Adapter
│
├─ Need to add responsibilities without subclassing?
│  └─→ Decorator  (Python has @decorator syntax built in for functions)
│
└─ Want to simplify a complex subsystem?
   └─→ Facade
```

## Process

### Phase 1: Identify the Problem

1. **Read the code.** Understand current implementation; do not assume.
2. **Identify code smells.** Look for:
   - Tight coupling between classes (one knows the concrete type of another)
   - Constructors with > 5 parameters (Builder candidate, or *split the class*)
   - Long `if/elif` chains on type or state (Strategy/State candidate)
   - Duplicate code across "almost identical" classes (Template Method candidate)
   - Global state, module-level mutable defaults, or singletons (DI candidate)
   - Classes with > 1 reason to change (split — SRP)
   - Imports that flow upward (e.g., `repository` importing `service`) — layering violation

**Verification:** You can articulate the problem in one sentence without saying "we might want to…".

### Phase 2: Match Problem to Pattern

1. **Foundational principles first.** Re-read the table above. If a principle solves it, *stop* — no pattern needed.
2. **Use the decision tree.** Navigate from the smell to a candidate pattern.
3. **Consult reference files** for full Python examples and trade-offs:
   - [`references/creational.md`](references/creational.md) — Factory Method, Abstract Factory, Builder, Singleton
   - [`references/structural.md`](references/structural.md) — Adapter, Decorator, Facade
   - [`references/behavioral.md`](references/behavioral.md) — Observer, Strategy, Command, State, Template Method, Memento
   - [`references/python-idioms.md`](references/python-idioms.md) — when Python features replace a classical pattern
4. **Consider alternatives.** Evaluate 2–3 patterns if multiple fit; mention which idiom is most Pythonic.
5. **Explain trade-offs.** State pros, cons, and the *cost* of the abstraction.

**Verification:** The pattern directly addresses the identified problem, and a Pythonic alternative has been considered.

### Phase 3: Implement Solution

1. **Show the structure.** Name the participants (`Strategy`, `Context`, etc.), their interfaces, and how they relate.
2. **Provide example code.** Use Python ≥ 3.10 with type hints, `Protocol`/`ABC` as appropriate, and dataclasses where they fit.
3. **Walk through flow.** Explain how a request travels through the participants.
4. **Point out gotchas.** Memory leaks (Observer), pickling (Memento), thread safety (Singleton), test difficulty (Singleton/global state).

**Verification:** Implementation follows pattern principles, is < 100 lines of clear Python, and solves the stated problem.

## Common Scenarios → Patterns

| Scenario | Pattern | Why |
|----------|---------|-----|
| Multiple payment methods (credit card, PayPal, crypto) | Strategy *(or callable)* | Swap algorithms at runtime |
| Cache layer between service and repository | Decorator | Add behavior without modifying repository |
| UI must update when shared state changes | Observer | Automatic notification |
| Wrapping a vendor SDK that doesn't match our interface | Adapter | Bridge incompatible interfaces |
| `boto3` exposes 50 calls but we only need "upload to bucket" | Facade | Simplified subsystem entry point |
| Building a complex API request with 20 optional parameters | Builder *(or @dataclass)* | Step-by-step construction |
| Document editor with undo/redo | Command + Memento | Encapsulate operations + snapshot state |
| Connection states: disconnected, connecting, connected, error | State | Behavior depends on state |
| Two parsers (PDF, CSV) with the same overall flow | Template Method | Extract shared skeleton |
| Object pool / database connection lifecycle | Singleton *(or module-level)* | Single shared resource |

## Anti-Patterns

| Avoid | Why | Instead |
|-------|-----|---------|
| Pattern for pattern's sake | Adds complexity with no payoff | Identify the actual problem first |
| `Singleton` everywhere | Hidden dependencies, untestable | Module-level instance + DI |
| Deep `Decorator` chains | Debugging nightmare; order-dependent | Compose at one level, or use middleware |
| Premature abstraction | YAGNI violation; wrong abstraction is worse than duplication | Wait for *three* concrete cases |
| `Factory` for a single product | Over-engineering | Just `MyClass()` |
| `Observer` for everything | Memory leaks, ordering issues, async pitfalls | Use only when subscribers are dynamic |
| Inheritance for code reuse | Tight coupling, fragile base class | Composition + dependency injection |
| Fat handler with SQL inside | Layering violation, untestable | Extract to repository / service |
| Writing a Strategy interface for one swap-able function | Pure ceremony | Just pass a callable |

## Verification Checklist

After applying a pattern:

- [ ] The original problem (named in Phase 1) is solved
- [ ] Code is more maintainable, not just more abstract
- [ ] Each participant has a single, clear responsibility
- [ ] Tests still pass and cover the new structure
- [ ] No new global state or hidden coupling introduced
- [ ] A reader can name the pattern from the code in < 30 seconds
- [ ] You can explain *why this pattern, not the simpler Pythonic alternative*

## Extension Points

1. **Domain-specific patterns** — document patterns recurring in your codebase (e.g., the Route + Service + Repository layering used in this project's `app/` tree).
2. **Pattern combinations** — Command + Memento for undo/redo; Strategy + Factory for runtime selection; Decorator + Adapter for legacy wrapping.
3. **Refactoring catalog** — collect before/after snippets in `references/refactorings.md` (create as needed) when you discover one that helps the team.

## References

- [Foundational Principles](references/foundations.md) — KISS, SRP, composition, separation of concerns, dependency injection, rule of three
- [Creational Patterns](references/creational.md) — Factory Method, Abstract Factory, Builder, Singleton
- [Structural Patterns](references/structural.md) — Adapter, Decorator, Facade
- [Behavioral Patterns](references/behavioral.md) — Observer, Strategy, Command, State, Template Method, Memento
- [Python Idioms vs GoF](references/python-idioms.md) — when first-class functions, decorators, dataclasses, and protocols replace classical patterns
- [Refactoring.Guru](https://refactoring.guru/design-patterns/catalog) — full pattern catalog (language-agnostic descriptions)

---

**Note**: Pattern selection requires judgment. When in doubt, prefer the simpler Pythonic alternative. Patterns are tools, not goals.
