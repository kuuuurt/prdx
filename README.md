# PRDX

> Complete PRD workflow experience for Claude Code

PRDX is a comprehensive Product Requirements Document (PRD) workflow system for Claude Code that helps you manage feature development from planning through implementation to deployment.

## Features

✨ **Complete PRD Workflow**
- Interactive PRD creation with guided wizard
- Feature planning with multi-agent collaboration
- Implementation tracking with verification
- GitHub integration for issue management
- Status dashboard and search capabilities
- Dependency management between PRDs

🚀 **Multi-Platform Development Support**
- Backend development (TypeScript, Hono, BFF patterns)
- Android development (Kotlin, Jetpack Compose, Clean Architecture)
- iOS development (Swift, SwiftUI, MVVM)

🤖 **AI Agents Included**
- **backend-developer**: TypeScript/Hono expert
- **android-developer**: Kotlin/Compose expert
- **ios-developer**: Swift/SwiftUI expert

📦 **What's Inside**
- **15 PRD Commands**: Complete workflow automation
- **3 PRD Skills**: Specialized knowledge bases
- **3 AI Agents**: Platform-specific development experts

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

### 1. Add Marketplace & Install

```bash
# Add the PRDX marketplace
/plugin marketplace add kuuuurt/prdx

# Install the plugin
/plugin install prdx@prdx
```

### 2. Create Your First PRD

```
/prdx:wizard
```

The wizard will guide you through creating a complete PRD with:
- Feature overview and motivation
- Technical specifications
- Implementation checklist
- Dependencies and blockers

### 3. Plan Implementation

```
/prdx:plan <feature-id>
```

AI agents will analyze your codebase and create a business-level PRD with high-level phases.

### 4. Start Development

```
/prdx:dev:start <feature-id>
```

Implements features from the detailed plan. If no detailed plan exists, it will automatically create one with file paths, API contracts, and code patterns before starting implementation.

### 5. Verify Implementation

```
/prdx:dev:check <feature-id>
```

Agents will review your implementation for quality.

### 6. Create Pull Request

```
/prdx:dev:push <feature-id>
```

Automatically creates a PR with full context.

## Available Commands

### Core Workflow

| Command | Description |
|---------|-------------|
| `/prdx:wizard` | Interactive PRD creation |
| `/prdx:plan <feature-id>` | Business-level PRD planning |
| `/prdx:dev:start <feature-id>` | Begin implementation (auto-creates detailed plan) |
| `/prdx:dev:check <feature-id>` | Verify quality |
| `/prdx:dev:push <feature-id>` | Create PR |

### GitHub Integration

| Command | Description |
|---------|-------------|
| `/prdx:publish <feature-id>` | Create GitHub issue |
| `/prdx:sync <feature-id>` | Sync with GitHub |

### Management

| Command | Description |
|---------|-------------|
| `/prdx:list` | List all PRDs |
| `/prdx:search <query>` | Search PRDs |
| `/prdx:update <feature-id>` | Update PRD |
| `/prdx:close <feature-id>` | Close PRD |
| `/prdx:status` | Status dashboard |
| `/prdx:deps <feature-id>` | Manage dependencies |

### Help

| Command | Description |
|---------|-------------|
| `/prdx:help` | Complete documentation |

## Workflow Example

Here's a complete feature development workflow:

```bash
# 1. Create PRD (business requirements)
/prdx:wizard
# → Fill in: feature-id, title, description, platform
# → Creates PRD with high-level implementation phases

# 2. Plan with AI agents (business-level)
/prdx:plan user-authentication-v2
# → Agents analyze and create business-level PRD
# → Includes WHAT needs to be done, not HOW

# 3. Publish to GitHub (optional)
/prdx:publish user-authentication-v2
# → Creates GitHub issue for team visibility

# 4. Start implementation
/prdx:dev:start user-authentication-v2
# → Creates detailed technical plan automatically (file paths, API contracts, patterns)
# → Implements feature following the detailed plan

# 5. Verify as you go
/prdx:dev:check user-authentication-v2
# → Agents review code quality and architecture

# 6. Create pull request
/prdx:dev:push user-authentication-v2
# → Automated PR with full context

# 7. After merge, close PRD
/prdx:close user-authentication-v2
# → Mark as completed
```

## PRD File Structure

PRDs are stored in `.claude/prds/` directory:

```
.claude/prds/
├── backend-user-auth.md
├── mobile-push-notifications.md
└── frontend-dashboard-v2.md
```

Each PRD contains:
- **Overview**: Feature description and motivation
- **Technical Approach**: High-level architecture decisions
- **Implementation**: High-level phases (WHAT needs to be done)
- **Detailed Implementation Plan**: Technical breakdown with file paths (created automatically by `/prdx:dev:start`)
- **Acceptance Criteria**: Testable requirements
- **Dependencies**: Related PRDs and blockers
- **Status**: Current state (draft/published/in-progress/implemented/completed)
- **GitHub Link**: Issue reference (if published)

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
rm .claude/agents/android-developer.md
rm .claude/agents/ios-developer.md

# Update commands to only use backend-developer
# Edit these files and remove mobile platform routing:
# - .claude/commands/prd/plan.md
# - .claude/commands/prd/dev-start.md
# - .claude/commands/prd/dev-check.md
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

### 1. Start with the Wizard
Always use `/prdx:wizard` to create PRDs with consistent structure.

### 2. Plan Before Coding
Run `/prdx:plan` to get multi-agent insights before starting implementation.

### 3. Verify Often
Use `/prdx:dev:check` during development, not just at the end.

### 4. Keep PRDs Updated
Update status, blockers, and progress regularly as you work.

### 5. Link Dependencies
Use `/prdx:deps` to track relationships between features.

### 6. Close When Done
Always run `/prdx:close` to properly complete PRDs and track metrics.

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
├── plugin.json           # Claude Code plugin manifest
├── marketplace.json      # Private marketplace config
├── README.md            # This file
├── install.sh           # Installation script
├── .claudeignore        # Files to ignore
├── commands/            # 14 PRD workflow commands
│   ├── wizard.md
│   ├── plan.md
│   ├── list.md
│   ├── search.md
│   ├── update.md
│   ├── close.md
│   ├── publish.md
│   ├── sync.md
│   ├── status.md
│   ├── deps.md
│   ├── help.md
│   └── dev/
│       ├── start.md     # Auto-creates detailed plan inline
│       ├── check.md
│       └── push.md
├── skills/              # 3 specialized skills
│   ├── prd-review.md
│   ├── impl-patterns.md
│   └── testing-strategy.md
└── agents/              # 3 AI agents
    ├── backend-developer.md
    ├── android-developer.md
    └── ios-developer.md
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

### v0.2.0 (2025-01-10)
- **CHANGED**: `/prdx:plan` now creates business-level PRDs only (high-level phases, WHAT not HOW)
- **CHANGED**: `/prdx:dev:start` auto-creates detailed technical plans inline when needed
- Separated business planning from technical planning
- Detailed plans include file paths, API contracts, code patterns, and testing strategy
- Improved workflow: simpler command structure, same powerful features

### v0.1.0 (2024-11-10)
- Initial release
- 14 PRD workflow commands
- 3 specialized skills
- 3 AI agents (backend, Android, iOS)
- GitHub integration
- Status tracking and search
- Dependency management
- Claude Code marketplace support

---

**Made with ❤️ by Kurt**

[Claude Code](https://claude.ai/code) • [GitHub](https://github.com/kuuuurt/prdx)
