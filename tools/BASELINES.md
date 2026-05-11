# Eval Baselines

Reference scores from the most recent eval run on each artifact. Use these to
judge whether a prompt edit is a real improvement or noise — a new run's
aggregate should beat the most recent baseline by more than the noise floor
(roughly **±0.05 at N=30**, **±0.10 at N=10**) to count as a real win.

When you establish a new baseline (after a confirmed improvement), prepend a
new entry to the artifact's table — do not edit historical entries.

## How to read these

- **aggregate** = `0.6 × structural + 0.4 × graded` (per `artifacts.ts`)
- **structural** = fraction of deterministic checks that passed
- **graded** = mean of judge axis scores, normalized to 0–1 (1.0 ≈ 5★, 0.5 ≈ 3★)
- **per-axis** = same normalization, per rubric axis
- **prompt_hash** = first 12 chars of sha256 of the prompt body, post-frontmatter

To reproduce a baseline:
```bash
cd tools && bun run.ts eval <artifact>
```
…with the prompt file at the recorded `prompt_hash` (check `git log` for the
commit that introduced it).

---

## `plan` — `commands/plan.md`

**Current baseline:**

| run_id | date | prompt_hash | N | backend | aggregate |
|---|---|---|---|---|---|
| `2026-05-10-bd0487e1ab3c-bboi` | 2026-05-10 | `bd0487e1ab3c` | 30 | cli | **0.933** |

```
structural   0.983
graded       0.857

per axis:
  codebase_grounded    0.983
  scope_bounded        0.908
  goal_clarity         0.833
  problem_specificity  0.842
  ac_testability       0.800
  actionability        0.775
```

**Context:** baseline after the AC-testability + Open-Questions edit
(commit `b62cd86`). Targeted axes (`ac_testability`, `actionability`) each
moved +0.092 from the prior baseline.

### History

| run_id | date | prompt_hash | N | aggregate | note |
|---|---|---|---|---|---|
| `2026-05-09-e0bf106f4230-0mc9` | 2026-05-09 | `e0bf106f4230` | 30 | 0.923 | initial baseline (pre-edit) |

---

## `publish` — `commands/publish.md`

**Current baseline (preliminary — N=10):**

| run_id | date | prompt_hash | N | backend | aggregate |
|---|---|---|---|---|---|
| `2026-05-11-102fc3c963b4-4hia` | 2026-05-11 | `102fc3c963b4` | 10 | cli | **0.964** |

```
structural   1.000
graded       0.910

per axis:
  github_ready                1.000
  strip_noise                 1.000
  ac_preserved_as_checkboxes  0.950
  title_quality               0.900
  faithful_to_prd             0.700   ← weakness
```

**Context:** first end-to-end sanity run. Promote to a proper baseline by
re-running at N=30 once the scaffold is settled.

---

## `pr-author` — `agents/pr-author.md`

**No baseline yet.** Run:

```bash
cd tools
bun run.ts generate pr-author --n 30
bun run.ts eval pr-author
```

Then add the entry here.

---

## `simplify` — `commands/simplify.md`

**No baseline yet.** Run:

```bash
cd tools
bun run.ts generate simplify --n 30
bun run.ts eval simplify
```

Then add the entry here.

The rubric and structural checks for `simplify` are first drafts — expect to
tune them before treating the first run as a real baseline.

---

## Promoting a sanity run to a baseline

A run becomes a baseline when:

1. It's at **N ≥ 30** (lower N is too noisy to anchor future comparisons).
2. The case file is committed to git.
3. The prompt hash corresponds to a committed prompt (not a working-copy edit).
4. No structural check is universally failing (would indicate a broken check,
   not a real prompt result).

Prepend the new row to the artifact's "Current baseline" table and move the
previous row to "History".
