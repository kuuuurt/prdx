import { call } from "./api.ts";
import type { Case, JudgeAxisScore } from "./types.ts";

const JUDGE_MODEL = "claude-haiku-4-5-20251001";

const SYSTEM = `You are a strict, calibrated grader. You will be given:
- a rubric describing axes to score, each with a 1-5 scale
- the case (what was asked and what to look for)
- the artifact produced by the prompt under test

For each axis, output a JSON object with: axis (string), score (integer 1-5), rationale (one sentence, concrete).

Output ONLY a JSON array of these objects, nothing else. No prose, no fences.

Calibration:
- 1: missing or wrong
- 2: present but weak / vague
- 3: adequate, would pass minimal review
- 4: clearly good
- 5: exemplary; nothing to improve

Be strict. Most real-world outputs are 2-3. Reserve 5 for genuinely excellent work.`;

export async function judge(
  rubric: string,
  c: Case,
  output: string,
): Promise<JudgeAxisScore[]> {
  const userMsg = [
    `# Rubric`,
    rubric,
    ``,
    `# Case`,
    `Request: ${c.input.request}`,
    c.input.expectations ? `Expectations for this case: ${c.input.expectations}` : "",
    ``,
    `# Artifact under review`,
    `\`\`\``,
    output,
    `\`\`\``,
    ``,
    `Output the JSON array now.`,
  ].filter(Boolean).join("\n");

  const raw = await call({
    model: JUDGE_MODEL,
    system: SYSTEM,
    messages: [{ role: "user", content: userMsg }],
    temperature: 0,
    maxTokens: 2048,
  });

  return parseJudgeOutput(raw);
}

function parseJudgeOutput(raw: string): JudgeAxisScore[] {
  // Tolerate a stray ```json ... ``` fence even though we asked for none.
  const stripped = raw
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "");

  const start = stripped.indexOf("[");
  const end = stripped.lastIndexOf("]");
  if (start === -1 || end === -1) {
    throw new Error(`Judge output not parseable as JSON array:\n${raw}`);
  }
  const slice = stripped.slice(start, end + 1);
  const parsed = JSON.parse(slice) as JudgeAxisScore[];

  for (const item of parsed) {
    if (typeof item.axis !== "string" || typeof item.score !== "number") {
      throw new Error(`Malformed judge axis: ${JSON.stringify(item)}`);
    }
    if (item.score < 1 || item.score > 5) {
      throw new Error(`Judge score out of range 1-5: ${JSON.stringify(item)}`);
    }
  }
  return parsed;
}
