#!/usr/bin/env bash
# Link tracked hooks from .githooks/ into .git/hooks/ (idempotent). Leaves
# existing untracked hooks such as prepare-commit-msg untouched.
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
hooks_dir="$(git rev-parse --git-path hooks)"
mkdir -p "$hooks_dir"
for hook in "$root"/.githooks/*; do
    name="$(basename "$hook")"
    chmod +x "$hook"
    ln -sfn "$hook" "$hooks_dir/$name"
    echo "linked $name"
done
