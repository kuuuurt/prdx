// Deterministic checks on PRD output.
// Each check returns a boolean. Final structural score is fraction passed.

import type { Case } from "../types.ts";

export function check(output: string, _c: Case): Record<string, boolean> {
  const lower = output.toLowerCase();

  return {
    has_problem_section: /(^|\n)#+\s*problem\b/i.test(output),
    has_goal_section: /(^|\n)#+\s*goal\b/i.test(output),
    has_acceptance_criteria: /(^|\n)#+\s*acceptance criteria\b/i.test(output),
    has_project_field: /\*\*project:\*\*/i.test(output),
    ac_uses_checkboxes: /-\s*\[\s?\]/.test(output),
    ac_count_at_least_three: countAcceptanceCriteria(output) >= 3,
    no_implementation_code_blocks: !hasNonTrivialCodeBlock(output),
    has_some_structure: (output.match(/^#+\s/gm) ?? []).length >= 3,
    not_truncated: output.trim().length > 200 && !output.trim().endsWith("..."),
    not_obvious_refusal:
      !lower.includes("i can't") &&
      !lower.includes("i cannot") &&
      !lower.startsWith("sorry"),
  };
}

function countAcceptanceCriteria(output: string): number {
  const acHeader = output.match(/(^|\n)#+\s*acceptance criteria\b[^\n]*\n([\s\S]*?)(?=\n#+\s|\n*$)/i);
  if (!acHeader) return 0;
  const body = acHeader[2] ?? "";
  return (body.match(/^\s*-\s*\[\s?\]/gm) ?? []).length;
}

function hasNonTrivialCodeBlock(output: string): boolean {
  // PRDs may include short illustrative snippets; flag only large code blocks
  // (>15 lines) which suggest the prompt is producing implementation code.
  const blocks = output.match(/```[\s\S]*?```/g) ?? [];
  return blocks.some((b) => b.split("\n").length > 15);
}
