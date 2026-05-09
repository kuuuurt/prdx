// Registry of artifacts under test. Add a new entry here to support a new
// prompt (e.g. dev-planner, pr-author, ac-verifier).

import { check as checkPlan } from "./structural/plan.ts";
import type { Case, StructuralCheck } from "./types.ts";

export interface Artifact {
  name: string;
  // Path (relative to repo root) of the prompt file under test.
  promptPath: string;
  // Path of the rubric used by the judge.
  rubricPath: string;
  // Path of the case-generator prompt.
  generatorPath: string;
  // Build the user message sent to the prompt-under-test from a case.
  buildUserMessage: (c: Case) => string;
  // Deterministic checks on the artifact's output.
  structural: StructuralCheck;
  // Weighting between structural and graded scores.
  structuralWeight: number;
  // Model used to invoke the prompt under test.
  model: string;
  // Max tokens for the prompt-under-test response.
  maxTokens: number;
}

export const ARTIFACTS: Record<string, Artifact> = {
  plan: {
    name: "plan",
    promptPath: "commands/plan.md",
    rubricPath: "tools/rubrics/plan.md",
    generatorPath: "tools/generators/plan.md",
    buildUserMessage: (c) => {
      // Plan mode normally explores the repo via tools. For eval we synthesize
      // the codebase context as text so the prompt becomes a pure function.
      return [
        `# Feature request`,
        c.input.request,
        ``,
        `# Repo context (synthesized — pretend you've already explored)`,
        `**Project name:** ${c.input.projectName}`,
        `**Stack:** ${c.input.stack}`,
        `**Relevant files / patterns:**`,
        c.input.codebaseSummary,
        ``,
        `# Instructions`,
        `Skip the exploration steps in your system prompt. Produce ONLY the final PRD markdown — no preamble, no tool calls, no plan-mode framing. Output the PRD body that would be saved to .prdx/plans/prdx-{slug}.md.`,
      ].join("\n");
    },
    structural: checkPlan,
    structuralWeight: 0.6,
    model: "claude-sonnet-4-6",
    maxTokens: 4096,
  },
};

export function getArtifact(name: string): Artifact {
  const a = ARTIFACTS[name];
  if (!a) throw new Error(`Unknown artifact "${name}". Known: ${Object.keys(ARTIFACTS).join(", ")}`);
  return a;
}
