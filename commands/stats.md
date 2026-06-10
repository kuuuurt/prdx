---
description: "Show token usage and cost analytics for PRDX runs"
argument-hint: ""
---

## Pre-Computed Context

```bash
_PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
_USAGE_FILE="$_PROJECT_ROOT/.prdx/metrics/usage.jsonl"
_HAS_DATA=false
if [ -f "$_USAGE_FILE" ] && [ -s "$_USAGE_FILE" ]; then
  _HAS_DATA=true
fi
```

# /prdx:stats - Token Usage Analytics

> Reads `.prdx/metrics/usage.jsonl` and prints aggregated cost and token metrics.

---

### Step 1: Check for Data

If `_HAS_DATA` is `false`, print:

```
No runs recorded yet.
```

Then stop.

---

### Step 2: Compute and Display Aggregates

Run the following jq commands against `$_USAGE_FILE` and display the results in a readable format.

**Total runs and cost summary:**

```bash
jq -sc '
  length as $runs |
  (map(.cost_usd) | add // 0) as $total_cost |
  (if $runs > 0 then $total_cost / $runs else 0 end) as $avg_cost_run |
  (map(.phases) | add // 0) as $total_phases |
  (if $total_phases > 0 then $total_cost / $total_phases else 0 end) as $avg_cost_phase |
  {
    total_runs:     $runs,
    total_cost_usd: ($total_cost * 100 | round / 100),
    avg_cost_run:   ($avg_cost_run * 10000 | round / 10000),
    avg_cost_phase: ($avg_cost_phase * 10000 | round / 10000)
  }
' "$_USAGE_FILE"
```

**Opus vs Sonnet token split:**

```bash
jq -sc '
  map(.tokens_by_model) |
  {
    "claude-opus-4-7": (
      [.[]["claude-opus-4-7"] // empty |
       (.input + .output + .cache_creation + .cache_read)] | add // 0
    ),
    "claude-sonnet-4-6": (
      [.[]["claude-sonnet-4-6"] // empty |
       (.input + .output + .cache_creation + .cache_read)] | add // 0
    ),
    "claude-haiku-4-5": (
      [.[]["claude-haiku-4-5"] // empty |
       (.input + .output + .cache_creation + .cache_read)] | add // 0
    )
  }
' "$_USAGE_FILE"
```

**Top-5 most expensive slugs (by total cost):**

```bash
jq -sc '
  group_by(.slug) |
  map({
    slug:      (.[0].slug | if . == "" then "(unknown)" else . end),
    runs:      length,
    cost_usd:  ([.[].cost_usd] | add // 0 | (. * 10000 | round / 10000))
  }) |
  sort_by(-.cost_usd) |
  .[:5]
' "$_USAGE_FILE"
```

---

### Step 3: Format Output

Display the results in a clean, human-readable format. Example layout:

```
## PRDX Token Analytics

Runs:              12
Total cost:        $1.42
Avg cost / run:    $0.1183
Avg cost / phase:  $0.1183

Token split (all-time):
  claude-opus-4-7:    1,234,567 tokens
  claude-sonnet-4-6:  4,567,890 tokens
  claude-haiku-4-5:        1,234 tokens

Top 5 most expensive slugs:
  1. my-big-feature     (3 runs)   $0.6700
  2. auth-refactor      (2 runs)   $0.3200
  3. lint-cleanup       (1 run)    $0.1500
  4. fix-timeout        (4 runs)   $0.1200
  5. (unknown)          (2 runs)   $0.0800
```

Use the actual values from the jq output. Format costs with 4 decimal places. Format large token counts with commas.
