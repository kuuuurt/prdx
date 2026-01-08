---
description: "Create a commit using PRDX configuration settings"
argument-hint: "[message]"
---

# /prdx:commit - Create Commit

Create a git commit following the project's PRDX configuration for commit format, co-authorship, and extended descriptions.

## Usage

```bash
/prdx:commit "add user authentication"
/prdx:commit                           # Auto-generate message from changes
```

## How It Works

This command creates commits based on `prdx.json` settings:

| Setting | Effect |
|---------|--------|
| `commits.format` | "conventional" or "simple" |
| `commits.coAuthor.enabled` | Adds Co-Authored-By trailer |
| `commits.extendedDescription.enabled` | Adds detailed description |
| `commits.extendedDescription.includeClaudeCodeLink` | Adds Claude Code attribution |

## Workflow

### Phase 1: Load Configuration

Load PRDX configuration:

```bash
# Load prdx.json config (check multiple locations)
CONFIG_FILE=""
if [ -f "prdx.json" ]; then
  CONFIG_FILE="prdx.json"
elif [ -f ".prdx/prdx.json" ]; then
  CONFIG_FILE=".prdx/prdx.json"
fi

# Parse config or use defaults
if [ -n "$CONFIG_FILE" ]; then
  # Read config values using jq if available, otherwise use defaults
  if command -v jq &> /dev/null; then
    COAUTHOR_ENABLED=$(jq -r '.commits.coAuthor.enabled // true' "$CONFIG_FILE")
    COAUTHOR_NAME=$(jq -r '.commits.coAuthor.name // "Claude"' "$CONFIG_FILE")
    COAUTHOR_EMAIL=$(jq -r '.commits.coAuthor.email // "noreply@anthropic.com"' "$CONFIG_FILE")
    EXTENDED_DESC_ENABLED=$(jq -r '.commits.extendedDescription.enabled // true' "$CONFIG_FILE")
    CLAUDE_LINK_ENABLED=$(jq -r '.commits.extendedDescription.includeClaudeCodeLink // true' "$CONFIG_FILE")
    COMMIT_FORMAT=$(jq -r '.commits.format // "conventional"' "$CONFIG_FILE")
  else
    # Defaults if jq not available
    COAUTHOR_ENABLED=true
    COAUTHOR_NAME="Claude"
    COAUTHOR_EMAIL="noreply@anthropic.com"
    EXTENDED_DESC_ENABLED=true
    CLAUDE_LINK_ENABLED=true
    COMMIT_FORMAT="conventional"
  fi
else
  # Use defaults if no config file
  COAUTHOR_ENABLED=true
  COAUTHOR_NAME="Claude"
  COAUTHOR_EMAIL="noreply@anthropic.com"
  EXTENDED_DESC_ENABLED=true
  CLAUDE_LINK_ENABLED=true
  COMMIT_FORMAT="conventional"
fi
```

Display loaded configuration:

```
📋 Commit Configuration
Format: {COMMIT_FORMAT}
Co-Author: {COAUTHOR_ENABLED} ({COAUTHOR_NAME} <{COAUTHOR_EMAIL}>)
Extended Description: {EXTENDED_DESC_ENABLED}
Claude Code Link: {CLAUDE_LINK_ENABLED}
```

### Phase 2: Check Git State

```bash
# Check for staged changes
STAGED=$(git diff --cached --name-only)

# Check for unstaged changes
UNSTAGED=$(git diff --name-only)

# Check for untracked files
UNTRACKED=$(git ls-files --others --exclude-standard)
```

**If no staged changes:**

```
⚠️  No staged changes

Unstaged changes:
{UNSTAGED}

Untracked files:
{UNTRACKED}

Stage changes first:
  git add <files>
  git add -A  (all changes)

Or use: /prdx:commit --all "message"
```

**If `--all` flag used:** Stage all changes first.

### Phase 3: Analyze Changes

Review staged changes to understand the commit:

```bash
# Get list of changed files
git diff --cached --name-status

# Get summary of changes
git diff --cached --stat
```

**If no message provided:**

Analyze the changes and generate an appropriate commit message:

1. Look at the files changed
2. Read the diffs to understand what changed
3. Determine the type (feat, fix, refactor, etc.)
4. Write a concise summary

**Display proposed message based on config:**

```
📝 Proposed commit:

{TYPE}: {SUBJECT}
```

**Then ONLY add these sections if their corresponding setting is enabled:**

- If `EXTENDED_DESC_ENABLED` is `true`: Add blank line + extended description
- If `CLAUDE_LINK_ENABLED` is `true`: Add blank line + Claude Code link
- If `COAUTHOR_ENABLED` is `true`: Add blank line + Co-Authored-By line

**Example proposal when extendedDescription is DISABLED:**
```
📝 Proposed commit:

feat: add user authentication

Proceed? (y/n/edit)
```

**Example proposal when extendedDescription is ENABLED:**
```
📝 Proposed commit:

feat: add user authentication

Implement authentication endpoints with JWT token generation
and password hashing using bcrypt.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

Proceed? (y/n/edit)
```

### Phase 4: Build Commit Message

**CRITICAL: Build the commit message STRICTLY based on the configuration values loaded in Phase 1.**

**STRICT RULES - READ CAREFULLY:**

1. **If `EXTENDED_DESC_ENABLED` is `false`:**
   - The commit message is ONLY the subject line
   - DO NOT add any description after the subject
   - DO NOT add blank lines after the subject (unless needed for trailers below)
   - The commit should be concise, single-purpose

2. **If `CLAUDE_LINK_ENABLED` is `false`:**
   - DO NOT include the Claude Code link line
   - DO NOT include the 🤖 emoji line at all

3. **If `COAUTHOR_ENABLED` is `false`:**
   - DO NOT include the Co-Authored-By line

**Build the message in this order:**

**Line 1 (Subject) - ALWAYS REQUIRED:**
- If `COMMIT_FORMAT` is `conventional`: `{type}: {description}`
- If `COMMIT_FORMAT` is `simple`: `{description}`

**Extended Description - ONLY if `EXTENDED_DESC_ENABLED` is `true`:**
- Blank line
- Detailed explanation of the changes
- What and why (not how)
- **SKIP ENTIRELY if `EXTENDED_DESC_ENABLED` is `false`**

**Claude Code Link - ONLY if `CLAUDE_LINK_ENABLED` is `true`:**
- Blank line
- `🤖 Generated with [Claude Code](https://claude.com/claude-code)`
- **SKIP ENTIRELY if `CLAUDE_LINK_ENABLED` is `false`**

**Co-Author - ONLY if `COAUTHOR_ENABLED` is `true`:**
- Blank line
- `Co-Authored-By: {name} <{email}>`
- **SKIP ENTIRELY if `COAUTHOR_ENABLED` is `false`**

### Phase 5: Create Commit

**ALWAYS use HEREDOC format:**

```bash
git commit -m "$(cat <<'EOF'
{COMMIT_MESSAGE}
EOF
)"
```

**Example with all options enabled (conventional format, extendedDescription=true):**

```bash
git commit -m "$(cat <<'EOF'
feat: add user authentication

Implement authentication endpoints with JWT token generation
and password hashing using bcrypt.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**Example with extendedDescription DISABLED (conventional format):**

```bash
git commit -m "$(cat <<'EOF'
feat: add user authentication
EOF
)"
```

**Example with extendedDescription DISABLED but co-author enabled (conventional format):**

```bash
git commit -m "$(cat <<'EOF'
feat: add user authentication

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**Example with simple format and extendedDescription DISABLED:**

```bash
git commit -m "$(cat <<'EOF'
add user authentication
EOF
)"
```

**IMPORTANT: When `extendedDescription.enabled` is `false`, there should be NO multi-line explanation of changes. The subject line IS the entire commit message (plus optional trailers like co-author).**

### Phase 6: Display Result

```
✅ Commit created!

{COMMIT_HASH} {SUBJECT}

Files changed: {COUNT}
Insertions: +{ADDITIONS}
Deletions: -{DELETIONS}

Branch: {CURRENT_BRANCH}
```

## Options

### --all / -a

Stage all changes before committing:

```bash
/prdx:commit --all "fix login bug"
```

Equivalent to `git add -A && git commit`.

### --amend

Amend the previous commit:

```bash
/prdx:commit --amend
```

**Safety checks:**
1. Check authorship: `git log -1 --format='%an %ae'`
2. Check not pushed: branch is ahead of remote
3. Only amend if both conditions pass

### --dry-run

Show what would be committed without creating the commit:

```bash
/prdx:commit --dry-run "add feature"
```

## Error Handling

### No Changes to Commit

```
❌ Nothing to commit

Working tree is clean. Make changes first.
```

### Not in a Git Repository

```
❌ Not a git repository

Initialize with: git init
```

### Commit Failed

```
❌ Commit failed

{ERROR_MESSAGE}

Check:
1. Staged changes exist
2. No merge conflicts
3. Pre-commit hooks passed
```

### Pre-Commit Hook Failed

```
⚠️  Pre-commit hook modified files

Files changed:
{CHANGED_FILES}

Amending commit to include hook changes...
```

If safe to amend (authorship matches, not pushed), automatically amend.

## Configuration Examples

### Full Attribution (Default)

`prdx.json`:
```json
{
  "commits": {
    "format": "conventional",
    "coAuthor": {
      "enabled": true,
      "name": "Claude",
      "email": "noreply@anthropic.com"
    },
    "extendedDescription": {
      "enabled": true,
      "includeClaudeCodeLink": true
    }
  }
}
```

Produces:
```
feat: add authentication

Implement JWT-based authentication with refresh tokens
and secure password hashing.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Minimal Commits

`prdx.json`:
```json
{
  "commits": {
    "format": "simple",
    "coAuthor": {
      "enabled": false
    },
    "extendedDescription": {
      "enabled": false,
      "includeClaudeCodeLink": false
    }
  }
}
```

Produces:
```
add authentication
```

### Conventional Without Attribution

`prdx.json`:
```json
{
  "commits": {
    "format": "conventional",
    "coAuthor": {
      "enabled": false
    },
    "extendedDescription": {
      "enabled": true,
      "includeClaudeCodeLink": false
    }
  }
}
```

Produces:
```
feat: add authentication

Implement JWT-based authentication with refresh tokens
and secure password hashing.
```

## Examples

### Basic Commit with Message

```
User: /prdx:commit "add login endpoint"

→ Loads prdx.json config
→ Checks staged changes exist
→ Creates commit with configured format

✅ Commit created!

a1b2c3d feat: add login endpoint

Files changed: 3
Insertions: +45
Deletions: -0
```

### Auto-Generated Message (with extendedDescription ENABLED)

```
User: /prdx:commit

→ Loads prdx.json: extendedDescription.enabled = true
→ Analyzes staged changes
→ Determines: new auth module files
→ Proposes: "feat: add authentication module"

📝 Proposed commit:

feat: add authentication module

Add JWT-based authentication with login and refresh endpoints.
Includes middleware for protected routes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

Proceed? (y/n/edit)

User: y

✅ Commit created!
```

### Auto-Generated Message (with extendedDescription DISABLED)

```
User: /prdx:commit

→ Loads prdx.json: extendedDescription.enabled = false
→ Analyzes staged changes
→ Determines: new auth module files
→ Proposes: "feat: add authentication module"

📝 Proposed commit:

feat: add authentication module

Proceed? (y/n/edit)

User: y

✅ Commit created!
```

**Note:** When extendedDescription is disabled, the commit is just the subject line. NO extended description is added.

### Commit All Changes

```
User: /prdx:commit --all "fix validation bug"

→ Stages all changes
→ Creates commit

✅ Commit created!

d4e5f6g fix: fix validation bug

Files changed: 2
Insertions: +12
Deletions: -5
```

## Implementation Notes

### Why HEREDOC Format?

HEREDOC ensures:
- Multi-line messages work correctly
- Special characters are preserved
- Consistent formatting across shells

**Always use:**
```bash
git commit -m "$(cat <<'EOF'
message here
EOF
)"
```

**Never use simple quotes for multi-line commits.**

### Conventional Commit Types

| Type | When to Use |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code change without feature/fix |
| `docs` | Documentation only |
| `test` | Adding/updating tests |
| `chore` | Maintenance tasks |
| `style` | Formatting changes |
| `perf` | Performance improvements |

### Co-Author Best Practices

- Only attribute when Claude contributed meaningfully
- Use consistent email format
- Keep attribution honest and accurate
