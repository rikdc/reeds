#!/usr/bin/env bash
set -euo pipefail

max_iterations=0

while [[ $# -gt 0 ]]; do
    case $1 in
        -h | --help)
            cat << 'EOF'
Reeds - Autonomous Beads Task Execution

Usage: /reeds-start [--max-iterations N]

Starts an autonomous loop that works through all ready Beads tasks.
Claude will query `bd ready`, implement each task, close it, and continue
until no tasks remain.

Options:
  --max-iterations N   Stop after N iterations (default: unlimited)
  -h, --help          Show this help

To stop: Output "REEDS COMPLETE" when all tasks are done.
To cancel: Run /reeds-cancel
EOF
            exit 0
            ;;
        --max-iterations)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --max-iterations requires a value" >&2
                exit 1
            fi
            if [[ ! "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: --max-iterations must be a positive integer" >&2
                exit 1
            fi
            max_iterations="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if ! command -v bd &> /dev/null; then
    echo "Error: Beads CLI (bd) not found" >&2
    exit 1
fi

if ! bd stats &> /dev/null; then
    echo "Error: Beads not initialized. Run: bd init" >&2
    exit 1
fi

mkdir -p .claude

cat > .claude/reeds-state.local.md << 'STATEFILE'
---
iteration: 1
max_iterations: MAX_ITERATIONS_PLACEHOLDER
---

You are in Reeds autonomous mode. Your job is to work through ALL tasks in the Beads backlog.

## Your Loop

Repeat these steps until done:

1. **Query for next task:**
   ```bash
   bd ready --limit 1
   ```

2. **If no tasks returned:** Output "REEDS COMPLETE" and stop.

3. **If a task is returned:**
   - Read the task details with `bd show <task-id>`
   - Implement the task fully
   - Verify your work (build, test if applicable)
   - Close the task: `bd close <task-id> --reason "Completed: brief summary"`

4. **Go back to step 1** to get the next task.

## Rules

- Work autonomously - do not ask for permission or confirmation
- Implement each task completely before moving to the next
- Close each task with `bd close` before querying for the next
- Only output "REEDS COMPLETE" when `bd ready` returns no tasks
- If you encounter an error, try to fix it and continue

## Start Now

Query `bd ready --limit 1` to get your first task.
STATEFILE

sed -i.bak "s/MAX_ITERATIONS_PLACEHOLDER/$max_iterations/" .claude/reeds-state.local.md
rm -f .claude/reeds-state.local.md.bak

ready_count=$(bd ready --json 2> /dev/null | jq 'length' || echo "0")

cat << EOF
Reeds loop activated!

Ready tasks: $ready_count
Max iterations: $(if [[ $max_iterations -gt 0 ]]; then echo "$max_iterations"; else echo "unlimited"; fi)

Starting autonomous task execution...

EOF

awk '/^---$/{i++; next} i>=2' .claude/reeds-state.local.md
