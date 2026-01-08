# Testing Strategy Skill

Expert skill for generating **effective, efficient** testing strategies based on feature type and platform. Agents should **discover the actual test framework from the codebase** and adapt accordingly.

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

### Backend

**Discover test framework from:** `package.json`, `requirements.txt`, etc.
- Node.js: Jest, Vitest, Bun test, Mocha
- Python: pytest, unittest
- Go: testing package
- Java/Kotlin: JUnit

**Unit Tests:**
- Business logic in services
- Utility functions
- Validation logic
- Data transformations

**Integration Tests:**
- API endpoint flows (request → response)
- Third-party service integrations (mocked)
- Database operations
- Authentication/authorization flows
- Error handling scenarios

**Testing Pattern (Given-When-Then):**

```
// Test end-to-end API flow
describe('POST /api/resource', () => {
  test('creates resource with valid data', async () => {
    // Given: Authenticated user with valid input
    const token = generateAuthToken(userId)
    const input = { name: 'Test', value: 123 }

    // When: Request is made
    const response = await app.request('/api/resource', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: JSON.stringify(input)
    })

    // Then: Resource is created
    expect(response.status).toBe(201)
    expect(await response.json()).toMatchObject({
      id: expect.any(String),
      name: 'Test'
    })
  })

  test('rejects invalid data', async () => {
    // Given: Invalid input
    // When: Request is made
    // Then: Request rejected with validation error
    expect(response.status).toBe(400)
  })
})
```

**What to Test:**
- API endpoints (full request → response)
- Authentication/authorization (access control)
- Validation (reject bad input)
- Error handling (timeouts, failures)
- Business logic (core rules)

**What NOT to Test:**
- Framework internals
- Third-party library code
- Trivial code (getters/setters)
- Implementation details (which internal functions are called)

### Android (Kotlin + Compose)

**Test framework:** JUnit4/5 + Compose Testing (native)
- Discover mocking library from build.gradle: MockK, Mockito
- Discover flow testing: Turbine

**Unit Tests:**
- ViewModel logic
- Repository implementations
- Data transformations
- Business rules

**Instrumentation Tests:**
- Compose UI components
- Navigation flows
- Database operations (if applicable)
- Repository with real data sources

**UI Testing Pattern (Given-When-Then):**

```kotlin
// Test user-facing behavior
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

// Test ViewModel behavior (end result)
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

// Test error handling
@Test
fun `login fails with invalid credentials`() = runTest {
    // Given: Invalid credentials (mock failure)
    // When: User attempts login
    // Then: Error is shown
}
```

**What to Test:**
- User flows (login, navigation, submission)
- ViewModel state changes (input → state)
- Error handling (network failures, validation)
- Data transformations (DTO → UI model)

**What NOT to Test:**
- Compose recomposition logic
- Android framework internals
- Repository method calls (test outcomes instead)
- Private functions

### iOS (Swift + SwiftUI)

**Test framework:** XCTest (native)
- Discover UI testing approach from project

**Unit Tests:**
- ViewModel logic
- Business rules
- Data transformations
- Repository implementations

**UI Tests:**
- Critical user flows
- Navigation scenarios
- Error state handling
- Screenshot generation (optional)

**Testing Pattern:**
```swift
func testLoginSuccess() async throws {
    // Given: Mock service returns success
    let mockService = MockAuthService()
    mockService.loginResult = .success(User(id: "1", name: "Test"))

    let viewModel = LoginViewModel(authService: mockService)

    // When: User attempts login
    await viewModel.login(email: "test@example.com", password: "pass")

    // Then: User is authenticated
    XCTAssertTrue(viewModel.isAuthenticated)
    XCTAssertNil(viewModel.error)
}

func testLoginFailure() async throws {
    // Given: Mock service returns error
    // When: User attempts login
    // Then: Error is displayed
}
```

**What to Test:**
- ViewModel state changes
- Service method results
- Error handling
- User flows (login, navigation)

**What NOT to Test:**
- SwiftUI view rendering
- Framework behavior
- Trivial code

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

### Data Layer Changes

**Tests Required:**
1. **Migration Tests**: Schema changes apply correctly
2. **Repository Tests**: CRUD operations work
3. **Data Integrity**: Constraints enforced
4. **Backward Compatibility**: Old data handled gracefully

### Authentication/Authorization

**Critical Test Scenarios:**
1. **Token Lifecycle**:
   - Token refresh when expired
   - Logout clears tokens
   - Invalid token handled

2. **Permissions**:
   - Role-based access enforced
   - Unauthorized access blocked

3. **Security**:
   - Tokens not logged
   - Secure storage used

### Third-Party Integration

**Tests Required:**
1. **Mock Tests**: Integration works with mocked service
2. **Error Handling**: Service timeout/failure handled
3. **Data Transformation**: API response → internal model
4. **Retry Logic**: Failures trigger retries appropriately

## Test Coverage Goals

### Backend
- **Unit Tests**: >80% coverage for business logic
- **Integration Tests**: All API endpoints
- **Critical Paths**: 100% coverage (auth, payments)

### Android
- **Unit Tests**: >70% coverage for ViewModels/Repositories
- **UI Tests**: Critical user flows
- **Screenshot Tests**: Key screens (optional)

### iOS
- **Unit Tests**: >70% coverage for ViewModels/business logic
- **UI Tests**: Critical user flows
- **Snapshot Tests**: Key screens (optional)

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

## Commands Reference

**Discover test commands from project configuration:**
- Check `package.json` scripts for backend
- Check `build.gradle` tasks for Android
- Check Xcode scheme for iOS

**Common patterns:**
- Backend: `npm test`, `yarn test`, `bun test`, `pytest`, `go test`
- Android: `./gradlew test`, `./gradlew connectedAndroidTest`
- iOS: `xcodebuild test -scheme YourApp`

## Usage in PRD Workflow

This skill is used to:
1. Generate Testing phase in PRD Implementation section
2. Provide test scenarios during /prdx:implement
3. Validate test coverage during implementation
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
- [Platform-specific commands discovered from project]

**Risks:**
- [Testing challenges or areas needing extra attention]
