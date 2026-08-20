#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
export PATH="/opt/homebrew/bin:$PATH"
export DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"

# shellcheck disable=SC1091
source .shared-config

mode="${1:-lint}"
if [ "$mode" = "fix" ]; then
    echo "Running SwiftFormat"
    swiftformat $dirs
    echo "Running SwiftLint fixes"
    swiftlint --fix --quiet || true
elif [ "$mode" != "lint" ]; then
    echo "Usage: ./scripts/lint.sh [lint|fix]" >&2
    exit 2
fi

echo "Checking SwiftFormat"
swiftformat $dirs --lint
echo "Checking SwiftLint"
swiftlint lint --strict --quiet
echo "Checking new comments"
python3 scripts/check-no-new-comments.py

for check in scripts/check-*.py; do
    [ -e "$check" ] || continue
    [ "$(basename "$check")" = "check-no-new-comments.py" ] && continue
    echo "Running $(basename "$check" .py)"
    python3 "$check"
done

echo "Lint checks passed."
