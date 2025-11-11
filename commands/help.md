# PRDX Help

Complete PRD workflow system for feature development with AI agents.

## Quick Start

```bash
# 1. Create a PRD (smart defaults, minimal questions)
/prdx:plan "add biometric login"

# 2. Publish to GitHub (optional)
/prdx:publish android-219

# 3. Start implementation (auto-creates detailed plan)
/prdx:dev

# 4. Create PR (auto-verifies quality)
/prdx:dev:push

# 5. Sync issue status (after PR created)
/prdx:sync
```

That's it! Clean separation: `plan/sync` for issues, `dev:*` for PRs.

---

## Core Commands (8 total)

### Planning & Discovery

**`/prdx:plan <description> [options]`**
- Create PRD with agent-powered planning
- **Smart defaults**: Infers type and platform from description
- **Auto-duplicate detection**: Prevents creating duplicate PRDs
- **Minimal questions**: Only asks what can't be inferred
- Options: `--type`, `--platform`, `--depends-on`
- Examples:
  ```bash
  /prdx:plan "fix memory leak in auth"     # Infers: bug-fix, backend
  /prdx:plan "add dark mode" --platform android
  /prdx:plan "refactor auth" --depends-on #215
  ```

**`/prdx:show [slug or keyword] [options]`**
- **Smart viewer**: Lists all, searches, or shows detailed status
- No arguments → List all PRDs
- Keyword → Search PRDs
- Exact slug → Show detailed status
- Options: `--status`, `--platform`
- Examples:
  ```bash
  /prdx:show                    # List all PRDs
  /prdx:show auth               # Search for "auth"
  /prdx:show android-219        # Detailed status
  /prdx:show --status draft     # Filter by status
  ```

**`/prdx:update [slug]`**
- Update existing PRD with agent assistance
- Uses strikethrough to preserve history
- Agent-powered impact analysis
- Optional auto-sync to GitHub
- Example:
  ```bash
  /prdx:update android-219
  ```

---

### Development

**`/prdx:dev [slug] [prompt]`**
- **Context-aware**: Remembers last PRD, no slug needed
- **Shows what you're working on**: Visual PRD banner
- **Validates context**: Asks if wrong PRD loaded
- Auto-creates detailed implementation plan if missing
- Handles PRD updates via prompt
- Examples:
  ```bash
  /prdx:dev                   # Continue last PRD (confirms which one)
  /prdx:dev android-219       # Start new PRD
  /prdx:dev "add OAuth"       # Continue with prompt
  ```

**`/prdx:dev:push [slug] [options]`**
- **Auto-verifies** before creating PR (runs quality checks)
- Creates comprehensive PR description
- Links PR to GitHub issue
- Options: `--skip-check`
- Examples:
  ```bash
  /prdx:dev:push                    # Use context
  /prdx:dev:push android-219        # Specify PRD
  /prdx:dev:push --skip-check       # Skip verification
  ```

---

### GitHub Integration

**`/prdx:publish [slug]`**
- Create GitHub issue from PRD
- Auto-updates PRD with issue number
- Example:
  ```bash
  /prdx:publish android-219
  ```

**`/prdx:sync [slug]`**
- Sync PRD status/updates to GitHub issue
- Updates issue labels and posts comments
- Context-aware (can omit slug)
- Example:
  ```bash
  /prdx:sync android-219     # Sync specific PRD
  /prdx:sync                 # Sync current PRD
  ```

**`/prdx:close [slug]`**
- Mark PRD as completed
- Closes GitHub issue
- Example:
  ```bash
  /prdx:close android-219
  ```

---

## Removed Commands (Simplified!)

These commands were **removed** for simplicity:

- ❌ `/prdx:wizard` → Use `/prdx:plan` (smarter, fewer steps)
- ❌ `/prdx:list` → Use `/prdx:show` (smart viewer)
- ❌ `/prdx:search` → Use `/prdx:show <keyword>`
- ❌ `/prdx:status` → Use `/prdx:show <slug>`
- ❌ `/prdx:deps` → Shown in `/prdx:show <slug>`
- ❌ `/prdx:dev:check` → Auto-runs in `/prdx:dev:push`

**Result**: 14 commands → 8 commands (43% reduction!)

---

## Key Features

### 🎯 Context Awareness
Commands remember your last PRD:
```bash
/prdx:dev android-219    # Set context (shows PRD banner)
/prdx:dev                # Uses android-219 (confirms PRD)
/prdx:dev:push           # Also uses android-219
```

### 🤖 Smart Defaults
Minimal questions, maximum intelligence:
- **Type inference**: "fix bug" → `bug-fix`, "add feature" → `feature`
- **Platform detection**: From directory, description, or recent PRDs
- **Duplicate detection**: Automatically checks for similar PRDs

### ⚡ Automation
Things that happen automatically:
- Quality verification before PR
- GitHub issue sync
- Detailed implementation planning
- Duplicate PRD detection
- Type and platform inference

### 🔍 All-in-One Viewer
`/prdx:show` does everything:
- List all PRDs
- Search by keyword
- Show detailed status
- View dependencies
- Check PR/issue status

---

## Typical Workflows

### Quick Feature (5 commands)
```bash
/prdx:plan "add biometric login"
/prdx:publish               # Create GitHub issue
/prdx:dev                   # Start implementation (shows PRD banner)
# ...implement...
/prdx:dev:push             # Create PR
/prdx:sync                 # Update issue status
```

### With Context (Fewer Args)
```bash
/prdx:plan "add dark mode"
/prdx:publish android-219
/prdx:dev                   # Remembers android-219 (shows banner)
# ...work...
/prdx:dev                   # Continue (confirms PRD)
# ...more work...
/prdx:dev:push             # Still remembers the PRD
/prdx:sync                 # Sync to issue
```

### Bug Fix Flow
```bash
/prdx:plan "fix memory leak in auth service"
→ Auto-infers: bug-fix type
→ Asks: "Steps to reproduce?"
/prdx:dev
/prdx:dev:push
```

### Search & Continue
```bash
/prdx:show auth                  # Find auth-related PRDs
/prdx:dev android-219            # Pick one (shows PRD banner)
/prdx:dev "add OAuth"            # Continue with update
```

---

## Full Command Reference

| Command | Purpose | Manages | Context-Aware |
|---------|---------|---------|---------------|
| `/prdx:plan` | Create PRD | PRDs | No |
| `/prdx:show` | View PRDs | PRDs | No |
| `/prdx:update` | Update PRD | PRDs | Yes |
| `/prdx:publish` | Create issue | GitHub Issues | No |
| `/prdx:sync` | Sync to issue | GitHub Issues | Yes |
| `/prdx:dev` | Implement | Code | Yes |
| `/prdx:dev:push` | Create PR | GitHub PRs | Yes |
| `/prdx:close` | Complete | PRDs + Issues | No |

### Clean Separation of Concerns

**Planning** (`plan`, `show`, `update`):
- Manage PRD files locally
- Agent-powered planning and review

**GitHub Issues** (`publish`, `sync`):
- Create and sync issues
- Update status labels and comments
- Track work at planning level

**Development** (`dev`, `dev:push`):
- Implement features
- Create and manage PRs
- Auto-verify quality

**That's it!** Simple, smart, and context-aware.
