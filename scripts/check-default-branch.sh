#!/usr/bin/env bash
set -euo pipefail

current_branch="$(git symbolic-ref --quiet --short HEAD || true)"
[ -n "$current_branch" ] || exit 0

remote_head="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
default_branch="${remote_head#origin/}"
if [ -z "$default_branch" ]; then
    default_branch="$(git config --get init.defaultBranch || true)"
fi
if [ -z "$default_branch" ]; then
    if git show-ref --verify --quiet refs/heads/main; then
        default_branch=main
    elif git show-ref --verify --quiet refs/heads/master; then
        default_branch=master
    else
        exit 0
    fi
fi

[ "$current_branch" = "$default_branch" ] || exit 0
[ "${AGENT_ALLOW_DIRECT_DEFAULT_COMMIT:-}" = "1" ] && exit 0

echo "Direct commits to '$default_branch' are blocked." >&2
echo "Create a work branch and use a pull request." >&2
echo "A one-command override is allowed only after the user explicitly authorizes skipping the PR in the current task." >&2
exit 1
