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
  └─→ Loop until bd ready returns nothing
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
│   ├── setup-reeds.sh    # Prerequisites validation & state setup
│   └── stop-hook.sh      # Iteration control hook
└── README.md
```

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

## Acknowledgments

- [ralph-tui](https://github.com/human-ui/ralph-tui) - PRD to Beads skill adapted from here (MIT License)
- [Beads](https://github.com/steveyegge/beads) - Git-based issue tracking

## License

MIT
