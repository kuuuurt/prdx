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
cp .env.example .env       # only needed if you want the api backend
```

Bun auto-loads `.env`; no `export` needed.

## Use

```bash
# Generate test cases (one-time per artifact, committed to git)
bun run.ts generate plan --n 30

# Run eval against current commands/plan.md
bun run.ts eval plan

# Tweak the prompt, run again
bun run.ts eval plan

# Compare two runs (prefix-match on run id is fine)
bun run.ts diff <run_id_a> <run_id_b>

# List runs
bun run.ts runs plan
```

## Backends

Two ways to call Claude. Switch with `PRDX_EVAL_BACKEND=cli|api` (default `cli`).

| backend | auth | cost | speed | when to use |
|---|---|---|---|---|
| `cli` | OAuth (your Claude Code subscription) | $0 marginal, counts against plan quota | ~5–10s/call, concurrency 3 | iteration, "free" stress testing |
| `api` | `ANTHROPIC_API_KEY` from `.env` | per-call billing | ~1–2s/call, concurrency 8 | when you want speed or are out of quota |

The CLI backend strips `ANTHROPIC_API_KEY` from the subprocess env so a stale
or wrong key in `.env` doesn't override OAuth.

## How a run works

```
1. Load prompt-under-test (e.g. commands/plan.md), strip frontmatter
2. Hash the prompt → prompt_hash (12 chars)
3. Load cases/<artifact>.jsonl
4. For each case (concurrency-limited):
     a. Send system=prompt, user=buildUserMessage(case) to chosen backend
     b. Strip any outer ```markdown fence the model wraps in
     c. Run structural check → fraction of checks passed
     d. Send (rubric, case, output) to judge (Haiku, temp=0) → 1-5 per axis
     e. case_score = 0.6 * structural + 0.4 * graded
     f. Cache result by (artifact, case_id, prompt_hash, case_content_hash)
5. Aggregate: mean over all cases. Save runs/<run_id>.json.
```

## Structure

```
tools/
  run.ts                # CLI: generate | eval | diff | runs
  api.ts                # backend dispatch + fetch implementation
  claude-cli.ts         # CLI backend (shells out to `claude -p`)
  judge.ts              # Haiku judge with strict JSON parse
  artifacts.ts          # registry: per-artifact config (prompt path, checks, rubric, weights)
  types.ts              # Case, CaseResult, RunResult
  structural/<name>.ts  # deterministic checks per artifact
  rubrics/<name>.md     # judge rubric per artifact
  generators/<name>.md  # case-generator prompt per artifact
  cases/<name>.jsonl    # generated cases (committed)
  runs/                 # results (gitignored)
  runs/.cache/          # per-case cached results (gitignored)
```

## Scoring

```
case_score = structural_weight * structural + (1 - structural_weight) * graded
run_score  = mean(case_score) over all non-error cases
```

Per-axis graded score: `(judge_1to5 - 1) / 4`. So 1★→0.0, 3★→0.5, 5★→1.0.

`structural_weight` is per-artifact in `artifacts.ts` (default 0.6).

## Working on the tool

### Add a new artifact (e.g. `dev-planner`)

1. Add an entry to `ARTIFACTS` in `artifacts.ts` with `promptPath`,
   `rubricPath`, `generatorPath`, `buildUserMessage`, `structural`, `model`,
   `maxTokens`, and `structuralWeight`.
2. Create `structural/dev-planner.ts` exporting
   `check(output, case) -> Record<string, boolean>`. Each entry is one
   yes/no check.
3. Create `rubrics/dev-planner.md` listing the axes the judge should score
   (1–5 with calibration). Be strict; prefer 4 axes over 8.
4. Create `generators/dev-planner.md` describing what realistic test cases
   look like. Vary along axes that matter for the artifact.
5. `bun run.ts generate dev-planner --n 30` and inspect a few cases by hand.

### Tweak structural checks

Add or modify entries in `structural/<name>.ts`. Each returned boolean is one
check; the structural score is `passed / total`. Aim for checks that are:

- Cheap (regex, length, presence/absence of headers)
- Specific (avoid "looks reasonable" — that's the judge's job)
- Stable across reasonable prompt variations

### Tweak the rubric

Edit `rubrics/<name>.md`. Each axis section is sent verbatim to the judge.
Calibrate explicitly ("3 = adequate; reserve 5 for exemplary work") so the
judge doesn't drift toward 4-by-default.

### Tweak the case generator

Edit `generators/<name>.md`. The prompt should specify the JSON schema of a
case and the diversity dimensions (platform, scope, request style, adversarial
cases). Cases are generated with `temperature: 0.8` for variety.

### Tunable knobs

| where | knob | effect |
|---|---|---|
| `run.ts` | `CONCURRENCY` | parallelism per backend (cli=3, api=8) |
| `artifacts.ts` | `structuralWeight` | structural vs graded weighting per artifact |
| `artifacts.ts` | `model` | model used to invoke the prompt-under-test |
| `judge.ts` | `JUDGE_MODEL` | model used by the judge (default Haiku 4.5) |

## Gotchas

- **Outer markdown fence**: when invoked as a pure function, models sometimes
  wrap the whole PRD in ` ```markdown ... ``` `. The runner strips this before
  scoring — don't add structural checks that depend on it being present.
- **Cache key includes case content hash** — regenerating cases with new
  content under existing IDs (e.g. `plan-0001`) won't hit stale cached results.
- **Judge variance**: at N=10 expect ±0.1 swing per axis between identical
  runs. At N=30 it's roughly ±0.05. For a real comparison either run N≥30 or
  treat sub-0.05 deltas as noise.
- **Structural failure on every case** = check is broken or invocation has a
  systematic bug, not the prompt.

## Token-cost measurement (planned)

The harness currently scores prompt *output quality* but not *token cost*. This
gap matters now that some commands fan out sub-agents — `/prdx:simplify` chains
the built-in `simplify` skill (3 parallel review agents) before its own
pragmatism pass, costing roughly 5–6× a single-context command.

We need a measuring tool that approximates per-command token usage so we can
watch for regressions as commands grow. Rough shape:

- Capture `usage` (input/output/cache tokens) from each backend call — the API
  backend returns it directly; the CLI backend can emit it via `claude -p
  --output-format json`.
- Aggregate per artifact per run; record alongside the quality aggregate in
  `runs/<run_id>.json` and surface it in `runs` / `diff`.
- For commands that spawn sub-agents (simplify), the pure-function eval can't
  see the fan-out — note that the measured number is a *lower bound* and the
  real cost is dominated by the sub-agent calls.

Until this exists, treat sub-agent-spawning commands as "monitor cost manually."

## Recommended sample sizes

- **Iteration**: N=30. ~4 min per run on cli backend, enough to see a 0.05+
  delta as signal.
- **Milestone validation**: N=100, once per meaningful prompt change.

## Conventions

- Cases are committed so runs are comparable across prompt versions.
- Run JSON files are gitignored — they're per-developer.
- Hand-review 5–10 cases per run to sanity-check the judge isn't being fooled.
