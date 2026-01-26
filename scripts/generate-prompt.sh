#!/usr/bin/env bash
set -euo pipefail

task_json="$1"

id=$(echo "$task_json" | jq --raw-output '.id')
task_type=$(echo "$task_json" | jq --raw-output '.issue_type // .type // "task"')
priority=$(echo "$task_json" | jq --raw-output '.priority // 2')
title=$(echo "$task_json" | jq --raw-output '.title')
description=$(echo "$task_json" | jq --raw-output '.description // ""')
acceptance=$(echo "$task_json" | jq --raw-output '.acceptance_criteria // ""')

template_file="${CLAUDE_PLUGIN_ROOT}/templates/task-prompt.md"

if [[ -f "$template_file" ]]; then
    awk -v id="$id" \
        -v type="$task_type" \
        -v priority="$priority" \
        -v title="$title" '
    {
        gsub(/{id}/, id)
        gsub(/{type}/, type)
        gsub(/{priority}/, priority)
        gsub(/{title}/, title)
        print
    }' "$template_file"

    echo ""
    echo "### Description"
    echo "$description"
    echo ""
    echo "### Acceptance Criteria"
    echo "$acceptance"
else
    cat << EOF
## Current Task: $id

**Type**: $task_type
**Priority**: P$priority
**Title**: $title

### Description
$description

### Acceptance Criteria
$acceptance

### Instructions
1. Implement this task completely
2. Run verification gates when done (build, test)
3. Update the task in Beads when complete
4. Output <promise>TASK COMPLETE</promise> when finished

### Completion Rules
- Only claim completion when the task is GENUINELY done
- All acceptance criteria must be met
- Verification gates must pass
- Do NOT output false promises to exit the loop
EOF
fi
