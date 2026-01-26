#!/usr/bin/env bash

set -euo pipefail

hook_input=$(cat)

reeds_state_file=".claude/reeds-state.local.md"

# Safe file removal - only remove regular files, not symlinks
safe_rm() {
    local file="$1"
    if [[ -f "$file" && ! -L "$file" ]]; then
        rm "$file"
    fi
}

if [[ ! -f "$reeds_state_file" ]]; then
    exit 0
fi

# Reject symlinks to prevent symlink attacks
if [[ -L "$reeds_state_file" ]]; then
    echo "Reeds: State file is a symlink. Refusing to process." >&2
    exit 1
fi

frontmatter=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$reeds_state_file")
iteration=$(echo "$frontmatter" | grep '^iteration:' | sed 's/iteration: *//')
max_iterations=$(echo "$frontmatter" | grep '^max_iterations:' | sed 's/max_iterations: *//')

if [[ ! "$iteration" =~ ^[0-9]+$ ]]; then
    echo "Reeds: State file corrupted (iteration). Stopping." >&2
    safe_rm "$reeds_state_file"
    exit 0
fi

if [[ ! "$max_iterations" =~ ^[0-9]+$ ]]; then
    echo "Reeds: State file corrupted (max_iterations). Stopping." >&2
    safe_rm "$reeds_state_file"
    exit 0
fi

if [[ $max_iterations -gt 0 ]] && [[ $iteration -ge $max_iterations ]]; then
    echo "Reeds: Max iterations ($max_iterations) reached." >&2
    safe_rm "$reeds_state_file"
    exit 0
fi

transcript_path=$(echo "$hook_input" | jq --raw-output '.transcript_path')

# Validate transcript path - must be non-empty and end with expected extension
if [[ -z "$transcript_path" || "$transcript_path" == "null" ]]; then
    echo "Reeds: No transcript path provided. Stopping." >&2
    safe_rm "$reeds_state_file"
    exit 0
fi

# Prevent path traversal attacks
if [[ "$transcript_path" == *".."* ]]; then
    echo "Reeds: Invalid transcript path (path traversal detected). Stopping." >&2
    safe_rm "$reeds_state_file"
    exit 1
fi

if [[ ! -f "$transcript_path" ]]; then
    echo "Reeds: Transcript not found. Stopping." >&2
    safe_rm "$reeds_state_file"
    exit 0
fi

if ! grep --quiet '"role":"assistant"' "$transcript_path"; then
    echo "Reeds: No assistant messages. Stopping." >&2
    safe_rm "$reeds_state_file"
    exit 0
fi

last_line=$(grep '"role":"assistant"' "$transcript_path" | tail -1)
last_output=$(echo "$last_line" | jq --raw-output '
  .message.content |
  map(select(.type == "text")) |
  map(.text) |
  join("\n")
' 2> /dev/null || echo "")

if echo "$last_output" | grep --quiet --extended-regexp "(REEDS COMPLETE|ALL TASKS COMPLETE)"; then
    echo "Reeds: All tasks complete!" >&2
    safe_rm "$reeds_state_file"
    exit 0
fi

next_iteration=$((iteration + 1))

prompt_text=$(awk '/^---$/{i++; next} i>=2' "$reeds_state_file")

if [[ -z "$prompt_text" ]]; then
    echo "Reeds: No prompt in state file. Stopping." >&2
    safe_rm "$reeds_state_file"
    exit 0
fi

# Use mktemp for secure temp file creation
temp_file=$(mktemp "${reeds_state_file}.XXXXXX")
trap 'rm -f "$temp_file"' EXIT

sed "s/^iteration: .*/iteration: $next_iteration/" "$reeds_state_file" > "$temp_file"
mv "$temp_file" "$reeds_state_file"

# Clear trap since file was successfully moved
trap - EXIT

system_msg="Reeds iteration $next_iteration | Continue working through Beads tasks | Output REEDS COMPLETE when bd ready returns no tasks"

jq --null-input \
    --arg prompt "$prompt_text" \
    --arg msg "$system_msg" \
    '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
