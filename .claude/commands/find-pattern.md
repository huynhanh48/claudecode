---
description: Recommend a design pattern (or no pattern) for a described problem, grounded in the team's design-patterns skill.
argument-hint: "<problem description>"
---

# /find-pattern

Recommend a design pattern — or explicitly *no* pattern — for the problem described in `$ARGUMENTS`.

## Steps

1. Activate the `design-patterns` skill at `.claude/skills/design-patterns/SKILL.md`.
2. Run the **Foundational Principles** check from `references/foundations.md`:
   - KISS — does a dict / function / `@dataclass` solve this?
   - SRP — is the problem really "one class doing too much"?
   - Rule of Three — have we seen this *three* times?
   - Composition over inheritance — would composition beat the inheritance instinct?
   If any principle resolves the problem, **recommend that** and stop. No pattern.
3. Otherwise, navigate the decision tree in `SKILL.md` and pick a candidate.
4. Read the deeper coverage in the appropriate references file (`creational.md`, `structural.md`, `behavioral.md`).
5. Check `python-idioms.md` for a more Pythonic alternative (callable / `@decorator` / `Protocol` / `blinker` / `match` / `@dataclass(frozen=True)` …).
6. Output:
   - **Problem (one sentence).**
   - **Recommendation**: principle / pattern / Pythonic alternative.
   - **Why** (2–3 bullets).
   - **Trade-offs** (one bullet of cons).
   - **Skeleton**: ≤ 30 lines of idiomatic Python showing the participants.
   - **Alternative considered**: name + one-line reason it lost.

Keep the answer under 250 words unless the user asks for more.
