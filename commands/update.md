| description | argument-hint |
| Enhanced PRD update with agent assistance and optional GitHub sync | Feature slug or issue number |

# Enhanced Feature Update (PRD2)

> **Agent-assisted updates with intelligent review**
> Updates leverage specialized agents for technical validation and impact analysis

**CRITICAL**: Never delete content. Use `~~strikethrough~~` for outdated info, then add new content.

---

## Phase 1: Locate PRD & Understand Changes

**Find and assess:**

1. If slug/issue provided: `ls .claude/prds/*[slug]*.md`
2. If not: list PRDs and ask user to select
3. **DO NOT PROCEED** without valid PRD

4. **Ask user what needs updating:**
   ```
   What needs to be updated?

   Common reasons:
   1. Hit technical roadblock
   2. Discovered new requirements
   3. Found better approach
   4. External dependencies changed
   5. Revise acceptance criteria

   Describe what changed and why:
   ```

5. Wait for input, clarify scope of changes

---

## Phase 2: Agent-Powered Impact Analysis

**Route to specialized agent for impact assessment:**

Based on PRD platform, use Task tool with appropriate agent:

**Backend Projects:**
```
Task(
  subagent_type="backend-developer",
  prompt="Analyze PRD update impact for [feature].

  Current PRD: [path]
  Proposed changes: [user's description]

  Assess:
  - Technical feasibility of new approach
  - Impact on existing API contracts
  - Database/service dependencies affected
  - Backward compatibility concerns
  - Testing requirements for changes

  Provide structured impact analysis with recommendations."
)
```

**Android Projects:**
```
Task(
  subagent_type="android-developer",
  prompt="Analyze PRD update impact for [feature].

  Current PRD: [path]
  Proposed changes: [user's description]

  Assess:
  - UI/UX implications
  - ViewModel/Repository changes needed
  - Navigation flow impacts
  - State management adjustments
  - Testing requirements

  Provide structured impact analysis with recommendations."
)
```

**iOS Projects:**
```
Task(
  subagent_type="ios-developer",
  prompt="Analyze PRD update impact for [feature].

  Current PRD: [path]
  Proposed changes: [user's description]

  Assess:
  - SwiftUI view changes
  - ViewModel/Service adjustments
  - Navigation impacts
  - State management changes
  - Testing requirements

  Provide structured impact analysis with recommendations."
)
```

Agent provides:
- Technical validation of proposed changes
- Impact on implementation phases
- Timeline/complexity adjustments
- Additional risks or considerations

---

## Phase 3: Review Current State

**Check implementation progress:**

1. Check PRD for "Implementation Notes" section
2. Check git history:
   ```bash
   cd your-[project] && git log --oneline -10
   ```

3. Display current state with agent insights:
   ```
   Current: [Feature Name]

   Status: [draft/published/in-progress]
   Issue: #[number] (if exists)

   Progress: [count] of [total] tasks complete
   Last commit: [message]

   Proposed Changes: [sections mentioned]

   Agent Impact Analysis:
   ✓ Technical Feasibility: [assessment]
   ⚠️ Dependencies Affected: [list]
   📊 Timeline Impact: [extended/reduced/no change]
   🔧 Complexity Impact: [increased/decreased/no change]
   🧪 Testing Changes: [requirements]
   ```

---

## Phase 4: Skills-Enhanced Update Planning

**Leverage skills for update guidance:**

Read relevant skills:
- `.claude/skills/impl-patterns.md` (for technical approach changes)
- `.claude/skills/prd-review.md` (for validation)
- `.claude/skills/testing-strategy.md` (for testing changes)

Apply skill guidance to:
- Ensure new approach follows platform patterns
- Validate updated technical approach
- Define new test requirements
- Identify additional risks

---

## Phase 5: Update PRD with Strikethrough

**Apply changes preserving history:**

### Core Principle: NEVER DELETE

- ✓ Use `~~strikethrough~~` for outdated/incorrect info
- ✓ Add new information alongside or below
- ✓ Mark updates with dates
- ✗ Never delete original content

### Update Patterns:

**Problem/Goal:**
```markdown
~~Original goal statement~~

**Revised ([date])**: Updated goal statement

**Why changed**: [Reason + agent insight]
```

**Acceptance Criteria:**
```markdown
- [x] Completed criterion (keep as-is)
- ~~[ ] Obsolete criterion~~ *(Changed to support [reason])*
- [ ] **REVISED**: Updated criterion
- [ ] **NEW**: Additional criterion
```

**Technical Approach:**
```markdown
**Architecture**: ~~Original approach~~ → **Revised ([date])**: New approach

**Why changed**: [Reason + agent analysis]

**Key changes**:
- **Component**: ~~Old design~~ → **Updated**: New design
- **NEW**: Additional component
```

**Implementation:**
```markdown
### Phase 1: Setup
- [x] Completed task (keep as-is)
- ~~[ ] Obsolete task~~ *(Replaced by new approach)*
- [ ] **NEW**: Replacement task (complexity: S/M/L)
```

**Risks:**
```markdown
| ~~Obsolete risk~~ | ~~H~~ | **RESOLVED ([date])**: [How resolved] |
| New risk | M/H/L | [Mitigation from agent analysis] |
```

---

## Phase 6: Agent Review of Updates

**Validate changes with review agent:**

Use Task tool with code-reviewer:

```
Task(
  subagent_type="code-reviewer",
  prompt="Review PRD updates for [feature].

  Updated PRD: [path]
  Changes made: [summary]

  Use prd-review skill: .claude/skills/prd-review.md

  Validate:
  - Updated approach follows platform patterns
  - New acceptance criteria are testable
  - Implementation phases still logical
  - Risks adequately addressed
  - Testing requirements complete

  Return structured feedback: Issues, Suggestions, Approval"
)
```

Apply any additional improvements from review feedback.

---

## Phase 7: Track Revision

**Add revision history entry:**

Never edit existing revisions. Always add new:

```markdown
---

## Revision History

### Revision [N] - [date]
**Reason**: [Why update was needed]
**Agent Analysis**: [Key insights from agent impact analysis]
**Sections updated**: [List]
**Impact**:
- Timeline: [extended/reduced/no change]
- Complexity: [increased/decreased/no change]
- Testing: [additional requirements]

### Revision [N-1] - [date]
[Previous revision]

### Original - [date]
Initial PRD
```

---

## Phase 8: Display Summary & Sync

**Show what changed:**

```
✓ Enhanced PRD Updated with Agent Review!

PRD: .claude/prds/[filename]
Revision: [number]
Platform: [backend/android/ios]

Changes:
- Marked obsolete: [count] items (strikethrough)
- Added new: [count] items
- Revised: [count] items

Agent Analysis:
✓ Technical Feasibility: [assessment]
✓ Dependencies Reviewed: [list]
✓ Patterns Validated: [skill checks]

Impact:
- Timeline: [extended/reduced/no change]
- Complexity: [increased/decreased/no change]
- Testing: [requirements added/changed]

Skills Used:
✓ impl-patterns.md - Validated approach
✓ prd-review.md - Review checklist
✓ testing-strategy.md - Test requirements

Agent Reviews:
✓ [platform]-developer - Impact analysis
✓ code-reviewer - Update validation
```

**Optional GitHub sync** (if published):
```
This PRD is linked to issue #[number]

Sync changes to GitHub? (y/n)

Note: Can keep local-only if preferred
```

If yes, post update comment:
```markdown
## 🔄 PRD Updated - [date] (Rev [N]) - Agent-Reviewed

### Reason
[Why updated]

### Agent Analysis
**Technical Feasibility**: [assessment]
**Dependencies Affected**: [list]
**Timeline Impact**: [impact]

### Changes
- ~~Obsolete item~~ → Reason: [why]
- **NEW**: [New item]
- **REVISED**: [What changed]

### Impact
- Timeline: [impact]
- Complexity: [impact]
- Testing: [requirements]

<details>
<summary>Updated Implementation Plan</summary>

[Checklist with strikethrough and NEW markers]

</details>

**Full PRD**: `.claude/prds/[filename]`

---
*Updated with agent-assisted analysis using specialized skills*
```

**Next steps:**
```
- Review updated PRD and agent analysis
- Continue implementation: /prdx:dev:start [slug]
- Sync to GitHub later: /prdx:sync [slug] (if needed)
```

---

## Important Rules

- **NEVER DELETE** - Use `~~strikethrough~~` for obsolete content
- **PRESERVE HISTORY** - Keep all original content visible
- **USE AGENTS** - Leverage platform agents for impact analysis
- **APPLY SKILLS** - Use impl-patterns, prd-review, testing-strategy
- **DATE REVISIONS** - Mark updates with dates
- **EXPLAIN CHANGES** - Document why content became obsolete + agent insights
- **LABEL NEW CONTENT** - Use **NEW**, **REVISED** markers
- **KEEP COMPLETED TASKS** - Never strikethrough `[x]` tasks
- **GITHUB OPTIONAL** - User explicitly chooses whether to sync
- **LOCAL-FIRST** - Update locally first, GitHub sync is secondary
- **VALIDATE CHANGES** - Review agent validates updates

---

## Differences from /prdx:update

**Enhanced Features:**
- ✅ Agent-powered impact analysis (platform-specific)
- ✅ Skills integration for update guidance
- ✅ Review agent validates changes
- ✅ Technical feasibility assessment
- ✅ Dependency impact analysis

**Result:**
- Smarter updates with technical validation
- Better risk assessment
- Platform-specific impact understanding
- Ensures updates follow established patterns
