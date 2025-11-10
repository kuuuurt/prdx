# PRD Commands Help

Quick reference guide for all PRD workflow commands.

## Instructions

Display a comprehensive help guide for all available PRD commands.

Show the following information:

```
╔════════════════════════════════════════════════════════════════════════════╗
║                         PRD WORKFLOW COMMANDS                              ║
╚════════════════════════════════════════════════════════════════════════════╝

DISCOVERY & BROWSING
────────────────────────────────────────────────────────────────────────────
/prdx:list [--status <status>] [--platform <platform>]
  List all PRDs with optional filtering
  Examples:
    /prdx:list                          # Show all PRDs
    /prdx:list --status draft           # Show only drafts
    /prdx:list --platform android       # Show Android PRDs

/prdx:search <keyword> [keywords...]
  Search PRDs by keyword or phrase
  Examples:
    /prdx:search auth0                  # Find PRDs mentioning "auth0"
    /prdx:search "memory leak"          # Search exact phrase
    /prdx:search viewmodel state        # Multiple keywords (OR)

/prdx:status <slug>
  Show detailed status and progress for a specific PRD
  Example:
    /prdx:status android-219            # Show status for android-219.md

/prdx:deps <slug>
  Display dependency tree for a PRD
  Example:
    /prdx:deps backend-auth-refactor    # Show dependencies

/prdx:help
  Show this help guide

────────────────────────────────────────────────────────────────────────────

PLANNING & CREATION
────────────────────────────────────────────────────────────────────────────
/prdx:wizard
  Interactive PRD creation wizard (RECOMMENDED FOR NEW USERS)
  - Guides you through PRD creation step-by-step
  - Auto-detects platform and suggests templates
  - Searches for similar PRDs to avoid duplicates
  - Helps identify dependencies

/prdx:plan <feature> [--type <type>] [--depends-on <issue>]
  Create a new PRD with agent-powered research and multi-agent review

  Types: feature (default), bug-fix, refactor, spike

  Examples:
    /prdx:plan "add biometric login"
    /prdx:plan "fix memory leak" --type bug-fix
    /prdx:plan "refactor auth" --type refactor --depends-on #215

  Flow:
    1. Clarifying questions
    2. Platform-specific codebase research
    3. PRD creation with appropriate template
    4. Multi-agent review (technical, testing, security)
    5. Inline feedback consolidation

/prdx:update <slug>
  Update an existing PRD with agent impact analysis
  Example:
    /prdx:update android-219

────────────────────────────────────────────────────────────────────────────

GITHUB INTEGRATION
────────────────────────────────────────────────────────────────────────────
/prdx:publish <slug>
  Publish PRD to GitHub issue
  - Creates GitHub issue
  - Renames PRD to [platform]-[issue-number].md
  - Updates PRD metadata with issue link

/prdx:sync <slug>
  Bidirectional sync between PRD and GitHub issue
  - Auto-detects sync direction based on timestamps
  - Handles conflicts gracefully

────────────────────────────────────────────────────────────────────────────

DEVELOPMENT WORKFLOW
────────────────────────────────────────────────────────────────────────────
/prdx:dev:start <slug>
  Start implementation (creates detailed plan automatically if needed)

  Phase 1-2 (Auto-Planning):
    - Checks for "## Detailed Implementation Plan" in PRD
    - If missing, creates it inline using platform-specific agent
    - Includes task breakdown, file paths, API contracts, testing strategy

  Phase 3-8 (Implementation):
    - Creates feature branch (feat/*, fix/*, refactor/*, etc.)
    - Executes tasks from detailed plan
    - One task = one commit (conventional format)
    - Runs tests based on strategy
    - Updates PRD status to "in-progress" automatically

  Example:
    /prdx:dev:start android-219

/prdx:dev:check <slug>
  Multi-agent verification of implementation
  - Implementation quality check (platform-specific)
  - Testing coverage validation
  - Security/performance review
  - Git commit validation
  - Code quality scoring with actionable recommendations

  Example:
    /prdx:dev:check android-219

/prdx:dev:push <slug>
  Create GitHub pull request
  - Pushes branch to remote
  - Creates PR with detailed plan as description
  - Links PR to issue
  - Updates PRD status to "in-review" automatically

  Example:
    /prdx:dev:push android-219

/prdx:close <slug>
  Mark PRD as completed when work is done
  - Updates status to "completed"
  - Archives PRD metadata

  Example:
    /prdx:close android-219

────────────────────────────────────────────────────────────────────────────

TYPICAL WORKFLOWS
────────────────────────────────────────────────────────────────────────────

New Feature (Full Cycle):
  1. /prdx:wizard                       # Create PRD interactively
  2. /prdx:publish <slug>               # Publish to GitHub
  3. /prdx:dev:start <slug>             # Implement (auto-creates detailed plan)
  4. /prdx:dev:check <slug>             # Verify implementation
  5. /prdx:dev:push <slug>              # Create PR
  6. (Manual: Code review & merge)
  7. /prdx:close <slug>                 # Mark as completed

Bug Fix (Fast Track):
  1. /prdx:plan "fix xyz" --type bug-fix
  2. /prdx:dev:start <slug>             # Implement immediately
  3. /prdx:dev:push <slug>              # Create PR

Research/Spike:
  1. /prdx:plan "investigate xyz" --type spike
  2. /prdx:dev:start <slug>             # Conduct research
  3. Update ## Findings section
  4. /prdx:close <slug>                 # Document outcomes

Finding & Updating Existing PRD:
  1. /prdx:search "keyword"             # Find relevant PRD
  2. /prdx:update <slug>                # Make changes
  3. /prdx:sync <slug>                  # Sync with GitHub

────────────────────────────────────────────────────────────────────────────

PRD STATUSES
────────────────────────────────────────────────────────────────────────────
draft        → Initial creation, not yet published
published    → GitHub issue created, ready for work
in-progress  → Implementation underway (auto-set by /prdx:dev:start)
in-review    → PR created, awaiting review (auto-set by /prdx:dev:push)
implemented  → Code merged, PRD work complete
completed    → Fully done, archived (set by /prdx:close)

────────────────────────────────────────────────────────────────────────────

PRD TYPES & TEMPLATES
────────────────────────────────────────────────────────────────────────────
feature      → New functionality (default template)
bug-fix      → Fix broken behavior (simpler, includes reproduction steps)
refactor     → Improve code quality (includes migration plan)
spike        → Research/investigation (time-boxed, findings-focused)

────────────────────────────────────────────────────────────────────────────

BRANCH NAMING CONVENTIONS
────────────────────────────────────────────────────────────────────────────
feat/<platform>-<issue>-<slug>      → New features
fix/<platform>-<issue>-<slug>       → Bug fixes
refactor/<platform>-<issue>-<slug>  → Refactoring work
chore/<platform>-<issue>-<slug>     → Maintenance tasks
docs/<platform>-<issue>-<slug>      → Documentation updates

Examples:
  feat/android-219-biometric-login
  fix/backend-215-memory-leak
  refactor/ios-220-navigation

────────────────────────────────────────────────────────────────────────────

DOCUMENTATION
────────────────────────────────────────────────────────────────────────────
Full Guide:     .claude/docs/prd-workflow-guide.md
Implementation: .claude/docs/prd-implementation-summary.md
Templates:      .claude/prds/templates/

────────────────────────────────────────────────────────────────────────────

TIPS & BEST PRACTICES
────────────────────────────────────────────────────────────────────────────
✓ Use /prdx:wizard for your first few PRDs
✓ Let agents do the research - they explore the codebase thoroughly
✓ Keep acceptance criteria to 3-5 essential items only
✓ Review agent feedback carefully - they catch real issues
✓ One task = one commit for clean git history
✓ Run /prdx:dev:check before creating PR
✓ Use --type to get the right template for your work
✓ Track dependencies to avoid blockers

✗ Don't skip the planning phase
✗ Don't commit without running tests
✗ Don't ignore agent recommendations
✗ Don't create PRDs for trivial changes (<30 min work)

────────────────────────────────────────────────────────────────────────────

Need more help? Check the full guide:
.claude/docs/prd-workflow-guide.md

╚════════════════════════════════════════════════════════════════════════════╝
```

## Additional Notes

- Keep the output concise but comprehensive
- Use clear formatting with borders and sections
- Highlight key commands and examples
- Show the most common workflows
- Include links to detailed documentation
