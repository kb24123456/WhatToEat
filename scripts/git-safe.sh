#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CURRENT_BRANCH="$(git branch --show-current)"
NOW="$(date '+%Y-%m-%d %H:%M:%S')"

print_help() {
  cat <<'EOF'
Usage:
  scripts/git-safe.sh status
  scripts/git-safe.sh snapshot [message]
  scripts/git-safe.sh push [branch]
  scripts/git-safe.sh save [message]      # snapshot + push
  scripts/git-safe.sh undo                # revert HEAD with a new commit
  scripts/git-safe.sh rollback <commit>   # revert a specific commit with a new commit
  scripts/git-safe.sh tag <name>          # create annotated tag on current HEAD
  scripts/git-safe.sh tag-push <name>     # create and push tag

Notes:
  - All rollback operations are "safe revert" (no reset --hard).
  - snapshot/save will include all tracked/untracked changes.
EOF
}

ensure_repo() {
  git rev-parse --is-inside-work-tree >/dev/null
}

has_changes() {
  [[ -n "$(git status --porcelain)" ]]
}

require_clean_worktree() {
  if has_changes; then
    echo "Working tree is not clean. Please run snapshot first."
    echo "Tip: scripts/git-safe.sh snapshot \"wip before rollback\""
    exit 1
  fi
}

cmd_status() {
  git status -sb
  echo
  git remote -v
}

cmd_snapshot() {
  local msg="${1:-}"
  if ! has_changes; then
    echo "No changes to snapshot."
    exit 0
  fi

  if [[ -z "$msg" ]]; then
    msg="snapshot: $NOW"
  fi

  git add -A
  git commit -m "$msg"
  echo "Snapshot committed on branch '$CURRENT_BRANCH'."
}

cmd_push() {
  local target_branch="${1:-$CURRENT_BRANCH}"
  git push origin "$target_branch"
  echo "Pushed to origin/$target_branch"
}

cmd_save() {
  local msg="${1:-}"
  cmd_snapshot "$msg"
  cmd_push "$CURRENT_BRANCH"
}

cmd_undo() {
  require_clean_worktree
  git revert --no-edit HEAD
  echo "Reverted HEAD by creating a new commit."
}

cmd_rollback() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    echo "Missing commit hash."
    echo "Usage: scripts/git-safe.sh rollback <commit>"
    exit 1
  fi
  require_clean_worktree
  git revert --no-edit "$target"
  echo "Reverted commit: $target"
}

cmd_tag() {
  local name="${1:-}"
  if [[ -z "$name" ]]; then
    echo "Missing tag name."
    echo "Usage: scripts/git-safe.sh tag <name>"
    exit 1
  fi
  git tag -a "$name" -m "snapshot tag: $name ($NOW)"
  echo "Created tag: $name"
}

cmd_tag_push() {
  local name="${1:-}"
  if [[ -z "$name" ]]; then
    echo "Missing tag name."
    echo "Usage: scripts/git-safe.sh tag-push <name>"
    exit 1
  fi
  cmd_tag "$name"
  git push origin "$name"
  echo "Pushed tag: $name"
}

main() {
  ensure_repo
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    status) cmd_status "$@" ;;
    snapshot) cmd_snapshot "$@" ;;
    push) cmd_push "$@" ;;
    save) cmd_save "$@" ;;
    undo) cmd_undo "$@" ;;
    rollback) cmd_rollback "$@" ;;
    tag) cmd_tag "$@" ;;
    tag-push) cmd_tag_push "$@" ;;
    help|-h|--help) print_help ;;
    *)
      echo "Unknown command: $cmd"
      print_help
      exit 1
      ;;
  esac
}

main "$@"
