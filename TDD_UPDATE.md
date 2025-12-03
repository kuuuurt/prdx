# Test-Driven Development (TDD) Integration

## 🎯 Update Summary

PRDX now follows **Test-Driven Development (TDD)** principles in `/prdx:dev`, ensuring tests are written **before** implementation code.

---

## ✨ What Changed

### New TDD Workflow

**Before (v0.3.0):**
```
Phase 6: Execute Implementation
Phase 7: Testing
Phase 8: Finalize
```

**After (v0.3.0 + TDD):**
```
Phase 6: Write Tests First ⭐ NEW
Phase 7: Execute Implementation (TDD cycle)
Phase 8: Verify All Tests Pass ⭐ NEW
Phase 9: Testing Strategy Reference
Phase 10: Finalize
```

---

## 🔄 TDD Cycle (Red-Green-Refactor)

### Phase 6: Write Tests First (RED)

**Create failing tests that define desired behavior:**

1. **Map each Acceptance Criterion to tests**
   - Unit test (business logic)
   - Integration test (API endpoints)
   - UI test (user interactions)
   - Manual test (visual checks)

2. **Create test scaffolds** with Given-When-Then structure:

   **Backend (Bun):**
   ```typescript
   test('should authenticate user with valid credentials', async () => {
     // Given: Valid credentials
     // When: User attempts login
     // Then: Authentication succeeds
     expect(true).toBe(false) // Fails initially
   })
   ```

   **Android (Kotlin):**
   ```kotlin
   @Test
   fun `should display error for invalid credentials`() = runTest {
     // Given: Invalid credentials
     // When: User attempts login
     // Then: Error is displayed
     fail("Not implemented") // Fails initially
   }
   ```

   **iOS (Swift):**
   ```swift
   func testShouldPersistUserSession() async throws {
     // Given: Logged in user
     // When: App restarts
     // Then: Session is restored
     XCTFail("Not implemented") // Fails initially
   }
   ```

3. **Commit test scaffolds:**
   ```bash
   git commit -m "test: add test scaffolds for authentication (all failing)"
   ```

4. **Verify tests fail** - confirms test setup is correct

### Phase 7: Implement Features (GREEN)

**Write minimum code to make tests pass:**

1. **Run tests first** - verify they fail (RED state)
2. **Implement feature** - follow detailed plan
3. **Run tests frequently** - aim for GREEN
4. **Stop when tests pass** - don't over-engineer
5. **Commit each feature:**
   ```bash
   git commit -m "feat: implement user authentication logic"
   ```

### Phase 8: Verify All Tests Pass (REFACTOR)

**Final validation:**

1. **Run complete test suite:**
   ```bash
   bun test                    # Backend
   ./gradlew test              # Android
   xcodebuild test -scheme App # iOS
   ```

2. **Verify 100% AC coverage:**
   ```
   ✓ AC #1: User can login (3 tests passing)
   ✓ AC #2: Invalid creds rejected (2 tests passing)
   ✓ AC #3: Session persists (1 test passing)
   ```

3. **All tests must be GREEN** - otherwise STOP and fix

---

## 💡 Benefits

### 1. Tests Define Requirements
- Tests written first act as executable specifications
- Clear definition of "done" (all tests green)
- No ambiguity about expected behavior

### 2. Better Code Quality
- Implementation focused on passing tests
- No unnecessary code (stop when tests pass)
- Forces thinking about testability upfront

### 3. Regression Safety
- Refactor with confidence
- Tests catch breaking changes immediately
- Existing tests become regression suite

### 4. 100% AC Coverage
- Every Acceptance Criterion has tests
- No criteria left untested
- Comprehensive validation

### 5. Documentation
- Tests serve as living documentation
- Show how features should be used
- Given-When-Then makes intent clear

---

## 📋 Example Workflow

### Feature: User Authentication

**Phase 6: Write Tests First**
```bash
# Create test scaffolds
tests/auth/LoginTest.kt
tests/auth/SessionTest.kt
tests/auth/ErrorHandlingTest.kt

# All tests fail initially ✓
# Commit: "test: add authentication test scaffolds"
```

**Phase 7: Implement Features**
```bash
# Implement login logic
src/auth/LoginViewModel.kt
- Run tests: 2 passing, 3 failing
- Commit: "feat: implement login validation"

# Implement session management
src/auth/SessionRepository.kt
- Run tests: 3 passing, 2 failing
- Commit: "feat: implement session persistence"

# Implement error handling
src/auth/ErrorMapper.kt
- Run tests: 5 passing, 0 failing ✓
- Commit: "feat: implement authentication error handling"
```

**Phase 8: Verify**
```bash
# Run all tests
./gradlew test

# Result:
✓ 15 tests passing
✓ 0 tests failing
✓ 100% AC coverage
```

---

## 🔧 Technical Details

### Test Scaffold Structure

**Backend:**
```typescript
// tests/features/auth.test.ts
import { describe, test, expect } from 'bun:test'

describe('Authentication', () => {
  // AC #1: User can login with valid credentials
  test('should authenticate user successfully', async () => {
    // Given: Valid user credentials
    const email = 'user@example.com'
    const password = 'secure123'

    // When: User attempts login
    const response = await authService.login(email, password)

    // Then: Authentication succeeds
    expect(response.status).toBe(200)
    expect(response.token).toBeDefined()
  })

  // AC #2: Invalid credentials are rejected
  test('should reject invalid credentials', async () => {
    // Given: Invalid credentials
    const email = 'wrong@example.com'
    const password = 'wrong'

    // When: User attempts login
    const response = await authService.login(email, password)

    // Then: Authentication fails
    expect(response.status).toBe(401)
    expect(response.error).toBe('INVALID_CREDENTIALS')
  })
})
```

**Android:**
```kotlin
// tests/.../LoginViewModelTest.kt
class LoginViewModelTest {
    private lateinit var viewModel: LoginViewModel
    private lateinit var fakeAuthRepository: FakeAuthRepository

    @Before
    fun setup() {
        fakeAuthRepository = FakeAuthRepository()
        viewModel = LoginViewModel(fakeAuthRepository)
    }

    // AC #1: User can login with valid credentials
    @Test
    fun `should authenticate user successfully`() = runTest {
        // Given: Valid credentials
        val email = "user@example.com"
        val password = "secure123"

        // When: User attempts login
        viewModel.login(email, password)

        // Then: Authentication succeeds
        val state = viewModel.state.value
        assertTrue(state.isAuthenticated)
        assertEquals("user@example.com", state.user?.email)
    }

    // AC #2: Invalid credentials are rejected
    @Test
    fun `should reject invalid credentials`() = runTest {
        // Given: Invalid credentials
        fakeAuthRepository.shouldFail = true

        // When: User attempts login
        viewModel.login("wrong@example.com", "wrong")

        // Then: Error is shown
        val state = viewModel.state.value
        assertFalse(state.isAuthenticated)
        assertEquals("INVALID_CREDENTIALS", state.error)
    }
}
```

**iOS:**
```swift
// Tests/LoginViewModelTests.swift
class LoginViewModelTests: XCTestCase {
    var viewModel: LoginViewModel!
    var mockAuthService: MockAuthService!

    override func setUp() {
        super.setUp()
        mockAuthService = MockAuthService()
        viewModel = LoginViewModel(authService: mockAuthService)
    }

    // AC #1: User can login with valid credentials
    func testShouldAuthenticateUserSuccessfully() async throws {
        // Given: Valid credentials
        let email = "user@example.com"
        let password = "secure123"

        // When: User attempts login
        await viewModel.login(email: email, password: password)

        // Then: Authentication succeeds
        XCTAssertTrue(viewModel.isAuthenticated)
        XCTAssertEqual(viewModel.user?.email, email)
        XCTAssertNil(viewModel.error)
    }

    // AC #2: Invalid credentials are rejected
    func testShouldRejectInvalidCredentials() async throws {
        // Given: Invalid credentials
        mockAuthService.shouldFail = true

        // When: User attempts login
        await viewModel.login(email: "wrong@example.com", password: "wrong")

        // Then: Error is shown
        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertEqual(viewModel.error, .invalidCredentials)
    }
}
```

---

## 🚀 Getting Started

### 1. Use /prdx:dev as usual

```bash
/prdx:dev backend-authentication
```

### 2. Tests are created first automatically

```
✓ Test Scaffolds Created

Acceptance Criteria → Test Mapping:
- AC #1: User can login → tests/auth/LoginTest.kt
- AC #2: Invalid creds rejected → tests/auth/LoginTest.kt
- AC #3: Session persists → tests/auth/SessionTest.kt

Status: All 8 tests created and failing ✓
Next: Implement features to make tests pass
```

### 3. Implement to make tests pass

```
Task: Implement login validation
→ Run tests: FAILING
→ Write code: validation logic
→ Run tests: PASSING ✓
→ Commit: "feat: implement login validation"
```

### 4. All tests green = Done!

```
✓ Test Suite Complete

Total: 45 tests
Passed: 45 ✓
Failed: 0

All acceptance criteria verified ✓
```

---

## 📚 Best Practices

### 1. Write Minimal Tests First
- One test per acceptance criterion (minimum)
- Focus on behavior, not implementation
- Use Given-When-Then structure

### 2. Implement to Pass Tests
- Write simplest code that makes tests pass
- Don't over-engineer
- Stop when tests are green

### 3. Refactor with Confidence
- Tests provide safety net
- Clean up code knowing tests will catch breaks
- Keep tests green throughout refactoring

### 4. Commit Frequently
- Commit test scaffolds first
- Commit each passing feature
- Small, focused commits

### 5. Run Tests Often
- Before starting (verify RED)
- During implementation (aim for GREEN)
- After refactoring (ensure still GREEN)

---

## 🎓 TDD Philosophy

**Quote from Kent Beck (creator of TDD):**
> "Test-driven development is a way of managing fear during programming."

**Benefits:**
- **Fear Management**: Tests catch regressions
- **Design Improvement**: Forces testable code
- **Documentation**: Tests show how to use code
- **Confidence**: Refactor without breaking things

**The Three Laws of TDD:**
1. Don't write production code until you have a failing test
2. Don't write more of a test than is sufficient to fail
3. Don't write more production code than is sufficient to pass the test

---

## 📊 Metrics Impact

TDD improves metrics tracked by `/prdx:metrics`:

- **Test Effectiveness**: 100% AC coverage guaranteed
- **Code Quality**: Higher due to test-first approach
- **Regression Rate**: Lower due to comprehensive tests
- **Refactoring Confidence**: Higher with test safety net

---

## 🔗 Resources

- [Test-Driven Development: By Example](https://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530) - Kent Beck
- [Growing Object-Oriented Software, Guided by Tests](http://www.growing-object-oriented-software.com/) - Freeman & Pryce
- [TDD Best Practices](https://martinfowler.com/bliki/TestDrivenDevelopment.html) - Martin Fowler

---

**Version:** 0.3.0 + TDD
**Updated:** 2025-01-12
**Status:** Live in `/prdx:dev`
