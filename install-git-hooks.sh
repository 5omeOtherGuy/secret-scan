#!/usr/bin/env bash
# Install the pre-push secret-scan hook into this repository's hooks directory.
# Idempotent; replaces only the pre-push hook.
set -eu
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOOKS=$(git -C "$REPO_ROOT" rev-parse --git-path hooks)
case "$HOOKS" in /*) ;; *) HOOKS="$REPO_ROOT/$HOOKS";; esac
mkdir -p "$HOOKS"
install -m 0755 "$REPO_ROOT/hooks/pre-push" "$HOOKS/pre-push"
echo "installed $HOOKS/pre-push"
