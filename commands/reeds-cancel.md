---
description: "Cancel Reeds loop"
allowed-tools: ["Bash(rm:*)", "Bash(cat:*)"]
---

# Reeds Cancel

Cancel the active Reeds loop:

```!
if [[ -f ".claude/reeds-state.local.md" ]]; then
    echo "Cancelling Reeds loop..."
    cat ".claude/reeds-state.local.md" | head -15
    rm ".claude/reeds-state.local.md"
    echo ""
    echo "Reeds loop cancelled"
else
    echo "No active Reeds loop"
fi
```
