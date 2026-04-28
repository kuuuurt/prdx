---
description: "Configure PRDX settings"
argument-hint: "[setting] [value]"
---

# /prdx:config — Configure PRDX Settings

Manage PRDX configuration interactively or via command line.

## Usage

```bash
/prdx:config                              # Interactive guided setup
/prdx:config minimal|standard|simple      # Quick presets
/prdx:config show | init                  # View / create default
/prdx:config get <path>                   # Get value (e.g. commits.format)
/prdx:config set <path> <value>           # Set value
/prdx:config hooks [enable|disable] <name>
/prdx:config plans [local|set <path>]
```

Settings paths: `commits.format` (conventional|simple), `commits.coAuthor.enabled`, `commits.coAuthor.name`, `commits.coAuthor.email`, `commits.extendedDescription.enabled`, `commits.extendedDescription.includeClaudeCodeLink`, `pullRequest.defaultBase`, `pullRequest.autoAssign`.

## Workflow

### Phase 1: Parse Arguments and Dispatch

Determine `MODE` from `$1`:

| `$1` | MODE |
|---|---|
| (empty) | `interactive` |
| `show` / `init` | matching mode |
| `minimal` / `standard` / `simple` | `preset` (with $1 as preset name) |
| `set` | `set` (use `$2` path, `$3` value) |
| `get` | `get` (use `$2` path) |
| `hooks` | `hooks` (use `$2` action, `$3` name) |
| `plans` | `plans` (use `$2` action, `$3` path) |

For all bash modes (everything except `interactive`), source the handler:

```bash
source "$(git rev-parse --show-toplevel)/hooks/prdx/config-handler.sh"
handle_config "$MODE" "$@"
```

The hook walks up to find `prdx.json` (supports monorepos), exports `CONFIG_FILE`, and dispatches to the matching mode function. It handles defaults when no config exists, jq-based reads/writes for `set`/`get`, settings.local.json updates for `hooks`/`plans`, and validation.

### Phase 2: Interactive Mode

Only invoked when `MODE=interactive`. Use AskUserQuestion to walk the user through four questions:

1. **Format** — Conventional commits | Simple messages
2. **Detail** — Detailed (extendedDescription on) | Concise (off)
3. **Attribution** (multiSelect) — Co-author (Claude) | Claude Code link
4. **PR base** — main | master | develop

Map answers and write `prdx.json`:

```json
{
  "version": "1.0",
  "commits": {
    "format": "<conventional|simple>",
    "coAuthor": {"enabled": <bool>, "name": "Claude", "email": "noreply@anthropic.com"},
    "extendedDescription": {"enabled": <bool>, "includeClaudeCodeLink": <bool>}
  },
  "pullRequest": {"defaultBase": "<branch>", "autoAssign": true}
}
```

After writing, show the resolved config and an example commit matching the choices.
