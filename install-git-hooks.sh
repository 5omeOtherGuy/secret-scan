#!/usr/bin/env bash
# Install the pre-push secret-scan hook into the hooks directory of the Git
# repository this script sits in (its top level must also carry
# hooks/pre-push and secret-scan.sh). Works from any working directory and from
# a linked worktree. Idempotent; replaces only the pre-push hook.
set -eu
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null) || {
  echo "install-git-hooks: $SCRIPT_DIR is not inside a Git working tree; refusing" >&2; exit 1; }
for f in hooks/pre-push secret-scan.sh; do
  [ -f "$REPO_ROOT/$f" ] || {
    echo "install-git-hooks: missing $REPO_ROOT/$f; copy it into the repository first; refusing" >&2; exit 1; }
done
[ -x "$REPO_ROOT/secret-scan.sh" ] || {
  echo "install-git-hooks: $REPO_ROOT/secret-scan.sh is not executable (run: chmod +x secret-scan.sh); refusing" >&2; exit 1; }
HOOKS=$(git -C "$REPO_ROOT" rev-parse --git-path hooks)
case "$HOOKS" in /*) ;; *) HOOKS="$REPO_ROOT/$HOOKS";; esac
mkdir -p "$HOOKS"
install -m 0755 "$REPO_ROOT/hooks/pre-push" "$HOOKS/pre-push"
echo "installed $HOOKS/pre-push"
