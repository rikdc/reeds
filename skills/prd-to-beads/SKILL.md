---
name: prd-to-beads
description: "Convert PRDs to Beads tasks for Reeds autonomous execution. Creates an epic with child beads for each user story. Triggers on: create beads, convert prd to beads, prd to tasks."
---

# PRD to Beads

Converts PRDs to Beads (epic + child tasks) for Reeds autonomous execution.

> Adapted from [ralph-tui](https://github.com/human-ui/ralph-tui) (MIT License).

---

## The Job

Take a PRD (markdown file or text) and create beads in `.beads/beads.jsonl`:

1. **Extract Quality Gates** from the PRD's "Quality Gates" section
2. Create an **epic** bead for the feature
3. Create **child beads** for each user story (with quality gates appended)
4. Set up **dependencies** between beads (schema → backend → UI)
5. Output ready for `/reeds-start`

---

## Step 1: Extract Quality Gates

Look for the "Quality Gates" section in the PRD:

```markdown
## Quality Gates

These commands must pass for every user story:
- `make test` - Run tests
- `make lint` - Linting

For UI stories, also include:
- Manual browser verification
```

Extract:

- **Universal gates:** Commands that apply to ALL stories (e.g., `make test`)
- **UI gates:** Commands that apply only to UI stories (e.g., browser verification)

**If no Quality Gates section exists:** Ask the user what commands should pass, or use a sensible default like `go test ./...`.

---

## Output Format

Beads use `bd create` command with **HEREDOC syntax** to safely handle special characters:

```bash
# Create epic (link back to source PRD)
bd create --type=epic \
  --title="[Feature Name]" \
  --description="$(cat <<'EOF'
[Feature description from PRD]
EOF
)" \
  --external-ref="prd:./path/to/prd.md"

# Create child bead (with quality gates in acceptance criteria)
bd create \
  --parent=EPIC_ID \
  --title="[Story Title]" \
  --description="$(cat <<'EOF'
[Story description with acceptance criteria INCLUDING quality gates]
EOF
)" \
  --priority=[1-4]
```

> **CRITICAL:** Always use `<<'EOF'` (single-quoted) for the HEREDOC delimiter. This prevents shell interpretation of backticks, `$variables`, and `()` in descriptions.

---

## Story Size: The #1 Rule

**Each story must be completable in ONE Reeds iteration (~one agent context window).**

Reeds spawns a fresh agent instance per iteration with no memory of previous work. If a story is too big, the agent runs out of context before finishing.

### Right-sized stories

- Add a database column + migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

### Too big (split these)

- "Build the entire dashboard" → Split into: schema, queries, UI components, filters
- "Add authentication" → Split into: schema, middleware, login UI, session handling
- "Refactor the API" → Split into one story per endpoint or pattern

**Rule of thumb:** If you can't describe the change in 2-3 sentences, it's too big.

---

## Story Ordering: Dependencies First

Stories execute in dependency order. Earlier stories must not depend on later ones.

**Correct order:**

1. Schema/database changes (migrations)
2. Server actions / backend logic
3. UI components that use the backend
4. Dashboard/summary views that aggregate data

**Wrong order:**

1. UI component (depends on schema that doesn't exist yet)
2. Schema change

---

## Dependencies with `bd dep add`

Use the `bd dep add` command to specify which beads must complete first:

```bash
# Create the beads first
bd create --parent=epic-123 --title="US-001: Add schema" ...
bd create --parent=epic-123 --title="US-002: Create API" ...
bd create --parent=epic-123 --title="US-003: Build UI" ...

# Then add dependencies (issue depends-on blocker)
bd dep add reeds-002 reeds-001  # US-002 depends on US-001
bd dep add reeds-003 reeds-002  # US-003 depends on US-002
```

**Syntax:** `bd dep add <issue> <depends-on>` — the issue depends on (is blocked by) depends-on.

Reeds will:

- Show blocked beads as "blocked" until dependencies complete
- Never select a bead for execution while its dependencies are open
- Include dependency context in the prompt when working on a bead

**Correct dependency order:**

1. Schema/database changes (no dependencies)
2. Backend logic (depends on schema)
3. UI components (depends on backend)
4. Integration/polish (depends on UI)

---

## Acceptance Criteria: Quality Gates + Story-Specific

Each bead's description should include acceptance criteria with:

1. **Story-specific criteria** from the PRD (what this story accomplishes)
2. **Quality gates** from the PRD's Quality Gates section (appended at the end)

### Good criteria (verifiable)

- "Add `status` column to orders table with default 'pending'"
- "Filter dropdown has options: All, Pending, Complete"
- "Clicking toggle shows confirmation dialog"

### Bad criteria (vague)

- "Works correctly"
- "User can do X easily"
- "Good UX"
- "Handles edge cases"

---

## Conversion Rules

1. **Extract Quality Gates** from PRD first
2. **Each user story → one bead**
3. **First story**: No dependencies (creates foundation)
4. **Subsequent stories**: Depend on their predecessors (UI depends on backend, etc.)
5. **Priority**: Based on dependency order, then document order (1=critical, 2=high, 3=medium, 4=low)
6. **All stories**: `status: "open"`
7. **Acceptance criteria**: Story criteria + quality gates appended
8. **UI stories**: Also append UI-specific gates (browser verification)

---

## Splitting Large PRDs

If a PRD has big features, split them:

**Original:**
> "Add order tracking with status updates"

**Split into:**

1. US-001: Add status field to orders table
2. US-002: Add status enum type and migration
3. US-003: Create status update endpoint
4. US-004: Add status badge to order list UI
5. US-005: Add status filter dropdown
6. US-006: Update order detail page with status
7. US-007: Add status change history

Each is one focused change that can be completed and verified independently.

---

## Example

**Input PRD:**

```markdown
# PRD: Order Status Tracking

Add ability to track order status through lifecycle.

## Quality Gates

These commands must pass for every user story:
- `make test` - Run tests
- `make lint` - Linting

For UI stories, also include:
- Manual browser verification

## User Stories

### US-001: Add status field to orders table
**Description:** As a developer, I need to track order status.

**Acceptance Criteria:**
- [ ] Add status column: 'pending' | 'processing' | 'complete' (default 'pending')
- [ ] Generate and run migration successfully

### US-002: Add status badge to order list
**Description:** As a user, I want to see order status in the list.

**Acceptance Criteria:**
- [ ] Each row shows status badge with color
- [ ] Badge colors: pending=yellow, processing=blue, complete=green

### US-003: Filter orders by status
**Description:** As a user, I want to filter orders by status.

**Acceptance Criteria:**
- [ ] Filter dropdown: All | Pending | Processing | Complete
- [ ] Filter persists in URL params
```

**Output beads:**

```bash
# Create epic (link back to source PRD)
bd create --type=epic \
  --title="Order Status Tracking" \
  --description="$(cat <<'EOF'
Track order status through lifecycle
EOF
)" \
  --external-ref="prd:./docs/order-status-prd.md"

# US-001: No deps (first - creates schema)
bd create --parent=reeds-abc \
  --title="US-001: Add status field to orders table" \
  --description="$(cat <<'EOF'
As a developer, I need to track order status.

## Acceptance Criteria
- [ ] Add status column: 'pending' | 'processing' | 'complete' (default 'pending')
- [ ] Generate and run migration successfully
- [ ] make test passes
- [ ] make lint passes
EOF
)" \
  --priority=1

# US-002: UI story (gets browser verification too)
bd create --parent=reeds-abc \
  --title="US-002: Add status badge to order list" \
  --description="$(cat <<'EOF'
As a user, I want to see order status in the list.

## Acceptance Criteria
- [ ] Each row shows status badge with color
- [ ] Badge colors: pending=yellow, processing=blue, complete=green
- [ ] make test passes
- [ ] make lint passes
- [ ] Manual browser verification
EOF
)" \
  --priority=2

# Add dependency: US-002 depends on US-001
bd dep add reeds-002 reeds-001

# US-003: UI story
bd create --parent=reeds-abc \
  --title="US-003: Filter orders by status" \
  --description="$(cat <<'EOF'
As a user, I want to filter orders by status.

## Acceptance Criteria
- [ ] Filter dropdown: All | Pending | Processing | Complete
- [ ] Filter persists in URL params
- [ ] make test passes
- [ ] make lint passes
- [ ] Manual browser verification
EOF
)" \
  --priority=3

# Add dependency: US-003 depends on US-002
bd dep add reeds-003 reeds-002
```

---

## Output Location

Beads are written to: `.beads/beads.jsonl`

After creation, start Reeds:

```bash
/reeds-start
```

Reeds will:

1. Query `bd ready --limit 1` for the next task
2. Close each bead when complete
3. Output `REEDS COMPLETE` when all tasks are done

---

## Checklist Before Creating Beads

- [ ] Extracted Quality Gates from PRD (or asked user if missing)
- [ ] Each story is completable in one iteration (small enough)
- [ ] Stories are ordered by dependency (schema → backend → UI)
- [ ] Quality gates appended to every bead's acceptance criteria
- [ ] UI stories have browser verification (if specified in Quality Gates)
- [ ] Acceptance criteria are verifiable (not vague)
- [ ] No story depends on a later story (only earlier stories)
- [ ] Dependencies added with `bd dep add` after creating beads
