---
description: "Start Reeds autonomous task loop"
argument-hint: "[--max-iterations N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-reeds.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Reeds Start Command

Execute the setup script to initialize the Reeds loop:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-reeds.sh" $ARGUMENTS
```

Follow the instructions above. Work through all Beads tasks autonomously.

When `bd ready` returns no tasks, output "REEDS COMPLETE" to exit the loop.
