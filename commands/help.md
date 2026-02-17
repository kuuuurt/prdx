# PRDX Help

Complete PRD workflow system for feature development with AI agents.

## Quick Start

```bash
# All-in-one workflow (recommended)
/prdx:prdx "add biometric login"

# Or step-by-step:
# 1. Create a PRD (smart defaults, minimal questions)
/prdx:plan "add biometric login"

# 2. Publish to GitHub (optional)
/prdx:publish biometric-login

# 3. Start implementation (auto-creates detailed plan)
/prdx:implement biometric-login

# 4. Create PR (auto-verifies quality)
/prdx:push biometric-login

# 5. Sync issue status (after PR created)
/prdx:sync biometric-login
```

---

## Core Commands (11 total)

### Main Entry Point

**`/prdx:prdx [description or slug]`**
- Complete workflow: plan → implement → push
- **Decision points**: Never auto-proceeds between phases
- **Resumes from current status** when given existing PRD slug
- Examples:
  ```bash
  /prdx:prdx "add biometric login"    # New feature
  /prdx:prdx biometric-login          # Resume existing PRD
  ```

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
  /prdx:show                       # List all PRDs
  /prdx:show auth                  # Search for "auth"
  /prdx:show biometric-login       # Detailed status
  /prdx:show --status planning     # Filter by status
  ```

---

### Development

**`/prdx:implement [slug] [platform]`**
- Three-phase implementation: Dev Planning → Development → Code Review
- Auto-creates detailed implementation plan
- Platform agent executes with TDD
- Code reviewer validates before handoff
- Examples:
  ```bash
  /prdx:implement backend-auth           # Implement backend feature
  /prdx:implement mobile-login android   # Implement Android only
  /prdx:implement mobile-login ios       # Implement iOS only
  ```

**`/prdx:push [slug] [--draft]`**
- Create PR with comprehensive description
- **Auto-detects PRD** from current branch if no slug provided
- **Standalone mode**: Works without a PRD (analyzes commits/diff)
- Examples:
  ```bash
  /prdx:push backend-auth       # PRD mode: rich PR description
  /prdx:push                    # Auto-detect PRD or standalone
  /prdx:push --draft            # Create draft PR
  ```

**`/prdx:commit [message]`**
- Commit with project's prdx.json configuration
- Respects commit format, co-author, and extended description settings
- Example:
  ```bash
  /prdx:commit "fix login validation"
  ```

**`/prdx:simplify [path]`**
- Code cleanup and simplification
- Removes unnecessary complexity
- Example:
  ```bash
  /prdx:simplify src/auth/
  ```

---

### GitHub Integration

**`/prdx:publish [slug]`**
- Create GitHub issue from PRD
- Auto-updates PRD with issue number
- Example:
  ```bash
  /prdx:publish biometric-login
  ```

**`/prdx:sync [slug] [--github]`**
- Sync PRD with current implementation state
- Updates acceptance criteria, implementation notes
- Optional GitHub issue sync with `--github`
- Example:
  ```bash
  /prdx:sync backend-auth          # Local sync
  /prdx:sync backend-auth --github # Also sync GitHub issue
  ```

**`/prdx:close [slug]`**
- Mark PRD as completed
- Closes GitHub issue
- Example:
  ```bash
  /prdx:close backend-auth
  ```

---

## Removed Commands (Simplified!)

These commands were **removed** for simplicity:

- `/prdx:wizard` → Use `/prdx:plan` (smarter, fewer steps)
- `/prdx:list` → Use `/prdx:show` (smart viewer)
- `/prdx:search` → Use `/prdx:show <keyword>`
- `/prdx:status` → Use `/prdx:show <slug>`
- `/prdx:deps` → Shown in `/prdx:show <slug>`
- `/prdx:update` → Use `/prdx:prdx <slug>` to resume and iterate
- `/prdx:dev` → Use `/prdx:implement`
- `/prdx:dev:push` → Use `/prdx:push`
- `/prdx:dev:check` → Auto-runs in `/prdx:push`

---

## Key Features

### Context Awareness
Commands remember your last PRD:
```bash
/prdx:prdx biometric-login   # Set context
/prdx:prdx                   # Offers last-used PRD
/prdx:implement               # Uses last-used slug
```

### Smart Defaults
Minimal questions, maximum intelligence:
- **Type inference**: "fix bug" → `bug-fix`, "add feature" → `feature`
- **Platform detection**: From directory, description, or recent PRDs
- **Duplicate detection**: Automatically checks for similar PRDs

### Automation
Things that happen automatically:
- Code review before handoff to user
- Quality verification before PR
- GitHub issue sync
- Detailed implementation planning
- Duplicate PRD detection
- Type and platform inference

### All-in-One Viewer
`/prdx:show` does everything:
- List all PRDs
- Search by keyword
- Show detailed status
- View dependencies
- Check PR/issue status

---

## Typical Workflows

### Complete Feature (One Command)
```bash
/prdx:prdx "add biometric login"
# Plan Mode → PRD saved → [Publish?] → [Implement?] → Implementation → Review → [PR?] → PR
```

### Step-by-Step
```bash
/prdx:plan "add biometric login"
/prdx:publish biometric-login    # Optional: create GitHub issue
/prdx:implement biometric-login  # Three-phase implementation
# ...test implementation...
/prdx:push biometric-login       # Create PR
/prdx:close biometric-login      # After PR merged
```

### Bug Fix Flow
```bash
/prdx:prdx "fix memory leak in auth service"
# → Auto-infers: bug-fix type
# → Plans, implements, creates PR
```

### Standalone (No PRD)
```bash
# Quick commit with project config
/prdx:commit "fix typo in readme"

# Quick PR from current branch
/prdx:push

# Code cleanup
/prdx:simplify src/auth/
```

---

## Full Command Reference

| Command | Purpose | Context-Aware |
|---------|---------|---------------|
| `/prdx:prdx` | Complete workflow | Yes |
| `/prdx:plan` | Create PRD | No |
| `/prdx:show` | View PRDs | No |
| `/prdx:implement` | Implement feature | Yes |
| `/prdx:push` | Create PR | Yes |
| `/prdx:commit` | Commit changes | No |
| `/prdx:simplify` | Code cleanup | No |
| `/prdx:publish` | Create GitHub issue | No |
| `/prdx:sync` | Sync PRD state | Yes |
| `/prdx:close` | Complete PRD | No |
| `/prdx:help` | Show this help | No |

### Clean Separation of Concerns

**Planning** (`plan`, `show`):
- Manage PRD files locally
- Agent-powered planning and review

**Development** (`implement`, `push`, `commit`, `simplify`):
- Implement features
- Create and manage PRs
- Auto-verify quality

**GitHub Issues** (`publish`, `sync`, `close`):
- Create and sync issues
- Update status labels and comments
- Track work at planning level

**That's it!** Simple, smart, and context-aware.
