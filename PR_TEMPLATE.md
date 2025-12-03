# PR Description Template

**This is the template used by `/prdx:dev:push` to create skimmable 1-pager PR descriptions.**

---

## What

[1-2 sentence summary: "This PR [adds/fixes/refactors] X to achieve Y"]

## Changes

- New: [Component/Feature added]
- Updated: [Component/Feature modified]
- Fixed: [Component/Feature fixed]
- Removed: [Component/Feature removed]

## Testing

- ✅ **[X new/updated tests]**: [What they cover]

## Review Focus

- [ ] **[File.ext]**: [Specific function/logic to check]
- [ ] **[File.ext]**: [Edge case to verify]

## Known Issues

_[Optional - only if there are temporary solutions]_

---

Closes #[issue-number]

---

🤖 _Generated with [Claude Code](https://claude.com/claude-code)_

---

## Guidelines

**What Section** (2-3 lines max):
- Pull from PRD goal
- Focus on the "why" and high-level "what"
- Example: "Adds biometric authentication to replace password-only login for better UX and security"

**Changes Section** (3-5 bullets max):
- Focus on WHAT changed, not HOW
- Group related changes
- Use prefixes: New, Updated, Fixed, Removed
- Be specific but concise: "New: `BiometricAuthService` handles fingerprint/face ID"

**Testing Section** (1-2 lines max):
- **ONLY tests added/updated in THIS PR**
- NO unrelated warnings, deployment notes, or monitoring
- Format: "✅ X new/updated tests: [what they cover]"
- Keep it tight and relevant

**Review Focus** (2-3 checkboxes max):
- **ONLY code-level review items**
- Be specific: file names, function names, logic to check
- NO vague items, NO external actions, NO deployment steps
- Examples:
  - ✅ "**service.ts**: Check null handling in `processOrder()`"
  - ❌ "Verify feature works" (vague)
  - ❌ "Monitor logs in production" (not code review)
  - ❌ "Check Datadog dashboard" (deployment, not review)

**Known Issues** (Optional):
- **ONLY if there are temporary solutions**
- Keep brief: "[Issue] - [Plan]"
- Skip this section if none

**Footer** (2 lines):
- Link to issue: "Closes #123"
- Claude Code attribution: "🤖 Generated with Claude Code"
- **NEVER mention PRD** - PRDs are internal planning docs, not for PR descriptions

---

## Real Examples

### Backend Feature
```markdown
## What

Adds real-time location tracking API for drivers to enable live map updates in rider app.

## Changes

- New: `LocationService` handles WebSocket connections and Redis pub/sub
- New: `POST /api/v1/driver/location` endpoint validates and broadcasts location
- Updated: Driver model includes `last_location_update` timestamp
- Updated: Auth middleware validates driver session tokens

## Testing

- ✅ **15 new tests**: WebSocket handling, location validation, pub/sub

## Review Focus

- [ ] **`LocationService.ts`**: Rate limiting in `handleLocationUpdate()`
- [ ] **`location.routes.ts`**: Coordinate validation and sanitization

---

Closes #234

---

🤖 _Generated with [Claude Code](https://claude.com/claude-code)_
```

### Mobile Bug Fix
```markdown
## What

Fixes crash when users rotate device during biometric prompt on Android 12+.

## Changes

- Fixed: `BiometricPrompt` lifecycle handling in `LoginFragment`
- Updated: Prompt cancellation clears state properly
- Added: Rotation config change handling in manifest

## Testing

- ✅ **8 regression tests**: Fragment lifecycle and state management

## Review Focus

- [ ] **`LoginFragment.kt`**: Lifecycle handling in `onConfigurationChanged()`
- [ ] **`LoginFragment.kt`**: Cleanup in `onDestroy()`

## Known Issues

- Android 11 rotation warning suppressed - UX approved (#457)

---

Closes #456

---

🤖 _Generated with [Claude Code](https://claude.com/claude-code)_
```

### Refactor
```markdown
## What

Simplifies LoginViewModel by removing Use Case layer and calling Auth0Client directly per new architecture.

## Changes

- Removed: `DoLoginUseCase` and `ConfirmOtpUseCase` (deprecated pattern)
- Updated: `LoginViewModel` calls `Auth0Client` directly
- Simplified: State management using `UIState` sealed class
- Updated: 12 tests adapted to new structure

## Testing

- ✅ **12 updated tests**: Adapted to direct Auth0Client usage

## Review Focus

- [ ] **`LoginViewModel.kt`**: Direct `Auth0Client` calls in `login()`
- [ ] **Error handling**: Verify `mapAuth0Error()` matches previous behavior

---

Closes #789

---

🤖 _Generated with [Claude Code](https://claude.com/claude-code)_
```

---

## Anti-Patterns

❌ **Don't write prose**:
```markdown
In this PR, I've implemented a comprehensive solution that addresses
the requirements outlined in the PRD...
```

❌ **Don't dump implementation tasks**:
```markdown
- Created BiometricAuthService.kt file
- Added imports for AndroidX Biometric
- Wrote validateBiometric function
[20 more low-level tasks...]
```

❌ **Don't explain HOW in Changes**:
```markdown
- Refactored LocationService to use the Observer pattern with a custom
  EventEmitter that implements WeakRef to prevent memory leaks by...
```

✅ **Do keep it high-level and scannable**:
```markdown
- New: LocationService handles real-time updates
- Updated: Driver model tracks location
```

❌ **Don't give vague Review Focus**:
```markdown
- [ ] Verify the feature works correctly
- [ ] Check for edge cases
- [ ] Test error handling
```

✅ **Do provide specific code-level guidance**:
```markdown
- [ ] **`AuthService.ts`**: Review token refresh logic in `refreshToken()` method
- [ ] **Edge case**: Check null handling in `getUserProfile()` when user data is missing
- [ ] **Error handling**: Verify 401/403 responses map correctly in `handleAuthError()`
```

---

## Design Principles

1. **Skimmable**: 30 seconds to understand the PR
2. **1-pager**: Fits on one screen, no scrolling
3. **Essential only**: What changed, why, what to review
4. **Visual hierarchy**: Bullets, short sentences, emojis
5. **Actionable**: Clear guidance for reviewers

**Goal**: Reviewer can understand the PR and know what to focus on in under a minute.
