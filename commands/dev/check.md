| description | argument-hint |
| Enhanced verification with multi-agent validation and skills-based assessment | PRD filename or feature slug |

# Enhanced Feature Verification (PRD2)

> **Multi-agent validation with skills-based assessment**
> Leverages specialized agents for comprehensive quality verification

---

## Phase 1: Locate & Load PRD

**Goal**: Find and validate PRD (no impl plan needed for prd).

**Tasks**:
- Accept PRD filename (e.g., `android-feature-bug-fix.md`) or feature slug (e.g., `android-feature-bug-fix`)
- Search in `.claude/prds/` for matching PRD file
- Read and parse PRD document
- Validate PRD has required metadata: Project, Status, Issue (optional), Created, Branch (if implemented)
- Check PRD status is "implemented" or "in-progress" (warn if "draft" or "published")

**Output**: Display PRD metadata summary

---

## Phase 2: Parse Acceptance Criteria & Tasks

**Goal**: Extract and understand all verification targets.

**Tasks**:
- **From PRD:**
  - Locate "## Acceptance Criteria" section
  - Extract all checkbox items (`- [ ]` or `- [x]`)
  - Count total criteria vs completed criteria

- **From PRD Implementation:**
  - Parse "## Implementation" section
  - Extract all tasks from all phases
  - Count total tasks vs completed tasks (`[x]`)
  - Note any deviations documented in Implementation Notes

**Output**: Show acceptance criteria and task checklist with completion stats

---

## Phase 3: Multi-Agent Technical Verification

**Launch verification agents in parallel:**

### 1. Implementation Quality Agent

Based on PRD platform, use Task tool with appropriate agent:

**Backend Projects:**
```
Task(
  subagent_type="backend-developer",
  prompt="Verify implementation quality for [feature].

  PRD: [path]
  Branch: [branch-name]

  Use impl-patterns skill: .claude/skills/impl-patterns.md

  Verify:
  - Implementation follows platform patterns
  - Architecture matches PRD approach
  - Error handling is comprehensive
  - API design follows conventions
  - Integration points implemented correctly

  Review actual code files mentioned in PRD.

  Return structured assessment: Compliant Items, Issues, Code Quality Score"
)
```

**Android Projects:**
```
Task(
  subagent_type="android-developer",
  prompt="Verify implementation quality for [feature].

  PRD: [path]
  Branch: [branch-name]

  Use impl-patterns skill: .claude/skills/impl-patterns.md

  Verify:
  - MVVM pattern followed correctly
  - Repository pattern (no Use Cases)
  - Compose UI best practices
  - State management proper
  - Navigation implemented correctly

  Review actual code files mentioned in PRD.

  Return structured assessment: Compliant Items, Issues, Code Quality Score"
)
```

**iOS Projects:**
```
Task(
  subagent_type="ios-developer",
  prompt="Verify implementation quality for [feature].

  PRD: [path]
  Branch: [branch-name]

  Use impl-patterns skill: .claude/skills/impl-patterns.md

  Verify:
  - SwiftUI patterns followed
  - ViewModel architecture correct
  - Navigation implemented properly
  - State management with @MainActor
  - Service layer follows conventions

  Review actual code files mentioned in PRD.

  Return structured assessment: Compliant Items, Issues, Code Quality Score"
)
```

### 2. Testing Verification Agent

```
Task(
  subagent_type="code-reviewer",
  prompt="Verify testing completeness for [feature].

  PRD: [path]
  Branch: [branch-name]

  Use testing-strategy skill: .claude/skills/testing-strategy.md

  Verify:
  - Unit tests exist for key components
  - Test coverage meets goals from skill
  - Edge cases tested
  - Error scenarios tested
  - Integration tests if applicable

  Review actual test files.

  Return structured assessment: Test Coverage %, Missing Tests, Test Quality"
)
```

### 3. Security & Performance Agent

```
Task(
  subagent_type="performance-optimizer",
  prompt="Verify security and performance for [feature].

  PRD: [path]
  Branch: [branch-name]

  Verify:
  - No security vulnerabilities introduced
  - Performance optimizations from PRD implemented
  - Memory management proper (mobile)
  - API rate limiting considered (backend)
  - Data validation/sanitization present

  Review actual code changes.

  Return structured assessment: Security Issues, Performance Concerns, Recommendations"
)
```

**Wait for all agents to complete**, then consolidate feedback.

---

## Phase 4: Verify Git Commits

**Goal**: Validate that implementation work was committed properly.

**Tasks**:
- Check if PRD has Branch metadata field
- If branch exists:
  - Navigate to appropriate project directory (your-backend-project/android/ios)
  - Verify branch exists in git (`git branch --list`)
  - Get commit history for branch (`git log`)
  - Check commits follow conventional commit format (feat:, fix:, refactor:, test:, chore:, docs:)
  - Match commit messages against implementation tasks
  - Verify one task = one commit pattern was followed
- If no branch:
  - Warn that verification is limited without branch information
  - Check recent commits in current branch for PRD-related work

**Output**: Commit summary with conventional commit validation

---

## Phase 5: Validate File Changes

**Goal**: Confirm files mentioned in PRD were actually modified.

**Tasks**:
- **From PRD:**
  - Parse "Key changes" section from "## Approach"
  - Extract file paths or patterns mentioned

- **Verify changes:**
  - If branch exists:
    - Get list of files changed in branch (`git diff --name-only main...branch`)
    - Compare with files mentioned in PRD
    - Flag if key files are missing from git history
  - If no branch:
    - Check if mentioned files exist in codebase
    - Warn about limited verification

**Output**: File change validation report

---

## Phase 6: Check Branch Status

**Goal**: Verify branch state and PR/merge status.

**Tasks**:
- If branch metadata exists:
  - Check if branch is merged (`git branch --merged`)
  - Check if PR exists using `gh pr list --head [branch]`
  - Check PR status (open, closed, merged)
  - Verify if branch has been deleted (merged and cleaned up)
- If branch doesn't exist but status is "implemented":
  - Check if commits exist in main branch
  - Suggest updating PRD status if work is complete

**Output**: Branch and PR status summary

---

## Phase 7: Consolidate Agent Feedback

**Goal**: Synthesize multi-agent verification results.

**Tasks**:
- Combine findings from all three agents:
  - Implementation quality assessment
  - Testing coverage assessment
  - Security/performance assessment

- Calculate quality scores:
  - Code quality: [Agent 1 score]
  - Test coverage: [Agent 2 percentage]
  - Security/performance: [Agent 3 pass/fail]

- Identify critical issues across all agents
- Prioritize recommendations

**Output**: Consolidated agent assessment

---

## Phase 8: Check for Deviations

**Goal**: Identify and assess any deviations from original PRD.

**Tasks**:
- **From Implementation Notes (if exists):**
  - Check "Deviations from PRD" section
  - Check "Issues encountered" section
  - Check "Agent Guidance Summary"

- **Assess deviations with agent insight:**
  - Were deviations documented properly?
  - Do they make sense given implementation?
  - Did agents flag any undocumented deviations?
  - Were PRD updates made with strikethrough?

**Output**: Deviation assessment with agent validation

---

## Phase 9: Generate Enhanced Verification Report

**Goal**: Provide comprehensive multi-agent assessment.

**Tasks**:
- Calculate overall completion percentage
- Categorize results:
  - ✅ **PASS**: All acceptance criteria checked, all tasks complete, agents approve quality, commits exist, files modified, tests passed, PR merged
  - ⚠️ **PARTIAL**: Some criteria met, but agent feedback identifies issues, or missing commits/PR/tests
  - ❌ **FAIL**: Acceptance criteria unchecked, agents flag critical issues, major gaps, or failing tests

- List specific gaps or issues:
  - Unchecked acceptance criteria
  - Incomplete PRD Implementation tasks
  - Missing conventional commits
  - Unmodified key files
  - Agent-identified code quality issues
  - Missing tests or test failures
  - Security/performance concerns from agents
  - Undocumented deviations
  - Missing or unmerged PR

- Suggest next steps:
  - If gaps found: specific actions from agent recommendations
  - If complete: suggest updating PRD status to "completed"
  - If PR not merged: remind to complete code review
  - If agents identified issues: prioritized fix list

**Output**: Enhanced verification report with multi-agent insights

---

## Example Output

```
📋 Enhanced Feature Verification: Android Feature Bug Fix
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📄 Documents
PRD: .claude/prds/android-feature-bug-fix.md
Project: android
Status: implemented
Issue: #216
Branch: fix/feature-bug-fix
Created: 2025-01-15

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Acceptance Criteria: 4/4 (100%)
✅ Marker position updates correctly during map movement
✅ Performance remains smooth during rapid scrolling
✅ Original pin behavior preserved for other markers
✅ No regressions in existing map functionality

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Implementation Tasks: 12/12 (100%)
Phase 1 (Foundation): 2/2 complete
Phase 2 (Core Logic): 4/4 complete
Phase 3 (Integration): 3/3 complete
Phase 4 (Testing): 2/2 complete
Phase 5 (Polish): 1/1 complete

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🤖 Multi-Agent Verification Results

✅ Implementation Quality (android-developer)
Score: 9.2/10
✓ MVVM pattern correctly implemented
✓ Repository pattern used (no Use Cases)
✓ Compose UI best practices followed
✓ State management with StateFlow proper
⚠️ Minor: Consider extracting magic constants in MapViewModel.kt:45

✅ Testing Coverage (code-reviewer)
Coverage: 87% (Target: 70%)
✓ Unit tests for MapViewModel comprehensive
✓ Edge cases tested (rapid scrolling, boundary conditions)
✓ Error scenarios covered
✓ Integration test for marker stability
💡 Suggestion: Add screenshot test for visual regression

✅ Security & Performance (performance-optimizer)
Status: PASS
✓ No security vulnerabilities identified
✓ Performance optimizations implemented (view recycling)
✓ Memory management proper (lifecycle-aware observers)
✓ No memory leaks detected in coroutine scopes
💡 Suggestion: Consider caching marker bitmaps for better performance

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Git Commits: 12 commits found (1 per task)
✅ feat: add MapView state management
✅ feat: implement marker position tracking
✅ refactor: optimize MapView state updates
✅ feat: integrate with existing map fragment
✅ test: add MapViewModel unit tests
✅ test: add marker stability tests
✅ refactor: handle edge cases for marker positioning

All commits follow conventional commit format.
One task = one commit pattern followed.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ File Changes: 5/5 files modified
✅ app/.../MapFragment.kt (modified)
✅ app/.../MapViewModel.kt (created)
✅ app/.../MapViewState.kt (created)
✅ app/.../MapFragmentTest.kt (modified)
✅ app/.../MapViewModelTest.kt (created)

All key files from PRD were changed.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️ Deviations: 1 documented
- Changed MapView approach: Used observable state pattern instead of listener pattern
  Reason: Better fits existing MVVM architecture
  Agent Validation: ✓ Approved - aligns with impl-patterns skill
  Status: PRD updated with strikethrough

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Branch Status
Branch: fix/feature-bug-fix (merged and deleted)
PR: #218 (merged to main on 2025-01-16)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ VERIFICATION PASSED (95%)

All acceptance criteria met, all tasks complete, multi-agent validation passed.

Agent Summary:
✓ Implementation Quality: 9.2/10 (Excellent)
✓ Testing Coverage: 87% (Exceeds target)
✓ Security & Performance: PASS (No issues)

Minor Improvements Suggested:
1. Extract magic constants (MapViewModel.kt:45)
2. Add screenshot test for visual regression
3. Consider caching marker bitmaps

Skills Validated:
✓ impl-patterns.md - Android patterns followed
✓ testing-strategy.md - Coverage targets exceeded

Next steps:
- Feature is fully implemented and merged
- Consider applying suggested improvements in future iteration
- Close GitHub issue #216 if still open
- Update PRD status to "completed"
```

---

## Guidelines

### When to Run This Command
- After completing `/prdx:dev:start` to validate work
- Before pushing PR to ensure quality
- Before marking a feature as "done"
- During code review to get agent assessment
- When returning to old features to assess current state

### What This Command Does
- ✅ Verifies acceptance criteria completion
- ✅ Validates implementation quality with platform agent
- ✅ Checks test coverage with testing expert
- ✅ Assesses security/performance
- ✅ Validates git commits and branch status
- ✅ Provides actionable recommendations

### What This Command Does NOT Do
- Does not run tests (use project-specific test commands)
- Does not deploy or build the project
- Does not modify the PRD or create commits
- Does not enforce code style (use linters/formatters)

### Edge Cases
- **PRD without branch**: Limited verification, focus on acceptance criteria and agent code review
- **Multiple branches**: Only check the branch specified in PRD metadata
- **Monorepo structure**: Verify in correct project directory (backend/android/ios)
- **PRD status "draft"**: Warn that feature hasn't been implemented yet
- **Missing GitHub issue**: Still verify, just skip PR-related checks
- **Undocumented deviations**: Agent may flag issues not documented

### Success Criteria
- Clear pass/fail status with completion percentage
- Multi-agent validation provides quality assessment
- Skills-based verification ensures patterns followed
- Actionable next steps from agent recommendations
- No false positives (agents provide context for issues)

---

## Example Usage

```bash
# Verify by filename
/prdx:dev:check android-feature-bug-fix.md

# Verify by slug (will find matching file)
/prdx:dev:check android-feature-bug-fix

# Verify backend feature
/prdx:dev:check backend-fix-context-storage-logger-tracing
```

---

## Differences from /prdx:dev:check

**Enhanced Features:**
- ✅ Multi-agent validation (implementation, testing, security/performance)
- ✅ Skills-based assessment (impl-patterns, testing-strategy)
- ✅ Code quality scoring
- ✅ Deeper technical verification
- ✅ Actionable recommendations from agents

**Simplified:**
- ✅ No separate impl plan to verify (PRD only)
- ✅ Agent-driven assessment vs manual checklist

**Result:**
- Higher confidence in implementation quality
- Expert-level code review automatically
- Skills ensure patterns followed
- Better recommendations for improvements
