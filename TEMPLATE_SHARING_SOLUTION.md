# Template Sharing Solution for PRDX Plugin Users

## Problem

Currently, these files are NOT being shared with plugin users:
- ❌ `templates/` (PRD templates)
- ❌ `hooks/` (validation hooks)
- ❌ `PR_TEMPLATE.md` (PR description template)

**Why?**
1. Claude Code plugin system only distributes `commands/`, `skills/`, and `agents/`
2. `install.sh` script also only copies those three directories
3. Templates/hooks are in plugin root, not installed anywhere

---

## Solution Options

### Option 1: Reference Templates via Commands (Recommended) ✅

**Approach:** Make templates accessible through commands that read from plugin directory

**Implementation:**

1. **Create `/prdx:templates` command** that shows available templates
2. **Create `/prdx:template <type>` command** that copies template to user's project
3. **Create `/prdx:setup` command** that installs hooks and PR template

**Pros:**
- ✅ Works with plugin marketplace installation
- ✅ Templates stay in plugin, always up-to-date
- ✅ User gets templates on-demand
- ✅ Can update templates without reinstall

**Cons:**
- ⚠️ Requires creating new commands

**File Structure:**
```
~/.claude/plugins/prdx/
├── templates/          # Source templates (plugin)
├── hooks/              # Source hooks (plugin)
└── PR_TEMPLATE.md      # Source PR template (plugin)

.claude/prds/           # User's project
├── templates/          # Copied on /prdx:setup
│   └── *.md           # Template instances
└── hooks/              # Copied on /prdx:setup
    └── prd/
        └── *.sh       # Hook instances
```

---

### Option 2: Documentation-Based (Simple) ✅

**Approach:** Document templates in README, users copy manually

**Implementation:**

1. Add "Templates" section to README with examples
2. Add "Hooks" section with hook scripts
3. Add "PR Template" section with template content
4. Users copy/paste as needed

**Pros:**
- ✅ Simple, no code changes
- ✅ Works immediately
- ✅ Users can customize freely

**Cons:**
- ⚠️ Manual copy/paste
- ⚠️ Templates might get out of sync
- ⚠️ User needs to check for updates

---

### Option 3: Auto-Copy on First Use (Hybrid) ✅

**Approach:** Commands auto-copy templates when first needed

**Implementation:**

**In `/prdx:plan` command:**
```markdown
## Phase 1: Check Templates

If `.claude/prds/templates/` doesn't exist:
1. Copy templates from plugin dir to `.claude/prds/templates/`
2. Show message: "✓ PRD templates installed to .claude/prds/templates/"
```

**In `/prdx:dev` command:**
```markdown
## Phase 1: Check Hooks

If `.claude/hooks/prd/` doesn't exist:
1. Copy hooks from plugin dir to `.claude/hooks/prd/`
2. Make hooks executable
3. Show message: "✓ PRD hooks installed to .claude/hooks/prd/"
```

**In `/prdx:dev:push` command:**
```markdown
## Phase 1: Check PR Template

If `PR_TEMPLATE.md` doesn't exist in project root:
1. Copy from plugin dir
2. Show message: "✓ PR template installed"
```

**Pros:**
- ✅ Automatic, no user action needed
- ✅ Templates appear when first needed
- ✅ Works with any installation method

**Cons:**
- ⚠️ Templates get stale (don't auto-update)
- ⚠️ Needs path resolution logic

---

### Option 4: Command-Line Init Command ✅

**Approach:** `/prdx:init` command sets up everything

**Implementation:**

Create `commands/init.md`:
```markdown
# Initialize PRDX

Installs templates, hooks, and PR template to your project.

## Phase 1: Install Templates

Copy all templates to `.claude/prds/templates/`:
- feature-template.md
- bug-fix-template.md
- refactor-template.md
- spike-template.md

## Phase 2: Install Hooks

Copy hooks to `.claude/hooks/prd/`:
- pre-dev.sh
- pre-plan.sh (future)
- post-dev.sh (future)

Make executable:
```bash
chmod +x .claude/hooks/prd/*.sh
```

## Phase 3: Install PR Template

Copy PR_TEMPLATE.md to project root (or .github/)

## Phase 4: Summary

Show what was installed and how to use it.
```

**Pros:**
- ✅ Explicit, user knows what's happening
- ✅ One-time setup per project
- ✅ Can run again to update

**Cons:**
- ⚠️ Requires user to run `/prdx:init`
- ⚠️ Templates can get stale

---

## Recommended Approach: **Hybrid (Option 3 + Option 4)**

**Best solution combines auto-copy with explicit init:**

### 1. Create `/prdx:init` command
- User can explicitly install/update templates
- Shows what's being installed
- Updates stale templates

### 2. Auto-copy on first use
- `/prdx:plan` checks for templates, copies if missing
- `/prdx:dev` checks for hooks, copies if missing
- Seamless experience, no manual setup required

### 3. Template management via commands
- `/prdx:templates` - List available templates
- `/prdx:template <type>` - Create PRD from template
- Templates always read from plugin source (latest version)

---

## Implementation Plan

### Step 1: Create `/prdx:init` Command

```markdown
| description | argument-hint |
| Initialize PRDX templates and hooks | [--force] |

# Initialize PRDX

Sets up templates, hooks, and PR template in your project.

## Usage

```bash
# First-time setup
/prdx:init

# Force reinstall (updates templates)
/prdx:init --force
```

## Phase 1: Check Installation

Check if already initialized:
- `.claude/prds/templates/` exists
- `.claude/hooks/prd/` exists
- `PR_TEMPLATE.md` or `.github/pull_request_template.md` exists

If all exist and --force not provided:
  "✓ PRDX already initialized. Use --force to reinstall."

## Phase 2: Install Templates

Copy from plugin to `.claude/prds/templates/`:
```bash
mkdir -p .claude/prds/templates
cp ~/.claude/plugins/prdx/templates/*.md .claude/prds/templates/
```

Templates installed:
- feature-template.md
- bug-fix-template.md
- refactor-template.md
- spike-template.md

## Phase 3: Install Hooks

Copy from plugin to `.claude/hooks/prd/`:
```bash
mkdir -p .claude/hooks/prd
cp ~/.claude/plugins/prdx/hooks/prd/*.sh .claude/hooks/prd/
chmod +x .claude/hooks/prd/*.sh
```

Hooks installed:
- pre-dev.sh (validates PRD before implementation)
- pre-plan.sh (future)
- post-dev.sh (future)

## Phase 4: Install PR Template

Ask user where to install:
- Project root: `PR_TEMPLATE.md`
- GitHub: `.github/pull_request_template.md`

Copy from plugin:
```bash
cp ~/.claude/plugins/prdx/PR_TEMPLATE.md [chosen location]
```

## Phase 5: Add to .gitignore

Ensure `.prdx/` is git-ignored:
```bash
if ! grep -q "^\.prdx/" .gitignore 2>/dev/null; then
  echo ".prdx/" >> .gitignore
fi
```

## Phase 6: Summary

```
✅ PRDX Initialized Successfully!

📁 Templates installed:
   .claude/prds/templates/ (4 templates)

🪝 Hooks installed:
   .claude/hooks/prd/ (1 hook, executable)

📋 PR Template installed:
   PR_TEMPLATE.md

⚙️  Git config:
   .gitignore updated (.prdx/ excluded)

Next Steps:
  1. Create your first PRD: /prdx:plan "feature description"
  2. View templates: ls .claude/prds/templates/
  3. Customize as needed for your stack

Documentation: /prdx:help
```
```

### Step 2: Add Auto-Copy to Existing Commands

**In `/prdx:plan`:**
```markdown
## Phase 1: Ensure Templates

If `.claude/prds/templates/` doesn't exist:
  Run template installation logic (silent)
  Show: "✓ Templates auto-installed to .claude/prds/templates/"
```

**In `/prdx:dev`:**
```markdown
## Phase 1: Ensure Hooks

If `.claude/hooks/prd/` doesn't exist:
  Run hook installation logic (silent)
  Show: "✓ Hooks auto-installed to .claude/hooks/prd/"
```

### Step 3: Update Documentation

**README.md:**
```markdown
## First-Time Setup

After installing the plugin, initialize templates and hooks:

```bash
/prdx:init
```

This installs:
- PRD templates (feature, bug-fix, refactor, spike)
- Validation hooks (pre-dev checks)
- PR description template

Templates will also auto-install on first use of `/prdx:plan`.
```

---

## Path Resolution

**Finding plugin directory:**

```bash
# Plugin installation
~/.claude/plugins/prdx/templates/

# Project installation  
.claude/commands/prd/../../templates/

# Fallback logic in commands:
if [ -d "~/.claude/plugins/prdx/templates" ]; then
  TEMPLATE_DIR="~/.claude/plugins/prdx/templates"
elif [ -d ".claude/templates" ]; then
  TEMPLATE_DIR=".claude/templates"
fi
```

---

## Summary

**Recommended Implementation:**

1. ✅ Create `/prdx:init` command for explicit setup
2. ✅ Add auto-copy logic to `/prdx:plan` and `/prdx:dev`
3. ✅ Update README with setup instructions
4. ✅ Templates always up-to-date in plugin dir
5. ✅ Users get copies in their project for customization

**User Experience:**

```bash
# Option 1: Explicit init
/prdx:init

# Option 2: Auto-init on first use
/prdx:plan "add feature"
# → "✓ Templates auto-installed"

# Templates are now in .claude/prds/templates/
# Users can customize for their stack
```

**Benefits:**
- ✅ Works with marketplace installation
- ✅ Templates accessible to all users
- ✅ Can update templates easily
- ✅ Seamless auto-install experience
- ✅ Explicit init for power users
