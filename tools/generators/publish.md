# Case Generator: publish

Generate test cases for the `/prdx:publish` command, which takes a local PRD
and produces a GitHub issue body.

Each case is a JSON object on a single line (JSONL):

```json
{
  "id": "publish-0001",
  "input": {
    "prdMarkdown": "Full PRD markdown that would live at .prdx/plans/prdx-{slug}.md. Include front-matter fields (Type, Project, Platform, Status, Branch, Created) AND body sections (Problem, Goal, Acceptance Criteria, Approach, optionally Risks/Open Questions). 20-50 lines.",
    "isChild": false,
    "parentIssue": null,
    "expectations": "One sentence on what a good issue body for this PRD must preserve and what it must strip."
  }
}
```

## Diversity

Across N cases vary on:

- **Platform**: backend, frontend, mobile, infra, data
- **Type**: feature, bug-fix, refactor, spike
- **Size**: small (3 AC), medium (5 AC), large (7 AC)
- **PRD shape**: with and without optional sections (Risks, Open Questions, User Stories)
- **Parent/child**: ~15% of cases should set `"isChild": true` with a `parentIssue` number; their PRDs should include a `**Parent:** {slug}` field
- **Noise**: PRDs with extra fields the issue body must NOT carry (Status, Branch, Created, Codebase Context section)
- **Adversarial (~10%)**: PRDs with malformed sections or unusual AC phrasing; verify the publish prompt still extracts the right content

## Output

Produce exactly N JSONL lines. No prose, no fences. IDs start at `publish-0001`.
