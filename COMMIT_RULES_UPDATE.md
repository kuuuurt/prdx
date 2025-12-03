# PRDX Commit Rules - Simple One-Line Format

## ✅ Update Complete

Clarified and enforced simple one-line conventional commit format throughout PRDX.

---

## 📋 Commit Format Rules

### The Simple Format

```bash
git commit -m "type: description"
```

**That's it. Nothing more.**

---

## ✅ DO

### Good Examples

```bash
git commit -m "feat: add user authentication"
git commit -m "test: add login validation tests"
git commit -m "fix: handle null pointer in auth service"
git commit -m "refactor: simplify error handling logic"
git commit -m "chore: update dependencies"
```

**Characteristics:**
- ✅ One line only
- ✅ Format: `type: description`
- ✅ Clear and concise
- ✅ Describes what changed
- ✅ Lowercase description

---

## ❌ DON'T

### Bad Examples

```bash
# ❌ Extended description (body)
git commit -m "feat: add user authentication

Added login and signup flows with email validation.
Updated the database schema to support new user table."

# ❌ Co-author tags
git commit -m "feat: add user authentication

Co-Authored-By: Claude <noreply@anthropic.com>"

# ❌ Multiple lines
git commit -m "feat: add user authentication
- Added login flow
- Added signup flow
- Added validation"

# ❌ Issue footer
git commit -m "feat: add user authentication

Closes #123"
```

**Why these are wrong:**
- ❌ Multi-line (body/footer)
- ❌ Co-author tags
- ❌ Extra metadata
- ❌ Too verbose

---

## 📝 Commit Types

**Standard types used in PRDX:**

| Type | Purpose | Example |
|------|---------|---------|
| `feat:` | New feature | `feat: add OAuth login` |
| `fix:` | Bug fix | `fix: resolve memory leak` |
| `test:` | Test changes | `test: add auth unit tests` |
| `refactor:` | Code refactoring | `refactor: extract validation logic` |
| `chore:` | Maintenance | `chore: update dependencies` |
| `docs:` | Documentation | `docs: update API readme` |

---

## 🔧 Implementation in Commands

### commands/dev.md

**Phase 8: Commit task**

```markdown
5. **Commit task** (one task = one commit):
   ```bash
   git add [relevant files]
   git commit -m "[type]: [simple description]"
   ```

   **IMPORTANT: Commit format rules:**
   - ✅ One-line only: `type: description`
   - ✅ No extended description (no body)
   - ✅ No co-author tags
   - ✅ Keep it simple and atomic
```

**Important Notes section:**

```markdown
### Commits (Simple One-Line Format)
- **CONVENTIONAL COMMITS** - Format: `type: description`
- **ONE LINE ONLY** - No extended description, no body, no footers
- **NO CO-AUTHOR TAGS** - Never add Co-Authored-By or similar tags
- **ONE TASK = ONE COMMIT** - Keep commits atomic and focused
- **CLEAR MESSAGES** - Describe what, not how
- **Examples:**
  - ✅ `feat: add user authentication`
  - ✅ `test: add login validation tests`
  - ❌ `feat: add user auth\n\nAdded flows\n\nCo-Authored-By...`
```

---

## 📖 Updated Documentation

### CLAUDE.md

**Important Notes section:**

```markdown
- **Conventional commits**: All commits follow simple `type: description` format (one-line only)
- **No extended descriptions**: Never use commit body or footers
- **No co-authors**: Never add Co-Authored-By or similar tags
```

---

## 🎯 Why This Format?

### 1. Simplicity
- ✅ Easy to write
- ✅ Easy to read
- ✅ No ambiguity

### 2. Clean History
- ✅ `git log --oneline` is already perfect
- ✅ No need for `git log --pretty=short`
- ✅ Scannable history

### 3. Focus on Code
- ✅ Commit message describes WHAT changed
- ✅ Code diff shows HOW it changed
- ✅ PRD/issue provides context WHY

### 4. Automated Workflows
- ✅ Easy to parse for changelogs
- ✅ Works with conventional-changelog
- ✅ Consistent format for CI/CD

---

## 📊 Git History Example

**With simple one-line commits:**

```bash
$ git log --oneline
a3b2c1d feat: add biometric authentication
e4f5g6h test: add biometric auth tests
i7j8k9l feat: implement token refresh logic
m0n1o2p fix: handle expired token edge case
```

**Clean, scannable, perfect.** ✅

**vs. verbose commits:**

```bash
$ git log --oneline
a3b2c1d feat: add biometric authentication
        (shows only first line, hides the mess below)
```

You'd need `git log` (not `--oneline`) to see the full mess.

---

## 🛡️ Enforcement

### In /prdx:dev

**During implementation:**
- Each task gets one commit
- Format enforced: `type: description`
- No prompts for extended description
- No co-author tags added

**Example flow:**
```bash
# Phase 8: Task execution
1. Implement feature
2. Run tests (verify green)
3. Commit:
   git add src/auth/service.ts
   git commit -m "feat: implement login validation"
4. Move to next task
```

### In /prdx:dev:push

**PR creation uses PR template, NOT commit messages:**
- Commits: Simple one-line
- PR description: Detailed (from PR_TEMPLATE.md)
- Clear separation of concerns

---

## 📋 Checklist

**Updated files:**
- [x] commands/dev.md (Phase 8 + Important Notes)
- [x] CLAUDE.md (Important Notes section)
- [x] Documentation clarified
- [x] Examples provided (good vs bad)

**Rules enforced:**
- [x] One-line only
- [x] No extended description
- [x] No co-author tags
- [x] Conventional format: `type: description`

---

## 🎯 Summary

**Rule:**
```bash
git commit -m "type: description"
```

**That's it. Nothing more. Keep it simple.**

**Benefits:**
- ✅ Clean history
- ✅ Easy to scan
- ✅ No clutter
- ✅ Focused commits

**Remember:**
- One line
- No body
- No co-authors
- Just: `type: description`

**The simplest format is the best format!** ✨
