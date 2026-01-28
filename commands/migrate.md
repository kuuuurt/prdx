---
description: "Migrate PRDs from old .prdx/prds to ~/.claude/plans"
---

# /prdx:migrate - Migrate to Native Plans Directory

Migrates PRDX files from the old `.prdx/prds/` location to Claude's native `~/.claude/plans/` directory with the `prdx-` prefix.

## What Gets Migrated

| Old Location | New Location |
|--------------|--------------|
| `.prdx/prds/*.md` | `~/.claude/plans/prdx-*.md` |

## Usage

```bash
/prdx:migrate
```

## How It Works

### Step 1: Check for Files to Migrate

Check if there are files in the old location:

```bash
OLD_PRDS_COUNT=$(ls -1 .prdx/prds/*.md 2>/dev/null | wc -l)
```

If none exist, inform user:
```
Nothing to migrate.

Old location: .prdx/prds/ (not found or empty)

Your PRDs may already be in ~/.claude/plans/ with prdx-* prefix.
```

### Step 2: Ensure Target Directory Exists

```bash
mkdir -p ~/.claude/plans
```

### Step 3: Migrate Each PRD

For each file in `.prdx/prds/`:

1. Extract the slug from filename
2. Copy to new location with `prdx-` prefix:
   ```bash
   cp .prdx/prds/backend-auth.md ~/.claude/plans/prdx-backend-auth.md
   ```

### Step 4: Ask About Cleanup

After successful migration, use **AskUserQuestion**:

```
Question: "Migration complete. Remove old .prdx/prds/ directory?"
Header: "Cleanup"
Options:
  - Label: "Yes, remove old files (Recommended)"
    Description: "Delete .prdx/prds/ to avoid confusion"
  - Label: "No, keep both"
    Description: "Keep old files as backup"
```

If user chooses to remove:
```bash
rm -rf .prdx/prds
```

### Step 5: Display Summary

```
Migration Complete!

Migrated:
  {COUNT} PRDs → ~/.claude/plans/prdx-*.md

{If cleanup was done:}
Removed:
  .prdx/prds/

Your PRDs are now in Claude's native plans directory.
```

## Error Handling

### Permission Denied

```
Permission denied

Could not write to ~/.claude/plans/ directory.
Check folder permissions and try again.
```

### Partial Migration

If some files fail to copy:

```
Partial migration

Successfully migrated:
- {list of successful files}

Failed to migrate:
- {list of failed files with reasons}

Please check the failed files and migrate them manually.
```
