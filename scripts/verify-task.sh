#!/usr/bin/env bash
set -euo pipefail

state_file=".claude/reeds-state.local.md"

verify_enabled=$(sed -n '/^---$/,/^---$/p' "$state_file" | grep 'enabled:' | head -1 | sed 's/.*enabled: *//' || echo "false")

if [[ "$verify_enabled" != "true" ]]; then
    exit 0
fi

failed=0

run_gate() {
    local name="$1"
    shift
    echo "Running: $name"
    if "$@" 2> /dev/null; then
        return 0
    fi
    return 1
}

# Build gate
if ! run_gate "build" npm run build && \
   ! run_gate "build" make build && \
   ! run_gate "build" go build ./...; then
    echo "No build command found or build failed"
    failed=1
fi

# Test gate
if ! run_gate "test" npm test && \
   ! run_gate "test" make test && \
   ! run_gate "test" go test ./...; then
    echo "No test command found or tests failed"
    failed=1
fi

exit "$failed"
