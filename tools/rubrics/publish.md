# GitHub Issue Body Rubric (for /prdx:publish)

Score each axis 1-5. Be strict; 3 = adequate, 5 = exemplary.

The artifact under review is the **issue body** that `/prdx:publish` would
send to `gh issue create`. The command's job is to *transform a PRD* into a
clean GitHub-ready issue. The bar is faithfulness + readability, not
creativity.

## Axes

### faithful_to_prd
Does the issue body accurately reflect what the PRD says — Problem, Goal,
AC list, Approach?
- 1: drops or distorts key content from the PRD
- 3: covers everything but loses nuance
- 5: every AC and key claim preserved exactly; nothing invented

### strip_noise
Did it strip PRD-only metadata (Status, Branch, Created, Type, Codebase
Context section, etc.) that doesn't belong on a public GitHub issue?
- 1: dumps the whole PRD verbatim including state fields
- 3: removes some but leaks status/branch/created
- 5: clean — only Problem, Goal, AC, Approach, and the PRDX footer remain

### ac_preserved_as_checkboxes
Are acceptance criteria rendered as `- [ ]` GitHub checkboxes (so the issue
becomes a live checklist) and in the same order as the PRD?
- 1: AC missing, reordered, or as plain bullets
- 3: present and as checkboxes but order/wording drifts
- 5: identical to PRD, all as `- [ ]`

### title_quality
Is the issue title concise, descriptive, and free of redundant prefixes
("Implement…", "Add support for…")? Should read like a feature name, not a
sentence.
- 1: vague, redundant, or restates the type
- 3: acceptable but verbose
- 5: short, specific, scannable

### github_ready
Does the output render correctly on GitHub — valid markdown, no stray
template placeholders like `[From PRD]` or `{ISSUE_NUMBER}`?
- 1: contains unresolved placeholders or broken markdown
- 3: renders but has minor cosmetic issues
- 5: looks polished as-is
