---
description: "Migrate PRDs from old .prdx/prds to ~/.claude/plans"
---

# /prdx:migrate - Migrate to Native Plans Directory

Migrates PRDX files from the old `.prdx/prds/` location to Claude's native `~/.claude/plans/` directory with the `prdx-` prefix.

## What Gets Migrated

| Old Location | New Location |
|--------------|--------------|
| `.prdx/prds/*.md` | `~/.claude/plans/prdx-*.md` |
| `.prdx/workflow.json` | `.prdx/state/{slug}.json` |

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

### Step 5: Migrate workflow.json to Per-PRD State Files

Check if the legacy `.prdx/workflow.json` exists:

```bash
WORKFLOW_JSON=".prdx/workflow.json"
```

If it exists:

1. Read the file and extract the `slug` field:
   ```bash
   SLUG=$(cat .prdx/workflow.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('slug',''))" 2>/dev/null)
   ```

2. If the slug is non-empty, create the per-PRD state file:
   ```bash
   mkdir -p .prdx/state
   cp .prdx/workflow.json .prdx/state/${SLUG}.json
   ```

3. If the slug is empty or the file cannot be parsed, warn the user:
   ```
   Warning: .prdx/workflow.json found but could not extract a slug.
   Please manually copy it to .prdx/state/{your-slug}.json.
   ```

4. After successful copy, ask the user whether to remove the old file using **AskUserQuestion**:
   ```
   Question: "workflow.json migrated to .prdx/state/{SLUG}.json. Remove .prdx/workflow.json?"
   Header: "Cleanup legacy workflow.json"
   Options:
     - Label: "Yes, remove (Recommended)"
       Description: "Delete .prdx/workflow.json to avoid confusion"
     - Label: "No, keep as backup"
       Description: "Keep the old file alongside the new state file"
   ```

   If the user confirms removal:
   ```bash
   rm .prdx/workflow.json
   ```

If `.prdx/workflow.json` does not exist, skip this step silently.

### Step 7: Display Summary

```
Migration Complete!

Migrated:
  {COUNT} PRDs → ~/.claude/plans/prdx-*.md
  {If workflow.json migrated:} .prdx/workflow.json → .prdx/state/{slug}.json

{If cleanup was done:}
Removed:
  .prdx/prds/
  {If workflow.json removed:} .prdx/workflow.json

Your PRDs are now in Claude's native plans directory.
State files are now per-PRD in .prdx/state/.
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
