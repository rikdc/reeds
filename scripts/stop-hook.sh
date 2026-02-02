#!/usr/bin/env bash

STATE_FILE=".claude/reeds-state.local.md"
TEMP_FILE=""

# Cleanup trap for temp files
# shellcheck disable=SC2329  # Function invoked via trap
cleanup() {
  if [[ -n "$TEMP_FILE" ]] && [[ -f "$TEMP_FILE" ]]; then
    rm -f "$TEMP_FILE"
  fi
}
trap cleanup EXIT INT TERM

# Portable sed in-place edit (works on macOS and Linux)
sed_inplace() {
  local pattern="$1"
  local file="$2"
  TEMP_FILE=$(mktemp)
  if ! sed "$pattern" "$file" > "$TEMP_FILE"; then
    echo "Warning: sed operation failed" >&2
    rm -f "$TEMP_FILE"
    TEMP_FILE=""
    return 1
  fi
  if ! mv "$TEMP_FILE" "$file"; then
    echo "Warning: Failed to update file" >&2
    rm -f "$TEMP_FILE"
    TEMP_FILE=""
    return 1
  fi
  TEMP_FILE=""
  return 0
}

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Check if Reeds is active
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Parse frontmatter
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
ACTIVE=$(echo "$FRONTMATTER" | grep '^active:' | sed 's/active: *//')
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
# Simplified: combine multiple sed calls into one
CURRENT_TASK_ID=$(echo "$FRONTMATTER" | sed -n 's/^current_task_id: *"\?\([^"]*\)"\?/\1/p')

# Check if active
if [[ "$ACTIVE" != "true" ]]; then
  exit 0
fi

# Validate numeric fields
if ! [[ "$ITERATION" =~ ^[0-9]+$ ]] || ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Warning: Corrupted reeds state file" >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# Check iteration limit
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "Reeds: Max iterations ($MAX_ITERATIONS) reached."
  sed_inplace "s/^active: true/active: false/" "$STATE_FILE"
  exit 0
fi

# Get transcript path and check for completion promises
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq --raw-output '.transcript_path // empty')
LAST_OUTPUT=""

if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
  # Get last assistant message using jq to parse the entire JSONL file
  LAST_OUTPUT=$(jq --raw-output --slurp '
    map(select(.role == "assistant")) |
    last |
    .message.content |
    if type == "array" then
      map(select(.type == "text")) |
      map(.text) |
      join("\n")
    else
      . // ""
    end
  ' "$TRANSCRIPT_PATH" 2>/dev/null || echo "")
fi

# Check for REEDS COMPLETE (all tasks done)
if [[ "$LAST_OUTPUT" == *"<promise>REEDS COMPLETE</promise>"* ]]; then
  echo "Reeds: All tasks complete!"
  sed_inplace "s/^active: true/active: false/" "$STATE_FILE"
  exit 0
fi

# Check for TASK COMPLETE (current task done, get next)
TASK_COMPLETE=""
if [[ "$LAST_OUTPUT" =~ \<promise\>TASK\ COMPLETE:\ ([^<]+)\</promise\> ]]; then
  TASK_COMPLETE="${BASH_REMATCH[1]}"
fi

# Increment iteration
NEXT_ITERATION=$((ITERATION + 1))
sed_inplace "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$STATE_FILE"

# Determine which prompt to re-inject
if [[ -n "$TASK_COMPLETE" ]]; then
  # Task completed - clear current task and get next
  sed_inplace "s/^current_task_id: .*/current_task_id: \"\"/" "$STATE_FILE"

  PROMPT="Task $TASK_COMPLETE completed. Get the next task.

## Next Steps
1. Run: \`bd ready --limit 1\`
2. If no tasks returned: Output \`<promise>REEDS COMPLETE</promise>\` and stop
3. If task returned:
   - Extract the task ID
   - Run: \`bd show <task-id>\` to get full details
   - Use the **task-implementer agent** to implement the task
   - When the agent completes, output \`<promise>TASK COMPLETE: <task-id></promise>\`
   - Then run: \`bd close <task-id> --reason \"<summary>\"\`

Run: \`bd ready --limit 1\`"

  SYSTEM_MSG="Reeds iteration $NEXT_ITERATION/$MAX_ITERATIONS | Task $TASK_COMPLETE done, getting next task"

elif [[ -n "$CURRENT_TASK_ID" ]]; then
  # Task in progress - continue working on it
  PROMPT="Continue implementing task $CURRENT_TASK_ID.

The task is not yet complete. Use the **task-implementer agent** to continue working on it.

When the task is fully implemented and verified:
1. Output \`<promise>TASK COMPLETE: $CURRENT_TASK_ID</promise>\`
2. Run: \`bd close $CURRENT_TASK_ID --reason \"<summary>\"\`

If you need task details again, run: \`bd show $CURRENT_TASK_ID\`"

  SYSTEM_MSG="Reeds iteration $NEXT_ITERATION/$MAX_ITERATIONS | Continue task $CURRENT_TASK_ID"

else
  # No current task - get one
  PROMPT="Get the next task from Beads.

## Task Loop
1. Run: \`bd ready --limit 1\`
2. If no tasks returned: Output \`<promise>REEDS COMPLETE</promise>\` and stop
3. If task returned:
   - Extract the task ID
   - Run: \`bd show <task-id>\` to get full details
   - Use the **task-implementer agent** to implement the task
   - When the agent completes, output \`<promise>TASK COMPLETE: <task-id></promise>\`
   - Then run: \`bd close <task-id> --reason \"<summary>\"\`

Run: \`bd ready --limit 1\`"

  SYSTEM_MSG="Reeds iteration $NEXT_ITERATION/$MAX_ITERATIONS | Get next task"
fi

# Output JSON to block exit and re-inject prompt
jq --null-input \
  --arg prompt "$PROMPT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
