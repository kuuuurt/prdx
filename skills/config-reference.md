# Config Reference Skill

Reference material for `/prdx:config` — examples, error handling, configuration settings, and implementation notes. Agents implementing or extending the config command should read this file for expected behavior and conventions.

## Examples

### Example 1: Quick Preset - Minimal

```
User: /prdx:config minimal

✅ Applied 'Minimal' preset

Conventional commits with no co-author or extended descriptions

Configuration saved to: .prdx/prdx.json

Example commit:

feat: add user authentication


Commands:
  View config: /prdx:config show
  Customize:   /prdx:config
```

### Example 2: Quick Preset - Standard

```
User: /prdx:config standard

✅ Applied 'Standard' preset

Conventional commits with co-author and extended descriptions

Configuration saved to: .prdx/prdx.json

Example commit:

feat: add user authentication

Implement JWT-based authentication with secure password hashing
and token refresh mechanism.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

Commands:
  View config: /prdx:config show
  Customize:   /prdx:config
```

### Example 3: Quick Preset - Simple

```
User: /prdx:config simple

✅ Applied 'Simple' preset

Simple commit format (no type prefix) with co-author and descriptions

Configuration saved to: .prdx/prdx.json

Example commit:

add user authentication

Implement JWT-based authentication with secure password hashing
and token refresh mechanism.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

Commands:
  View config: /prdx:config show
  Customize:   /prdx:config
```

### Example 4: Show Current Config

```
User: /prdx:config show

📋 Current Configuration

File: .prdx/prdx.json

Commits:
  Format: conventional
  Co-author enabled: true
  Co-author name: Claude
  Co-author email: noreply@anthropic.com
  Extended descriptions: true
  Claude Code link: true

Pull Requests:
  Default base: main
  Auto-assign: true

To edit: /prdx:config
```

### Example 2: Initialize Config

```
User: /prdx:config init

✅ Configuration file created: .prdx/prdx.json

To view: /prdx:config show
To edit: /prdx:config
```

### Example 3: Set Specific Value

```
User: /prdx:config set commits.format simple

✅ Updated commits.format = simple

To view all settings: /prdx:config show
```

### Example 4: Interactive Setup

```
User: /prdx:config

[Interactive questions via AskUserQuestion]

✅ Configuration saved to .prdx/prdx.json

Your settings:
  Commit format: conventional
  Co-author: enabled
  Extended descriptions: enabled
  Claude Code link: enabled
  Default PR base: main
  Auto-assign PRs: enabled

To view anytime: /prdx:config show
```

### Example 5: Get Specific Value

```
User: /prdx:config get commits.format

conventional
```

### Example 6: View Hooks

```
User: /prdx:config hooks

🔧 PRDX Hooks

Available hooks:

  auto-simplify
    Prompts optimization of changed lines after Edit/Write operations.
    Removes documentation-style comments, inlines single-use variables
    and functions.

  Status: ❌ disabled

Commands:
  /prdx:config hooks enable auto-simplify
  /prdx:config hooks disable auto-simplify
```

### Example 7: Enable Auto-Simplify Hook

```
User: /prdx:config hooks enable auto-simplify

✅ Enabled auto-simplify hook

The hook will prompt optimization after Edit/Write operations on:
  .kt, .kts, .swift, .ts, .tsx, .js, .jsx, .py, .go, .rs files

Optimization rules:
  - Remove documentation-style comments (keeps // MARK:, // TODO:)
  - Inline single-use variables when expression is clear
  - Inline single-use private functions when simple

To disable: /prdx:config hooks disable auto-simplify
```

### Example 8: Disable Auto-Simplify Hook

```
User: /prdx:config hooks disable auto-simplify

✅ Disabled auto-simplify hook

To re-enable: /prdx:config hooks enable auto-simplify
```

### Example 9: Show Plans Directory

```
User: /prdx:config plans

📁 Plans Directory

  Directory: /Users/alice/projects/my-app/.prdx/plans
  Plans are tracked in git as project documentation.

Commands:
  /prdx:config plans local   # Set up project-local plans
```

### Example 10: Set Up Local Plans

```
User: /prdx:config plans local

✅ Project-local plans configured

  Directory: /Users/alice/projects/my-app/.prdx/plans
  Setting:   plansDirectory = ".prdx/plans" in .claude/settings.local.json

Plans are saved to .prdx/plans/ and tracked in git as project documentation.
```

## Error Handling

### jq Not Installed

```
⚠️  jq not installed - cannot modify JSON config

Install:
  macOS: brew install jq
  Linux: apt-get install jq

Alternative: Edit manually: .prdx/prdx.json
```

### Invalid Setting Path

```
❌ Setting not found: invalid.path

Valid paths:
  commits.format
  commits.coAuthor.enabled
  commits.coAuthor.name
  commits.coAuthor.email
  commits.extendedDescription.enabled
  commits.extendedDescription.includeClaudeCodeLink
  pullRequest.defaultBase
  pullRequest.autoAssign
```

### Invalid Value

```
❌ Invalid value for commits.format: invalid

Allowed values: conventional, simple
```

## Configuration Settings Reference

### commits.format
- **Type**: string
- **Values**: `conventional` | `simple`
- **Default**: `conventional`
- **Example**: `/prdx:config set commits.format simple`

### commits.coAuthor.enabled
- **Type**: boolean
- **Default**: `true`
- **Example**: `/prdx:config set commits.coAuthor.enabled false`

### commits.coAuthor.name
- **Type**: string
- **Default**: `Claude`
- **Example**: `/prdx:config set commits.coAuthor.name "Your Name"`

### commits.coAuthor.email
- **Type**: string
- **Default**: `noreply@anthropic.com`
- **Example**: `/prdx:config set commits.coAuthor.email "your@email.com"`

### commits.extendedDescription.enabled
- **Type**: boolean
- **Default**: `true`
- **Example**: `/prdx:config set commits.extendedDescription.enabled false`

### commits.extendedDescription.includeClaudeCodeLink
- **Type**: boolean
- **Default**: `true`
- **Example**: `/prdx:config set commits.extendedDescription.includeClaudeCodeLink false`

### pullRequest.defaultBase
- **Type**: string
- **Default**: `main`
- **Example**: `/prdx:config set pullRequest.defaultBase develop`

### pullRequest.autoAssign
- **Type**: boolean
- **Default**: `true`
- **Example**: `/prdx:config set pullRequest.autoAssign false`

## Implementation Notes

### Interactive Mode Implementation

Use AskUserQuestion tool to create user-friendly configuration:

```javascript
{
  questions: [
    {
      question: "What commit message format do you prefer?",
      header: "Format",
      multiSelect: false,
      options: [
        {
          label: "Conventional (feat: description)",
          description: "Uses conventional commits with type prefix"
        },
        {
          label: "Simple (description)",
          description: "Plain commit messages without type prefix"
        }
      ]
    },
    // ... more questions
  ]
}
```

Map answers to configuration values and generate JSON.

### JSON Manipulation

Use `jq` for JSON manipulation when available:
- Reading: `jq -r '.commits.format' prdx.json`
- Writing: `jq '.commits.format = "simple"' prdx.json`
- Provide fallback instructions if `jq` not available

### File Location Priority (Walk-Up Resolution)

**Reading config** (show, get, and all commands that load config):
1. Check `prdx.json` in current directory
2. Check `.prdx/prdx.json` in current directory
3. Walk up to parent directory and repeat
4. Continue until found or filesystem root reached

This supports monorepo/meta-project layouts:
```
meta/               ← prdx.json found here
  project1/         ← working directory (no config here)
  project2/
  .prdx/prdx.json
```

**Creating config** (init, set, preset, interactive):
1. If config found via walk-up, modify it in place
2. If no config found, create in current directory:
   - `.prdx/prdx.json` if `.claude/` directory exists
   - `prdx.json` otherwise

### Validation

Validate values before writing:
- Enum values (conventional/simple)
- Boolean values (true/false)
- String values (any non-empty string)
- Provide clear error messages for invalid inputs

### Backup

Always create backup before modifying:
```bash
cp prdx.json prdx.json.backup
```

Remove backup only after successful update.
