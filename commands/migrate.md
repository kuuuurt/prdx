---
description: "Migrate PRDs and config from .claude to .prdx folder"
---

# /prdx:migrate - Migrate to New Folder Structure

Migrates PRDX files from the old `.claude/` location to the new `.prdx/` folder.

## What Gets Migrated

| Old Location | New Location |
|--------------|--------------|
| `.claude/prds/` | `.prdx/prds/` |
| `.claude/prdx.json` | `.prdx/prdx.json` |

## Usage

```bash
/prdx:migrate
```

## How It Works

### Step 1: Check for Existing Files

Check if there are files to migrate:

```bash
# Check for old PRDs directory
OLD_PRDS_EXISTS=$([ -d ".claude/prds" ] && echo "yes" || echo "no")

# Check for old config file
OLD_CONFIG_EXISTS=$([ -f ".claude/prdx.json" ] && echo "yes" || echo "no")
```

If neither exists, inform user:
```
Nothing to migrate.

Old locations checked:
- .claude/prds/ (not found)
- .claude/prdx.json (not found)

Your project may already be using the new .prdx/ structure,
or PRDX hasn't been used in this project yet.
```

### Step 2: Check for Conflicts

Before migrating, check if new locations already have files:

```bash
# Check for existing .prdx directory
NEW_PRDS_EXISTS=$([ -d ".prdx/prds" ] && echo "yes" || echo "no")
NEW_CONFIG_EXISTS=$([ -f ".prdx/prdx.json" ] && echo "yes" || echo "no")
```

If conflicts exist, use **AskUserQuestion**:

```
Question: "Found existing files in .prdx/. How should we handle conflicts?"
Header: "Conflicts"
Options:
  - Label: "Skip existing"
    Description: "Only migrate files that don't already exist in .prdx/"
  - Label: "Overwrite"
    Description: "Replace existing .prdx/ files with ones from .claude/"
  - Label: "Cancel"
    Description: "Don't migrate anything, I'll handle it manually"
```

### Step 3: Create New Directory Structure

```bash
mkdir -p .prdx/prds
```

### Step 4: Migrate PRDs

If `.claude/prds/` exists and has files:

```bash
# Count PRDs to migrate
PRD_COUNT=$(ls -1 .claude/prds/*.md 2>/dev/null | wc -l)

if [ "$PRD_COUNT" -gt 0 ]; then
  # Copy PRDs (or move based on user preference)
  cp .claude/prds/*.md .prdx/prds/
fi
```

### Step 5: Migrate Config

If `.claude/prdx.json` exists:

```bash
cp .claude/prdx.json .prdx/prdx.json
```

### Step 6: Update .gitignore

Check if `.gitignore` needs updating:

```bash
# Check if old pattern exists
if grep -q "\.claude/prds" .gitignore 2>/dev/null; then
  # Add new pattern if not already present
  if ! grep -q "\.prdx/prds" .gitignore 2>/dev/null; then
    echo ".prdx/prds/" >> .gitignore
  fi
fi
```

### Step 7: Ask About Cleanup

After successful migration, use **AskUserQuestion**:

```
Question: "Migration complete. Remove old .claude/prds/ and .claude/prdx.json?"
Header: "Cleanup"
Options:
  - Label: "Yes, remove old files (Recommended)"
    Description: "Delete .claude/prds/ and .claude/prdx.json to avoid confusion"
  - Label: "No, keep both"
    Description: "Keep old files as backup (you can delete them later)"
```

If user chooses to remove:

```bash
rm -rf .claude/prds
rm -f .claude/prdx.json
```

### Step 8: Display Summary

```
✅ Migration Complete!

Migrated:
  📁 {PRD_COUNT} PRDs → .prdx/prds/
  ⚙️  Config → .prdx/prdx.json

{If cleanup was done:}
Removed:
  🗑️  .claude/prds/
  🗑️  .claude/prdx.json

{If .gitignore was updated:}
Updated:
  📝 .gitignore (added .prdx/prds/)

Your PRDX files are now in the .prdx/ folder.
```

## Error Handling

### Permission Denied

```
❌ Permission denied

Could not write to .prdx/ directory.
Check folder permissions and try again.
```

### Partial Migration

If some files fail to copy:

```
⚠️  Partial migration

Successfully migrated:
- {list of successful files}

Failed to migrate:
- {list of failed files with reasons}

Please check the failed files and migrate them manually.
```
