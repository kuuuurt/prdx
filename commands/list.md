# List PRDs

List all PRDs in the project with optional filtering.

## Usage

```bash
/prdx:list [options]
```

## Options

- `--status <status>` - Filter by status (draft, published, in-progress, in-review, implemented, completed)
- `--platform <platform>` - Filter by platform (backend, android, ios)
- `--all` - Show all PRDs including templates

## Instructions

You are helping the user list and browse PRDs in the `.claude/prds/` directory.

### Steps

1. **Find all PRD files**:
   ```bash
   find .claude/prds -name "*.md" -type f ! -path "*/templates/*"
   ```
   - Exclude files in the `templates/` subdirectory by default
   - If `--all` is specified, include template files

2. **Parse each PRD file** to extract metadata:
   - **Title**: First line starting with `#` (remove the `#` and trim)
   - **Platform**: Extract from metadata line (format: `**Project**: [platform]`)
   - **Status**: Extract from metadata line (format: `**Status**: [status]`)
   - **Created**: Extract from metadata line (format: `**Created**: [date]`)
   - **Issue**: Extract from metadata line if present (format: `**Issue**: #[number]`)
   - **Dependencies**: Extract if present (format: `**Dependencies**: [value]`)
   - **Blocks**: Extract if present (format: `**Blocks**: [value]`)

3. **Apply filters** if specified:
   - If `--status` is provided, only include PRDs with matching status
   - If `--platform` is provided, only include PRDs with matching platform
   - Filters are case-insensitive

4. **Sort PRDs** by created date (newest first)

5. **Display results** in a formatted table:

```
Found 12 PRDs:

BACKEND (3)
┌────────────────────────────────────────┬─────────────┬────────────┬──────────┐
│ Title                                  │ Status      │ Issue      │ Created  │
├────────────────────────────────────────┼─────────────┼────────────┼──────────┤
│ Fix IoT Client Memory Leak             │ completed   │ #215       │ 2025-11-04 │
│ Add Health Check Endpoint              │ in-progress │ -          │ 2025-11-03 │
│ Optimize Database Queries              │ draft       │ -          │ 2025-11-01 │
└────────────────────────────────────────┴─────────────┴────────────┴──────────┘

ANDROID (5)
┌────────────────────────────────────────┬─────────────┬────────────┬──────────┐
│ Title                                  │ Status      │ Issue      │ Created  │
├────────────────────────────────────────┼─────────────┼────────────┼──────────┤
│ Optimize LoginViewModel                │ draft       │ -          │ 2025-11-05 │
│ Production Observability Enhancement   │ in-review   │ #218       │ 2025-11-04 │
│ Extract Reset ViewModels               │ implemented │ #217       │ 2025-11-03 │
│ Feature Bug Fix                  │ completed   │ #219       │ 2025-11-02 │
│ Add Dark Mode Support                  │ draft       │ -          │ 2025-10-30 │
└────────────────────────────────────────┴─────────────┴────────────┴──────────┘

IOS (4)
┌────────────────────────────────────────┬─────────────┬────────────┬──────────┐
│ Title                                  │ Status      │ Issue      │ Created  │
├────────────────────────────────────────┼─────────────┼────────────┼──────────┤
│ SwiftUI Navigation Refactor            │ in-progress │ #220       │ 2025-11-05 │
│ Add Biometric Authentication           │ draft       │ -          │ 2025-11-02 │
│ Fix Map Performance Issues             │ completed   │ #216       │ 2025-10-28 │
│ Add Analytics Framework                │ draft       │ -          │ 2025-10-25 │
└────────────────────────────────────────┴─────────────┴────────────┴──────────┘
```

6. **Summary information**:
   - Show total count and breakdown by platform
   - If filters were applied, mention which filters were used
   - If no PRDs match the filters, show helpful message:
     ```
     No PRDs found matching your filters.

     Try:
     - /prdx:list (show all PRDs)
     - /prdx:list --status draft (show only drafts)
     - /prdx:list --platform android (show Android PRDs)
     ```

## Additional Features

- **Color coding** (optional, if terminal supports it):
  - `draft`: yellow
  - `in-progress`: blue
  - `in-review`: purple
  - `implemented`: green
  - `completed`: gray

- **Show dependencies** if `--verbose` or `-v` flag is provided:
  ```
  Title: Optimize LoginViewModel
  Status: draft
  Dependencies: #215 (Fix Auth0 Token Refresh)
  Blocks: #220 (Complete Auth Refactor)
  ```

## Edge Cases

- If `.claude/prds/` directory doesn't exist, show:
  ```
  No PRDs directory found.

  Create your first PRD with:
  /prdx:plan <feature-description>
  ```

- If a PRD file is malformed (missing metadata), show warning but still include it:
  ```
  ⚠️ android-something.md: Could not parse metadata (showing as draft)
  ```

- Handle PRDs with unconventional naming (e.g., cross-platform PRDs without platform prefix)

## Implementation Notes

- Parse only the first 10 lines of each PRD file for efficiency
- Use bash tools for file operations
- Format tables using Unicode box-drawing characters for clean display
- Keep the command fast (<1 second for up to 50 PRDs)
