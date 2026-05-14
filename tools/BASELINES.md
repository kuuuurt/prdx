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

**Current baseline:**

| run_id | date | prompt_hash | N | backend | aggregate |
|---|---|---|---|---|---|
| `2026-05-11-d48999dde70d-7a2q` | 2026-05-11 | `d48999dde70d` | 30 | cli | **0.921** |

```
structural   0.997
graded       0.807

per axis:
  closes_issue       0.914
  title_quality      0.879
  summary_quality    0.836
  concision          0.733
  ac_coverage        0.672   ← weakness
```

**Context:** initial baseline. 1 of 30 cases had a judge JSON-parse error
(case `pr-author-0010`) — minor noise, doesn't change the picture.
`ac_coverage` is the clear weakness — judge thinks the PR body doesn't
always reproduce every AC from the PRD.

---

## `simplify` — `commands/simplify.md`

**Current baseline:**

| run_id | date | prompt_hash | N | backend | aggregate |
|---|---|---|---|---|---|
| `2026-05-11-bc10648e1d7f-jyve` | 2026-05-11 | `bc10648e1d7f` | 30 | cli | **0.962** |

```
structural   0.995
graded       0.912

per axis:
  output_format       1.000
  no_invention        0.967
  behavior_preserved  0.925
  comment_discipline  0.917
  actually_simpler    0.750   ← weakness
```

**Context:** initial baseline. The four highest axes show the prompt
reliably emits clean code without inventing new constructs and preserves
MARK/TODO comments. `actually_simpler` lagging suggests the simplifications
are often shortenings that don't read as meaningfully cleaner — likely
target if you iterate the prompt.

Rubric and structural checks are first drafts; expect to tune them before
treating this number as load-bearing.

> **Stale (2026-05-15):** `commands/simplify.md` was rewritten as a chained
> wrapper (built-in `simplify` skill → PRDX pragmatism pass). The eval now
> scores Phase 3 only — rubric/structural/generator were re-scoped to match.
> This baseline predates that change; re-run at N≥30 against the new prompt to
> establish a fresh Phase-3 baseline.

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
