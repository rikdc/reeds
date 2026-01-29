# Reeds

Autonomous multi-task development loops powered by Beads issue tracking.

**Ralph Loop + Beads integration for Claude Code.**

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

### Manual Installation

If you prefer symlinks:

```bash
git clone https://github.com/rikdc/reeds ~/tools/reeds
ln -s ~/tools/reeds/reeds ~/.claude/plugins/reeds
```

## Usage

### Start a Loop

```text
/reeds-start [--max-iterations N]
```

Options:

- `--max-iterations N` - Stop after N iterations (default: unlimited)
- `-h, --help` - Show help

### Check Status

```text
/reeds-status
```

Shows current iteration, max iterations, and Beads task statistics.

### Cancel Loop

```text
/reeds-cancel
```

Removes the state file and stops the autonomous loop.

## How It Works

1. `/reeds-start` creates a state file at `.claude/reeds-state.local.md`
2. Claude receives instructions to work through the Beads backlog
3. For each iteration, Claude:
   - Queries `bd ready --limit 1` for the next task
   - Reads task details with `bd show <task-id>`
   - Implements the task fully
   - Closes the task with `bd close <task-id> --reason "..."`
4. When Claude tries to exit, the stop hook intercepts and:
   - Checks if "REEDS COMPLETE" or "ALL TASKS COMPLETE" was output
   - If not, increments the iteration counter and continues the loop
5. Loop ends when:
   - Claude outputs "REEDS COMPLETE" (no more ready tasks)
   - Max iterations reached
   - State file is corrupted or missing

## Task Completion

When all tasks are done and `bd ready` returns nothing, output:

```text
REEDS COMPLETE
```

Or alternatively:

```text
ALL TASKS COMPLETE
```

**Important**: Only output these when genuinely complete. The loop will continue until one of these signals is detected.

## State File

State is stored in `.claude/reeds-state.local.md` with YAML frontmatter:

```yaml
---
iteration: 1
max_iterations: 0
---
```

The body of the file contains the prompt instructions for Claude.

Fields:

- `iteration` - Current iteration number (incremented by stop hook)
- `max_iterations` - Maximum iterations before stopping (0 = unlimited)

## Project Structure

```text
reeds/
├── .claude-plugin/
│   └── plugin.json       # Plugin manifest
├── commands/
│   ├── reeds-start.md    # Start command definition
│   ├── reeds-status.md   # Status command definition
│   └── reeds-cancel.md   # Cancel command definition
├── hooks/
│   ├── hooks.json        # Hook configuration
│   └── stop-hook.sh      # Stop hook script
├── scripts/
│   └── setup-reeds.sh    # Setup script called by /reeds-start
└── README.md             # This file
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
/reeds-start --max-iterations 10
```

Claude will work through each task, closing them as they're completed, until no ready tasks remain.

## Troubleshooting

### Loop won't start

- Ensure Beads is initialized: `bd init`
- Check for ready tasks: `bd ready`
- Verify `bd` is in PATH: `which bd`

### Loop stops unexpectedly

- Check `.claude/reeds-state.local.md` exists
- Look for error messages in Claude's output
- Max iterations may have been reached

### Tasks not being picked up

- Ensure tasks are in `open` status: `bd list`
- Check for dependency blocks: `bd blocked`

## Acknowledgments

The `/prd-to-beads` skill is adapted from [ralph-tui](https://github.com/human-ui/ralph-tui) (MIT License).

## License

MIT
