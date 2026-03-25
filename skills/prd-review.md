# PRD Review Skill

Expert skill for reviewing PRDs against the project's actual patterns and best practices. Agents should **discover the project's stack and conventions** before applying review checks.

## Platform-Specific Review Patterns

### Backend

**Architecture Checks:**
- API endpoint design follows the project's established routing conventions
- Authentication/authorization follows existing auth patterns
- Error handling uses the project's consistent error response format
- Input validation follows project's validation approach
- Third-party service integration follows established patterns

**Common Pitfalls:**
- Missing input validation at API boundaries
- Not handling external service failures gracefully
- Missing API documentation for new endpoints
- Not considering caching for expensive operations
- Inconsistent error response format

**Performance Considerations:**
- Database queries optimized (avoid N+1)
- Caching strategy for frequently-accessed or expensive data
- Async operations properly handled
- Connection pooling for external services

**Testing Requirements:**
- Unit tests for business logic
- Integration tests for API endpoints
- Mock external services in tests
- Test error scenarios and edge cases

### Android

**Architecture Checks:**
- Code follows the project's established architecture pattern
- Dependency injection uses the project's existing DI approach
- Navigation follows the project's navigation patterns
- State management uses the project's established approach
- New code matches existing package/module organization

**Common Pitfalls:**
- Not handling configuration changes properly
- Memory leaks with lifecycle-unaware components
- Missing loading/error states in UI
- Inconsistent use of project's established patterns
- Not following the project's existing UI framework conventions

**Performance Considerations:**
- Efficient list rendering for large datasets
- Image loading follows project's established approach
- Background operations on appropriate threads/dispatchers
- Avoiding unnecessary UI rebuilds

**Testing Requirements:**
- Unit tests for business logic and state management
- Tests for data layer with mocked sources
- UI tests for critical user flows
- Follow project's existing test conventions

### iOS

**Architecture Checks:**
- Code follows the project's established architecture pattern
- State management uses the project's existing approach
- Navigation follows the project's navigation patterns
- Async operations follow project conventions
- New code matches existing file/group organization

**Common Pitfalls:**
- Retain cycles with closures
- Not updating UI on the main thread
- Incorrect use of project's state management primitives
- Missing accessibility labels
- Not handling background/foreground transitions

**Performance Considerations:**
- Efficient list rendering for large datasets
- Image caching strategy
- Avoiding expensive operations on main thread
- Proper lifecycle management for async work

**Testing Requirements:**
- Unit tests for business logic
- Tests for critical user flows
- Follow project's existing test patterns and frameworks

### Frontend

**Architecture Checks:**
- Component structure follows project conventions
- State management approach is consistent with existing code
- Data fetching uses project's established pattern
- Routing follows framework conventions
- Form handling uses consistent validation approach
- API layer is properly abstracted (not fetching directly in components)

**Common Pitfalls:**
- Missing loading, error, and empty states in UI
- Not handling form validation on both client and display level
- Prop drilling instead of using project's state management approach
- Missing responsive design for mobile viewports
- No error boundaries for graceful failure handling
- Forgetting accessibility (ARIA labels, keyboard navigation, focus management)
- Not handling stale data or race conditions in async operations

**Performance Considerations:**
- Bundle size monitored (code splitting, tree shaking)
- Lazy loading for routes and heavy components
- Memoization for expensive computations
- Image optimization (lazy loading, proper formats)
- Avoiding unnecessary re-renders

**Testing Requirements:**
- Component tests for interactive behavior
- Integration tests for user flows
- Accessibility testing
- Follow project's existing test conventions

## Cross-Platform Concerns

**Security:**
- Sensitive data not logged
- API keys in environment variables
- Proper token refresh handling
- Input sanitization

**Accessibility:**
- Screen reader support
- Keyboard navigation
- Color contrast ratios

**Observability:**
- Error tracking configured
- Analytics events defined
- Logging strategy follows project conventions

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
   - [ ] Architecture follows project's established patterns
   - [ ] Key changes are realistic and scoped
   - [ ] Top risks identified with mitigation
   - [ ] Platform-specific pitfalls addressed

5. **Implementation Plan**
   - [ ] Phases are logical and committable
   - [ ] Complexity markers realistic (S/M/L)
   - [ ] Testing phase included
   - [ ] Dependencies between phases clear

6. **Multi-Project Impact**
   - [ ] If backend changes, client apps considered
   - [ ] If client changes, backend implications checked
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

**Strengths:**
- [List what's well-defined in the PRD]

**Concerns:**
- [List potential issues or gaps]

**Suggestions:**
- [List specific improvements with rationale]

**Blockers:**
- [List critical issues that must be addressed before proceeding]
