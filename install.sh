#!/usr/bin/env bash
# install.sh — drop the claudecode template into a project.
#
# Usage:
#   bash install.sh                                    # install into the current dir
#   bash install.sh --dest path/to/project              # install elsewhere
#   bash install.sh --update                           # overwrite existing template files
#   bash install.sh --tag v1.2.3                       # pin a specific ref (default: main)
#   bash install.sh --help
#
# The script clones this repo to a temp dir, copies the template files
# (.claude/, .mcp.json, CLAUDE.md) into the destination, and updates the
# destination's .gitignore. Per-developer files (.claude/settings.local.json)
# are never copied.
#
# Idempotent: re-running with no flags only adds files that don't exist yet.
# Re-run with --update to overwrite the managed files.

set -euo pipefail

REPO_URL="${CLAUDECODE_REPO_URL:-https://github.com/huynhanh48/claudecode.git}"
REF="main"
DEST="$PWD"
UPDATE=0
INSTALL_LOCAL_EXAMPLE=1

# Files / dirs the template manages.
MANAGED=(
  ".claude"
  ".mcp.json"
  "CLAUDE.md"
)

# .gitignore lines we ensure exist in the destination.
GITIGNORE_LINES=(
  ".claude/settings.local.json"
  ".env"
  ".env.*"
  "!.env.example"
  ".lobehub-market/"
)

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
}

die()  { echo "error: $*" >&2; exit 1; }
info() { echo "==> $*"; }
ok()   { echo "  [ok]  $*"; }
skip() { echo "  [skip] $*"; }
warn() { echo "  [warn] $*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dest)            DEST="${2:?--dest needs a path}"; shift 2 ;;
    --tag|--ref)       REF="${2:?--tag needs a ref}"; shift 2 ;;
    --update|--force)  UPDATE=1; shift ;;
    --no-local-example) INSTALL_LOCAL_EXAMPLE=0; shift ;;
    --help|-h)         usage; exit 0 ;;
    *) die "unknown flag: $1 (try --help)" ;;
  esac
done

command -v git >/dev/null 2>&1 || die "git not found in PATH"
DEST="$(cd "$DEST" && pwd)" || die "destination does not exist: $DEST"

info "Cloning $REPO_URL ($REF) into a temp dir"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git clone --depth 1 --branch "$REF" "$REPO_URL" "$TMP/template" >/dev/null 2>&1 \
  || git clone "$REPO_URL" "$TMP/template" >/dev/null 2>&1 \
  || die "clone failed (network? bad ref?)"
ok "cloned"

info "Copying template files into $DEST"
copied=0
for entry in "${MANAGED[@]}"; do
  src="$TMP/template/$entry"
  dst="$DEST/$entry"

  if [ ! -e "$src" ]; then
    warn "$entry not present in template (skipped)"
    continue
  fi

  if [ -e "$dst" ] && [ "$UPDATE" -ne 1 ]; then
    skip "$entry already exists (use --update to overwrite)"
    continue
  fi

  if [ -e "$dst" ]; then
    rm -rf "$dst"
  fi

  if [ -d "$src" ]; then
    cp -R "$src" "$dst"
    # Per-developer overrides must never travel via the template.
    rm -f "$dst/settings.local.json"
  else
    cp "$src" "$dst"
  fi
  ok "$entry"
  copied=$((copied + 1))
done

# Optional: also drop in the per-user override starter if it exists upstream.
if [ "$INSTALL_LOCAL_EXAMPLE" -eq 1 ] && [ -f "$TMP/template/.claude/settings.local.json.example" ]; then
  if [ ! -e "$DEST/.claude/settings.local.json.example" ] || [ "$UPDATE" -eq 1 ]; then
    cp "$TMP/template/.claude/settings.local.json.example" "$DEST/.claude/settings.local.json.example"
    ok ".claude/settings.local.json.example"
  fi
fi

info "Marking hooks executable"
if [ -d "$DEST/.claude/hooks" ]; then
  chmod +x "$DEST/.claude/hooks"/*.sh 2>/dev/null || true
  ok "chmod +x .claude/hooks/*.sh"
fi

info "Updating $DEST/.gitignore"
gi="$DEST/.gitignore"
touch "$gi"
added=0
for line in "${GITIGNORE_LINES[@]}"; do
  if ! grep -qxF "$line" "$gi"; then
    [ -s "$gi" ] && [ "$(tail -c 1 "$gi")" != "" ] && printf '\n' >> "$gi"
    printf '%s\n' "$line" >> "$gi"
    added=$((added + 1))
    ok "+ $line"
  fi
done
[ "$added" -eq 0 ] && skip ".gitignore already up to date"

info "Done"
echo
echo "  Files copied:   $copied"
echo "  .gitignore:     +$added line(s)"
echo
echo "Next steps:"
echo "  1. export the MCP env vars in your shell:"
echo "       POSTGRES_CONNECTION_STRING, CONTEXT7_API_KEY, GITHUB_PERSONAL_ACCESS_TOKEN"
echo "  2. claude mcp list           # verify all four servers are connected"
echo "  3. open .claude/README.md    # full guide"
