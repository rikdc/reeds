#!/usr/bin/env bash
set -euo pipefail

STATE_FILE=".claude/reeds-state.local.md"
TEMP_FILE=""

# Cleanup trap for temp files
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
  sed "$pattern" "$file" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$file"
  TEMP_FILE=""
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

# Get transcript path and check for completion promise
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq --raw-output '.transcript_path // empty')

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

  # Check for completion promise
  if [[ "$LAST_OUTPUT" == *"<promise>REEDS COMPLETE</promise>"* ]]; then
    echo "Reeds: All tasks complete!"
    sed_inplace "s/^active: true/active: false/" "$STATE_FILE"
    exit 0
  fi
fi

# Increment iteration
NEXT_ITERATION=$((ITERATION + 1))
sed_inplace "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$STATE_FILE"

# Build the re-injection prompt
PROMPT="Continue the Reeds task loop.

## Your Task Loop

Work through ALL Beads tasks using this exact process:

### For Each Task:
1. Run: \`bd ready --limit 1\`
2. If no tasks returned: Output \`<promise>REEDS COMPLETE</promise>\` and stop
3. Extract the task ID from the output
4. Run: \`bd show <task-id>\` to get full details
5. Use the **task-implementer agent** to implement the task
   - Pass the task title and description to the agent
   - Wait for the agent to complete and return its summary
6. Run: \`bd close <task-id> --reason \"<summary from agent>\"\`
7. Go back to step 1

### Rules
- Use the task-implementer agent for ALL implementation work
- Do NOT implement tasks directly - always delegate to the agent
- Continue until no ready tasks remain

### Start Now
Run: \`bd ready --limit 1\`"

SYSTEM_MSG="Reeds iteration $NEXT_ITERATION/$MAX_ITERATIONS | To complete: output <promise>REEDS COMPLETE</promise> when bd ready returns nothing"

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
