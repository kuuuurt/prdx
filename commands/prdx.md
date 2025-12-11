---
description: "Complete PRD workflow: plan → publish → implement → push"
argument-hint: "[feature description or PRD slug]"
---

# /prdx - Complete Feature Workflow

> **One command to rule them all.**
> Orchestrates the complete feature development workflow with decision points.

## Workflow

Execute the following phases based on the argument provided:

### Step 1: Determine Entry Point

**If the argument matches an existing PRD** (check `.prdx/prds/`):
- Read PRD and check its status
- For multi-platform mobile PRDs, also check which platforms have been implemented (look for `## Implementation Notes (android)` and `## Implementation Notes (ios)` sections)
- Resume from the appropriate phase:
  - `planning` → Continue planning (Phase 2)
  - `published` → Implement (Phase 3)
  - `in-progress` → Continue implementation (Phase 3)
    - For multi-platform: Check which platforms are done, resume with remaining platform
  - `implemented` → Create PR (Phase 4)
  - `review` → Create PR (Phase 4)
  - `completed` → Inform user the PRD is done

**If the argument is a feature description** (not an existing PRD):
- Proceed to Phase 2 (planning)

**If no argument provided**:
- List existing PRDs with their status using: `ls -la .prdx/prds/*.md 2>/dev/null`
- Ask: "Start a new feature or continue an existing PRD?"

---

### Step 2: Planning

Run the planning command with the feature description:

```
/prdx:plan [description]
```

**IMPORTANT: The planner agent will use AskUserQuestion to get explicit PRD approval.**

Wait for `/prdx:plan` to complete. The agent will:
1. Explore the codebase
2. Create a PRD draft
3. Ask user to approve via AskUserQuestion (Approve / Request changes / Start over)
4. Only return when user explicitly selects "Approve PRD"

**Do NOT proceed until the planner returns with "✅ PRD Approved" in its output.**

If the planner returns without approval (user chose "Start over" or abandoned), stop the workflow.

**After PRD is approved and saved, use AskUserQuestion to ask:**
- Option 1: "Publish to GitHub" (creates issue for team visibility)
- Option 2: "Implement now" (start coding immediately)
- Option 3: "Stop here" (review PRD later)

Route based on choice:
- Publish → Phase 2a (then ask about implementation)
- Implement → Phase 3
- Stop → End workflow, tell user they can resume with `/prdx [slug]`

---

### Step 2a: Publish (Optional)

If user chose to publish:

```
/prdx:publish [slug]
```

After issue is created, use AskUserQuestion:
- Option 1: "Yes, start implementation"
- Option 2: "No, I'll implement later"

Route based on choice:
- Yes → Phase 3
- No → End workflow

---

### Step 3: Implementation

**Check if this is a multi-platform mobile PRD:**

Read the PRD and check for `**Platforms:**` field with multiple platforms (e.g., "android, ios").

**For single-platform PRDs:**
```
/prdx:implement [slug]
```
Wait for implementation to complete, then proceed to PR decision.

**For multi-platform mobile PRDs:**

Implementation runs **sequentially** per platform to learn from the first implementation.

1. **First Platform (Android):**
   - Display: "Starting Android implementation..."
   - Run: `/prdx:implement [slug] android`
   - Wait for completion

2. **Between Platforms - Ask User:**
   Use AskUserQuestion:
   - Option 1: "Continue to iOS" (Recommended)
   - Option 2: "Stop here, I'll continue iOS later"
   - Option 3: "Skip iOS, Android only"

   Route based on choice:
   - Continue → Proceed to iOS
   - Stop → End workflow, tell user to resume with `/prdx [slug]`
   - Skip → Update PRD to remove iOS from Platforms, proceed to PR decision

3. **Second Platform (iOS):**
   - Display: "Starting iOS implementation (applying learnings from Android)..."
   - Run: `/prdx:implement [slug] ios`
   - Wait for completion

**After all platform implementations complete, use AskUserQuestion:**
- Option 1: "Yes, create PR now"
- Option 2: "No, I need to review first"

Route based on choice:
- Yes → Phase 4
- No → End workflow, tell user they can resume with `/prdx [slug]`

---

### Step 4: Create Pull Request

Run the push command:

```
/prdx:push [slug]
```

**After PR is created, display completion message:**

```
🎉 Feature complete!

PRD: .prdx/prds/[slug].md
Issue: #[issue-number] (if published)
PR: #[pr-number]

The feature is ready for review.
```

---

## Important Guidelines

**Use AskUserQuestion tool** at each decision point with clear options.

**Always show context:**
- Current PRD status
- What was just completed
- What comes next

**Respect user choice:**
- Never auto-proceed to the next phase without asking
- "Stop here" is always a valid option
- Always show how to resume later with `/prdx [slug]`

**Error handling:**
- If any phase fails, show clear error message
- Don't auto-proceed after errors
- Offer: retry, stop, or skip options
