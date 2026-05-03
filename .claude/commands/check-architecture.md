---
description: Verify the project follows the team's layered architecture, security, and style rules.
---

# /check-architecture

Run the full project verification suite and report results.

## Steps

1. **Layer discipline & layout**: `bash .claude/skills/fastapi/scripts/validate.sh`
2. **Lint**: `ruff check .`
3. **Format**: `ruff format --check .`
4. **Tests** (only if `tests/` exists): `pytest -q --cov=app --cov-report=term-missing --cov-fail-under=80`
5. **Secrets**: scan staged files for likely tokens — `grep -RInE '(SECRET|TOKEN|PASSWORD|API_KEY)[[:space:]]*=[[:space:]]*["\047][^"\047]+["\047]' app/ tests/ alembic/ 2>/dev/null || echo "  (no obvious hardcoded secrets)"`

For each step, report PASS / FAIL with the first relevant line(s) of output. If any step fails, do **not** propose a fix — let the user decide. Then point to the rule that was violated:

| Failure | Rule |
|---------|------|
| Layer / wiring | `.claude/rules/architecture.md` |
| Lint / format / style | `.claude/rules/coding-style.md` |
| Coverage | `.claude/rules/testing.md` |
| Secret leak | `.claude/rules/security.md` |
