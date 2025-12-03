# PR Template Update Summary

## ✅ Changes Made

Updated `PR_TEMPLATE.md` to improve reviewer guidance and PR quality.

---

## 🎯 Key Updates

### 1. **Review Focus** - Code-Centric Guidance ✓

**Before:**
```markdown
## Review Focus

- [ ] [Specific file or logic to review]
- [ ] [Edge case or security concern to verify]
```

**After:**
```markdown
## Review Focus

**Guide reviewers on what to look at in the code:**

- [ ] **[File/Component]**: [Specific logic or pattern to review]
- [ ] **[Edge Case]**: [Behavior or condition to verify in code]
- [ ] **[Security/Performance]**: [Concern to validate in implementation]
```

**Improvements:**
- ✅ Explicit instruction to focus on **code review**
- ✅ Format: `**File/Component**: Specific function/logic`
- ✅ Prevents vague items like "Verify feature works"
- ✅ Directs to specific files and methods

**Example:**
```markdown
- [ ] **`AuthService.ts`**: Review token refresh logic in `refreshToken()` method
- [ ] **Edge case**: Check null handling in `getUserProfile()` when user data is missing
```

---

### 2. **Testing** - Focus on This PR's Tests ✓

**Before:**
```markdown
## Testing

✅ [X] tests passing | ✅ Coverage: [Y]% | [⚠️ Manual: Specific scenario to test]
```

**After:**
```markdown
## Testing

**Highlight tests added/updated for this PR:**

- ✅ **[X new/updated tests]**: [Brief description of what they cover]
- ⚠️ **Manual**: [Specific scenario tested externally, if applicable]
```

**Improvements:**
- ✅ Focuses on **new/updated tests** in this PR
- ✅ Removed coverage percentage (not PR-specific)
- ✅ Removed verification status from testing section
- ✅ Highlights what changed, not overall stats

**Example:**
```markdown
- ✅ **15 new tests**: WebSocket connection handling, location validation, Redis pub/sub
- ⚠️ **Manual**: Tested WebSocket reconnection on network drop (Pixel 6, iOS 16)
```

---

### 3. **Known Issues / Workarounds** - New Optional Section ✓

**Added:**
```markdown
## Known Issues / Workarounds

_Optional: Document any temporary solutions or limitations_

- [Issue]: [Workaround or plan to address]
```

**Use Cases:**
- Temporary solutions that need follow-up
- Known limitations or constraints
- Intentional technical debt
- Platform-specific workarounds

**Example:**
```markdown
## Known Issues / Workarounds

- **Android 11 warning**: Suppressed rotation warning dialog - acceptable per UX team (#457)
- **Rate limiting**: Disabled in dev mode - to be re-enabled in #456
```

---

### 4. **Footer** - Added Claude Code Attribution ✓

**Before:**
```markdown
---
Closes #[issue-number] | [Verification passed ✅ / ⚠️ Warning details]
```

**After:**
```markdown
---

Closes #[issue-number]

---

🤖 _Generated with [Claude Code](https://claude.com/claude-code)_
```

**Improvements:**
- ✅ Removed verification status (moved elsewhere or removed)
- ✅ Added Claude Code attribution
- ✅ Cleaner separation with double horizontal rules

---

## 📋 Updated Guidelines

### Testing Section Guidelines

**OLD:**
- Show numbers and manual test requirements only
- Format: "✅ X tests | ✅ Y% coverage | ⚠️ Manual: Z"

**NEW:**
- Highlight tests **added or updated** in this PR
- Format: "✅ X new/updated tests: [what they cover]"
- Include manual testing if done externally
- Don't include verification passed status

### Review Focus Guidelines

**NEW RULES:**
- Guide reviewers on **what to look at in the code**
- Be specific: file names, function names, logic to review
- Focus on code-level concerns (not external actions)

**Examples Added:**
- ✅ "**BiometricService.kt**: Review retry logic in `authenticate()` method"
- ❌ "Verify the feature works" (too vague)
- ✅ "**Error handling**: Check edge cases in `validateInput()` function"
- ❌ "Test on device" (not code review)

---

## 📚 Real Examples Updated

All three examples updated with new format:

### Backend Feature
```markdown
## Testing

- ✅ **15 new tests**: WebSocket connection handling, location validation, Redis pub/sub
- ✅ **Integration tests**: End-to-end location broadcast flow
- ⚠️ **Manual**: Tested WebSocket reconnection on network drop (Pixel 6, iOS 16)

## Review Focus

- [ ] **`LocationService.ts`**: Review rate limiting logic in `handleLocationUpdate()` (max 1/sec per driver)
- [ ] **`location.routes.ts`**: Check coordinate validation and sanitization (no PII leakage)
- [ ] **Redis pub/sub**: Verify channel naming and subscription cleanup in `subscribeToDriver()`

---

Closes #234

---

🤖 _Generated with [Claude Code](https://claude.com/claude-code)_
```

### Mobile Bug Fix
```markdown
## Testing

- ✅ **8 regression tests**: Fragment lifecycle scenarios and state management
- ⚠️ **Manual**: Tested rotation during prompt on Pixel 6 (Android 12 & 13)

## Review Focus

- [ ] **`LoginFragment.kt`**: Review lifecycle handling in `onConfigurationChanged()`
- [ ] **`LoginFragment.kt`**: Check `BiometricPrompt` cleanup in `onDestroy()`
- [ ] **Memory leaks**: Verify `viewLifecycleOwner` usage prevents leaks

## Known Issues / Workarounds

- **Android 11 warning**: Suppressed rotation warning dialog - acceptable per UX team (#457)

---

Closes #456

---

🤖 _Generated with [Claude Code](https://claude.com/claude-code)_
```

### Refactor
```markdown
## Testing

- ✅ **12 updated tests**: Adapted to direct Auth0Client usage
- ✅ **All 24 tests passing**: No behavioral changes, refactor only

## Review Focus

- [ ] **`LoginViewModel.kt`**: Review direct `Auth0Client` calls in `login()` and `confirmOtp()` methods
- [ ] **Error handling**: Verify `mapAuth0Error()` matches previous Use Case behavior
- [ ] **State management**: Check `UIState` transitions in ViewModel

---

Closes #789

---

🤖 _Generated with [Claude Code](https://claude.com/claude-code)_
```

---

## 🚫 New Anti-Patterns

**Added example of vague Review Focus:**

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

## 🎯 Benefits

### For PR Authors
1. ✅ Clear guidance on what to document
2. ✅ Forces thinking about code-level review points
3. ✅ Place to document workarounds/limitations
4. ✅ Consistent attribution format

### For Reviewers
1. ✅ Direct links to specific files and functions
2. ✅ Clear understanding of what changed (tests)
3. ✅ Awareness of known issues upfront
4. ✅ Faster, more focused code review

### For Teams
1. ✅ Better PR quality and review efficiency
2. ✅ Knowledge sharing through specific guidance
3. ✅ Transparency about technical debt
4. ✅ Consistent PR format across team

---

## 📊 Summary

**Sections Updated:** 4
- Testing (focus on new/updated tests)
- Review Focus (code-centric guidance)
- Known Issues/Workarounds (new optional section)
- Footer (Claude Code attribution)

**Guidelines Updated:** 3
- Testing section guidelines
- Review Focus guidelines
- Footer guidelines

**Examples Updated:** 3
- All real examples now follow new format

**Anti-Patterns Added:** 1
- Vague vs specific Review Focus examples

---

## 🔄 Migration

**For existing PRs:**
- No action needed (template is for new PRs)

**For `/prdx:dev:push`:**
- Will automatically use updated template
- Next PR will include:
  - Specific code review guidance
  - Test highlights
  - Optional workarounds section
  - Claude Code attribution

---

**Status:** ✅ Complete and ready to use
**File:** PR_TEMPLATE.md
**Backwards Compatible:** Yes (optional sections)
