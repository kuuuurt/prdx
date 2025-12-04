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

**If the argument matches an existing PRD** (check `.claude/prds/`):
- Read PRD and check its status
- Resume from the appropriate phase:
  - `planning` → Continue planning (Phase 2)
  - `published` → Implement (Phase 3)
  - `in-progress` → Continue implementation (Phase 3)
  - `implemented` → Create PR (Phase 4)
  - `review` → Create PR (Phase 4)
  - `completed` → Inform user the PRD is done

**If the argument is a feature description** (not an existing PRD):
- Proceed to Phase 2 (planning)

**If no argument provided**:
- List existing PRDs with their status using: `ls -la .claude/prds/*.md 2>/dev/null`
- Ask: "Start a new feature or continue an existing PRD?"

---

### Step 2: Planning

Run the planning command with the feature description:

```
/prdx:plan [description]
```

Wait for planning to complete and user to approve the PRD.

**After PRD is created, use AskUserQuestion to ask:**
- Option 1: "Publish to GitHub" (creates issue for team visibility)
- Option 2: "Implement now" (start coding immediately)
- Option 3: "Stop here" (review PRD later)

Route based on choice:
- Publish → Phase 3a (then ask about implementation)
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

Run the implementation command:

```
/prdx:implement [slug]
```

Wait for implementation to complete.

**After implementation, use AskUserQuestion:**
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

PRD: .claude/prds/[slug].md
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
