# PR Description Rubric (for prdx:pr-author, PRD mode)

Score each axis 1-5. Be strict; 3 = adequate, 5 = exemplary.

The artifact is the PR **title and body** that `pr-author` would pass to
`gh pr create`. The first line of the output is `Title: …`; the rest is the
body markdown.

## Axes

### title_quality
Is the title concise (≤70 chars), conventional-commit prefixed, and
descriptive of the WHAT?
- 1: missing prefix, restates the type ("feat: Add feature for X"), or vague
- 3: passable but verbose
- 5: short, specific, scannable; prefix derived correctly from PRD type

### summary_quality
Does the Summary describe the user/business value delivered, not the
mechanics? 1-2 sentences max.
- 1: missing, or describes how (the diff) instead of what (the value)
- 3: present but mechanical
- 5: states value crisply in user-facing terms

### ac_coverage
Does the "Acceptance Criteria" section reproduce every AC from the PRD, each
marked `- [x]` (since implementation is complete)?
- 1: AC missing, or AC list invented from scratch
- 3: most AC present but a few dropped or reworded
- 5: every AC from the PRD reproduced verbatim, all checked

### closes_issue
If the PRD's `**Issue:**` field is set, does the body include a `Closes #N`
line so the PR auto-closes the tracking issue on merge?
- 1: missing despite PRD having an issue
- 3: present but malformed (wrong syntax)
- 5: `Closes #{N}` exactly as required

### concision
Does the body avoid filler ("This PR does X" preambles, restating the title,
hedging) per the prompt's writing style rules?
- 1: heavy preambles, hedging, repetition
- 3: some filler but readable
- 5: tight; every sentence carries weight
