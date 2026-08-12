#!/bin/bash
set -euo pipefail

branch="${1:-custom}"
upstream_remote="${UPSTREAM_REMOTE:-upstream}"
upstream_url="${UPSTREAM_URL:-https://github.com/lonelysoul/OpenWrt.git}"
upstream_branch="${UPSTREAM_BRANCH:-main}"
push_remote="${PUSH_REMOTE:-origin}"

current_branch="$(git branch --show-current)"
test "$current_branch" = "$branch" || {
    echo "Expected branch '$branch', found '$current_branch'" >&2
    exit 1
}

if git remote get-url "$upstream_remote" >/dev/null 2>&1; then
    configured_url="$(git remote get-url "$upstream_remote")"
    test "$configured_url" = "$upstream_url" || {
        echo "Remote '$upstream_remote' points to '$configured_url', expected '$upstream_url'" >&2
        exit 1
    }
else
    git remote add "$upstream_remote" "$upstream_url"
fi

git fetch "$upstream_remote" "$upstream_branch"
base_ref="$upstream_remote/$upstream_branch"
old_tip="$(git rev-parse HEAD)"

git rebase "$base_ref"
new_tip="$(git rev-parse HEAD)"

if test "$old_tip" = "$new_tip"; then
    echo "Already based on $base_ref at $new_tip"
    exit 0
fi

remote_tip="$(git ls-remote --heads "$push_remote" "refs/heads/$branch" | awk '{print $1}')"
test -n "$remote_tip" || {
    echo "Remote branch '$push_remote/$branch' was not found" >&2
    exit 1
}

git push --force-with-lease="refs/heads/$branch:$remote_tip" \
    "$push_remote" "HEAD:refs/heads/$branch"
echo "Rebased $branch onto $base_ref and pushed $new_tip"
