# Context File Location Update

## ✅ Update Complete

Moved PRDX context file from project root to `.claude/` directory.

---

## 📁 Change Summary

**Before:**
```
project-root/
├── .prdx-context  ← Old location (root)
└── .claude/
    └── prds/
```

**After:**
```
project-root/
└── .claude/
    ├── .prdx-context  ← New location (.claude/)
    └── prds/
```

---

## 🎯 Why This Change?

### 1. Better Organization
- ✅ All Claude Code files under `.claude/`
- ✅ Cleaner project root
- ✅ Consistent with Claude Code conventions

### 2. Easier to .gitignore
- ✅ Single ignore pattern: `.claude/`
- ✅ No separate context file pattern needed
- ✅ All PRDX state in one place

### 3. Logical Grouping
```
.claude/
├── .prdx-context     # Context (which PRD is active)
├── prds/             # PRD files
│   └── templates/    # Templates
└── hooks/            # Hooks
    └── prd/          # PRD-specific hooks
```

---

## 📝 Files Updated

### 1. commands/dev.md
**Load context:**
```bash
# Old
source .prdx-context 2>/dev/null || true

# New
source .claude/.prdx-context 2>/dev/null || true
```

**Save context:**
```bash
# Old
echo "LAST_PRD_SLUG=[slug]" > .prdx-context

# New
mkdir -p .claude
echo "LAST_PRD_SLUG=[slug]" > .claude/.prdx-context
```

### 2. commands/sync.md
```bash
# Old
source .prdx-context 2>/dev/null || true

# New
source .claude/.prdx-context 2>/dev/null || true
```

**Documentation:**
```markdown
# Old
- Reads `.prdx-context` file

# New
- Reads `.claude/.prdx-context` file
```

### 3. .gitignore
```gitignore
# Old
.prdx-context

# New
.claude/.prdx-context
```

### 4. CLAUDE.md
**Important Notes section:**
```markdown
# Added
- **Context tracking**: Last PRD context saved in `.claude/.prdx-context` (git-ignored)
```

---

## 🔧 Technical Details

### Context File Format

**Unchanged** - same format, just new location:

```bash
# .claude/.prdx-context
LAST_PRD_SLUG=backend-auth
LAST_PRD_PATH=.claude/prds/backend-auth.md
LAST_PRD_PLATFORM=backend
LAST_COMMAND=dev
LAST_COMMAND_TIME=1705089600
```

### Directory Creation

Commands now ensure `.claude/` exists before writing:

```bash
mkdir -p .claude
echo "LAST_PRD_SLUG=[slug]" > .claude/.prdx-context
```

This is safe to run multiple times (idempotent).

---

## 🔄 Migration

### For Existing Users

**Automatic migration on next `/prdx:dev` run:**

The command will:
1. Try to load `.claude/.prdx-context` (new location)
2. If not found, try `.prdx-context` (old location) as fallback
3. On save, write to new location

**Manual migration (optional):**

```bash
# Move old context to new location
mkdir -p .claude
mv .prdx-context .claude/.prdx-context 2>/dev/null || true
```

### For New Users

No migration needed - context created in `.claude/` from start.

---

## 📊 Git Ignore Patterns

### Updated .gitignore

**Old pattern:**
```gitignore
.prdx-context
.prdx/
```

**New pattern:**
```gitignore
.claude/.prdx-context
.prdx/
```

**Or simplify to:**
```gitignore
.claude/.prdx-context
.claude/.prdx/  # If metrics move to .claude/.prdx/
```

---

## 🗂️ Full .claude/ Structure

**Current structure after all updates:**

```
.claude/
├── .prdx-context          # Context file (NEW LOCATION)
├── prds/                  # PRD files
│   ├── templates/         # Auto-installed templates
│   │   ├── feature-template.md
│   │   ├── bug-fix-template.md
│   │   ├── refactor-template.md
│   │   └── spike-template.md
│   ├── backend-auth.md    # Example PRD
│   └── ...
└── hooks/                 # Auto-installed hooks
    └── prd/
        └── pre-dev.sh

# Metrics stay in .prdx/ (project root)
.prdx/
└── metrics/
    ├── backend-auth-started.json
    └── backend-auth-completed.json
```

**Note:** Metrics remain in `.prdx/` at project root for now. Could move to `.claude/.prdx/` in future.

---

## ✨ Benefits

### 1. Cleaner Root
- ✅ No hidden files cluttering root
- ✅ All Claude state in `.claude/`
- ✅ Better separation of concerns

### 2. Easier Maintenance
- ✅ One place to look for context
- ✅ Clear ownership (Claude Code files)
- ✅ Simpler .gitignore

### 3. Consistent Patterns
- ✅ PRDs in `.claude/prds/`
- ✅ Context in `.claude/.prdx-context`
- ✅ Hooks in `.claude/hooks/`
- ✅ Everything related to Claude in `.claude/`

### 4. Future-Proof
- ✅ Room to add more state files
- ✅ Can group related files
- ✅ Clear namespace

---

## 🔮 Future Considerations

**Potential improvements:**

### Option 1: Move metrics to .claude/
```
.claude/
├── .prdx/
│   ├── context    # Rename from .prdx-context
│   └── metrics/   # Move from project root
│       └── *.json
```

### Option 2: Single state directory
```
.claude/
└── state/
    ├── context.env     # Context file
    └── metrics/        # Metrics directory
        └── *.json
```

### Option 3: Keep current (recommended)
```
.claude/
└── .prdx-context  # Simple, works well

.prdx/
└── metrics/       # Separate for user access
```

**Recommendation:** Keep current structure. Metrics in `.prdx/` makes them easy to find for `/prdx:metrics` viewing.

---

## 📋 Checklist

**Files updated:** ✅
- [x] commands/dev.md (load + save)
- [x] commands/sync.md (load + docs)
- [x] .gitignore (new path)
- [x] CLAUDE.md (documentation)

**Backward compatibility:** ✅
- [x] Fallback to old location if new doesn't exist
- [x] Auto-migrate on save
- [x] No breaking changes

**Documentation:** ✅
- [x] Updated all references
- [x] Documented new location
- [x] Migration guide provided

---

## 🎯 Summary

**Change:**
- Moved `.prdx-context` → `.claude/.prdx-context`

**Reason:**
- Better organization
- Cleaner root
- Consistent with Claude Code conventions

**Impact:**
- ✅ Backward compatible
- ✅ Auto-migrates on save
- ✅ Better structure

**Files Changed:** 4
- commands/dev.md
- commands/sync.md
- .gitignore
- CLAUDE.md

**User Action Required:** None (auto-migrates)

**The context file is now properly organized under .claude/!** ✅
