---
description: "Start Reeds autonomous task loop"
argument-hint: "[--max-iterations N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-reeds.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/set-current-task.sh:*)", "Bash(bd:*)", "Task"]
---

# Reeds Start

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-reeds.sh" $ARGUMENTS
```

## Your Task Loop

Work through Beads tasks ONE AT A TIME with multiple iterations per task.

### For Each Task:

1. **Get task**: Run `bd ready --limit 1`
   - If no tasks: Output `<promise>REEDS COMPLETE</promise>` and stop

2. **Set current task**: Run `"${CLAUDE_PLUGIN_ROOT}/scripts/set-current-task.sh" <task-id>`

3. **Get details**: Run `bd show <task-id>`

4. **Implement**: Use the **task-implementer agent** to work on the task
   - The agent will iterate multiple times until the task is complete
   - Each iteration, the stop hook will re-invoke the agent to continue

5. **When complete**: Output `<promise>TASK COMPLETE: <task-id></promise>`

6. **Close task**: Run `bd close <task-id> --reason "<summary>"`

7. **Repeat**: Go back to step 1

### Important Rules

- ONE task at a time - do not get a new task until current is complete
- Use the task-implementer agent for ALL implementation work
- Output `<promise>TASK COMPLETE: <task-id></promise>` when a task is FULLY done
- Output `<promise>REEDS COMPLETE</promise>` when NO tasks remain
- The stop hook will keep you iterating on the current task until complete

### Start Now

Run: `bd ready --limit 1`
