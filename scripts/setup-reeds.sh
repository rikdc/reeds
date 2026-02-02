#!/usr/bin/env bash

# Parse arguments
max_iterations=30
prev_arg=""
for arg in "$@"; do
  case "$prev_arg" in
    --max-iterations) max_iterations="$arg" ;;
  esac
  prev_arg="$arg"
done

# Validate prerequisites
if ! command -v bd &> /dev/null; then
  echo "ERROR: bd command not found" >&2
  exit 1
fi

if ! bd stats &> /dev/null; then
  echo "ERROR: Beads not initialized. Run: bd init" >&2
  exit 1
fi

ready_count=$(bd ready --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
if [[ "$ready_count" == "0" ]]; then
  echo "No ready tasks found."
  exit 1
fi

# Create Reeds state file
if ! mkdir -p .claude; then
  echo "ERROR: Failed to create .claude directory" >&2
  exit 1
fi

cat > .claude/reeds-state.local.md << EOF
---
active: true
iteration: 1
max_iterations: $max_iterations
current_task_id: ""
started_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
---
EOF

echo "Reeds activated!"
echo ""
echo "Ready tasks: $ready_count"
echo "Max iterations: $max_iterations"
echo ""
echo "To cancel: /reeds:reeds-cancel"
