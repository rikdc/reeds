---
description: "Show Reeds loop status"
allowed-tools: ["Bash(cat:*)", "Bash(bd:*)", "Bash(head:*)"]
---

# Reeds Status

Show current Reeds/Ralph loop state and Beads status:

```!
echo "=== Ralph Loop Status ==="
if [[ -f ".claude/ralph-loop.local.md" ]]; then
    echo "Ralph Loop: ACTIVE"
    head -10 ".claude/ralph-loop.local.md"
else
    echo "Ralph Loop: not active"
fi

echo ""
echo "=== Beads Status ==="
if command -v bd &> /dev/null && bd stats &> /dev/null 2>&1; then
    echo "Ready tasks:   $(bd ready --json 2>/dev/null | jq 'length' 2>/dev/null || echo 0)"
    echo "Blocked tasks: $(bd blocked --json 2>/dev/null | jq 'length' 2>/dev/null || echo 0)"
    echo "Total tasks:   $(bd list --json 2>/dev/null | jq 'length' 2>/dev/null || echo 0)"
else
    echo "Beads not initialized"
fi
```
