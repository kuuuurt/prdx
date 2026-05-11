// Deterministic checks on the GitHub issue body that /prdx:publish produces.

import type { Case } from "../types.ts";

export function check(output: string, _c: Case): Record<string, boolean> {
  return {
    has_problem_section: /(^|\n)##\s+problem\b/i.test(output),
    has_goal_section: /(^|\n)##\s+goal\b/i.test(output),
    has_acceptance_criteria: /(^|\n)##\s+acceptance criteria\b/i.test(output),
    has_approach_section: /(^|\n)##\s+approach\b/i.test(output),
    ac_uses_checkboxes: /-\s*\[\s?\]/.test(output),
    has_prdx_footer: /prd managed by prdx|managed by prdx/i.test(output),
    not_truncated: output.trim().length > 100 && !output.trim().endsWith("..."),
    no_inline_state_field: !/\*\*status:\*\*/i.test(output),
    no_inline_branch_field: !/\*\*branch:\*\*/i.test(output),
    not_obvious_refusal:
      !/(i can't|i cannot|sorry)/i.test(output.slice(0, 200)),
  };
}
