# PR Template Cleanup - Remove Noise

## ✅ Changes Made

Simplified PR template based on feedback about noisy PR #472:

---

## 🎯 What Was Too Noisy

### 1. Testing Section - Unrelated Warnings
**Before:**
```markdown
## Testing

- ✅ **15 new tests**: WebSocket connection handling, location validation, Redis pub/sub
- ✅ **Integration tests**: End-to-end location broadcast flow
- ⚠️ **Manual**: Tested WebSocket reconnection on network drop (Pixel 6, iOS 16)
- ⚠️ **Warning**: Monitor memory usage in production
- ⚠️ **Warning**: Check Datadog for connection metrics
```

**Problem:** Warnings about monitoring, deployment, etc. are NOT testing.

**After:**
```markdown
## Testing

- ✅ **15 new tests**: WebSocket handling, location validation, pub/sub
```

**Fixed:** Only tests added/updated in THIS PR.

---

### 2. Review Focus - Too Much Noise
**Before:**
```markdown
## Review Focus

- [ ] **`LocationService.ts`**: Review rate limiting logic in `handleLocationUpdate()` method (max 1/sec per driver)
- [ ] **`location.routes.ts`**: Check coordinate validation and sanitization (no PII leakage)
- [ ] **Redis pub/sub**: Verify channel naming and subscription cleanup in `subscribeToDriver()` method
- [ ] **Deployment**: Verify feature flag is enabled
- [ ] **Monitoring**: Check Datadog dashboard for metrics
- [ ] **Performance**: Monitor response times
```

**Problem:** 
- Too verbose descriptions
- Non-code items (deployment, monitoring)
- Too many items (hard to focus)

**After:**
```markdown
## Review Focus

- [ ] **`LocationService.ts`**: Rate limiting in `handleLocationUpdate()`
- [ ] **`location.routes.ts`**: Coordinate validation and sanitization
```

**Fixed:**
- Short, specific
- Only code review items
- 2-3 items max (focused)

---

### 3. Next Steps - Mentioned Unrelated Things
**Before:**
```markdown
## Next Steps

- Monitor Datadog for errors
- Check CloudWatch logs
- Update documentation
- Deploy to staging first
```

**Problem:** 
- Datadog never mentioned in PR
- Deployment steps (not in PR description)
- Too many post-merge actions

**After:**
```markdown
[REMOVED - Not in template]
```

**Fixed:** Removed "Next Steps" entirely. Not needed in PR description.

---

### 4. PRD Mentioned - Internal Planning Doc
**Before:**
```markdown
## What

Implements location tracking as specified in PRD #234.
```

**Problem:** PRDs are internal planning docs, not for PR descriptions.

**After:**
```markdown
## What

Adds real-time location tracking API for drivers.
```

**Fixed:** Never mention PRD in PR descriptions.

---

## 📝 Updated Template

### Before (Noisy)
```markdown
## Testing

**Highlight tests added/updated for this PR:**

- ✅ **[X new/updated tests]**: [Brief description of what they cover]
- ⚠️ **Manual**: [Specific scenario tested externally, if applicable]

## Review Focus

**Guide reviewers on what to look at in the code:**

- [ ] **[File/Component]**: [Specific logic or pattern to review]
- [ ] **[Edge Case]**: [Behavior or condition to verify in code]
- [ ] **[Security/Performance]**: [Concern to validate in implementation]

## Known Issues / Workarounds

_Optional: Document any temporary solutions or limitations_

- [Issue]: [Workaround or plan to address]
```

### After (Clean)
```markdown
## Testing

- ✅ **[X new/updated tests]**: [What they cover]

## Review Focus

- [ ] **[File.ext]**: [Specific function/logic to check]
- [ ] **[File.ext]**: [Edge case to verify]

## Known Issues

_[Optional - only if there are temporary solutions]_
```

---

## 📋 New Guidelines

### Testing Section
**DO:**
- ✅ List tests added/updated in THIS PR only
- ✅ Keep it 1-2 lines max
- ✅ Format: "X tests: brief description"

**DON'T:**
- ❌ Add warnings about monitoring
- ❌ Mention deployment considerations
- ❌ Include Datadog/CloudWatch/observability
- ❌ Add manual testing unless critical

### Review Focus
**DO:**
- ✅ 2-3 items max (focused)
- ✅ Specific file + function
- ✅ Code-level concerns only
- ✅ Short descriptions

**DON'T:**
- ❌ Verbose explanations
- ❌ Deployment steps
- ❌ Monitoring/observability
- ❌ Vague items like "verify feature works"
- ❌ More than 3 items

### Known Issues
**DO:**
- ✅ Only if there ARE temporary solutions
- ✅ Keep brief: "[Issue] - [Plan]"
- ✅ Skip section if none

**DON'T:**
- ❌ Add placeholder text if empty
- ❌ Explain in detail
- ❌ Add "nice to haves" or future work

### General
**DO:**
- ✅ Keep PR description on 1 screen
- ✅ Focus on code changes
- ✅ Be specific but concise

**DON'T:**
- ❌ Mention PRD anywhere
- ❌ Add "Next Steps" section
- ❌ Include deployment instructions
- ❌ Add observability/monitoring items

---

## 📊 Updated Examples

### Example 1: Backend Feature (Cleaned)

```markdown
## What

Adds real-time location tracking API for drivers.

## Changes

- New: `LocationService` handles WebSocket and Redis pub/sub
- New: `POST /api/v1/driver/location` endpoint
- Updated: Driver model includes `last_location_update`

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

### Example 2: Mobile Bug Fix (Cleaned)

```markdown
## What

Fixes crash when rotating device during biometric prompt on Android 12+.

## Changes

- Fixed: `BiometricPrompt` lifecycle handling in `LoginFragment`
- Updated: Prompt cancellation clears state properly

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

### Example 3: Refactor (Cleaned)

```markdown
## What

Simplifies LoginViewModel by removing Use Case layer.

## Changes

- Removed: `DoLoginUseCase` and `ConfirmOtpUseCase`
- Updated: `LoginViewModel` calls `Auth0Client` directly
- Simplified: State management using `UIState` sealed class

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

## 🎯 Key Improvements

### Removed Noise
1. ❌ Manual testing details (unless critical)
2. ❌ Warning items in Testing section
3. ❌ Monitoring/Datadog/CloudWatch mentions
4. ❌ Deployment considerations
5. ❌ Next Steps section
6. ❌ PRD references
7. ❌ Verbose descriptions in Review Focus

### Kept Signal
1. ✅ Clear What section (1-2 sentences)
2. ✅ Focused Changes (3-5 bullets)
3. ✅ Relevant Testing (1-2 lines)
4. ✅ Specific Review Focus (2-3 items)
5. ✅ Optional Known Issues (only if needed)

---

## 📋 Checklist

**Updated files:**
- [x] PR_TEMPLATE.md (template structure)
- [x] Guidelines (Testing, Review Focus, Known Issues)
- [x] Examples (all 3 cleaned up)
- [x] Added "Never mention PRD" rule

**Noise removed:**
- [x] Verbose descriptions
- [x] Unrelated warnings
- [x] Monitoring mentions
- [x] Deployment steps
- [x] Next Steps section
- [x] PRD references

**Signal preserved:**
- [x] Clear What
- [x] Specific Changes
- [x] Relevant Testing
- [x] Focused Review

---

## 🎯 Summary

**Goal:** Skimmable 1-page PR description

**Changes:**
- Removed noise (monitoring, deployment, verbose text)
- Shortened sections (1-2 lines max)
- Focused Review Focus (2-3 items)
- Never mention PRD
- Keep it tight and relevant

**Result:**
- ✅ Cleaner PR descriptions
- ✅ Easier to review
- ✅ Fits on one screen
- ✅ No fluff

**Keep PR descriptions signal-only, no noise!** 🎯
