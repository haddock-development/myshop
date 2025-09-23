#!/usr/bin/env bash
set -euo pipefail

REMOTE_NAME="${1:-origin}"
REMOTE_URL="${2:-}" 

if git remote | grep -q "^${REMOTE_NAME}$"; then
  echo "Remote '${REMOTE_NAME}' exists already. Nothing to do." >&2
  exit 0
fi

if [ -z "$REMOTE_URL" ]; then
  read -rp "Remote URL (e.g. https://github.com/acme/myshop.git): " REMOTE_URL
fi

if [ -z "$REMOTE_URL" ]; then
  echo "Error: remote URL required." >&2
  exit 1
fi

echo "Adding remote '${REMOTE_NAME}' -> ${REMOTE_URL}" >&2

git remote add "$REMOTE_NAME" "$REMOTE_URL"

echo "Fetching remote..." >&2
git fetch "$REMOTE_NAME"

default_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo main)

echo "Pushing current branch (${default_branch})" >&2
git push -u "$REMOTE_NAME" "${default_branch}"

echo "Done. Remember to set GitHub secrets for workflows (see PROJECT-README)."
