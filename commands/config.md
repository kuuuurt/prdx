---
description: "Configure PRDX settings"
argument-hint: "[setting] [value]"
---

# /prdx:config - Configure PRDX Settings

Manage PRDX configuration interactively or via command line.

## Usage

```bash
# Interactive & Quick Setup
/prdx:config                           # Interactive guided setup
/prdx:config minimal                   # Quick: Minimal commits (no co-author, no link)
/prdx:config standard                  # Quick: Standard setup (conventional, detailed)
/prdx:config simple                    # Quick: Simple commits (no conventional prefix)

# View & Initialize
/prdx:config show                      # Show current configuration
/prdx:config init                      # Create default config file

# Granular Control
/prdx:config set commits.format simple # Set specific value
/prdx:config get commits.format        # Get specific value

# Hooks Management
/prdx:config hooks                     # Show available hooks
/prdx:config hooks enable auto-optimize # Enable auto-optimize hook
/prdx:config hooks disable auto-optimize # Disable auto-optimize hook
```

## Workflow

### Phase 1: Determine Mode

Parse arguments to determine mode:

```bash
if [ $# -eq 0 ]; then
  MODE="interactive"
elif [ "$1" = "show" ]; then
  MODE="show"
elif [ "$1" = "init" ]; then
  MODE="init"
elif [ "$1" = "minimal" ]; then
  MODE="preset"
  PRESET="minimal"
elif [ "$1" = "standard" ]; then
  MODE="preset"
  PRESET="standard"
elif [ "$1" = "simple" ]; then
  MODE="preset"
  PRESET="simple"
elif [ "$1" = "set" ]; then
  MODE="set"
  SETTING_PATH="$2"
  VALUE="$3"
elif [ "$1" = "get" ]; then
  MODE="get"
  SETTING_PATH="$2"
elif [ "$1" = "hooks" ]; then
  MODE="hooks"
  HOOKS_ACTION="$2"  # enable, disable, or empty (show)
  HOOK_NAME="$3"     # auto-optimize
else
  echo "❌ Unknown command: $1"
  echo ""
  echo "Usage:"
  echo "  /prdx:config                    # Interactive setup"
  echo "  /prdx:config [minimal|standard|simple]  # Quick presets"
  echo "  /prdx:config [show|init|set|get]        # Manage config"
  echo "  /prdx:config hooks [enable|disable] [hook-name]  # Manage hooks"
  exit 1
fi
```

### Phase 2: Locate or Create Config File

Find or create configuration file:

```bash
# Check for existing config
CONFIG_FILE=""
if [ -f "prdx.json" ]; then
  CONFIG_FILE="prdx.json"
elif [ -f ".prdx/prdx.json" ]; then
  CONFIG_FILE=".prdx/prdx.json"
fi

# For init mode, decide location
if [ "$MODE" = "init" ]; then
  if [ -d ".claude" ]; then
    CONFIG_FILE=".prdx/prdx.json"
  else
    CONFIG_FILE="prdx.json"
  fi

  # Check if already exists
  if [ -f "$CONFIG_FILE" ]; then
    echo "⚠️  Configuration file already exists: $CONFIG_FILE"
    echo ""
    echo "Options:"
    echo "1. View current config: /prdx:config show"
    echo "2. Edit interactively: /prdx:config"
    echo "3. Overwrite (cancel and backup manually)"
    exit 0
  fi
fi

# For other modes, use existing or create default location
if [ -z "$CONFIG_FILE" ] && [ "$MODE" != "init" ]; then
  if [ -d ".claude" ]; then
    CONFIG_FILE=".prdx/prdx.json"
  else
    CONFIG_FILE="prdx.json"
  fi
fi
```

### Phase 3: Execute Mode

#### Mode: show

Display current configuration:

```bash
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ℹ️  No configuration file found"
  echo ""
  echo "Using default configuration:"
  echo ""
  echo "  Commit format: conventional"
  echo "  Co-author: enabled (Claude <noreply@anthropic.com>)"
  echo "  Extended descriptions: enabled"
  echo "  Claude Code link: enabled"
  echo "  Default PR base: main"
  echo "  Auto-assign PR: enabled"
  echo ""
  echo "To create a config file: /prdx:config init"
  exit 0
fi

echo "📋 Current Configuration"
echo ""
echo "File: $CONFIG_FILE"
echo ""

if command -v jq &> /dev/null; then
  echo "Commits:"
  echo "  Format: $(jq -r '.commits.format // "conventional"' "$CONFIG_FILE")"
  echo "  Co-author enabled: $(jq -r '.commits.coAuthor.enabled // true' "$CONFIG_FILE")"
  echo "  Co-author name: $(jq -r '.commits.coAuthor.name // "Claude"' "$CONFIG_FILE")"
  echo "  Co-author email: $(jq -r '.commits.coAuthor.email // "noreply@anthropic.com"' "$CONFIG_FILE")"
  echo "  Extended descriptions: $(jq -r '.commits.extendedDescription.enabled // true' "$CONFIG_FILE")"
  echo "  Claude Code link: $(jq -r '.commits.extendedDescription.includeClaudeCodeLink // true' "$CONFIG_FILE")"
  echo ""
  echo "Pull Requests:"
  echo "  Default base: $(jq -r '.pullRequest.defaultBase // "main"' "$CONFIG_FILE")"
  echo "  Auto-assign: $(jq -r '.pullRequest.autoAssign // true' "$CONFIG_FILE")"
else
  # Fallback: show raw JSON if jq not available
  cat "$CONFIG_FILE"
fi

echo ""
echo "To edit: /prdx:config"
```

#### Mode: init

Create default configuration file:

```bash
cat > "$CONFIG_FILE" <<'EOF'
{
  "$schema": "https://raw.githubusercontent.com/kuuuurt/prdx/main/schema.json",
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
EOF

echo "✅ Configuration file created: $CONFIG_FILE"
echo ""
echo "To view: /prdx:config show"
echo "To edit: /prdx:config"
```

#### Mode: preset

Apply quick configuration presets:

```bash
# Determine preset configuration
case "$PRESET" in
  "minimal")
    # Minimal: No co-author, no link, concise
    cat > "$CONFIG_FILE" <<'EOF'
{
  "$schema": "https://raw.githubusercontent.com/kuuuurt/prdx/main/schema.json",
  "version": "1.0",
  "commits": {
    "coAuthor": {
      "enabled": false,
      "name": "Claude",
      "email": "noreply@anthropic.com"
    },
    "extendedDescription": {
      "enabled": false,
      "includeClaudeCodeLink": false
    },
    "format": "conventional"
  },
  "pullRequest": {
    "defaultBase": "main",
    "autoAssign": true
  }
}
EOF
    PRESET_NAME="Minimal"
    PRESET_DESC="Conventional commits with no co-author or extended descriptions"
    ;;

  "standard")
    # Standard: Everything enabled, conventional
    cat > "$CONFIG_FILE" <<'EOF'
{
  "$schema": "https://raw.githubusercontent.com/kuuuurt/prdx/main/schema.json",
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
EOF
    PRESET_NAME="Standard"
    PRESET_DESC="Conventional commits with co-author and extended descriptions"
    ;;

  "simple")
    # Simple: Simple format, everything else enabled
    cat > "$CONFIG_FILE" <<'EOF'
{
  "$schema": "https://raw.githubusercontent.com/kuuuurt/prdx/main/schema.json",
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
    "format": "simple"
  },
  "pullRequest": {
    "defaultBase": "main",
    "autoAssign": true
  }
}
EOF
    PRESET_NAME="Simple"
    PRESET_DESC="Simple commit format (no type prefix) with co-author and descriptions"
    ;;
esac

echo "✅ Applied '$PRESET_NAME' preset"
echo ""
echo "$PRESET_DESC"
echo ""
echo "Configuration saved to: $CONFIG_FILE"
echo ""
echo "Example commit:"
echo ""

# Show example based on preset
case "$PRESET" in
  "minimal")
    cat <<'EOF'
feat: add user authentication

EOF
    ;;
  "standard")
    cat <<'EOF'
feat: add user authentication

Implement JWT-based authentication with secure password hashing
and token refresh mechanism.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
    ;;
  "simple")
    cat <<'EOF'
add user authentication

Implement JWT-based authentication with secure password hashing
and token refresh mechanism.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
    ;;
esac

echo ""
echo "Commands:"
echo "  View config: /prdx:config show"
echo "  Customize:   /prdx:config"
```

#### Mode: get

Get specific configuration value:

```bash
if [ -z "$SETTING_PATH" ]; then
  echo "❌ No setting path provided"
  echo "Usage: /prdx:config get <setting.path>"
  echo ""
  echo "Examples:"
  echo "  /prdx:config get commits.format"
  echo "  /prdx:config get commits.coAuthor.enabled"
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ℹ️  No configuration file found, using defaults"
  # Return default values based on path
  case "$SETTING_PATH" in
    "commits.format") echo "conventional" ;;
    "commits.coAuthor.enabled") echo "true" ;;
    "commits.coAuthor.name") echo "Claude" ;;
    "commits.coAuthor.email") echo "noreply@anthropic.com" ;;
    "commits.extendedDescription.enabled") echo "true" ;;
    "commits.extendedDescription.includeClaudeCodeLink") echo "true" ;;
    "pullRequest.defaultBase") echo "main" ;;
    "pullRequest.autoAssign") echo "true" ;;
    *) echo "null" ;;
  esac
  exit 0
fi

if command -v jq &> /dev/null; then
  VALUE=$(jq -r ".$SETTING_PATH // empty" "$CONFIG_FILE")
  if [ -z "$VALUE" ]; then
    echo "❌ Setting not found: $SETTING_PATH"
    exit 1
  fi
  echo "$VALUE"
else
  echo "⚠️  jq not installed - cannot read JSON config"
  echo "Install: brew install jq (macOS) or apt-get install jq (Linux)"
  exit 1
fi
```

#### Mode: set

Set specific configuration value:

```bash
if [ -z "$SETTING_PATH" ] || [ -z "$VALUE" ]; then
  echo "❌ Missing arguments"
  echo "Usage: /prdx:config set <setting.path> <value>"
  echo ""
  echo "Examples:"
  echo "  /prdx:config set commits.format simple"
  echo "  /prdx:config set commits.coAuthor.enabled false"
  echo "  /prdx:config set commits.coAuthor.name 'Your Name'"
  exit 1
fi

# Ensure config file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ℹ️  No configuration file found, creating with defaults..."
  /prdx:config init
fi

if ! command -v jq &> /dev/null; then
  echo "⚠️  jq not installed - cannot modify JSON config"
  echo "Install: brew install jq (macOS) or apt-get install jq (Linux)"
  echo ""
  echo "Alternative: Edit manually: $CONFIG_FILE"
  exit 1
fi

# Validate setting path
case "$SETTING_PATH" in
  commits.format)
    if [ "$VALUE" != "conventional" ] && [ "$VALUE" != "simple" ]; then
      echo "❌ Invalid value for commits.format: $VALUE"
      echo "Allowed values: conventional, simple"
      exit 1
    fi
    ;;
  commits.coAuthor.enabled|commits.extendedDescription.enabled|commits.extendedDescription.includeClaudeCodeLink|pullRequest.autoAssign)
    if [ "$VALUE" != "true" ] && [ "$VALUE" != "false" ]; then
      echo "❌ Invalid boolean value: $VALUE"
      echo "Allowed values: true, false"
      exit 1
    fi
    ;;
esac

# Create backup
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"

# Update value
if [[ "$VALUE" == "true" ]] || [[ "$VALUE" == "false" ]]; then
  # Boolean value
  jq ".$SETTING_PATH = $VALUE" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
else
  # String value
  jq ".$SETTING_PATH = \"$VALUE\"" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
fi

# Check if jq succeeded
if [ $? -eq 0 ]; then
  mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
  rm "${CONFIG_FILE}.backup"
  echo "✅ Updated $SETTING_PATH = $VALUE"
  echo ""
  echo "To view all settings: /prdx:config show"
else
  echo "❌ Failed to update configuration"
  mv "${CONFIG_FILE}.backup" "$CONFIG_FILE"
  rm -f "${CONFIG_FILE}.tmp"
  exit 1
fi
```

#### Mode: interactive

Interactive configuration using AskUserQuestion tool:

```
Use the AskUserQuestion tool to guide users through configuration:

questions: [
  {
    question: "What commit message format do you prefer?",
    header: "Format",
    multiSelect: false,
    options: [
      {
        label: "Conventional commits",
        description: "feat: description - Standard conventional commits with type prefix"
      },
      {
        label: "Simple messages",
        description: "description - Plain commit messages without type prefix"
      }
    ]
  },
  {
    question: "How detailed should commit messages be?",
    header: "Detail",
    multiSelect: false,
    options: [
      {
        label: "Detailed",
        description: "Multi-line commits with extended explanations of changes"
      },
      {
        label: "Concise",
        description: "Single-line commit messages, brief and to the point"
      }
    ]
  },
  {
    question: "What attribution should commits include?",
    header: "Attribution",
    multiSelect: true,
    options: [
      {
        label: "Co-author (Claude)",
        description: "Add 'Co-Authored-By: Claude' footer to all commits"
      },
      {
        label: "Claude Code link",
        description: "Include 'Generated with Claude Code' link in commits"
      }
    ]
  },
  {
    question: "What's your default base branch for pull requests?",
    header: "PR Base",
    multiSelect: false,
    options: [
      {
        label: "main",
        description: "Use 'main' as the default base branch"
      },
      {
        label: "master",
        description: "Use 'master' as the default base branch"
      },
      {
        label: "develop",
        description: "Use 'develop' as the default base branch"
      }
    ]
  }
]

Map answers to configuration:
- Format: "Conventional commits" → conventional, "Simple messages" → simple
- Detail: "Detailed" → extendedDescription.enabled = true, "Concise" → false
- Attribution (multi-select):
  - "Co-author (Claude)" selected → coAuthor.enabled = true
  - "Claude Code link" selected → includeClaudeCodeLink = true
- PR Base: Use selected value directly

Generate JSON config:
{
  "version": "1.0",
  "commits": {
    "format": <mapped_format>,
    "coAuthor": {
      "enabled": <from_attribution>,
      "name": "Claude",
      "email": "noreply@anthropic.com"
    },
    "extendedDescription": {
      "enabled": <from_detail>,
      "includeClaudeCodeLink": <from_attribution>
    }
  },
  "pullRequest": {
    "defaultBase": <selected_base>,
    "autoAssign": true
  }
}

Write to CONFIG_FILE and show summary with preview:

✅ Configuration saved to {CONFIG_FILE}

Your commit format will look like this:

{Show example commit based on their choices}

Settings:
  📝 Format: {conventional/simple}
  📄 Detail level: {detailed/concise}
  👥 Co-author: {enabled/disabled}
  🤖 Claude Code link: {enabled/disabled}
  🔀 Default PR base: {branch}

Commands:
  View config:   /prdx:config show
  Change format: /prdx:config set commits.format {value}
  Disable co-author: /prdx:config set commits.coAuthor.enabled false
```

#### Mode: hooks

Manage PRDX hooks for the current project.

```bash
# Determine settings file location
SETTINGS_FILE=".claude/settings.local.json"

# Ensure .claude directory exists
mkdir -p .claude

# Create settings file if it doesn't exist
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi
```

**Show available hooks (no action):**

```bash
if [ -z "$HOOKS_ACTION" ]; then
  echo "🔧 PRDX Hooks"
  echo ""
  echo "Available hooks:"
  echo ""
  echo "  auto-optimize"
  echo "    Prompts optimization of changed lines after Edit/Write operations."
  echo "    Removes documentation-style comments, inlines single-use variables"
  echo "    and functions."
  echo ""

  # Check if hook is enabled
  if command -v jq &> /dev/null && [ -f "$SETTINGS_FILE" ]; then
    HOOK_ENABLED=$(jq -r '.hooks.PostToolUse[]?.hooks[]?.command // empty' "$SETTINGS_FILE" 2>/dev/null | grep -c "post-edit-optimize" || true)
    if [ "$HOOK_ENABLED" -gt 0 ]; then
      echo "  Status: ✅ enabled"
    else
      echo "  Status: ❌ disabled"
    fi
  else
    echo "  Status: ❌ disabled"
  fi

  echo ""
  echo "Commands:"
  echo "  /prdx:config hooks enable auto-optimize"
  echo "  /prdx:config hooks disable auto-optimize"
  exit 0
fi
```

**Enable hook:**

```bash
if [ "$HOOKS_ACTION" = "enable" ]; then
  if [ -z "$HOOK_NAME" ]; then
    echo "❌ No hook name provided"
    echo "Usage: /prdx:config hooks enable <hook-name>"
    echo ""
    echo "Available hooks: auto-optimize"
    exit 1
  fi

  case "$HOOK_NAME" in
    "auto-optimize")
      # Find the plugin hooks directory
      PLUGIN_DIR=""
      if [ -d "$HOME/.claude/plugins/prdx/hooks/prdx" ]; then
        PLUGIN_DIR="$HOME/.claude/plugins/prdx"
      elif [ -d ".claude/plugins/prdx/hooks/prdx" ]; then
        PLUGIN_DIR=".claude/plugins/prdx"
      else
        echo "❌ PRDX plugin not found"
        echo ""
        echo "Install PRDX first:"
        echo "  /plugin marketplace add kuuuurt/prdx"
        exit 1
      fi

      # Add hook configuration using jq
      if ! command -v jq &> /dev/null; then
        echo "⚠️  jq not installed - cannot modify settings"
        echo ""
        echo "Install: brew install jq (macOS) or apt-get install jq (Linux)"
        echo ""
        echo "Manual setup: Add this to $SETTINGS_FILE:"
        cat << 'MANUAL_EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$PLUGIN_DIR/hooks/prdx/post-edit-optimize.sh"
          }
        ]
      }
    ]
  }
}
MANUAL_EOF
        exit 1
      fi

      # Create or update the settings file with the hook
      HOOK_CONFIG=$(cat << EOF
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$PLUGIN_DIR/hooks/prdx/post-edit-optimize.sh"
          }
        ]
      }
    ]
  }
}
EOF
)

      # Merge with existing settings
      if [ -f "$SETTINGS_FILE" ] && [ -s "$SETTINGS_FILE" ]; then
        jq -s '.[0] * .[1]' "$SETTINGS_FILE" <(echo "$HOOK_CONFIG") > "${SETTINGS_FILE}.tmp"
        mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
      else
        echo "$HOOK_CONFIG" > "$SETTINGS_FILE"
      fi

      echo "✅ Enabled auto-optimize hook"
      echo ""
      echo "The hook will prompt optimization after Edit/Write operations on:"
      echo "  .kt, .kts, .swift, .ts, .tsx, .js, .jsx, .py, .go, .rs files"
      echo ""
      echo "Optimization rules:"
      echo "  - Remove documentation-style comments (keeps // MARK:, // TODO:)"
      echo "  - Inline single-use variables when expression is clear"
      echo "  - Inline single-use private functions when simple"
      echo ""
      echo "To disable: /prdx:config hooks disable auto-optimize"
      ;;
    *)
      echo "❌ Unknown hook: $HOOK_NAME"
      echo ""
      echo "Available hooks: auto-optimize"
      exit 1
      ;;
  esac
fi
```

**Disable hook:**

```bash
if [ "$HOOKS_ACTION" = "disable" ]; then
  if [ -z "$HOOK_NAME" ]; then
    echo "❌ No hook name provided"
    echo "Usage: /prdx:config hooks disable <hook-name>"
    exit 1
  fi

  case "$HOOK_NAME" in
    "auto-optimize")
      if ! command -v jq &> /dev/null; then
        echo "⚠️  jq not installed - cannot modify settings"
        echo "Manual: Remove the PostToolUse hook from $SETTINGS_FILE"
        exit 1
      fi

      if [ -f "$SETTINGS_FILE" ]; then
        # Remove the auto-optimize hook from PostToolUse
        jq 'del(.hooks.PostToolUse[] | select(.hooks[]?.command | contains("post-edit-optimize")))' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"
        mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"

        # Clean up empty arrays
        jq 'if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end | if .hooks == {} then del(.hooks) else . end' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"
        mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
      fi

      echo "✅ Disabled auto-optimize hook"
      echo ""
      echo "To re-enable: /prdx:config hooks enable auto-optimize"
      ;;
    *)
      echo "❌ Unknown hook: $HOOK_NAME"
      echo ""
      echo "Available hooks: auto-optimize"
      exit 1
      ;;
  esac
fi
```

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

  auto-optimize
    Prompts optimization of changed lines after Edit/Write operations.
    Removes documentation-style comments, inlines single-use variables
    and functions.

  Status: ❌ disabled

Commands:
  /prdx:config hooks enable auto-optimize
  /prdx:config hooks disable auto-optimize
```

### Example 7: Enable Auto-Optimize Hook

```
User: /prdx:config hooks enable auto-optimize

✅ Enabled auto-optimize hook

The hook will prompt optimization after Edit/Write operations on:
  .kt, .kts, .swift, .ts, .tsx, .js, .jsx, .py, .go, .rs files

Optimization rules:
  - Remove documentation-style comments (keeps // MARK:, // TODO:)
  - Inline single-use variables when expression is clear
  - Inline single-use private functions when simple

To disable: /prdx:config hooks disable auto-optimize
```

### Example 8: Disable Auto-Optimize Hook

```
User: /prdx:config hooks disable auto-optimize

✅ Disabled auto-optimize hook

To re-enable: /prdx:config hooks enable auto-optimize
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

### File Location Priority

1. Check for existing config in project root
2. Check for existing config in `.claude/` directory
3. Create new config in `.claude/` if directory exists
4. Otherwise create in project root

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
