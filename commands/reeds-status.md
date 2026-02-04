---
description: "Show Reeds loop status"
allowed-tools: ["Bash(cat:*)", "Bash(bd:*)", "Bash(head:*)"]
---

# Reeds Status

Show current Reeds loop state and Beads status:

```!
echo "=== Reeds Loop Status ==="
if [[ -f ".claude/reeds-state.local.md" ]]; then
    echo "Reeds Loop: ACTIVE"
    head -10 ".claude/reeds-state.local.md"
else
    echo "Reeds Loop: not active"
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
