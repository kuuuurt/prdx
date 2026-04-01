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
   - Given: Setup/preconditions
   - When: Action/trigger
   - Then: Expected result

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

### Android

**Discover test framework from:** `build.gradle` / `build.gradle.kts`
- Common: JUnit4/5, MockK, Mockito, Robolectric, Turbine

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

### iOS

**Discover test framework from:** Xcode project / `Package.swift`
- Common: XCTest, Quick/Nimble, ViewInspector

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

**What to Test:**
- ViewModel state changes
- Service method results
- Error handling
- User flows (login, navigation)

**What NOT to Test:**
- SwiftUI view rendering
- Framework behavior
- Trivial code

### Frontend (Web)

**Discover test framework from:** `package.json`
- Test runner: Vitest, Jest, Bun test
- Component testing: Testing Library (React/Vue/Svelte), Enzyme (legacy)
- E2E testing: Playwright, Cypress
- Accessibility: axe-core, jest-axe

**Unit Tests:**
- Utility functions and helpers
- Custom hooks/composables
- Data transformations
- Validation logic

**Component Tests:**
- User-facing behavior (clicks, input, navigation)
- State rendering (loading, error, empty, success)
- Form validation and submission
- Accessibility (roles, labels, keyboard)

**Integration/E2E Tests:**
- Critical user flows (login, checkout, onboarding)
- Navigation between pages
- Form submissions with API calls
- Error recovery flows

**What to Test:**
- User interactions (click, type, select)
- Rendered output (text, visibility, state changes)
- Accessibility (roles, labels, focus management)
- Error handling (API failures, validation)

**What NOT to Test:**
- CSS/styling details
- Framework internals (React re-renders, Vue reactivity)
- Third-party library behavior
- Implementation details (internal state, private methods)

**Coverage Goals:**
- Unit: >80% for utilities and hooks
- Component: Critical interactive components
- E2E: Core user flows (login, main features)

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

- [ ] Unit: [Component/Class] — [scenario]
- [ ] Integration: [Flow/Endpoint] — [end-to-end scenario]
- [ ] UI (mobile): [Screen/Flow] — [user interaction scenario]
- [ ] Manual: [Critical flow] — [step-by-step verification]
