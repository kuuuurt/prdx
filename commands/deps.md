# Show PRD Dependencies

Display the dependency tree for a specific PRD, showing what it depends on, what depends on it, and related PRDs.

## Usage

```bash
/prdx:deps <slug>
```

## Examples

```bash
/prdx:deps android-219                    # Show dependencies for android-219.md
/prdx:deps backend-auth-refactor          # Show dependencies using slug
```

## Instructions

You are helping the user visualize and understand the dependency relationships for a PRD.

### Steps

1. **Find the PRD file**:
   - Accept either full filename (`android-219.md`) or slug (`android-219`)
   - Search in `.claude/prds/` directory
   - If multiple matches, prompt user to clarify

2. **Parse the PRD metadata**:
   Extract from the metadata line:
   - **Dependencies**: PRDs or issues that must be completed first
   - **Blocks**: PRDs or issues that are waiting on this one
   - **Related**: PRDs that are related but not blocking

   Format examples:
   ```markdown
   **Dependencies**: #215, #218
   **Blocks**: #220, android-profile-refactor
   **Related**: backend-auth-improvements
   ```

3. **Resolve references**:
   - For issue numbers (e.g., `#215`), find the corresponding PRD file
   - For slugs (e.g., `android-profile-refactor`), find the matching PRD
   - If a reference can't be resolved, mark as `[Not Found]`

4. **Build dependency tree**:
   - Start with the current PRD
   - Recursively fetch dependencies and blockers
   - Detect circular dependencies (warn if found)
   - Limit depth to 3 levels to avoid overwhelming output

5. **Display the dependency tree** in a visual format:

```
╔════════════════════════════════════════════════════════════════════════════╗
║  Dependency Tree: android-219 (Optimize LoginViewModel)                   ║
╚════════════════════════════════════════════════════════════════════════════╝

DEPENDENCIES (What this PRD needs)
────────────────────────────────────────────────────────────────────────────
  ↓ #215: Fix Auth0 Token Refresh (backend)
    Status: completed | Created: 2025-11-03
    └─ No dependencies

  ↓ #218: Add UIState Helper (android)
    Status: in-progress | Created: 2025-11-04
    └─ Depends on: #215 (completed)

────────────────────────────────────────────────────────────────────────────

THIS PRD
────────────────────────────────────────────────────────────────────────────
  📄 android-219: Optimize LoginViewModel
  Platform: android | Status: draft | Created: 2025-11-05

────────────────────────────────────────────────────────────────────────────

BLOCKS (What's waiting on this PRD)
────────────────────────────────────────────────────────────────────────────
  ↑ #220: Complete Auth Refactor (android)
    Status: draft | Created: 2025-11-06
    └─ Also depends on: #218

  ↑ android-signup-refactor: Refactor Signup Flow
    Status: draft | Created: 2025-11-07
    └─ No other dependencies

────────────────────────────────────────────────────────────────────────────

RELATED (Non-blocking relationships)
────────────────────────────────────────────────────────────────────────────
  → backend-auth-improvements: Auth Service Enhancements
    Status: in-review | Created: 2025-11-02

────────────────────────────────────────────────────────────────────────────

SUMMARY
────────────────────────────────────────────────────────────────────────────
Dependencies:  2 PRDs (1 completed, 1 in-progress)
Blocks:        2 PRDs (both waiting on this)
Related:       1 PRD

⚠️  Action required:
  - Complete #218 (in-progress) before starting this PRD
  - 2 PRDs are blocked waiting for this one

✓  Ready to start:
  - All dependencies have been completed or are in progress
```

6. **Provide actionable insights**:

   - **Readiness check**:
     ```
     ✓ Ready to start: All dependencies completed
     ⚠️ Not ready: 2 dependencies still pending
     🔄 Partially ready: Some dependencies complete, others in-progress
     ```

   - **Impact analysis**:
     ```
     High impact: Blocks 3 other PRDs
     Medium impact: Blocks 1 other PRD
     Low impact: No blockers
     ```

   - **Circular dependency warning**:
     ```
     ⚠️  CIRCULAR DEPENDENCY DETECTED:
     android-219 → #220 → android-profile → android-219

     This needs to be resolved before proceeding.
     ```

## Advanced Features

- **Show full tree** with `--full` flag:
  ```bash
  /prdx:deps android-219 --full
  ```
  Shows all levels of dependencies (not just direct ones)

- **Show timeline** with `--timeline` flag:
  ```bash
  /prdx:deps android-219 --timeline
  ```
  Shows dependencies in chronological order based on created dates

- **Export to Mermaid** with `--mermaid` flag:
  ```bash
  /prdx:deps android-219 --mermaid
  ```
  Generates Mermaid diagram code for visualization:
  ```mermaid
  graph TD
    A[android-219] --> B[#215]
    A --> C[#218]
    D[#220] --> A
    E[android-signup] --> A
  ```

## Edge Cases

- **No dependencies**:
  ```
  ╔════════════════════════════════════════════════════════════════╗
  ║  Dependency Tree: android-simple-fix                           ║
  ╚════════════════════════════════════════════════════════════════╝

  📄 android-simple-fix: Fix Button Alignment
  Platform: android | Status: draft

  ✓ No dependencies - ready to start immediately
  ✓ No blockers - low impact change
  ```

- **Unresolved references**:
  ```
  DEPENDENCIES
  ────────────────────────────────────────────────────────────────
  ↓ #999 [Not Found - issue may have been deleted]
  ↓ backend-xyz [Not Found - PRD not in .claude/prds/]
  ```

- **PRD not found**:
  ```
  ❌ PRD not found: android-999

  Did you mean:
  - android-219: Optimize LoginViewModel
  - android-218: Add UIState Helper

  Try: /prdx:search <keyword> or /prdx:list
  ```

## Implementation Notes

- Parse only metadata sections for efficiency
- Cache PRD metadata to avoid re-reading files
- Use tree-drawing characters for visual clarity:
  - `└─` for last item
  - `├─` for middle items
  - `│` for vertical lines
  - `↓` for dependencies (downward)
  - `↑` for blockers (upward)
  - `→` for related (sideways)
- Highlight status with symbols:
  - ✓ completed (green)
  - 🔄 in-progress (blue)
  - ⏳ draft/pending (yellow)

## Integration Suggestions

After showing the dependency tree, suggest next actions:
```
What would you like to do?
- /prdx:dev:start android-219     # Start work (if ready)
- /prdx:update android-219         # Update dependencies
- /prdx:list --status in-progress  # Check dependency status
```
