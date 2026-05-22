#!/usr/bin/env bash
# Pre-commit / CI helper: scan markdown for accidentally committed secrets.
# Exit code 1 if any pattern matches.
#
# Usage:
#   scripts/check-secrets.sh                 # scan all *.md
#   scripts/check-secrets.sh path/to/file.md # scan specific file
set -eu

# Patterns to flag. Add new ones (lowercase) as you discover them.
# Each pattern is a fixed substring tested with ripgrep `-F`.
patterns=(
  "acmt2024"          # historical LDAP bind password (redacted 2026-05-22)
  "bindpw "           # any plaintext bind password
  "BEGIN RSA PRIVATE KEY"
  "BEGIN OPENSSH PRIVATE KEY"
  "BEGIN EC PRIVATE KEY"
  "ghp_"              # GitHub PAT
  "xoxb-"             # Slack bot token
)

if [[ "$#" -gt 0 ]]; then
  targets=("$@")
else
  # Use git ls-files -z + while-read to support old bash (no mapfile on macOS bash 3.2).
  targets=()
  while IFS= read -r -d '' f; do
    targets+=("$f")
  done < <(git ls-files -z '*.md')
fi

hit=0
for pat in "${patterns[@]}"; do
  if rg -F -n -i "$pat" -- "${targets[@]}" 2>/dev/null; then
    echo "ERROR: matched forbidden pattern '$pat' above. Redact and recommit." >&2
    hit=1
  fi
done

if [[ "$hit" -ne 0 ]]; then
  exit 1
fi

echo "OK: no leaked secrets matched in scanned files."
