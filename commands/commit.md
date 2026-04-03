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

Load commit config from the shared script (config variables set via Pre-Computed Context):

```bash
source "$(git rev-parse --show-toplevel)/hooks/prdx/resolve-commit-config.sh"
```

This sets: `COMMIT_FORMAT`, `COAUTHOR_ENABLED`, `COAUTHOR_NAME`, `COAUTHOR_EMAIL`, `EXTENDED_DESC_ENABLED`, `CLAUDE_LINK_ENABLED`.

Display loaded configuration:

```
Commit Configuration
Format: {COMMIT_FORMAT} | Co-Author: {COAUTHOR_ENABLED} ({COAUTHOR_NAME} <{COAUTHOR_EMAIL}>) | Extended: {EXTENDED_DESC_ENABLED} | Link: {CLAUDE_LINK_ENABLED}
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

## Notes

- Always use HEREDOC format for commits: `git commit -m "$(cat <<'EOF' ... EOF)"`
- Conventional types: feat, fix, refactor, docs, test, chore, style, perf
- When `extendedDescription.enabled` is false, the subject line IS the entire commit (no description body)
- See `/prdx:config` for all configuration options and examples
