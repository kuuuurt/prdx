# Hook-Based Template Sharing Solution

## ✅ Implemented

Created hook-based approach for sharing templates and hooks with plugin users.

---

## 🎯 Solution

### Two Self-Installing Hooks

1. **`install-templates.sh`** - Auto-installs PRD templates
2. **`install-hooks.sh`** - Auto-installs validation hooks

### How It Works

**Templates are installed when `/prdx:plan` runs:**
1. Check if `~/.claude/plugins/prdx/hooks/prd/install-templates.sh` exists
2. If yes, run it
3. Hook checks if `.claude/prds/templates/` already exists
4. If not, copies templates from plugin to project
5. Shows success message with available templates

**Hooks are installed when `/prdx:dev` runs:**
1. Check if `~/.claude/plugins/prdx/hooks/prd/install-hooks.sh` exists
2. If yes, run it
3. Hook checks if `.claude/hooks/prd/pre-dev.sh` already exists
4. If not, copies hooks from plugin to project
5. Makes hooks executable
6. Shows success message

---

## 📦 Files Created

### hooks/prd/install-templates.sh
```bash
#!/bin/bash
# Auto-install PRD templates
# Called by /prdx:plan via pre-planning hook
# Exit 0 if templates exist or installed successfully
# Silent if already installed
```

**Features:**
- Checks if templates already exist (silent success)
- Tries plugin location: `~/.claude/plugins/prdx/templates/`
- Falls back to relative: `.claude/commands/prd/../../templates/`
- Copies all `*.md` files to `.claude/prds/templates/`
- Shows success message only on first install

### hooks/prd/install-hooks.sh
```bash
#!/bin/bash
# Auto-install PRD validation hooks
# Called by /prdx:dev via pre-implementation hook
# Exit 0 if hooks exist or installed successfully
# Silent if already installed
```

**Features:**
- Checks if hooks already exist (silent success)
- Tries plugin location: `~/.claude/plugins/prdx/hooks/prd/`
- Falls back to relative: `.claude/commands/prd/../../hooks/prd/`
- Copies all hook scripts (except install-*.sh)
- Makes hooks executable (`chmod +x`)
- Shows success message only on first install

---

## 🔧 Command Updates

### /prdx:plan

Added to **Pre-Planning Hooks** section:
```markdown
1. **Install templates hook** (auto-installs templates on first use):
   ```bash
   if [ -f "$HOME/.claude/plugins/prdx/hooks/prd/install-templates.sh" ]; then
     bash "$HOME/.claude/plugins/prdx/hooks/prd/install-templates.sh"
   fi
   ```
```

### /prdx:dev

Added to **Pre-Implementation Hooks** section:
```markdown
1. **Install hooks** (auto-installs validation hooks on first use):
   ```bash
   if [ -f "$HOME/.claude/plugins/prdx/hooks/prd/install-hooks.sh" ]; then
     bash "$HOME/.claude/plugins/prdx/hooks/prd/install-hooks.sh"
   fi
   ```
```

---

## ✨ Benefits

### 1. Zero Context Bloat
- ✅ No template copying logic in commands
- ✅ Commands stay focused on core functionality
- ✅ Installation happens in separate process (hooks)

### 2. Seamless Experience
- ✅ Templates auto-install on first `/prdx:plan`
- ✅ Hooks auto-install on first `/prdx:dev`
- ✅ Silent on subsequent runs
- ✅ No user action required

### 3. Always Up-to-Date Source
- ✅ Install hooks live in plugin (always latest)
- ✅ Templates copied from plugin source
- ✅ Users get latest version on first use

### 4. Customizable After Install
- ✅ Templates copied to `.claude/prds/templates/`
- ✅ Users can modify for their tech stack
- ✅ Changes persist, don't get overwritten

### 5. Works Everywhere
- ✅ Plugin marketplace installation
- ✅ Symlink installation
- ✅ Project-specific installation
- ✅ Graceful fallback if source not found

---

## 🔄 User Experience

### First Time Using /prdx:plan

```bash
$ /prdx:plan "add user authentication"

Installing PRD templates...
✓ PRD templates installed to .claude/prds/templates/

Templates available:
  - feature-template.md (standard features)
  - bug-fix-template.md (bug fixes)
  - refactor-template.md (refactoring work)
  - spike-template.md (research/investigation)

You can customize these for your tech stack.

[continues with normal /prdx:plan flow...]
```

### First Time Using /prdx:dev

```bash
$ /prdx:dev backend-auth

Installing PRD validation hooks...
✓ PRD hooks installed to .claude/hooks/prd/

Hooks available:
  - pre-dev.sh (validates PRD before implementation)

[continues with normal /prdx:dev flow...]
```

### Subsequent Runs

```bash
$ /prdx:plan "add another feature"
[no install message, silent success]
[normal /prdx:plan flow...]

$ /prdx:dev backend-another
[no install message, silent success]
[normal /prdx:dev flow...]
```

---

## 📁 File Structure After Installation

**In Plugin:**
```
~/.claude/plugins/prdx/
├── templates/
│   ├── feature-template.md
│   ├── bug-fix-template.md
│   ├── refactor-template.md
│   └── spike-template.md
└── hooks/prd/
    ├── install-templates.sh  ← Self-installer
    ├── install-hooks.sh      ← Self-installer
    └── pre-dev.sh
```

**In User's Project (after first use):**
```
.claude/
├── prds/
│   └── templates/  ← Installed by install-templates.sh
│       ├── feature-template.md
│       ├── bug-fix-template.md
│       ├── refactor-template.md
│       └── spike-template.md
└── hooks/prd/  ← Installed by install-hooks.sh
    └── pre-dev.sh
```

---

## 🛡️ Safety Features

### 1. Idempotent
- Checks if already installed before copying
- Silent success if templates/hooks exist
- Safe to run multiple times

### 2. Graceful Degradation
- If plugin source not found, exit silently
- Templates/hooks are optional, not required
- Commands continue if hooks don't exist

### 3. No Overwrites
- Only installs if target doesn't exist
- User customizations preserved
- No force-update mechanism

### 4. Path Resolution
- Tries multiple source locations
- Works with different installation methods
- Falls back gracefully

---

## 🔮 Future Enhancements

**Optional improvements:**

1. **Version Checking**
   - Track template version
   - Warn if templates outdated
   - Offer to update

2. **Selective Install**
   - Ask which templates to install
   - Skip templates user doesn't need

3. **Update Command**
   - `/prdx:update-templates` - Refresh from plugin
   - `/prdx:update-hooks` - Refresh validation hooks

---

## 📊 Summary

**Files Created:** 2
- `hooks/prd/install-templates.sh`
- `hooks/prd/install-hooks.sh`

**Commands Updated:** 2
- `/prdx:plan` - Calls install-templates.sh
- `/prdx:dev` - Calls install-hooks.sh

**User Impact:**
- ✅ Zero-config setup
- ✅ Templates auto-install on first use
- ✅ No context bloat in commands
- ✅ Customizable after installation

**This solution keeps commands clean while ensuring all users get templates and hooks seamlessly!**
