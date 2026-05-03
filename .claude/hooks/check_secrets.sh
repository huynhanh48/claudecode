#!/usr/bin/env bash
# check_secrets.sh — invoked by PreToolUse on Edit / Write / MultiEdit.
#
# Scans the *content being written* for likely secret literals. If a match is
# found, exits 2 with a stderr message — Claude Code blocks the tool call and
# shows the message to the assistant so it can correct course.
#
# This is a fast, low-precision check meant to catch accidents (a JWT pasted
# into a config file, an AWS key, etc.). It is NOT a replacement for
# `gitleaks` / `trufflehog` / repo-wide scans.

set -u

payload="$(cat 2>/dev/null || true)"
[ -z "$payload" ] && exit 0

# Extract the candidate text that's being written. For Edit/Write this is in
# tool_input.content / tool_input.new_string. We just dump the whole payload
# and let grep find a match anywhere.
candidate="$payload"

# Patterns: AWS keys, private keys, JWT-shaped tokens, generic secret = "value"
# assignments where the value looks high-entropy.
patterns=(
  'AKIA[0-9A-Z]{16}'                                 # AWS access key
  'aws_secret_access_key[[:space:]]*=[[:space:]]*"[^"]{40}"'
  '-----BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY-----'
  'eyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}'  # JWT
  'ghp_[A-Za-z0-9]{36}'                              # GitHub personal access token
  'github_pat_[A-Za-z0-9_]{60,}'                     # GitHub fine-grained PAT
  'sk-[A-Za-z0-9]{40,}'                              # OpenAI / similar
  'xox[baprs]-[A-Za-z0-9-]{10,}'                     # Slack
  '(SECRET_KEY|API_KEY|PRIVATE_KEY|PASSWORD|TOKEN)[[:space:]]*=[[:space:]]*["\047][^"\047]{16,}["\047]'
)

for p in "${patterns[@]}"; do
  if echo "$candidate" | grep -qE -e "$p"; then
    echo "secret-like literal detected (pattern: $p) — refusing the edit." >&2
    echo "move the secret to .env / Settings instead." >&2
    exit 2
  fi
done

exit 0
