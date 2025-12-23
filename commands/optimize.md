---
description: "Simplify code with pragmatic cleanup"
argument-hint: "[files/features]"
---

# /prdx:optimize - Code Cleanup

Simplify code by removing unnecessary complexity, documentation-style comments, and single-use abstractions.

## Usage

```bash
/prdx:optimize                      # Changed files on current branch
/prdx:optimize src/auth/            # Specific directory
/prdx:optimize UserService.kt       # Specific file
/prdx:optimize "authentication"     # Feature name (searches for related files)
```

## Target Files

**Arguments provided:** Optimize specified files/features.

**No arguments:** Optimize ONLY changed files on the current branch:

```bash
git diff --name-only $(git merge-base HEAD main)..HEAD
```

Read those files and focus optimization on changed portions.

## Optimization Rules

### Code Style

| Rule | Action |
|------|--------|
| Self-documenting code | Use descriptive names instead of comments |
| Single-use variables | Inline when expression is clear |
| Single-use private functions | Inline when simple |
| Similar functions | Consolidate into one |
| Unnecessary abstraction | Remove, prefer simplicity |

### Comments

**REMOVE:**
- Comments describing what code does (code should be self-explanatory)
- Comments restating the variable/function name
- Outdated comments that no longer match code
- Redundant documentation headers

**KEEP:**
- `// MARK:` comments (iOS section markers)
- `// TODO:` and `// FIXME:` comments
- Comments explaining **why** (not what)
- Workaround explanations with context
- Complex algorithm descriptions
- Legal/license headers

## Workflow

### Phase 1: Identify Target Files

**If arguments provided:**

```bash
# Check if argument is a file/directory
if [ -f "$ARG" ] || [ -d "$ARG" ]; then
  TARGET="$ARG"
else
  # Search for files related to feature name
  git grep -l "$ARG" --include="*.kt" --include="*.swift" --include="*.ts"
fi
```

**If no arguments:**

```bash
# Get changed files on current branch vs main
CHANGED=$(git diff --name-only $(git merge-base HEAD main)..HEAD)

# Filter to source files only
echo "$CHANGED" | grep -E '\.(kt|swift|ts|tsx|js|jsx)$'
```

Display target files:

```
🎯 Target files:

src/auth/UserService.kt
src/auth/AuthViewModel.kt
src/ui/LoginScreen.kt

Proceed with optimization? (y/n)
```

### Phase 2: Analyze Each File

For each target file:

1. Read the file content
2. Identify optimization opportunities:
   - Documentation-style comments to remove
   - Single-use variables to inline
   - Single-use functions to inline
   - Similar code to consolidate

### Phase 3: Apply Optimizations

Use the Edit tool to apply changes. Show before/after for significant changes.

**Example - Inline single-use variable:**

Before:
```kotlin
val userName = user.name
displayGreeting(userName)
```

After:
```kotlin
displayGreeting(user.name)
```

**Example - Remove documentation comment:**

Before:
```swift
// Get the current user's profile
func getCurrentUserProfile() -> Profile {
```

After:
```swift
func getCurrentUserProfile() -> Profile {
```

**Example - Keep MARK comment (iOS):**

```swift
// MARK: - Lifecycle  ← KEEP THIS
override func viewDidLoad() {
```

**Example - Keep workaround comment:**

```kotlin
// Workaround for Android 12 splash screen bug
// See: https://issuetracker.google.com/issues/12345
Thread.sleep(100)  ← KEEP THE COMMENT
```

### Phase 4: Summary

```
✅ Optimization complete!

Files modified: 3
- src/auth/UserService.kt (removed 5 comments, inlined 2 variables)
- src/auth/AuthViewModel.kt (consolidated 2 functions)
- src/ui/LoginScreen.kt (removed 3 comments)

Total: 12 simplifications applied
```

## Examples

### Optimize Changed Files

```
User: /prdx:optimize

→ Gets changed files from git diff
→ Found: UserService.kt, AuthViewModel.kt

🎯 Target files:

src/auth/UserService.kt (45 lines changed)
src/auth/AuthViewModel.kt (23 lines changed)

Proceed? (y/n)

User: y

→ Analyzes and optimizes each file
→ Applies edits

✅ Optimization complete!

Files modified: 2
Total: 8 simplifications applied
```

### Optimize Specific File

```
User: /prdx:optimize src/auth/UserService.kt

→ Reading UserService.kt
→ Found 6 optimization opportunities

Optimizations:
1. Line 23: Remove comment "// Get user by ID"
2. Line 45: Inline single-use variable `result`
3. Line 67: Remove comment "// Check if valid"
4. Line 89: Inline single-use function `formatName()`
5. Line 112: Remove outdated comment
6. Line 134: Consolidate similar null checks

Apply all? (y/n/select)

User: y

✅ Applied 6 optimizations to UserService.kt
```

### Optimize by Feature Name

```
User: /prdx:optimize "authentication"

→ Searching for files related to "authentication"
→ Found: AuthService.kt, LoginViewModel.kt, AuthRepository.kt

🎯 Target files:

src/auth/AuthService.kt
src/auth/LoginViewModel.kt
src/data/AuthRepository.kt

Proceed? (y/n)
```

## Platform-Specific Rules

### iOS/Swift

- **Keep** `// MARK:` section markers
- **Keep** `#pragma mark` directives
- **Remove** `/// Documentation` comments unless public API

### Android/Kotlin

- **Keep** `@Suppress` annotations with explanations
- **Remove** KDoc on private functions
- **Inline** single-expression functions when clear

### TypeScript

- **Keep** `// @ts-expect-error` with explanation
- **Remove** JSDoc on internal functions
- **Inline** single-use type aliases

## What This Command Does NOT Do

- Refactor architecture (use `/prdx:plan` for that)
- Add new functionality
- Change behavior or logic
- Format code (use formatter)
- Fix bugs
