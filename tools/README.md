# PRDX Prompt Evals

Manual prompt-iteration harness. Run when tuning a prompt; not part of CI and
not shipped with the plugin (Claude Code only loads `commands/`, `agents/`,
`hooks/`, `skills/`).

## Concept

Each "artifact" (PRD, dev plan, PR description, etc.) is produced by a prompt
file (`commands/*.md` or `agents/prdx/*.md`). We treat that prompt as a pure
function: system prompt + synthesized user input → output text. Each output is
scored by:

- **Structural** checks — deterministic, 0 or 1 per check
- **Graded** axes — LLM judge with a rubric, 1-5 normalized to 0-1

A run produces one aggregate score in [0, 1]. Iterate the prompt, re-run, diff
scores.

## Setup

```bash
cd tools
bun install
cp .env.example .env   # then put your key in .env
```

Bun auto-loads `.env` from the cwd; no `export` needed.

## Use

```bash
# Generate 100 test cases for plan (one-time, committed)
bun run.ts generate plan --n 100

# Run eval against current commands/plan.md
bun run.ts eval plan

# Tweak the prompt, run again
bun run.ts eval plan

# Compare two runs
bun run.ts diff <run_id_a> <run_id_b>

# List runs
bun run.ts runs plan
```

## Structure

```
tools/
  run.ts                # CLI: generate, eval, diff, runs
  artifacts.ts          # registry: prompt path, checks, rubric per artifact
  judge.ts              # judge invocation
  api.ts                # Anthropic API helper
  structural/plan.ts    # deterministic checks for plan
  rubrics/plan.md       # judge rubric for plan
  generators/plan.md    # case-generator prompt for plan
  cases/plan.jsonl      # generated test cases (committed)
  runs/                 # results (gitignored)
```

## Scoring

```
case_score   = 0.6 * structural_score + 0.4 * graded_score
run_score    = mean(case_score) over all cases
```

Per-case structural = (passed checks) / (total checks).
Per-case graded     = mean(axis_score) where axis_score = (judge_1to5 - 1) / 4.

Tunable in `artifacts.ts`.

## Adding a new artifact

1. Add entry to `ARTIFACTS` in `artifacts.ts`
2. Write `structural/<name>.ts` exporting `check(output, case) -> Record<string, boolean>`
3. Write `rubrics/<name>.md` with judge axes
4. Write `generators/<name>.md` with the case-generator prompt
5. `bun run.ts generate <name> --n 100`

## Notes

- Cases are committed so runs are comparable across prompt versions.
- Results cached by `(case_id, prompt_hash)` in `runs/.cache/` — re-running with
  an unchanged prompt is free.
- Judge runs at temp=0; sample 5% through 3x per run to monitor judge stability.
- Hand-review 5-10 cases per run to sanity-check the judge isn't being fooled.
