#!/usr/bin/env bash
set -euo pipefail

STATE_FILE=".claude/reeds-state.local.md"
TASK_ID="${1:-}"

if [[ -z "$TASK_ID" ]]; then
  echo "Usage: set-current-task.sh <task-id>" >&2
  exit 1
fi

if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: Reeds state file not found" >&2
  exit 1
fi

# Update current_task_id in state file
TEMP_FILE=$(mktemp)
sed "s/^current_task_id: .*/current_task_id: \"$TASK_ID\"/" "$STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

echo "Current task set to: $TASK_ID"
