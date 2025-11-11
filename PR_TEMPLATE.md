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

✅ [X] tests passing | ✅ Coverage: [Y]% | [⚠️ Manual: Specific scenario to test]

## Review Focus

- [ ] [Specific file or logic to review]
- [ ] [Edge case or security concern to verify]

---
Closes #[issue-number] | [Verification passed ✅ / ⚠️ Warning details]

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

**Testing Section** (1 line):
- Show numbers and manual test requirements only
- Format: "✅ X tests | ✅ Y% coverage | ⚠️ Manual: Z"
- If manual test needed, specify what and why

**Review Focus** (2-3 checkboxes):
- Guide reviewers to critical areas
- Specific files, edge cases, or security concerns
- Actionable items reviewers can verify

**Footer** (1 line):
- Link to issue
- Show verification status from auto-check
- Format: "Closes #123 | Verification passed ✅"

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

✅ 15 tests passing | ✅ 89% coverage | ⚠️ Manual: Test WebSocket reconnection on network drop

## Review Focus

- [ ] Verify rate limiting prevents location spam (max 1/sec per driver)
- [ ] Check Redis pub/sub scales to 10k+ concurrent drivers
- [ ] Validate location data sanitization (no PII leakage)

---
Closes #234 | Verification passed ✅
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

✅ 8 regression tests | ✅ Manual: Tested on Pixel 6 (Android 12 & 13)

## Review Focus

- [ ] Verify no memory leaks in Fragment lifecycle
- [ ] Check prompt works after multiple rotations

---
Closes #456 | ⚠️ Manual testing required
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

✅ 24 tests passing | ✅ 91% coverage | ✅ No manual test needed

## Review Focus

- [ ] Verify error handling matches previous behavior
- [ ] Check Login flow still works end-to-end

---
Closes #789 | Verification passed ✅
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

---

## Design Principles

1. **Skimmable**: 30 seconds to understand the PR
2. **1-pager**: Fits on one screen, no scrolling
3. **Essential only**: What changed, why, what to review
4. **Visual hierarchy**: Bullets, short sentences, emojis
5. **Actionable**: Clear guidance for reviewers

**Goal**: Reviewer can understand the PR and know what to focus on in under a minute.
