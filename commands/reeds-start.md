---
description: "Start Reeds autonomous task loop"
argument-hint: "[--max-iterations N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-reeds.sh:*)", "Bash(bd:*)", "Task"]
---

# Reeds Start

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-reeds.sh" $ARGUMENTS
```

## Your Task Loop

Work through ALL Beads tasks using this exact process:

### For Each Task:
1. Run: `bd ready --limit 1`
2. If no tasks returned: Output `<promise>REEDS COMPLETE</promise>` and stop
3. Extract the task ID from the output
4. Run: `bd show <task-id>` to get full details
5. Use the **task-implementer agent** to implement the task
   - Pass the task title and description to the agent
   - Wait for the agent to complete and return its summary
6. Run: `bd close <task-id> --reason "<summary from agent>"`
7. Go back to step 1

### Rules
- Use the task-implementer agent for ALL implementation work
- Do NOT implement tasks directly - always delegate to the agent
- The agent handles implementation; you handle orchestration
- Continue until no ready tasks remain

### Start Now
Run: `bd ready --limit 1`
