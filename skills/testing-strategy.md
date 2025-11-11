# Testing Strategy Skill

Expert skill for generating **effective, efficient** testing strategies based on feature type and platform.

## Testing Philosophy

**Effective > Comprehensive**
- Test **end results**, not implementation details
- Focus on **user-facing behavior** and **contracts**
- Avoid testing framework internals or trivial code
- Use **Given-When-Then** pattern for clarity

**Key Principles:**
1. **Test the contract, not the implementation**
   - What the function promises to do (inputs → outputs)
   - Not how it does it internally

2. **Test end-to-end behavior over units**
   - API: Full request → response flow
   - UI: User action → visible result
   - Business logic: Input → outcome

3. **One test per acceptance criterion**
   - Each AC should have at least one test
   - Test maps directly to business requirement

4. **Don't chase coverage percentages**
   - 100% coverage ≠ good tests
   - Focus on critical paths and edge cases
   - Skip testing getters/setters, trivial code

5. **Given-When-Then pattern** (everywhere):
   ```
   Given: Setup/preconditions
   When: Action/trigger
   Then: Expected result
   ```

## Platform-Specific Testing Approaches

### Backend (TypeScript + Hono + Bun)

**Test Structure:**
```
backend-project/
├── src/
│   ├── routes/
│   │   └── __tests__/
│   ├── services/
│   │   └── __tests__/
│   └── utils/
│       └── __tests__/
```

**Unit Tests:**
- Business logic in services
- Utility functions
- Validation schemas (Zod)
- Data transformations
- Use Bun's native test runner

**Integration Tests:**
- API endpoint flows (request → response)
- Third-party service integrations (mocked)
- Database operations
- Authentication/authorization flows
- Error handling scenarios

**Testing Patterns (Given-When-Then):**

```typescript
// ✅ GOOD: Test end-to-end API flow
describe('POST /api/driver/location', () => {
  test('broadcasts location to riders', async () => {
    // Given: Authenticated driver
    const driverId = 'driver-123'
    const token = generateAuthToken(driverId)

    // When: Driver sends location update
    const response = await app.request('/api/driver/location', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: JSON.stringify({ lat: 37.7749, lng: -122.4194 })
    })

    // Then: Location is saved and broadcast
    expect(response.status).toBe(200)
    expect(await getDriverLocation(driverId)).toMatchObject({
      lat: 37.7749,
      lng: -122.4194
    })
  })

  test('rejects invalid coordinates', async () => {
    // Given: Authenticated driver
    const token = generateAuthToken('driver-123')

    // When: Driver sends invalid location
    const response = await app.request('/api/driver/location', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: JSON.stringify({ lat: 999, lng: -122 })
    })

    // Then: Request rejected with validation error
    expect(response.status).toBe(400)
    expect(await response.json()).toMatchObject({
      error: 'Invalid coordinates'
    })
  })
})

// ❌ BAD: Testing implementation details
test('validateLocation calls latitudeValidator', () => {
  const spy = vi.spyOn(validators, 'latitudeValidator')
  validateLocation({ lat: 37, lng: -122 })
  expect(spy).toHaveBeenCalled() // Who cares? Test the result!
})

// ✅ GOOD: Test the contract
test('validateLocation accepts valid coordinates', () => {
  // Given: Valid coordinates
  const location = { lat: 37.7749, lng: -122.4194 }

  // When: Validating
  const result = validateLocation(location)

  // Then: Validation passes
  expect(result.isValid).toBe(true)
})
```

**What to Test:**
- ✅ API endpoints (full request → response)
- ✅ Authentication/authorization (access control)
- ✅ Validation (reject bad input)
- ✅ Error handling (timeouts, failures)
- ✅ Business logic (core rules)

**What NOT to Test:**
- ❌ Framework internals (Hono's routing)
- ❌ Third-party libraries (Zod validation)
- ❌ Trivial code (getters/setters)
- ❌ Implementation details (which functions are called)

**Commands:**
```bash
bun test                    # Run all tests
bun test --watch           # Watch mode
bun test --coverage        # With coverage
bun test routes/users      # Specific test
```

### Android (Kotlin + Jetpack Compose)

**Test Structure:**
```
android-project/
├── app/src/
│   ├── test/              # Unit tests
│   ├── androidTest/       # Instrumentation tests
│   └── sharedTest/        # Shared test utilities
```

**Unit Tests:**
- ViewModel logic
- Repository implementations
- Data transformations
- Business rules
- Use JUnit 4/5 + MockK

**Instrumentation Tests:**
- Compose UI components
- Navigation flows
- Database operations (Room)
- Repository with real data sources
- Use Espresso + Compose Testing

**UI Testing Patterns (Given-When-Then):**

```kotlin
// ✅ GOOD: Test user-facing behavior
@Test
fun `user can login with valid credentials`() {
    // Given: Login screen is displayed
    composeTestRule.setContent {
        LoginScreen(viewModel = viewModel)
    }

    // When: User enters credentials and submits
    composeTestRule
        .onNodeWithTag("email_field")
        .performTextInput("user@example.com")
    composeTestRule
        .onNodeWithTag("password_field")
        .performTextInput("password123")
    composeTestRule
        .onNodeWithTag("login_button")
        .performClick()

    // Then: User sees home screen
    composeTestRule
        .onNodeWithText("Welcome")
        .assertIsDisplayed()
}

// ✅ GOOD: Test ViewModel behavior (end result)
@Test
fun `login succeeds with valid credentials`() = runTest {
    // Given: Valid credentials
    val email = "user@example.com"
    val password = "password123"

    // When: User attempts login
    viewModel.login(email, password)

    // Then: User is authenticated
    val state = viewModel.state.value
    assertTrue(state.isAuthenticated)
    assertNull(state.error)
}

// ❌ BAD: Testing implementation details
@Test
fun `login calls repository login method`() {
    val spy = spyk(repository)
    viewModel.login("email", "pass")
    verify { spy.login(any(), any()) } // Who cares? Test the outcome!
}

// ✅ GOOD: Test error handling
@Test
fun `login fails with invalid credentials`() = runTest {
    // Given: Invalid credentials
    coEvery { repository.login(any(), any()) } returns
        Result.failure(Exception("Invalid credentials"))

    // When: User attempts login
    viewModel.login("wrong@example.com", "wrong")

    // Then: Error is shown
    val state = viewModel.state.value
    assertFalse(state.isAuthenticated)
    assertEquals("Invalid credentials", state.error)
}
```

**What to Test:**
- ✅ User flows (login, navigation, submission)
- ✅ ViewModel state changes (input → state)
- ✅ Error handling (network failures, validation)
- ✅ Data transformations (DTO → UI model)

**What NOT to Test:**
- ❌ Compose recomposition logic
- ❌ Android framework internals
- ❌ Repository method calls (test outcomes)
- ❌ Private functions

**Commands:**
```bash
./gradlew test                          # Unit tests
./gradlew testDebugUnitTest            # Debug unit tests
./gradlew connectedDebugAndroidTest    # Instrumentation tests
./gradlew createDebugCoverageReport    # Coverage report
```

### iOS (Swift + SwiftUI)

**Test Structure:**
```
ios-project/
├── Tests/
│   ├── UnitTests/
│   ├── ViewModelTests/
│   └── IntegrationTests/
├── UITests/
│   └── Screenshots/
```

**Unit Tests:**
- ViewModel logic
- Business rules
- Data transformations
- Repository implementations
- Use XCTest

**UI Tests:**
- Critical user flows
- Navigation scenarios
- Error state handling
- Screenshot generation
- Use XCTest UI Testing

**Testing Patterns:**
```swift
func testLoginFlow() async throws {
    let viewModel = LoginViewModel(
        authService: MockAuthService()
    )

    await viewModel.login(email: "test@example.com", password: "pass")

    XCTAssertTrue(viewModel.isAuthenticated)
    XCTAssertNil(viewModel.error)
}
```

**Commands:**
```bash
xcodebuild test -scheme YourApp -destination 'platform=iOS Simulator,name=iPhone 15'
xcodebuild test -scheme YourAppUITests # UI tests with screenshots
```

## Feature-Type Testing Strategies

### New API Endpoint

**Backend Tests Required:**
1. **Happy Path**: Valid request → successful response
2. **Validation**: Invalid input → 400 with error details
3. **Authentication**: Missing/invalid token → 401
4. **Authorization**: Insufficient permissions → 403
5. **Error Handling**: Service failure → 500/503 with retry info
6. **Edge Cases**: Empty lists, null values, boundary conditions

**Mobile Tests Required:**
1. **Repository Test**: API call → data transformation
2. **ViewModel Test**: Loading/success/error states
3. **UI Test**: User interaction → correct UI updates

### New UI Screen

**Mobile Tests Required:**
1. **Unit Tests**:
   - ViewModel state management
   - User interaction handlers
   - Data validation logic

2. **UI Tests**:
   - Screen loads correctly
   - All interactive elements functional
   - Navigation flows work
   - Error states display properly
   - Loading states display properly

3. **Screenshot Tests**:
   - Light/dark mode
   - Different screen sizes
   - Empty states
   - Error states
   - Loaded states

**Backend Tests Required** (if new API):
- See "New API Endpoint" strategy

### Data Layer Changes

**Tests Required:**
1. **Migration Tests**: Schema changes apply correctly
2. **Repository Tests**: CRUD operations work
3. **Data Integrity**: Constraints enforced
4. **Backward Compatibility**: Old data handled gracefully
5. **Performance**: Queries are efficient

### Authentication/Authorization

**Critical Test Scenarios:**
1. **Token Lifecycle**:
   - Token refresh when expired
   - Logout clears tokens
   - Invalid token handled

2. **Permissions**:
   - Role-based access enforced
   - Unauthorized access blocked
   - Permission changes reflected

3. **Security**:
   - Tokens not logged
   - Secure storage (Keychain/KeyStore)
   - MITM protection

### Third-Party Integration

**Tests Required:**
1. **Mock Tests**: Integration works with mocked service
2. **Error Handling**: Service timeout/failure handled
3. **Data Transformation**: API response → internal model
4. **Retry Logic**: Failures trigger retries appropriately
5. **Fallback**: Degraded functionality when service unavailable

## Test Coverage Goals

### Backend
- **Unit Tests**: >80% coverage for business logic
- **Integration Tests**: All API endpoints
- **Critical Paths**: 100% coverage (auth, payments)

### Android
- **Unit Tests**: >70% coverage for ViewModels/Repositories
- **UI Tests**: Critical user flows (login, booking, payment)
- **Screenshot Tests**: Key screens in all states

### iOS
- **Unit Tests**: >70% coverage for ViewModels/business logic
- **UI Tests**: Critical user flows
- **Snapshot Tests**: Key screens

## Testing Checklist Template

When creating a testing strategy for a PRD, include:

### Unit Tests
- [ ] [Component/Class]: [Specific test scenario]
- [ ] [Component/Class]: [Specific test scenario]

### Integration Tests
- [ ] [Flow/Endpoint]: [End-to-end scenario]
- [ ] [Flow/Endpoint]: [Error scenario]

### UI Tests (Mobile Only)
- [ ] [Screen/Flow]: [User interaction scenario]
- [ ] [Screen/Flow]: [Visual regression test]

### Manual Tests
- [ ] [Critical flow]: [Step-by-step verification]
- [ ] [Edge case]: [Manual verification needed]

### Performance Tests (If Applicable)
- [ ] [Scenario]: [Performance baseline/threshold]

## Commands Reference

### Backend
```bash
bun test                          # All tests
bun test --coverage               # With coverage
bun test --watch                  # Watch mode
bun test <pattern>                # Specific tests
```

### Android
```bash
./gradlew test                              # Unit tests
./gradlew connectedDebugAndroidTest         # Instrumentation tests
./gradlew createDebugCoverageReport         # Coverage
./gradlew testDebugUnitTest --tests "*.LoginViewModelTest"
```

### iOS
```bash
xcodebuild test -scheme YourApp -destination 'platform=iOS Simulator,name=iPhone 15'
xcodebuild test -only-testing:YourAppTests/LoginViewModelTests
xcodebuild test -scheme YourAppUITests  # UI + screenshots
```

## Usage in PRD Workflow

This skill is used to:
1. Generate Testing phase in PRD Implementation section
2. Provide test scenarios during /prd:dev:start implementation
3. Validate test coverage during /prd:dev:check
4. Suggest additional test cases based on feature complexity

## Output Format

When generating a testing strategy, provide:

**Test Plan:**
- Unit tests: [List specific test files/scenarios]
- Integration tests: [List end-to-end scenarios]
- UI tests: [List user flows to test]
- Manual tests: [List scenarios requiring manual verification]

**Coverage Goals:**
- [Specific coverage percentage for each layer]

**Commands:**
- [Platform-specific commands to run tests]

**Risks:**
- [Testing challenges or areas needing extra attention]
