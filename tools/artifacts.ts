// Registry of artifacts under test. Add a new entry here to support a new
// prompt (e.g. dev-planner, pr-author, ac-verifier).

import { check as checkPlan } from "./structural/plan.ts";
import { check as checkPublish } from "./structural/publish.ts";
import { check as checkPrAuthor } from "./structural/pr-author.ts";
import { check as checkSimplify } from "./structural/simplify.ts";
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
        `Skip the exploration steps in your system prompt. Produce ONLY the final PRD body — exactly the markdown that would be saved to .prdx/plans/prdx-{slug}.md.`,
        `Output the raw markdown directly. Do NOT wrap your entire response in a triple-backtick fence. Do NOT add any preamble, summary, or trailing commentary. The first character of your response should be the first character of the PRD.`,
      ].join("\n");
    },
    structural: checkPlan,
    structuralWeight: 0.6,
    model: "claude-sonnet-4-6",
    maxTokens: 4096,
  },

  publish: {
    name: "publish",
    promptPath: "commands/publish.md",
    rubricPath: "tools/rubrics/publish.md",
    generatorPath: "tools/generators/publish.md",
    buildUserMessage: (c) => {
      // Publish normally inspects state files and shells out to `gh`. For eval
      // we hand it the PRD as text and ask for the issue body it would post.
      const parentLine = c.input.isChild && c.input.parentIssue
        ? `Parent issue: #${c.input.parentIssue}`
        : `Not a child PRD.`;
      return [
        `# PRD to publish`,
        ``,
        c.input.prdMarkdown,
        ``,
        `# Context`,
        parentLine,
        ``,
        `# Instructions`,
        `Skip the gh CLI steps, label lookups, and user confirmation. Produce ONLY the issue title and body you would pass to \`gh issue create\`.`,
        `Output format — exactly:`,
        `Title: <issue title>`,
        `Body:`,
        `<issue body markdown>`,
        ``,
        `Do NOT wrap the body in a triple-backtick fence. Do NOT add preamble or trailing commentary.`,
      ].join("\n");
    },
    structural: checkPublish,
    structuralWeight: 0.6,
    model: "claude-sonnet-4-6",
    maxTokens: 3072,
  },

  "pr-author": {
    name: "pr-author",
    promptPath: "agents/pr-author.md",
    rubricPath: "tools/rubrics/pr-author.md",
    generatorPath: "tools/generators/pr-author.md",
    buildUserMessage: (c) => {
      // pr-author normally inspects git state and calls `gh pr create`. For
      // eval we hand it the PRD, branch name, commits, and diff summary, and
      // ask for the title + body it would pass to gh.
      return [
        `# Mode: PRD mode`,
        ``,
        `# PRD (post-implementation)`,
        c.input.prdMarkdown,
        ``,
        `# Branch`,
        c.input.branchName,
        ``,
        `# Commit summaries (git log subjects)`,
        c.input.commitSummaries,
        ``,
        `# Diff summary`,
        c.input.diffSummary,
        ``,
        `# Instructions`,
        `Skip the gh CLI invocation and PRD-update step. Produce ONLY the PR title and body you would pass to \`gh pr create\`.`,
        `Output format — exactly:`,
        `Title: <pr title>`,
        `Body:`,
        `<pr body markdown>`,
        ``,
        `Do NOT wrap the body in a triple-backtick fence. Do NOT add preamble or trailing commentary.`,
      ].join("\n");
    },
    structural: checkPrAuthor,
    structuralWeight: 0.6,
    model: "claude-sonnet-4-6",
    maxTokens: 3072,
  },

  simplify: {
    name: "simplify",
    promptPath: "commands/simplify.md",
    rubricPath: "tools/rubrics/simplify.md",
    generatorPath: "tools/generators/simplify.md",
    buildUserMessage: (c) => {
      // Simplify normally reads files and applies Edits. For eval we hand it
      // one file's contents and ask for the simplified version emitted inline.
      return [
        `# File to simplify`,
        ``,
        `**Path:** ${c.input.filePath}`,
        `**Language:** ${c.input.language}`,
        ``,
        `Source:`,
        "```" + (c.input.language ?? ""),
        c.input.code,
        "```",
        ``,
        `# Instructions`,
        `Apply your simplification rules to this file. Skip the target-file selection, user confirmation, and Edit-tool mechanics.`,
        `Produce ONLY the full simplified file contents, inside a single fenced code block tagged with the language. Do NOT add preamble, summary, or commentary outside the fence.`,
        `If the file is already simple and no changes are warranted, return it unchanged inside the same fence.`,
      ].join("\n");
    },
    structural: checkSimplify,
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
