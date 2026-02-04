# Reeds

Autonomous multi-task development loops powered by Beads issue tracking and subagent isolation.

## What is Reeds?

Reeds connects [Beads](https://github.com/steveyegge/beads) (git-based issue tracker) with Claude's Task tool for autonomous task execution. It provides:

- **Task Orchestration**: Main agent queries Beads for ready tasks
- **Subagent Isolation**: Each task is implemented by a fresh subagent (no context pollution)
- **Iteration Control**: Own stop hook handles looping
- **Dependency Awareness**: Respects Beads' dependency system

## Architecture

```
Main Agent (orchestrator)
  │
  ├─→ bd ready --limit 1 (get next task)
  │
  ├─→ bd show <task-id> (get details)
  │
  ├─→ Task tool → task-implementer agent
  │     │
  │     └─→ Implements task in isolated context
  │         Returns summary when done
  │
  ├─→ bd close <task-id> --reason "summary"
  │
  ├─→ Output: <promise>TASK COMPLETE: <id></promise>
  │
  └─→ Claude attempts to stop...
        │
        └─→ Stop Hook intercepts
              │
              ├─→ Parses transcript for promises
              ├─→ Increments iteration counter
              ├─→ Re-injects prompt: "Get next task"
              │
              └─→ Loop continues until REEDS COMPLETE
```

## Prerequisites

- Claude Code CLI installed
- [Beads](https://github.com/steveyegge/beads) initialized in your project (`bd init`)
- `bd` CLI available in PATH
- `jq` for JSON processing

## Installation

```bash
cd ~/.claude/plugins
git clone https://github.com/rikdc/reeds
```

Restart Claude Code to load the plugin.

## Usage

### Start a Loop

```text
/reeds:reeds-start [--max-iterations N]
```

This will:
1. Validate Beads is initialized
2. Show ready task count
3. Start the autonomous task loop

Options:
- `--max-iterations N` - Stop after N iterations (default: 30)

### Check Status

```text
/reeds:reeds-status
```

Shows Reeds loop state and Beads task statistics.

### Cancel Loop

```text
/reeds:reeds-cancel
```

Stops the autonomous loop by setting the state file to inactive.

## How It Works

1. **Setup**: `/reeds:reeds-start` creates `.claude/reeds-state.local.md` with iteration tracking
2. **Orchestration**: Main agent runs `bd ready` to get tasks
3. **Delegation**: Each task is passed to the `task-implementer` subagent
4. **Isolation**: Subagent runs in clean context, implements task, returns summary
5. **Closure**: Main agent runs `bd close` with the summary
6. **Iteration**: Stop hook detects when Claude tries to stop, re-injects loop prompt
7. **Completion**: Loop ends when `bd ready` returns nothing

## How Iteration Control Works

Reeds uses a **promise protocol** and a **stop hook** to maintain the autonomous loop across multiple agent turns.

### Promise Markers

The orchestrator outputs special markers that the stop hook detects:

| Marker | Meaning |
|--------|---------|
| `<promise>TASK COMPLETE: <id></promise>` | Current task finished, get next task |
| `<promise>REEDS COMPLETE</promise>` | No more tasks, terminate loop |

### Stop Hook Behavior

When Claude attempts to stop, the stop hook (`scripts/stop-hook.sh`) intercepts:

1. **Parses the transcript** for promise markers
2. **If TASK COMPLETE**: Clears current task, re-injects prompt to get next task
3. **If REEDS COMPLETE**: Sets state to inactive, allows exit
4. **If neither**: Re-injects prompt to continue current task
5. **Increments iteration counter** and checks against max

### State Machine

```
┌─────────────┐
│  No Task    │◄───────────────────────────────┐
└──────┬──────┘                                │
       │ bd ready returns task                 │
       ▼                                       │
┌─────────────┐                                │
│ Implementing│──── TASK COMPLETE ────────────►│
└──────┬──────┘                                │
       │ bd ready returns nothing              │
       ▼                                       │
┌─────────────┐                                │
│   Complete  │ REEDS COMPLETE → exit          │
└─────────────┘
```

## Example Workflow

```bash
# Initialize a project with Beads
cd my-project
bd init

# Create some tasks
bd create "Set up project structure" --priority 1
bd create "Implement core feature" --priority 2
bd create "Add tests" --priority 3

# Open in Claude Code
claude

# Start the autonomous loop
/reeds:reeds-start --max-iterations 20
```

Claude will work through each task using subagents, closing them as completed, until no ready tasks remain.

## Skills

### /prd-to-beads

Convert a PRD (Product Requirements Document) to Beads tasks:

```text
/prd-to-beads path/to/prd.md
```

Creates an epic with child tasks for each user story, with proper dependencies.

## Project Structure

```text
reeds/
├── .claude-plugin/
│   └── plugin.json       # Plugin manifest
├── agents/
│   └── task-implementer.md  # Subagent for task implementation
├── commands/
│   ├── reeds-start.md    # Start command
│   ├── reeds-status.md   # Status command
│   └── reeds-cancel.md   # Cancel command
├── skills/
│   └── prd-to-beads/     # PRD to Beads conversion skill
├── hooks/
│   └── hooks.json        # Stop hook for iteration control
├── scripts/
│   ├── setup-reeds.sh       # Prerequisites validation & state setup
│   ├── stop-hook.sh         # Iteration control hook
│   └── set-current-task.sh  # Updates state with current task ID
└── README.md
```

## State File Format

Reeds maintains state in `.claude/reeds-state.local.md` with YAML frontmatter:

```yaml
---
active: true                          # Loop is running (true/false)
iteration: 5                          # Current iteration count
max_iterations: 30                    # Stop after this many iterations
current_task_id: "reeds-123"          # Task currently being worked on
started_at: 2024-01-15T10:30:00Z      # When the loop started (ISO 8601)
---
```

| Field | Type | Description |
|-------|------|-------------|
| `active` | boolean | Whether the loop is running |
| `iteration` | integer | Current iteration (incremented by stop hook) |
| `max_iterations` | integer | Safety limit to prevent runaway loops |
| `current_task_id` | string | Beads task ID being implemented (empty between tasks) |
| `started_at` | ISO 8601 | Timestamp when `/reeds:reeds-start` was invoked |

## Troubleshooting

### Loop won't start

- Ensure Beads is initialized: `bd init`
- Check for ready tasks: `bd ready`
- Verify `bd` is in PATH: `which bd`

### Tasks not being picked up

- Ensure tasks are in `open` status: `bd list`
- Check for dependency blocks: `bd blocked`

### Loop stops unexpectedly

- Check Reeds state: `cat .claude/reeds-state.local.md`
- Max iterations may have been reached
- Run `/reeds:reeds-status` for diagnostics

### Task fails verification

If a subagent reports test or build failures:

1. The task remains open in Beads (not closed)
2. Run `/reeds:reeds-cancel` to stop the loop
3. Manually fix the issue
4. Resume with `/reeds:reeds-start`

### Loop gets stuck

If the loop keeps iterating on the same task:

1. Check if `current_task_id` is set: `cat .claude/reeds-state.local.md`
2. Manually close the problematic task: `bd close <task-id> --reason "manually resolved"`
3. Resume with `/reeds:reeds-start`

### Manual state recovery

To reset Reeds state completely:

```bash
rm .claude/reeds-state.local.md
```

To manually adjust iteration count:

```bash
# Edit the state file directly
vim .claude/reeds-state.local.md
# Change iteration: N to a lower number
```

## Acknowledgments

- [ralph-tui](https://github.com/human-ui/ralph-tui) - PRD to Beads skill adapted from here (MIT License)
- [Beads](https://github.com/steveyegge/beads) - Git-based issue tracking

## License

MIT
