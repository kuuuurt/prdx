# Implementation Patterns Skill

Expert skill for guiding implementation based on the project's existing patterns and conventions. Agents MUST **discover the actual patterns from the codebase** before writing any code.

## Core Principle

**Follow the project's existing patterns — don't impose new ones.**

Every project has established conventions for structure, naming, error handling, state management, and testing. Your job is to discover these conventions and write code that fits naturally into the existing codebase.

## Discovery Process

Before implementing anything, answer these questions by exploring the codebase:

### 1. Project Structure

- How is the codebase organized? (by feature, by layer, flat, monorepo)
- Where do new files go for this type of change?
- What naming conventions are used for files and directories?

### 2. Architecture & Patterns

- What architectural pattern is used? (MVC, MVVM, layered services, etc.)
- How is business logic separated from presentation/routing?
- How is dependency injection handled? (framework, manual, none)
- What abstraction layers exist? (repositories, services, use cases, etc.)

### 3. Error Handling

- How are errors represented? (exceptions, Result types, sealed classes, error codes)
- Is there a consistent error response format?
- How are errors propagated between layers?

### 4. State Management

- How is state managed? (framework-specific: stores, state flows, observables, etc.)
- Where does state live? (local, global, server)
- How do components communicate state changes?

### 5. Data Flow

- How is data fetched? (HTTP clients, ORMs, SDKs)
- How is data validated? (schemas, decorators, manual)
- How is data transformed between layers?

### 6. Testing

- What test framework is used?
- What testing patterns are followed? (unit, integration, e2e)
- Where do test files live relative to source files?
- What mocking/stubbing approach is used?

## Implementation Guidelines

Once you've discovered the project's patterns:

1. **Match existing style** — If the project uses a specific pattern, follow it even if you'd prefer a different one
2. **Look at similar features** — Find the most recent, well-structured implementation of a similar feature and use it as a template
3. **Maintain consistency** — Use the same naming conventions, file organization, and abstraction levels as existing code
4. **Don't introduce new patterns** — Unless explicitly requested, don't add new architectural patterns, libraries, or conventions
5. **Keep it simple** — Write the minimum code needed. Don't add abstractions, utilities, or patterns that aren't already established in the project

## Implementation Checklist

1. Explore existing code for similar features (use as template)
2. Identify files to create and modify (follow project's file organization)
3. Implement following project's patterns exactly
4. Write tests matching project's testing conventions
5. Verify your code looks like it belongs in the codebase

## Usage

This skill provides implementation guidance during:
- /prdx:implement — Reference patterns while coding
- Code reviews — Validate against established patterns
- Architecture decisions — Follow existing precedent
