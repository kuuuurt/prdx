#!/bin/bash
# Aggregate token usage from transcripts and append a row to usage.jsonl.
# No-op if active-run.json is absent (e.g. prdx:prdx started before this feature shipped).
#
# Usage: source "$(dirname "$0")/metrics-end.sh"
#
# Reads .prdx/metrics/active-run.json, scans ~/.claude/projects/<encoded-cwd>/*.jsonl
# for files modified after started_at, aggregates usage by model, prices against
# pricing.json, appends one row to .prdx/metrics/usage.jsonl, and deletes active-run.json.

_PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
_METRICS_DIR="$_PROJECT_ROOT/.prdx/metrics"
_ACTIVE_RUN="$_METRICS_DIR/active-run.json"

# No-op if no active run marker
[ -f "$_ACTIVE_RUN" ] || return 0 2>/dev/null || exit 0

# Read active run fields
_SLUG=$(jq -r '.slug // ""' "$_ACTIVE_RUN")
_STARTED_AT=$(jq -r '.started_at' "$_ACTIVE_RUN")
_WORKING_DIR=$(jq -r '.working_dir' "$_ACTIVE_RUN")

_ENDED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Encode working dir to match Claude's projects directory naming (/ → -)
_ENCODED_CWD=$(echo "$_WORKING_DIR" | sed 's/\//-/g')
_PROJECTS_DIR="$HOME/.claude/projects/$_ENCODED_CWD"

# Create temp reference file with mtime set to started_at for find -newer windowing
_REF_FILE=$(mktemp /tmp/prdx-metrics-ref.XXXXXX)
# shellcheck disable=SC2064
trap "rm -f '$_REF_FILE'" EXIT

if [[ "$(uname)" == "Darwin" ]]; then
  # macOS: touch -t expects CCYYMMDDhhmm.ss
  _TOUCH_TS=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$_STARTED_AT" "+%Y%m%d%H%M.%S" 2>/dev/null)
  [ -n "$_TOUCH_TS" ] && touch -t "$_TOUCH_TS" "$_REF_FILE"
else
  # Linux: touch -d accepts ISO 8601 directly
  touch -d "$_STARTED_AT" "$_REF_FILE" 2>/dev/null
fi

# Collect JSONL transcript files newer than the reference (i.e. mtime >= started_at)
_JSONL_FILES=()
if [ -d "$_PROJECTS_DIR" ]; then
  while IFS= read -r -d '' f; do
    _JSONL_FILES+=("$f")
  done < <(find "$_PROJECTS_DIR" -maxdepth 1 -name "*.jsonl" -newer "$_REF_FILE" -print0 2>/dev/null)
fi

_PRICING_FILE="$_PROJECT_ROOT/hooks/prdx/pricing.json"

if [ ${#_JSONL_FILES[@]} -eq 0 ]; then
  _TOKENS_BY_MODEL="{}"
  _TOKENS_TOTAL=0
  _COST_USD="0.0"
else
  # Aggregate input/output/cache_creation/cache_read tokens grouped by model
  _TOKENS_BY_MODEL=$(jq -sc '
    [.[] | select(.type == "assistant" and .message != null and (.message.model // "") != "") |
     {model: .message.model, usage: (.message.usage // {})}] |
    group_by(.model) |
    map({
      key: .[0].model,
      value: {
        input:          ([.[].usage.input_tokens              // 0] | add),
        output:         ([.[].usage.output_tokens             // 0] | add),
        cache_creation: ([.[].usage.cache_creation_input_tokens // 0] | add),
        cache_read:     ([.[].usage.cache_read_input_tokens   // 0] | add)
      }
    }) |
    from_entries
  ' "${_JSONL_FILES[@]}")

  # Sum all token counts across all models
  _TOKENS_TOTAL=$(echo "$_TOKENS_BY_MODEL" | jq '
    [to_entries[] | .value | (.input + .output + .cache_creation + .cache_read)] | add // 0
  ')

  # Compute cost using pricing.json (rates are $/Mtok — divide by 1,000,000)
  _COST_USD=$(echo "$_TOKENS_BY_MODEL" | jq --slurpfile pricing "$_PRICING_FILE" '
    . as $usage |
    ($pricing[0]) as $p |
    [
      $usage | to_entries[] |
      .key as $model |
      .value as $t |
      ($p[$model] // {input:0, output:0, cache_creation:0, cache_read:0}) as $r |
      ($t.input          * $r.input          / 1000000) +
      ($t.output         * $r.output         / 1000000) +
      ($t.cache_creation * $r.cache_creation / 1000000) +
      ($t.cache_read     * $r.cache_read     / 1000000)
    ] | add // 0
  ')
fi

# Append usage row to usage.jsonl
jq -nc \
  --arg     slug            "$_SLUG" \
  --arg     started_at      "$_STARTED_AT" \
  --arg     ended_at        "$_ENDED_AT" \
  --argjson phases          1 \
  --argjson cost_usd        "$_COST_USD" \
  --argjson tokens_total    "$_TOKENS_TOTAL" \
  --argjson tokens_by_model "$_TOKENS_BY_MODEL" \
  '{
    slug:            $slug,
    started_at:      $started_at,
    ended_at:        $ended_at,
    phases:          $phases,
    cost_usd:        $cost_usd,
    tokens_total:    $tokens_total,
    tokens_by_model: $tokens_by_model
  }' >> "$_METRICS_DIR/usage.jsonl"

# Remove the active run marker now that the row has been written
rm -f "$_ACTIVE_RUN"
