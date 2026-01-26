---
description: "Show Reeds loop status"
allowed-tools: ["Bash(cat:*)", "Bash(bd:*)", "Bash(head:*)"]
---

# Reeds Status

Show current Reeds state:

```!
if [[ -f ".claude/reeds-state.local.md" ]]; then
    echo "Reeds Active"
    echo ""
    head -20 ".claude/reeds-state.local.md"
    echo ""
    echo "=== Beads Stats ==="
    bd stats 2>/dev/null || echo "Beads not available"
else
    echo "Reeds not active"
fi
```
