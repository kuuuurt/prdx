---
description: "Adversarially review a PRD by handing it to the /grill-me skill"
argument-hint: "[slug]"
---

## Pre-Computed Context

```bash
source "$(git rev-parse --show-toplevel)/hooks/prdx/resolve-plans-dir.sh"
```

# /prdx:grill — Stress-Test a PRD

Load a saved PRD and hand it to the `/grill-me` skill, which interviews you relentlessly until each branch of the design tree is resolved.

**Cheapest place to catch a bad design is before any code exists.** Run this between `/prdx:plan` and `/prdx:implement` whenever the PRD feels uncertain or the stakes are high.

## Usage

```bash
/prdx:grill                      # auto-detect active PRD
/prdx:grill biometric-auth       # specific slug
/prdx:grill lite-login-validation
```

## Workflow

### Step 1: Resolve PRD

Source the slug resolver:

```bash
source "$(git rev-parse --show-toplevel)/hooks/prdx/resolve-slug.sh" "$ARG"
# → sets: RESOLVED_SLUG, PRD_FILE
```

If no argument was passed, auto-detect from active state files:

```bash
ACTIVE=$(ls .prdx/state/*.json 2>/dev/null)
```

- Zero active states → tell user to pass a slug or run `/prdx:plan` first.
- Exactly one active state → use that slug.
- Multiple active states → use AskUserQuestion to let user pick which PRD to grill.

### Step 2: Read the PRD

```bash
cat "$PRD_FILE"
```

If the file is missing, error out clearly: `PRD not found: {PRD_FILE}. Run /prdx:show to list PRDs.`

### Step 3: Hand off to /grill-me

Invoke the `grill-me` skill via the Skill tool, passing the PRD content as the subject of the interview:

```
Skill: grill-me
args: |
  Grill me on the following PRD. Walk down each branch — Problem framing,
  Goal scope, Acceptance Criteria coverage, Approach risks, missing edge
  cases — and ask one question at a time with your recommended answer.

  PRD: {PRD_FILE}

  ---
  {PRD_CONTENTS}
```

The skill drives the interview. After grilling concludes, suggest the user re-edit the PRD with any new insights:

```
Grilling complete. If anything surfaced, edit {PRD_FILE} directly and
proceed with /prdx:implement {RESOLVED_SLUG} when ready.
```

## Notes

- This is a **read-only** command — it does not modify the PRD. The user revises after grilling based on what surfaced.
- Interactive only. CI mode skips this — non-interactive critique is not currently supported.
- Use after `/prdx:plan` and before `/prdx:implement`. Running it later is fine but cheaper to catch issues early.
