# PRD Creation Wizard

Interactive guided workflow for creating a PRD. Recommended for new users or when you want step-by-step assistance.

## Usage

```bash
/prdx:wizard
```

## Instructions

You are guiding the user through an interactive PRD creation process. This wizard makes PRD creation approachable and helps avoid common mistakes.

---

## Welcome Message

Display friendly introduction:

```
╔════════════════════════════════════════════════════════════════════════════╗
║                        PRD CREATION WIZARD                                 ║
╚════════════════════════════════════════════════════════════════════════════╝

Welcome! I'll help you create a comprehensive PRD step by step.

This wizard will guide you through:
  1. Detecting your platform and context
  2. Choosing the right PRD type
  3. Describing your feature or problem
  4. Finding similar existing PRDs
  5. Identifying dependencies
  6. Creating a complete PRD

Let's get started!

────────────────────────────────────────────────────────────────────────────
```

---

## Step 1: Detect Project Structure

**Auto-detect project structure and platform(s):**

1. **Check current working directory:**
   ```bash
   pwd && ls
   ```

2. **Detect project structure:**

   **Full-Stack Project** (multiple platforms):
   - Check for multiple platform directories: `backend/`, `android/`, `ios/`, `web/`
   - If 2+ platform dirs found → Full-Stack

   **Single-Platform Project**:
   - One platform per repository
   - Check for platform indicators:
     - `src/`, `package.json`, `tsconfig.json` → backend
     - `build.gradle`, `app/` → android
     - `*.xcodeproj`, `*.xcworkspace` → ios
   - Otherwise → unknown

3. **Confirm with user:**
   ```
   Step 1/7: Project Structure Detection

   Detected: [Full-Stack / Single-Platform]
   [If Full-Stack:] Platforms: backend, android, ios
   [If Single-Platform:] Platform: [backend/android/ios]

   Is this correct? (y/n)
   ```

   If "no" or "unknown", use AskUserQuestion:
   ```
   What type of project is this?

   Options:
   1. Full-Stack (Multiple platforms in one repo)
   2. Single-Platform Backend (API/Server only)
   3. Single-Platform Android (Mobile app only)
   4. Single-Platform iOS (Mobile app only)
   5. Single-Platform Web (Frontend only)
   ```

4. **Display project info:**
   ```
   ✓ Project Structure: [Full-Stack / Single-Platform]
   ✓ Platform(s): [platforms]

   [If Full-Stack:]
   This PRD can affect one or multiple platforms.
   You'll choose which platform(s) in the next step.

   [If Single-Platform:]
   This PRD is scoped to [platform] only.
   Other platforms will be treated as external dependencies.

   ────────────────────────────────────────────────────────────────────────
   ```

---

## Step 2: Choose PRD Type

**Help user select appropriate PRD type:**

Use AskUserQuestion:

```
Step 2/7: PRD Type Selection

What type of work are you planning?
```

Options:
1. **New Feature** - Adding new functionality to the app
   - Example: "Add biometric login", "Implement dark mode"
   - Uses: feature-template.md
   - Branch prefix: feat/

2. **Bug Fix** - Fixing broken behavior
   - Example: "Fix memory leak in IoT client", "Correct button alignment"
   - Uses: bug-fix-template.md (simpler, includes reproduction steps)
   - Branch prefix: fix/

3. **Refactoring** - Improving code quality without changing behavior
   - Example: "Refactor auth flow", "Extract ViewModels"
   - Uses: refactor-template.md (includes migration plan)
   - Branch prefix: refactor/

4. **Research/Spike** - Time-boxed investigation
   - Example: "Investigate performance options", "Evaluate new library"
   - Uses: spike-template.md (findings-focused, no implementation)
   - Branch prefix: chore/

**Store selection:**
- `type`: feature | bug-fix | refactor | spike
- `branch_prefix`: feat | fix | refactor | chore

```
✓ PRD Type: [type]
  Template: [template-name]
  Branch prefix: [prefix]/

────────────────────────────────────────────────────────────────────────────
```

---

## Step 3: Gather Basic Information

**Collect feature details based on PRD type:**

### For All Types:

1. **Feature/Bug/Work title:**
   ```
   Step 3/7: Basic Information

   What's a short, descriptive title? (3-8 words)
   Example: "Fix memory leak in IoT client"
   Example: "Add biometric authentication"

   Title: _______
   ```

2. **Brief description:**
   ```
   Provide a brief description (1-2 sentences):
   - What problem does this solve?
   - Who is affected?

   Description: _______
   ```

### Type-Specific Questions:

**If bug-fix:**
```
Bug-specific details:

Severity? (Critical / High / Medium / Low)
Steps to reproduce: _______
Expected behavior: _______
Actual behavior: _______
```

**If refactor:**
```
Refactor-specific details:

Current pain points: _______
What future work will this enable: _______
```

**If spike:**
```
Spike-specific details:

Research question to answer: _______
Decision this will inform: _______
Time box (in hours/days): _______
```

```
✓ Title: [title]
  Description: [description]
  [Type-specific details...]

────────────────────────────────────────────────────────────────────────────
```

---

## Step 4: Search for Similar PRDs

**Check for duplicate or related work:**

1. **Search for similar PRDs:**
   Extract keywords from title and description
   ```bash
   grep -r -i "<keyword1>" .claude/prds --include="*.md" --exclude-dir=templates
   grep -r -i "<keyword2>" .claude/prds --include="*.md" --exclude-dir=templates
   ```

2. **Display results:**
   ```
   Step 4/7: Checking for Similar PRDs

   Searching for: [keywords]

   Found [N] potentially related PRDs:

   1. android-215: Optimize Auth Flow (completed)
      Similarity: mentions "auth", "authentication"

   2. backend-auth-refresh: Fix Auth0 Token Refresh (in-progress)
      Similarity: mentions "auth", "token"

   3. android-biometric-setup: Add Face ID Support (draft)
      Similarity: mentions "biometric", "authentication"

   ────────────────────────────────────────────────────────────────────────
   ```

3. **Ask about duplicates:**
   ```
   Do any of these PRDs cover the same work? (y/n)
   ```

   If yes:
   ```
   Which PRD is a duplicate?
   Options:
   1. android-215
   2. backend-auth-refresh
   3. android-biometric-setup
   4. None, my work is different

   [If 1-3 selected:]
   ⚠️  Duplicate detected!

   This work may already be covered by: [selected-prd]

   Options:
   1. Open existing PRD and review
   2. Continue anyway (work is actually different)
   3. Cancel wizard

   What would you like to do?
   ```

4. **Note related PRDs:**
   ```
   ✓ No duplicates found
     Related PRDs noted: [list]

   ────────────────────────────────────────────────────────────────────────
   ```

---

## Step 5: Identify Dependencies

**Find what this work depends on:**

1. **List in-progress and draft PRDs:**
   ```bash
   find .claude/prds -name "*.md" -type f ! -path "*/templates/*" -exec grep -l "Status.*draft\|Status.*in-progress" {} \;
   ```

2. **Display available PRDs:**
   ```
   Step 5/7: Dependencies

   Does this work depend on any other PRDs or issues?

   Available PRDs:
   - #215: Fix Auth0 Token Refresh (in-progress)
   - #218: Add UIState Helper (in-progress)
   - android-signup-refactor: Refactor Signup Flow (draft)

   ────────────────────────────────────────────────────────────────────────
   ```

3. **Ask about dependencies:**
   Use AskUserQuestion with multiSelect:
   ```
   Select all dependencies (work that must complete first):
   ```

   Options:
   - #215: Fix Auth0 Token Refresh
   - #218: Add UIState Helper
   - android-signup-refactor
   - None (no dependencies)
   - Other (specify issue number or PRD slug)

4. **Store dependencies:**
   ```
   ✓ Dependencies: [#215, #218] OR [none]

   ────────────────────────────────────────────────────────────────────────
   ```

---

## Step 6: Create PRD Slug

**Generate PRD filename:**

1. **Create slug from title:**
   - Convert to lowercase
   - Replace spaces with hyphens
   - Remove special characters
   - Prefix with platform

   Example:
   - Title: "Fix Memory Leak in IoT Client"
   - Slug: `backend-fix-memory-leak-iot-client`

2. **Show and confirm:**
   ```
   Step 6/7: PRD Slug

   Generated filename: [platform]-[slug].md

   Example: backend-fix-memory-leak-iot-client.md

   Accept this filename? (y/n)
   [If no:] Enter custom slug: _______
   ```

3. **Check for conflicts:**
   ```bash
   ls .claude/prds/[slug].md 2>/dev/null
   ```

   If exists:
   ```
   ⚠️  A PRD with this name already exists!

   Existing: .claude/prds/[slug].md

   Options:
   1. Choose different name
   2. Overwrite existing (risky!)
   3. Cancel wizard

   What would you like to do?
   ```

```
✓ PRD Filename: [filename]

────────────────────────────────────────────────────────────────────────────
```

---

## Step 7: Review and Confirm

**Show summary before creating PRD:**

```
Step 7/7: Review & Confirm

Here's what we'll create:

╔════════════════════════════════════════════════════════════════════════════╗
║  PRD SUMMARY                                                               ║
╚════════════════════════════════════════════════════════════════════════════╝

Title:        [title]
Platform:     [platform]
Type:         [type]
Template:     [template-name]
Branch Type:  [prefix]/

Description:  [description]

Dependencies: [deps or "none"]
Related PRDs: [related or "none"]

Filename:     .claude/prds/[filename]

╚════════════════════════════════════════════════════════════════════════════╝

Ready to create this PRD? (y/n)
```

Options:
1. **Yes, create PRD** - Proceed to invoke `/prdx:plan`
2. **No, modify details** - Return to specific step
3. **Cancel** - Exit wizard

---

## Step 8: Invoke /prdx:plan

**Create PRD using gathered information:**

1. **Build command:**
   ```
   /prdx:plan "[title]" --type [type] --depends-on [deps]
   ```

2. **Execute /prdx:plan:**
   - Pass all collected information
   - Include title, description, type, dependencies
   - Let /prdx:plan handle the rest (agent research, multi-agent review)

3. **Show transition message:**
   ```
   ────────────────────────────────────────────────────────────────────────────

   ✓ Wizard Complete!

   Handing off to /prdx:plan for PRD creation...
   This will:
   - Research your codebase with specialized agents
   - Create PRD using the [type] template
   - Run multi-agent review (technical, testing, security)
   - Apply improvements inline

   ────────────────────────────────────────────────────────────────────────────
   ```

4. **Execute /prdx:plan with context:**
   Invoke `/prdx:plan` command workflow with all parameters

---

## Final Summary

**After /prdx:plan completes, show wizard summary:**

```
╔════════════════════════════════════════════════════════════════════════════╗
║  PRD WIZARD - SUCCESS!                                                     ║
╚════════════════════════════════════════════════════════════════════════════╝

✓ PRD Created: .claude/prds/[filename]
✓ Platform detected: [platform]
✓ Template selected: [type]
✓ Similar PRDs checked: [N found, 0 duplicates]
✓ Dependencies added: [deps]
✓ Agent research completed
✓ Multi-agent review applied

What's next?
  1. Review your PRD: Read .claude/prds/[filename]
  2. Publish to GitHub: /prdx:publish [slug]
  3. Start implementation: /prdx:dev:start [slug]
  4. Get help anytime: /prdx:help

────────────────────────────────────────────────────────────────────────────

💡 Tip: The wizard helped you avoid common pitfalls and ensured
   nothing was missed. For faster PRD creation next time, you can
   use /prdx:plan directly!

╚════════════════════════════════════════════════════════════════════════════╝
```

---

## Implementation Notes

- Use friendly, encouraging language throughout
- Validate all inputs before proceeding
- Allow users to go back and modify earlier choices
- Provide helpful examples at each step
- Search intelligently for similar PRDs (avoid duplicates)
- Auto-detect as much as possible (platform, type inference)
- Make it impossible to create a malformed PRD

## User Experience Guidelines

- **Be patient**: Don't rush through steps
- **Be helpful**: Provide examples and explanations
- **Be smart**: Auto-detect and suggest when possible
- **Be safe**: Check for duplicates and conflicts
- **Be clear**: Show exactly what will be created before proceeding

## Edge Cases

- **No platform detected**: Ask user to select
- **Too many similar PRDs**: Show top 5, offer to show more
- **User cancels mid-way**: Thank them and exit gracefully
- **Invalid inputs**: Re-prompt with helpful error messages
- **PRD creation fails**: Show error and offer to retry or save progress
