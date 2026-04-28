#!/bin/bash
# config-handler.sh — All bash mode handlers for /prdx:config.
# Usage from commands/config.md:
#   source hooks/prdx/config-handler.sh
#   handle_config "$MODE" "$@"
# Modes: show | init | preset | get | set | hooks | plans
# (Mode "interactive" stays in the command since it uses AskUserQuestion.)

set +e

# ----- Shared: locate or pick CONFIG_FILE -----
locate_config() {
  CONFIG_FILE=""
  local d="$(pwd)"
  while [ "$d" != "/" ]; do
    if [ -f "$d/prdx.json" ]; then CONFIG_FILE="$d/prdx.json"; break
    elif [ -f "$d/.prdx/prdx.json" ]; then CONFIG_FILE="$d/.prdx/prdx.json"; break
    fi
    d="$(dirname "$d")"
  done
  if [ -z "$CONFIG_FILE" ]; then
    if [ -d ".claude" ]; then CONFIG_FILE=".prdx/prdx.json"; else CONFIG_FILE="prdx.json"; fi
  fi
  export CONFIG_FILE
}

# ----- Mode: show -----
mode_show() {
  if [ ! -f "$CONFIG_FILE" ]; then
    cat <<EOF
ℹ️  No configuration file found

Defaults: conventional commits, co-author enabled, extended descriptions on,
Claude Code link on, PR base main, auto-assign on.

Create one: /prdx:config init
EOF
    return 0
  fi
  echo "📋 Configuration: $CONFIG_FILE"
  if command -v jq >/dev/null 2>&1; then
    jq -r '"Format: \(.commits.format // "conventional")
Co-author: \(.commits.coAuthor.enabled // true) (\(.commits.coAuthor.name // "Claude") <\(.commits.coAuthor.email // "noreply@anthropic.com")>)
Extended desc: \(.commits.extendedDescription.enabled // true)
Claude link: \(.commits.extendedDescription.includeClaudeCodeLink // true)
PR base: \(.pullRequest.defaultBase // "main")
Auto-assign: \(.pullRequest.autoAssign // true)"' "$CONFIG_FILE"
  else
    cat "$CONFIG_FILE"
  fi
}

# ----- Mode: init -----
mode_init() {
  if [ -f "$CONFIG_FILE" ]; then
    echo "⚠️  Config exists: $CONFIG_FILE — use /prdx:config show or edit manually"
    return 0
  fi
  cat > "$CONFIG_FILE" <<'EOF'
{
  "$schema": "https://raw.githubusercontent.com/kuuuurt/prdx/main/schema.json",
  "version": "1.0",
  "commits": {
    "coAuthor": {"enabled": true, "name": "Claude", "email": "noreply@anthropic.com"},
    "extendedDescription": {"enabled": true, "includeClaudeCodeLink": true},
    "format": "conventional"
  },
  "pullRequest": {"defaultBase": "main", "autoAssign": true}
}
EOF
  echo "✅ Created $CONFIG_FILE"
}

# ----- Mode: preset -----
_write_preset() {
  local fmt="$1" coa="$2" ext="$3" link="$4"
  cat > "$CONFIG_FILE" <<EOF
{
  "\$schema": "https://raw.githubusercontent.com/kuuuurt/prdx/main/schema.json",
  "version": "1.0",
  "commits": {
    "coAuthor": {"enabled": $coa, "name": "Claude", "email": "noreply@anthropic.com"},
    "extendedDescription": {"enabled": $ext, "includeClaudeCodeLink": $link},
    "format": "$fmt"
  },
  "pullRequest": {"defaultBase": "main", "autoAssign": true}
}
EOF
}
mode_preset() {
  case "$1" in
    minimal)  _write_preset "conventional" "false" "false" "false"; echo "✅ Applied 'minimal' preset → $CONFIG_FILE" ;;
    standard) _write_preset "conventional" "true"  "true"  "true";  echo "✅ Applied 'standard' preset → $CONFIG_FILE" ;;
    simple)   _write_preset "simple"       "true"  "true"  "true";  echo "✅ Applied 'simple' preset → $CONFIG_FILE" ;;
    *) echo "❌ Unknown preset: $1"; return 1 ;;
  esac
}

# ----- Mode: get -----
mode_get() {
  local key="$1"
  [ -z "$key" ] && { echo "❌ Usage: /prdx:config get <setting.path>"; return 1; }
  if [ ! -f "$CONFIG_FILE" ]; then
    case "$key" in
      commits.format) echo "conventional" ;;
      commits.coAuthor.enabled|commits.extendedDescription.enabled|commits.extendedDescription.includeClaudeCodeLink|pullRequest.autoAssign) echo "true" ;;
      commits.coAuthor.name) echo "Claude" ;;
      commits.coAuthor.email) echo "noreply@anthropic.com" ;;
      pullRequest.defaultBase) echo "main" ;;
      *) echo "null" ;;
    esac
    return 0
  fi
  command -v jq >/dev/null 2>&1 || { echo "⚠️  jq not installed"; return 1; }
  jq -r ".$key // empty" "$CONFIG_FILE"
}

# ----- Mode: set -----
mode_set() {
  local key="$1" val="$2"
  [ -z "$key" ] || [ -z "$val" ] && { echo "❌ Usage: /prdx:config set <setting.path> <value>"; return 1; }
  command -v jq >/dev/null 2>&1 || { echo "⚠️  jq not installed"; return 1; }
  [ -f "$CONFIG_FILE" ] || mode_init
  case "$key" in
    commits.format)
      [ "$val" != "conventional" ] && [ "$val" != "simple" ] && { echo "❌ format: conventional|simple"; return 1; } ;;
    commits.coAuthor.enabled|commits.extendedDescription.enabled|commits.extendedDescription.includeClaudeCodeLink|pullRequest.autoAssign)
      [ "$val" != "true" ] && [ "$val" != "false" ] && { echo "❌ boolean: true|false"; return 1; } ;;
  esac
  local tmp; tmp=$(mktemp "${CONFIG_FILE}.XXXXXX") || return 1
  if [ "$val" = "true" ] || [ "$val" = "false" ]; then
    jq ".$key = $val" "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
  else
    jq --arg v "$val" ".$key = \$v" "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
  fi
  echo "✅ $key = $val"
}

# ----- Mode: hooks -----
mode_hooks() {
  local action="$1" name="$2"
  local SETTINGS=".claude/settings.local.json"
  mkdir -p .claude
  [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

  if [ -z "$action" ]; then
    echo "🔧 Available hooks: auto-simplify"
    if command -v jq >/dev/null 2>&1; then
      local on=$(jq -r '.hooks.PostToolUse[]?.hooks[]?.command // empty' "$SETTINGS" 2>/dev/null | grep -c "post-edit-simplify" || true)
      [ "$on" -gt 0 ] && echo "  auto-simplify: enabled" || echo "  auto-simplify: disabled"
    fi
    return 0
  fi

  command -v jq >/dev/null 2>&1 || { echo "⚠️  jq not installed"; return 1; }
  [ -z "$name" ] && { echo "❌ Usage: /prdx:config hooks $action <hook-name>"; return 1; }
  [ "$name" != "auto-simplify" ] && { echo "❌ Unknown hook: $name"; return 1; }

  local PLUGIN_DIR=""
  [ -d "$HOME/.claude/plugins/prdx/hooks/prdx" ] && PLUGIN_DIR="$HOME/.claude/plugins/prdx"
  [ -z "$PLUGIN_DIR" ] && [ -d ".claude/plugins/prdx/hooks/prdx" ] && PLUGIN_DIR=".claude/plugins/prdx"

  if [ "$action" = "enable" ]; then
    [ -z "$PLUGIN_DIR" ] && { echo "❌ PRDX plugin not found"; return 1; }
    local cfg=$(cat <<EOF
{"hooks":{"PostToolUse":[{"matcher":"Edit|Write","hooks":[{"type":"command","command":"$PLUGIN_DIR/hooks/prdx/post-edit-simplify.sh"}]}]}}
EOF
)
    jq -s '.[0] * .[1]' "$SETTINGS" <(echo "$cfg") > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "✅ Enabled auto-simplify"
  elif [ "$action" = "disable" ]; then
    jq 'del(.hooks.PostToolUse[]? | select(.hooks[]?.command | contains("post-edit-simplify")))' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    jq 'if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end | if .hooks == {} then del(.hooks) else . end' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "✅ Disabled auto-simplify"
  else
    echo "❌ Unknown action: $action"; return 1
  fi
}

# ----- Mode: plans -----
mode_plans() {
  local action="$1" path="$2"
  source "$(git rev-parse --show-toplevel)/hooks/prdx/resolve-plans-dir.sh"
  local SETTINGS="$PROJECT_ROOT/.claude/settings.local.json"
  mkdir -p "$PROJECT_ROOT/.claude"
  [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

  if [ -z "$action" ]; then
    echo "📁 Plans: $PLANS_DIR"
    [ -n "$CONFIG_FILE" ] && echo "  Config: $CONFIG_FILE (plansDirectory=\"$PLANS_SUBDIR\")"
    return 0
  fi

  command -v jq >/dev/null 2>&1 || { echo "⚠️  jq not installed"; return 1; }

  if [ "$action" = "local" ]; then
    jq --arg d "$PLANS_SUBDIR" '. + {plansDirectory: $d}' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    mkdir -p "$PLANS_DIR"
    echo "local" > "$PROJECT_ROOT/.prdx/plans-setup-done"
    echo "✅ Plans dir: $PLANS_DIR"
    return 0
  fi

  if [ "$action" = "set" ]; then
    [ -z "$path" ] && { echo "❌ Usage: /prdx:config plans set <path>"; return 1; }
    echo "$path" | grep -q "^/" && { echo "❌ Absolute paths not allowed"; return 1; }
    echo "$path" | grep -qE "(^|/)\.\.(/|$)" && { echo "❌ Parent traversal not allowed"; return 1; }
    local target="${CONFIG_FILE:-$PROJECT_ROOT/prdx.json}"
    [ -f "$target" ] || echo '{}' > "$target"
    jq --arg d "$path" '. + {plansDirectory: $d}' "$target"   > "$target.tmp"   && mv "$target.tmp"   "$target"
    jq --arg d "$path" '. + {plansDirectory: $d}' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    mkdir -p "$PROJECT_ROOT/$path"
    echo "local" > "$PROJECT_ROOT/.prdx/plans-setup-done"
    echo "✅ Plans dir: $PROJECT_ROOT/$path"
    return 0
  fi

  echo "❌ Unknown plans action: $action"; return 1
}

# ----- Dispatcher -----
handle_config() {
  local mode="$1"; shift
  locate_config
  case "$mode" in
    show)    mode_show ;;
    init)    mode_init ;;
    preset)  mode_preset "$@" ;;
    get)     mode_get "$@" ;;
    set)     mode_set "$@" ;;
    hooks)   mode_hooks "$@" ;;
    plans)   mode_plans "$@" ;;
    *) echo "❌ Unknown mode: $mode"; return 1 ;;
  esac
}
