# /prdx:dev - Critical Test Review Checkpoint

## ✅ Update Complete

Added mandatory user review checkpoint after tests are written, before implementation begins.

---

## 🎯 New Workflow

### Updated Phase Order

**Before:**
1. Create plan
2. Setup branch
3. Write tests
4. ~~Implement~~ ← No review!

**After:**
1. Create plan (Phase 3-4)
2. Setup branch (Phase 5)
3. Write tests (Phase 6)
4. **⚠️ USER REVIEW CHECKPOINT** (Phase 7) ← NEW!
5. Implement (Phase 8)
6. Verify tests pass (Phase 9)

---

## ⚠️ Phase 7: CRITICAL Review Checkpoint

### What Happens

After tests are written and committed, `/prdx:dev` **STOPS** and displays:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  CRITICAL: Test Review Required
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Tests have been written and committed. Please review them before
implementation begins.

Test files created:
  - tests/auth/LoginTest.kt (5 tests)
  - tests/auth/SessionTest.kt (4 tests)
  - tests/ui/LoginScreenTest.kt (3 tests)

Review checklist:
  ✓ Tests cover all acceptance criteria
  ✓ Test structure follows Given-When-Then pattern
  ✓ Test names clearly describe expected behavior
  ✓ Edge cases are covered
  ✓ No implementation details leaked into tests

Actions:
  1. Review test files listed above
  2. Run tests to verify they fail: [test command for platform]
  3. Make any needed changes to tests
  4. Commit changes if modified

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Are the tests ready for implementation? (yes/no)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### User Options

**1. Approve (yes)**
```
User: yes

✓ Tests approved. Proceeding with implementation...
[continues to Phase 8]
```

**2. Request Changes (no)**
```
User: no

Tests need revision. What would you like to change?

Options:
1. Describe changes needed (I'll update the tests)
2. You'll edit manually (I'll wait)
3. Cancel implementation (stop here)

Your choice:
```

**Option 1: AI Updates Tests**
```
User: 1
User: "Add edge case for empty email field"

Updating tests based on feedback...
[AI updates test files]
git commit -m "test: update test scaffolds based on review"

Tests updated. Ready to proceed? (yes/no)
```

**Option 2: Manual Edit**
```
User: 2

Waiting for you to edit tests... Type 'ready' when done.

User: ready

[Check git status]
Please commit your test changes, then type 'continue'

User: continue

✓ Tests updated. Proceeding with implementation...
```

**Option 3: Cancel**
```
User: 3

Implementation cancelled. Tests are committed.
Run /prdx:dev again when ready.

[Exit cleanly]
```

---

## 🛡️ Safety Guarantees

### CRITICAL Rules

1. **NEVER proceed without "yes"**
   - Implementation blocked until user approves
   - No automatic bypass
   - No timeout

2. **Tests must be committed first**
   - Tests committed before review prompt
   - User can inspect via git
   - Changes trackable

3. **Multiple review rounds supported**
   - Can request changes multiple times
   - Each revision reviewed again
   - Loop until approved

4. **Cancel anytime**
   - Exit cleanly without implementation
   - Tests remain committed
   - Can resume later with `/prdx:dev`

---

## 📋 Review Checklist

**Automatically shown to user:**

- ✓ Tests cover all acceptance criteria
- ✓ Test structure follows Given-When-Then pattern
- ✓ Test names clearly describe expected behavior
- ✓ Edge cases are covered
- ✓ No implementation details leaked into tests

**User verifies:**
- Tests actually fail when run
- Test logic is correct
- Edge cases match requirements
- No premature implementation

---

## 🔄 Updated Workflow Scenarios

### Scenario 1: Fresh Implementation

```
/prdx:dev backend-auth

1. Create plan
2. Setup branch
3. Write tests → Commit
4. ⚠️ REVIEW CHECKPOINT
   → User reviews tests
   → User: "yes"
5. Implement features
6. Verify tests pass
7. Done!
```

### Scenario 2: Tests Need Changes

```
/prdx:dev backend-auth

1. Create plan
2. Setup branch
3. Write tests → Commit
4. ⚠️ REVIEW CHECKPOINT
   → User reviews tests
   → User: "no" → "Add null check test"
   → AI updates tests → Commit
   → User: "yes"
5. Implement features
6. Verify tests pass
7. Done!
```

### Scenario 3: Cancel After Review

```
/prdx:dev backend-auth

1. Create plan
2. Setup branch
3. Write tests → Commit
4. ⚠️ REVIEW CHECKPOINT
   → User reviews tests
   → User: "no" → "Cancel"
   → Exit cleanly
   
[Later...]
/prdx:dev backend-auth
→ Continues from existing tests
```

### Scenario 4: Refactor (No New Tests)

```
/prdx:dev backend-auth "refactor"

1. Update plan
2. Existing tests already exist
3. ⚠️ SKIP REVIEW (no new tests)
4. Implement refactor
5. Verify tests still pass
6. Done!
```

---

## 📊 Phase Summary

| Phase | Name | Action | User Interaction |
|-------|------|--------|------------------|
| 1-2 | Context | Load PRD | None |
| 3-4 | Planning | Create/update plan | Approve plan |
| 5 | Setup | Git branch | None |
| 6 | Tests | Write & commit tests | None |
| **7** | **⚠️ Review** | **Wait for approval** | **REQUIRED** |
| 8 | Implement | Code features | None |
| 9 | Verify | Run all tests | None |
| 10 | Reference | Testing docs | None |
| 11 | Finalize | Summary | None |

---

## ✨ Benefits

### 1. Quality Assurance
- ✅ Tests reviewed before implementation
- ✅ Catch test issues early
- ✅ Ensure tests actually test requirements

### 2. User Control
- ✅ Explicit approval required
- ✅ Can request changes iteratively
- ✅ Can cancel anytime

### 3. Better Tests
- ✅ User validates test logic
- ✅ Edge cases verified upfront
- ✅ No implementation details in tests

### 4. Safety
- ✅ No accidental implementation without review
- ✅ Tests committed and traceable
- ✅ Can resume after cancellation

### 5. Flexibility
- ✅ AI can update tests on request
- ✅ User can edit manually
- ✅ Multiple review rounds supported

---

## 🔧 Technical Details

### When Review Happens

**Review REQUIRED when:**
- New tests created (Phase 6)
- Tests updated for new ACs
- Tests written for first time

**Review SKIPPED when:**
- No new tests (refactor only)
- Tests already exist and unchanged
- Continuing from previous session with approved tests

### Review State Tracking

**Tests committed before review:**
```bash
git commit -m "test: add test scaffolds for [feature] (all failing)"
```

**User can inspect:**
```bash
git show HEAD  # See committed tests
git diff HEAD~1 HEAD  # Compare with previous
```

**Changes after review:**
```bash
git commit -m "test: update test scaffolds based on review"
```

---

## 📝 Documentation Updates

### Updated Sections

1. **Phase 7: CRITICAL - User Review Checkpoint** (NEW)
2. **Phase 8**: Implementation (renumbered from 7)
3. **Phase 9**: Verify tests (renumbered from 8)
4. **Phase 10**: Testing reference (renumbered from 9)
5. **Phase 11**: Finalize (renumbered from 10)

### Updated Scenarios

All 4 workflow scenarios updated with review checkpoint:
- Fresh implementation
- Update PRD
- Update plan only
- Subsequent run

### Updated Key Features

Added:
- ✅ **CRITICAL Review Checkpoint**: User must approve tests
- ✅ **Red-Green-Refactor cycle** enforced with review gate

---

## 🎯 Summary

**What Changed:**
- Added mandatory review checkpoint after tests written
- User MUST approve before implementation
- Options to revise, edit manually, or cancel
- Review can loop until user satisfied

**Impact:**
- Better test quality through human review
- User has explicit control over implementation start
- Tests validated before any code written
- Safer, more deliberate development process

**Result:**
- ✅ Tests reviewed by human
- ✅ Implementation only after approval
- ✅ Quality gate enforced
- ✅ User in full control

**The TDD workflow now has a human-in-the-loop review gate!** 🎉
