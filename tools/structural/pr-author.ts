// Deterministic checks on the PR title + body that pr-author produces.
// In eval, we expect the agent to emit the literal text it would have passed
// to `gh pr create --title ... --body ...`.

import type { Case } from "../types.ts";

const PREFIXES = ["feat", "fix", "refactor", "chore"];

export function check(output: string, c: Case): Record<string, boolean> {
  const title = extractTitle(output);
  const body = output;

  return {
    has_title: title.length > 0,
    title_under_70_chars: title.length > 0 && title.length <= 70,
    title_has_conventional_prefix:
      title.length > 0 && PREFIXES.some((p) => new RegExp(`^${p}(\\([^)]+\\))?:\\s`, "i").test(title)),
    title_not_double_prefixed:
      !/^(feat|fix|refactor|chore)(\([^)]+\))?:\s+(add|implement|refactor|fix)\b/i.test(title),
    has_summary_section: /(^|\n)##\s+summary\b/i.test(body),
    closes_issue_if_prd_had_one: !c.input.issueNumber
      ? true
      : new RegExp(`closes\\s+#${c.input.issueNumber}\\b`, "i").test(body),
    has_acceptance_criteria_when_prd: !c.input.prdMarkdown
      ? true
      : /(^|\n)##\s+acceptance criteria\b/i.test(body),
    ac_checkboxes_marked_done: !c.input.prdMarkdown
      ? true
      : /-\s*\[x\]/i.test(body),
    not_truncated: body.trim().length > 100 && !body.trim().endsWith("..."),
    not_obvious_refusal:
      !/(i can't|i cannot|sorry)/i.test(body.slice(0, 200)),
  };
}

function extractTitle(output: string): string {
  // We instruct the prompt to emit "Title: ..." on first line, then body.
  const m = output.match(/^\s*title\s*:\s*(.+?)\s*\n/i);
  if (m) return m[1].trim();
  // Fallback: first non-empty line
  const lines = output.split("\n").map((l) => l.trim()).filter(Boolean);
  return lines[0] ?? "";
}
