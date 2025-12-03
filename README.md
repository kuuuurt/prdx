# PRDX

> PRD workflow for Claude Code leveraging native tooling

PRDX is a Claude Code plugin that provides PRD (Product Requirements Document) workflow using native Plan agents, platform-specific agents, hooks, and skills.

## Features

✨ **Leverages Claude Code Native Tools**
- **Plan agent** for codebase exploration and planning
- **Platform agents** for implementation
- **Hooks** for validation gates
- **Skills** as knowledge bases
- **TodoWrite** for task tracking
- Thin wrapper commands that orchestrate

🚀 **Multi-Platform Development Support**
- Backend development (TypeScript, Hono, BFF patterns)
- Android development (Kotlin, Jetpack Compose, Clean Architecture)
- iOS development (Swift, SwiftUI, MVVM)

🤖 **Platform-Specific Agents**
- **backend-developer**: TypeScript/Hono expert
- **android-developer**: Kotlin/Compose expert
- **ios-developer**: Swift/SwiftUI expert

📦 **What's Inside**
- **Thin commands**: Trigger agents, handle files, run hooks
- **3 validation hooks**: Pre-plan, pre-implement, post-implement
- **3 PRD skills**: Specialized knowledge bases (impl-patterns, testing-strategy, prd-review)
- **3 platform agents**: Implementation experts

## Installation

### Option 1: Install from Marketplace (Recommended)

```bash
# Add the PRDX marketplace
/plugin marketplace add kuuuurt/prdx

# Install the plugin
/plugin install prdx@prdx
```

The plugin will be automatically installed and all commands will be available.

### Option 2: Direct GitHub Installation

```bash
# Clone the repository
git clone https://github.com/kuuuurt/prdx.git

# Link to Claude Code plugins directory
ln -s "$(pwd)/prdx" ~/.claude/plugins/prdx
```

Claude Code will automatically load the plugin.

### Option 3: Install Script (Project-Specific)

Use the included install script for project-specific installation:

```bash
cd your-project
git clone https://github.com/kuuuurt/prdx.git
./prdx/install.sh
```

The installer will copy all files to your project's `.claude` directory with backups.

### Option 4: Manual Installation

For direct project installation:

```bash
cd your-project
git clone https://github.com/kuuuurt/prdx.git
mkdir -p .claude/{commands/prd,skills,agents}
cp -r prdx/commands/* .claude/commands/prd/
cp -r prdx/skills/* .claude/skills/
cp -r prdx/agents/* .claude/agents/
```

## Quick Start

### 1. Install Plugin

```bash
# Add the PRDX marketplace
/plugin marketplace add kuuuurt/prdx

# Install the plugin
/plugin install prdx@prdx
```

### 2. Create Plan

```bash
/prdx:plan "add biometric authentication to Android app"
```

**What happens:**
1. Pre-plan hook validates environment
2. Platform detected: android
3. Plan agent explores codebase
4. Plan agent creates comprehensive plan
5. Plan displayed in conversation

**Iterate naturally:**
```
You: "Can you use BiometricPrompt API instead?"
→ Plan agent revises approach
→ Updated plan displayed

You: "looks good"
→ PRD written to .claude/prds/android-biometric-auth.md
```

### 3. Implement Feature

```bash
/prdx:implement android-biometric-auth
```

**What happens:**
1. Pre-implement hook validates PRD
2. Git branch created: `feat/android-biometric-auth`
3. Platform agent invoked (prdx:android-developer)
4. Agent uses TodoWrite to track tasks
5. Agent implements with TDD
6. Agent creates conventional commits
7. Post-implement hook updates PRD status

### 4. Create Pull Request

```bash
/prdx:push android-biometric-auth
```

Creates PR with comprehensive description from PRD.

## Configuration

PRDX can be customized using a `prdx.json` configuration file in your project root or `.claude/` directory.

### Quick Configuration

**Easiest: Use a preset** (one command setup):

```bash
/prdx:config minimal     # Conventional commits, no co-author/links
/prdx:config standard    # Conventional commits with full attribution (default)
/prdx:config simple      # Simple commits (no "feat:" prefix) with attribution
```

**Interactive: Guided setup** (asks you questions):

```bash
/prdx:config             # Answer 4 simple questions, done!
```

**Advanced: Granular control**:

```bash
/prdx:config show                         # View current settings
/prdx:config set commits.format simple    # Change specific setting
/prdx:config get commits.coAuthor.enabled # Check a setting
```

### Configuration File

Create `prdx.json` in your project root:

```json
{
  "version": "1.0",
  "commits": {
    "coAuthor": {
      "enabled": true,
      "name": "Claude",
      "email": "noreply@anthropic.com"
    },
    "extendedDescription": {
      "enabled": true,
      "includeClaudeCodeLink": true
    },
    "format": "conventional"
  },
  "pullRequest": {
    "defaultBase": "main",
    "autoAssign": true
  }
}
```

### Commit Configuration

Control how commits are formatted when platform agents implement features.

**`commits.format`** - Commit message format
- `"conventional"` (default) - Uses conventional commits (e.g., `feat: add feature`)
- `"simple"` - Plain descriptions (e.g., `add feature`)

**`commits.coAuthor.enabled`** - Include co-author attribution (default: `true`)

**`commits.coAuthor.name`** - Co-author name (default: `"Claude"`)

**`commits.coAuthor.email`** - Co-author email (default: `"noreply@anthropic.com"`)

**`commits.extendedDescription.enabled`** - Include extended commit descriptions (default: `true`)

**`commits.extendedDescription.includeClaudeCodeLink`** - Add Claude Code link in commits (default: `true`)

### Commit Examples

**Conventional with all options enabled:**
```
feat: add biometric authentication endpoints

Implement POST /api/auth/biometric/register and POST /api/auth/biometric/verify
endpoints with Zod validation and proper error handling.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Simple with extended description disabled:**
```json
{
  "commits": {
    "format": "simple",
    "extendedDescription": {
      "enabled": false
    }
  }
}
```

Results in:
```
add biometric authentication endpoints

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Minimal commits (no co-author, no link):**
```json
{
  "commits": {
    "coAuthor": {
      "enabled": false
    },
    "extendedDescription": {
      "includeClaudeCodeLink": false
    }
  }
}
```

Results in:
```
feat: add biometric authentication endpoints

Implement POST /api/auth/biometric/register and POST /api/auth/biometric/verify
endpoints with Zod validation and proper error handling.
```

### Pull Request Configuration

**`pullRequest.defaultBase`** - Default base branch for PRs (default: `"main"`)

**`pullRequest.autoAssign`** - Automatically assign PR to current user (default: `true`)

### Configuration Locations

PRDX looks for configuration in these locations (in order):
1. `./prdx.json` (project root)
2. `./.claude/prdx.json` (Claude Code directory)

If no configuration file is found, default values are used.

## Available Commands

### Core Workflow

| Command | Description |
|---------|-------------|
| `/prdx:plan <description>` | Create plan (triggers Plan agent) |
| `/prdx:implement <slug>` | Implement feature (triggers platform agent) |
| `/prdx:push <slug>` | Create pull request |

### Management

| Command | Description |
|---------|-------------|
| `/prdx:show [slug\|keyword]` | View/list/search PRDs |
| `/prdx:close <slug>` | Close completed PRD |
| `/prdx:config [show\|init\|set\|get]` | Configure PRDX settings |

### GitHub Integration

| Command | Description |
|---------|-------------|
| `/prdx:publish <slug>` | Create GitHub issue from PRD |
| `/prdx:sync <slug>` | Sync PRD with GitHub issue |

### Help

| Command | Description |
|---------|-------------|
| `/prdx:help` | Complete documentation |

## Workflow Example

Here's a complete feature development workflow:

```bash
# 1. Create plan (Plan agent explores and plans)
/prdx:plan "add OAuth2 authentication with Google and GitHub"
# → Pre-plan hook validates environment
# → Platform detected: backend
# → Plan agent explores codebase
# → Plan agent creates comprehensive plan
# → Plan displayed in conversation

# 2. Iterate naturally
"Can you add support for Azure AD too?"
# → Plan agent revises plan
# → Displays updated plan

"looks good"
# → PRD written to .claude/prds/backend-oauth2-auth.md

# 3. Implement feature (Platform agent implements)
/prdx:implement backend-oauth2-auth
# → Pre-implement hook validates PRD
# → Branch created: feat/backend-oauth2-auth
# → prdx:backend-developer agent invoked
# → Agent uses TodoWrite to track tasks
# → Agent implements with TDD
# → Agent creates conventional commits
# → Post-implement hook updates PRD status

# 4. Publish to GitHub (optional)
/prdx:publish backend-oauth2-auth
# → Creates GitHub issue for team visibility

# 5. Create pull request
/prdx:push backend-oauth2-auth
# → Creates PR with description from PRD
# → Links to GitHub issue if exists
# → Updates PRD with PR metadata

# 6. After merge, close PRD
/prdx:close backend-oauth2-auth
# → Marks PRD as completed
```

## PRD File Structure

PRDs are stored in `.claude/prds/` directory:

```
.claude/prds/
├── backend-user-auth.md
├── android-push-notifications.md
└── ios-dashboard-v2.md
```

Each PRD contains:
- **Goal**: What and why (1-2 sentences)
- **Acceptance Criteria**: Testable outcomes with test mappings
- **Approach**: Architecture, key changes, and risks
- **Implementation Tasks**: Phase-by-phase breakdown
- **Testing Strategy**: Unit, integration, and manual tests
- **Implementation Notes**: Added after implementation completes
- **Pull Request**: PR metadata after `/prdx:push`
- **Status**: planning → in-progress → implemented → review → completed

## Customization

### Adapting Agents for Your Stack

Edit agents in `.claude/agents/` to match your technology stack:

```bash
# Example: Customize backend agent for Express instead of Hono
vim .claude/agents/backend-developer.md
```

Update the agent's expertise section with your:
- Frameworks and libraries
- Architecture patterns
- Coding standards
- Testing approaches

### Adding Custom Commands

Create new commands in `.claude/commands/prd/`:

```bash
# Example: Add a deploy command
vim .claude/commands/prd/deploy.md
```

### Modifying Skills

Update skills in `.claude/skills/` to include:
- Your testing frameworks
- Company-specific patterns
- Architecture decisions
- Code review checklist

### Example: Backend-Only Setup

If you only need backend development:

```bash
# Remove mobile agents
rm agents/android-developer.md
rm agents/ios-developer.md

# Commands will automatically adapt to only detect backend platform
```

## Requirements

- **Claude Code** (claude.ai/code)
- **Git repository** (for GitHub integration features)
- **GitHub CLI** (`gh`) - Optional, for `/prdx:publish` and `/prdx:sync`

### Installing GitHub CLI

```bash
# macOS
brew install gh

# Linux
sudo apt install gh

# Windows
winget install GitHub.cli

# Authenticate
gh auth login
```

## Best Practices

### 1. Let Plan Agent Explore
Always use `/prdx:plan` to let the Plan agent explore your codebase thoroughly.

### 2. Iterate Naturally
During planning, just talk naturally - no special commands for revisions.

### 3. Use Clear Approval
Say "looks good", "approve", or "lgtm" when plan is ready.

### 4. Leverage Hooks
Hooks provide validation gates - fix issues they report before proceeding.

### 5. Review TodoWrite
During implementation, watch TodoWrite for real-time task progress.

### 6. Close When Done
Run `/prdx:close <slug>` to mark PRDs as completed.

## Troubleshooting

### Commands Not Found

```bash
# Verify installation
ls -la .claude/commands/prd/

# Ensure you're in project root
pwd
```

### Agents Not Working

```bash
# Check agent files exist
ls -la .claude/agents/

# Verify agent frontmatter
head -5 .claude/agents/backend-developer.md
```

### GitHub Integration Issues

```bash
# Install GitHub CLI
brew install gh

# Authenticate
gh auth login

# Test access
gh repo view
```

## Package Contents

```
prdx/
├── .claude-plugin/          # Plugin metadata
│   ├── plugin.json
│   └── marketplace.json
├── commands/                # Thin wrapper commands
│   ├── plan.md              # Triggers Plan agent
│   ├── implement.md         # Triggers platform agent
│   ├── show.md              # View/list/search PRDs
│   ├── push.md              # Create pull request
│   ├── close.md             # Close completed PRD
│   ├── publish.md           # Create GitHub issue
│   ├── sync.md              # Sync with GitHub
│   └── help.md              # Documentation
├── hooks/prdx/              # Validation hooks
│   ├── pre-plan.sh          # Pre-planning validation
│   ├── pre-implement.sh     # Pre-implementation validation
│   └── post-implement.sh    # Post-implementation actions
├── skills/                  # Knowledge bases (read by agents)
│   ├── prd-review.md        # Review checklist
│   ├── impl-patterns.md     # Implementation patterns
│   └── testing-strategy.md  # Testing approaches
├── agents/                  # Platform-specific agents
│   ├── backend-developer.md
│   ├── android-developer.md
│   └── ios-developer.md
├── README.md
└── install.sh
```

## Contributing

This is a personal tool, but if you find it useful and want to suggest improvements:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - Feel free to use and modify for your projects.

## Support

For issues or questions:
- Check `/prdx:help` for detailed command documentation
- Review the [GitHub Issues](https://github.com/kuuuurt/prdx/issues)
- Read PRD examples in `.claude/prds/`

## Changelog

### v0.3.0 (2025-01-13) - Native Tooling
- **BREAKING**: Complete redesign to leverage Claude Code native features
- **NEW**: `/prdx:plan` - Thin wrapper that triggers Plan agent
- **NEW**: `/prdx:implement` - Thin wrapper that triggers platform agent
- **NEW**: Validation hooks (pre-plan, pre-implement, post-implement)
- **REMOVED**: Custom codebase exploration (use Plan agent)
- **REMOVED**: Custom multi-agent orchestration
- **REMOVED**: Context files and state management
- **REMOVED**: Two-level planning system
- **REMOVED**: Custom task tracking (use TodoWrite)
- **REMOVED**: TDD review checkpoints
- **REMOVED**: Metrics tracking
- **REMOVED**: Templates
- **PHILOSOPHY**: Delegate to native Claude Code tools instead of custom implementations
- **COMMANDS**: Thin wrappers that orchestrate agents, hooks, and file I/O
- **AGENTS**: Platform agents do implementation, Plan agent does exploration
- **HOOKS**: Bash scripts for validation gates
- **SKILLS**: Passive knowledge bases read by agents

### v0.2.0 (2025-01-10)
- **CHANGED**: `/prdx:plan` creates business-level PRDs only
- **CHANGED**: `/prdx:dev` auto-creates detailed technical plans
- Separated business planning from technical planning

### v0.1.0 (2024-11-10)
- Initial release
- 14 PRD workflow commands
- 3 specialized skills
- 3 AI agents (backend, Android, iOS)
- GitHub integration

---

**Made with ❤️ by Kurt**

[Claude Code](https://claude.ai/code) • [GitHub](https://github.com/kuuuurt/prdx)
