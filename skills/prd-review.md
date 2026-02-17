# PRD Review Skill

Expert skill for reviewing PRDs with platform-specific domain knowledge and best practices.

## Platform-Specific Review Patterns

### Backend (TypeScript + Hono + Bun)

**Architecture Checks:**
- API endpoint design follows RESTful conventions
- Authentication/authorization via JWT tokens properly implemented
- Error handling uses consistent error response format
- Rate limiting considered for public endpoints
- Third-party service integration follows established patterns (payment providers, external APIs, notification services)

**Common Pitfalls:**
- Missing input validation with Zod schemas
- Not handling third-party API failures gracefully
- Missing OpenAPI documentation for new endpoints
- Forgetting to update generated types after API changes
- Not considering Redis caching for expensive operations

**Performance Considerations:**
- Database queries optimized (avoid N+1)
- Caching strategy for third-party API calls
- Async operations properly handled with Bun's native APIs
- Connection pooling for external services

**Testing Requirements:**
- Unit tests for business logic
- Integration tests for API endpoints
- Mock third-party services in tests
- Test error scenarios and edge cases

### Android (Kotlin + Jetpack Compose + Clean Architecture)

**Architecture Checks:**
- Repository pattern used consistently (no Use Cases - deprecated pattern)
- MVVM structure with ViewModel + State
- Hilt dependency injection properly configured
- Navigation follows Compose Navigation patterns
- State management with StateFlow/SharedFlow

**Common Pitfalls:**
- Creating new Use Cases (anti-pattern, use Repositories directly)
- Not handling configuration changes properly
- Memory leaks with ViewModels/Coroutines
- Missing loading/error states in UI
- Not following Material Design 3 guidelines
- Mixing ViewBinding and Compose patterns inconsistently

**Performance Considerations:**
- Lazy loading for lists with LazyColumn
- Image loading with Coil properly configured
- Background operations on IO dispatcher
- Avoiding recomposition issues in Compose

**Testing Requirements:**
- Unit tests for ViewModels
- Repository tests with mocked data sources
- UI tests with Compose Testing
- Screenshot tests for visual regression

### iOS (Swift + SwiftUI)

**Architecture Checks:**
- MVVM with @ObservableObject/@StateObject
- NavigationStack + NavigationPath for navigation
- Proper use of SwiftUI lifecycle methods
- Async/await for asynchronous operations
- Combine for reactive streams where needed

**Common Pitfalls:**
- Retaining cycles with closures
- Not using @MainActor for UI updates
- Incorrect use of @State vs @StateObject vs @ObservedObject
- Missing accessibility labels
- Not handling background/foreground transitions

**Performance Considerations:**
- Lazy loading with LazyVStack/LazyHStack
- Image caching strategy
- Avoiding expensive operations on main thread
- Proper use of task modifiers for async work

**Testing Requirements:**
- Unit tests for view models
- XCTest for business logic
- UI tests for critical flows
- Snapshot tests for visual regression

### Frontend (Web)

**Architecture Checks:**
- Component structure follows project conventions (pages, components, layouts)
- State management approach is consistent (Redux, Zustand, Context, signals, etc.)
- Data fetching uses project's established pattern (React Query, SWR, server components, etc.)
- Routing follows framework conventions (file-based, programmatic)
- Form handling uses consistent validation approach (Zod, Yup, native)
- API layer is properly abstracted (not fetching directly in components)

**Common Pitfalls:**
- Missing loading, error, and empty states in UI
- Not handling form validation on both client and display level
- Prop drilling instead of using context or state management
- Missing responsive design for mobile viewports
- No error boundaries for graceful failure handling
- Forgetting accessibility (ARIA labels, keyboard navigation, focus management)
- Not handling stale data or race conditions in async operations

**Performance Considerations:**
- Bundle size monitored (code splitting, tree shaking)
- Lazy loading for routes and heavy components
- Memoization for expensive computations (useMemo, computed)
- Image optimization (lazy loading, proper formats, srcset)
- Avoiding unnecessary re-renders

**Testing Requirements:**
- Component tests for interactive behavior
- Integration tests for user flows
- Accessibility testing (axe, testing-library queries)
- Visual regression tests for key screens (optional)

## Cross-Platform Concerns

**Security:**
- Sensitive data not logged
- API keys in environment variables
- Certificate pinning for critical APIs
- Proper token refresh handling
- Input sanitization

**Accessibility:**
- Screen reader support
- Dynamic type support (mobile)
- Keyboard navigation (mobile)
- Color contrast ratios

**Observability:**
- Error tracking configured
- Analytics events defined
- Performance monitoring enabled
- Logging strategy defined

## Review Checklist

When reviewing a PRD, systematically check:

1. **Problem Definition**
   - [ ] Problem is clear and specific
   - [ ] Impact/urgency is justified
   - [ ] Affected users are identified

2. **Goal & Success Metrics**
   - [ ] Goal is measurable
   - [ ] Success metrics are specific and achievable
   - [ ] Out of scope items prevent scope creep

3. **Acceptance Criteria**
   - [ ] 3-5 criteria that are testable
   - [ ] Covers architecture, functional, error handling, non-functional
   - [ ] Written as user stories where applicable

4. **Technical Approach**
   - [ ] Architecture follows platform patterns
   - [ ] Key changes are realistic and scoped
   - [ ] Top risks identified with mitigation
   - [ ] Platform-specific pitfalls addressed

5. **Implementation Plan**
   - [ ] Phases are logical and committable
   - [ ] Complexity markers realistic (S/M/L)
   - [ ] Testing phase included
   - [ ] Dependencies between phases clear

6. **Multi-Project Impact**
   - [ ] If backend changes, mobile apps considered
   - [ ] If mobile changes, backend implications checked
   - [ ] Versioning strategy for API changes
   - [ ] Backward compatibility maintained

## Usage in /prd:plan

This skill is automatically invoked during PRD creation to:
1. Validate PRD structure against template
2. Apply platform-specific review patterns
3. Identify common pitfalls and suggest improvements
4. Ensure technical approach aligns with project architecture
5. Flag missing considerations (security, performance, testing)

## Output Format

When reviewing, provide structured feedback:

**✅ Strengths:**
- [List what's well-defined in the PRD]

**⚠️ Concerns:**
- [List potential issues or gaps]

**💡 Suggestions:**
- [List specific improvements with rationale]

**🔴 Blockers:**
- [List critical issues that must be addressed before proceeding]
