# Case Generator: pr-author

Generate test cases for the `prdx:pr-author` agent in PRD mode. The agent
reads a completed PRD, inspects implementation context, and produces a PR
title + body.

Each case is a JSON object on a single line (JSONL):

```json
{
  "id": "pr-author-0001",
  "input": {
    "prdMarkdown": "Full PRD markdown after implementation — Status should be 'implemented' or 'review'. Include Problem, Goal, Acceptance Criteria, Approach. Include **Issue:** field for ~70% of cases (with a realistic issue number) and omit for the rest.",
    "issueNumber": 42,
    "branchName": "feat/example-slug",
    "commitSummaries": "3-8 commit subject lines that would show up in `git log`, e.g. 'feat(auth): add token refresh endpoint', 'test(auth): cover expired-token path'. Realistic and aligned with the PRD's scope.",
    "diffSummary": "2-5 lines describing what files changed and at what scale. e.g. 'internal/auth/token.go +120 -8; internal/auth/token_test.go +88 -0; cmd/server/main.go +6 -2'",
    "expectations": "One sentence on what a good PR title + body for this case must include or avoid."
  }
}
```

When `issueNumber` is null, omit the `**Issue:**` field from the PRD body so
the agent knows there's no issue to close.

## Diversity

- **PRD type**: feature (50%), bug-fix (25%), refactor (20%), spike (5%)
- **Platform**: backend, frontend, mobile, infra, data
- **AC count**: 3-7
- **Issue presence**: ~70% have `issueNumber`, ~30% don't (test standalone-like behavior even in PRD mode)
- **Title-deduplication traps (~20% of cases)**: PRD titles starting with the type word ("Refactor: read monthly report"), so the agent must strip the redundant word to avoid producing "refactor: Refactor …"
- **Adversarial (~10%)**: very long PRD titles, unusual AC phrasing, or implementations that drifted slightly from PRD (the PR body should still describe the value, not just what was built)

## Output

Produce exactly N JSONL lines. No prose, no fences. IDs start at `pr-author-0001`.
