---
description: "Cancel Reeds loop"
allowed-tools: ["Bash(sed:*)", "Bash(cat:*)", "Bash(rm:*)"]
---

# Reeds Cancel

```!
if [[ -f ".claude/reeds-state.local.md" ]]; then
  sed -i.bak "s/^active: true/active: false/" .claude/reeds-state.local.md
  rm -f .claude/reeds-state.local.md.bak
  echo "Reeds loop cancelled."
  cat .claude/reeds-state.local.md
else
  echo "Reeds is not active."
fi
```
