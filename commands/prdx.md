| description | argument-hint |
| Complete PRD workflow: plan → publish → implement → push | Feature description or existing PRD slug |

# PRDX Workflow

> **One command to rule them all.**
> Orchestrates the complete feature development workflow with decision points.

---

## Phase 1: Determine Entry Point

**Check the argument:**

1. If argument matches existing PRD (`.claude/prds/*[arg]*.md`):
   - Read PRD and check status
   - Skip to appropriate phase based on status:
     - `planning` → Phase 2 (continue planning)
     - `published` → Phase 4 (implement)
     - `in-progress` → Phase 4 (continue implementation)
     - `implemented` → Phase 5 (push)
     - `review` → Phase 5 (push)
     - `completed` → Inform user PRD is done

2. If argument is a feature description (not existing PRD):
   - Proceed to Phase 2 (planning)

3. If no argument:
   - List existing PRDs with status
   - Ask: "Start new feature or continue existing?"
   - Route accordingly

---

## Phase 2: Planning

**Run planning workflow:**

```
/prdx:plan [description]
```

Wait for plan completion and user approval.

**After PRD is created, ask:**

```
PRD created: .claude/prds/[slug].md

What would you like to do next?
1. Publish to GitHub (creates issue for team visibility)
2. Implement now (start coding immediately)
3. Stop here (review PRD later)
```

- If **Publish** → Phase 3
- If **Implement** → Phase 4
- If **Stop** → End workflow, show next steps

---

## Phase 3: Publish

**Run publish workflow:**

```
/prdx:publish [slug]
```

Wait for issue creation.

**After issue is created, ask:**

```
GitHub issue created: #[number]

Ready to implement?
1. Yes, start implementation
2. No, I'll implement later
```

- If **Yes** → Phase 4
- If **No** → End workflow, show next steps

---

## Phase 4: Implementation

**Run implementation workflow:**

```
/prdx:implement [slug]
```

Wait for implementation to complete.

**After implementation, ask:**

```
Implementation complete!

Ready to create pull request?
1. Yes, create PR now
2. No, I need to review first
```

- If **Yes** → Phase 5
- If **No** → End workflow, show next steps

---

## Phase 5: Push

**Run push workflow:**

```
/prdx:push [slug]
```

**After PR creation:**

```
🎉 Feature complete!

PRD: .claude/prds/[slug].md
Issue: #[issue-number]
PR: #[pr-number]

The feature is ready for review.
```

---

## Decision Point Guidelines

**Use AskUserQuestion tool** at each decision point with clear options.

**Always show context:**
- Current PRD status
- What was just completed
- What comes next

**Respect user choice:**
- Never auto-proceed without asking
- "Stop here" is always valid
- Show how to resume later

---

## Resuming Workflow

When user runs `/prdx [existing-slug]`:

1. Read PRD status
2. Show current state:
   ```
   Found PRD: [title]
   Status: [status]

   Resuming from: [phase]
   ```
3. Continue from appropriate phase

---

## Error Handling

**If any phase fails:**

1. Show clear error message
2. Don't auto-proceed to next phase
3. Offer options:
   ```
   [Phase] encountered an issue: [error]

   Options:
   1. Retry this step
   2. Stop and fix manually
   3. Skip to next step (if possible)
   ```

---

## Example Flow

```
User: /prdx add biometric login