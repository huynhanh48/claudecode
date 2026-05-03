#!/usr/bin/env bash
# format_python.sh — invoked by PostToolUse on Edit / Write / MultiEdit.
#
# Auto-formats edited Python files with `ruff` if it's available. Silent on
# success; never blocks (exits 0 even on format errors so the assistant can
# continue working).

set -u

# Claude Code hook payload arrives on stdin as JSON. We extract the file path
# from `tool_input.file_path` (Edit/Write) using a no-deps awk fallback if
# `jq` is missing.
payload="$(cat 2>/dev/null || true)"
if [ -z "$payload" ]; then exit 0; fi

extract_path() {
  if command -v jq >/dev/null 2>&1; then
    echo "$payload" | jq -r '.tool_input.file_path // empty'
  else
    # Naive fallback: grab the first "file_path": "..." occurrence.
    echo "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
  fi
}

file="$(extract_path)"
[ -z "$file" ] && exit 0
[ ! -f "$file" ] && exit 0

# Only format Python files inside this project.
case "$file" in
  *.py) ;;
  *) exit 0 ;;
esac

if command -v ruff >/dev/null 2>&1; then
  ruff format "$file" >/dev/null 2>&1 || true
  ruff check --fix --unsafe-fixes --quiet "$file" >/dev/null 2>&1 || true
fi

exit 0
