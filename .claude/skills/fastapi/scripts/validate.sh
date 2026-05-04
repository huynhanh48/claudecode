#!/usr/bin/env bash
# validate.sh — sanity-check a FastAPI project produced by the `fastapi` skill.
#
# Usage:
#   bash scripts/validate.sh [project-root]
#
# Default project-root is the current working directory.
#
# Exit codes:
#   0  all checks passed
#   1  layout / convention violation
#   2  ruff failed
#   3  pytest failed (only run if a tests/ dir exists)

set -u

ROOT="${1:-.}"
cd "$ROOT" || { echo "[validate] cannot cd into $ROOT"; exit 1; }

PASS=0
FAIL=0
WARN=0

ok()   { echo "  [ok]   $*";  PASS=$((PASS + 1)); }
bad()  { echo "  [FAIL] $*";  FAIL=$((FAIL + 1)); }
warn() { echo "  [warn] $*";  WARN=$((WARN + 1)); }

echo "==> Checking layout (project root: $(pwd))"

REQUIRED_PATHS=(
  "main.py"
  "requirements.txt"
  "app/__init__.py"
  "app/core/config.py"
  "app/db/database.py"
  "app/exception/httpexception.py"
  "app/models/base.py"
  "app/routes/__init__.py"
  "app/services"
  "app/repositories"
  "app/schema"
)

for path in "${REQUIRED_PATHS[@]}"; do
  if [ -e "$path" ]; then
    ok "$path"
  else
    bad "missing $path"
  fi
done

# Old-architecture leftovers — controllers/ was removed in the 4-layer migration.
if [ -d "app/controllers" ]; then
  bad "app/controllers/ still exists — the project uses 4 layers (route → service → repository → model). Remove app/controllers/."
fi

echo ""
echo "==> Checking layer discipline"

# Routes must not import from repositories or models directly — go through services.
# Repositories must not raise HttpException subclasses.

if [ -d "app/routes" ]; then
  if grep -RIn --include='*.py' -E 'from app\.(repositories|models)' app/routes \
      | grep -v 'app/routes/__init__.py' >/dev/null 2>&1; then
    bad "routes/ imports repositories/models directly — must go through services"
    grep -RIn --include='*.py' -E 'from app\.(repositories|models)' app/routes \
      | grep -v 'app/routes/__init__.py' | sed 's/^/        /'
  else
    ok "routes/ only depend on services"
  fi
fi

if [ -d "app/services" ]; then
  # Match SQLAlchemy session queries specifically: db.query(...), session.query(...),
  # or imports of select/insert/update/delete from sqlalchemy. Avoids false-positives
  # on adapter.query(...) etc.
  if grep -RIn --include='*.py' -E '\b(db|session)\.query\(|from sqlalchemy import .*\b(select|insert|update|delete)\b' app/services >/dev/null 2>&1; then
    bad "services/ contain SQLAlchemy queries — move them into a repository"
    grep -RIn --include='*.py' -E '\b(db|session)\.query\(|from sqlalchemy import .*\b(select|insert|update|delete)\b' app/services | sed 's/^/        /'
  else
    ok "services/ contain no SQLAlchemy queries"
  fi
fi

if [ -d "app/repositories" ]; then
  if grep -RIn --include='*.py' -E 'raise (NotFound|BadRequest|Unauthorized|Forbidden|InternalServerError|Http)Exception' app/repositories >/dev/null 2>&1; then
    bad "repositories/ raise HTTP exceptions — let services translate not-found etc."
    grep -RIn --include='*.py' -E 'raise (NotFound|BadRequest|Unauthorized|Forbidden|InternalServerError|Http)Exception' app/repositories | sed 's/^/        /'
  else
    ok "repositories/ raise no HTTP exceptions"
  fi
fi

echo ""
echo "==> Checking for forbidden patterns"

# Hardcoded secrets / print statements.
if grep -RIn --include='*.py' -E '\bprint\(' app/ 2>/dev/null | grep -v __pycache__ >/dev/null; then
  warn "print() calls found — prefer logging.getLogger(__name__)"
  grep -RIn --include='*.py' -E '\bprint\(' app/ | grep -v __pycache__ | sed 's/^/        /'
else
  ok "no print() calls under app/"
fi

if grep -RIn --include='*.py' -E '(SECRET_KEY|PASSWORD|API_KEY)\s*=\s*["\047][^"\047]+["\047]' app/ 2>/dev/null; then
  bad "hardcoded secret-looking literal in app/ — move to Settings"
  grep -RIn --include='*.py' -E '(SECRET_KEY|PASSWORD|API_KEY)\s*=\s*["\047][^"\047]+["\047]' app/ | sed 's/^/        /'
else
  ok "no hardcoded secret literals"
fi

# Raw HTTPException raised outside main.py — should always go through app/exception/.
if grep -RIn --include='*.py' -E '\braise\s+HTTPException\b' app/ 2>/dev/null | grep -v __pycache__ >/dev/null; then
  bad "raw HTTPException raised inside app/ — use the app/exception/ hierarchy instead"
  grep -RIn --include='*.py' -E '\braise\s+HTTPException\b' app/ | grep -v __pycache__ | sed 's/^/        /'
else
  ok "no raw HTTPException usage in app/"
fi

# JSONResponse instantiated outside main.py — should be the global handler's job.
if grep -RIn --include='*.py' -E '\bJSONResponse\(' app/ 2>/dev/null | grep -v __pycache__ >/dev/null; then
  warn "JSONResponse() used inside app/ — prefer letting main.py's exception handler format errors"
  grep -RIn --include='*.py' -E '\bJSONResponse\(' app/ | grep -v __pycache__ | sed 's/^/        /'
else
  ok "no JSONResponse() outside main.py"
fi

# Redundant try/except Exception in services — global handler in main.py should take these.
if [ -d "app/services" ]; then
  if grep -RIn --include='*.py' -B0 -A1 'except Exception' app/services 2>/dev/null | grep -v __pycache__ >/dev/null; then
    warn "services/ contains 'except Exception' — make sure it transforms a known error, not just logs+reraises (main.py global handler does that already)"
  else
    ok "services/ has no broad 'except Exception'"
  fi
fi

if [ -f ".env" ] && [ ! -f ".gitignore" ]; then
  bad ".env present but no .gitignore — add .gitignore that excludes .env"
elif [ -f ".env" ] && ! grep -q -E '^\.env(\s|$)' .gitignore 2>/dev/null; then
  warn ".env present but not listed in .gitignore"
else
  ok ".env handling looks fine"
fi

echo ""
echo "==> Checking new-resource wiring"

# For each <name>.py under app/models/ (excluding base/__init__), make sure
# matching files exist in routes/services/repositories/schema,
# and that the model is registered in app/db/database.py.

if [ -d "app/models" ]; then
  for model_path in app/models/*.py; do
    name="$(basename "$model_path" .py)"
    case "$name" in
      __init__|base) continue ;;
    esac
    for layer in repositories services routes schema; do
      if [ ! -f "app/$layer/$name.py" ]; then
        bad "model '$name' has no app/$layer/$name.py — every resource needs all 4 layers + schema"
      fi
    done
    if ! grep -q "app.models.$name" app/db/database.py 2>/dev/null; then
      warn "model '$name' is not imported in app/db/database.py (SQLAlchemy will not register it)"
    fi
  done
fi

echo ""
echo "==> Running ruff (if installed)"
if command -v ruff >/dev/null 2>&1; then
  if ruff check . ; then
    ok "ruff check passed"
  else
    bad "ruff check failed"
    RUFF_FAILED=1
  fi
else
  warn "ruff not installed — skipping (pip install ruff)"
fi

echo ""
echo "==> Running pytest (if tests/ exists)"
if [ -d tests ] && command -v pytest >/dev/null 2>&1; then
  if pytest -q ; then
    ok "pytest passed"
  else
    bad "pytest failed"
    PYTEST_FAILED=1
  fi
else
  warn "no tests/ directory or pytest missing — skipping"
fi

echo ""
echo "==================================="
echo "  passed:  $PASS"
echo "  failed:  $FAIL"
echo "  warnings: $WARN"
echo "==================================="

if [ "${PYTEST_FAILED:-0}" = "1" ]; then exit 3; fi
if [ "${RUFF_FAILED:-0}"   = "1" ]; then exit 2; fi
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
