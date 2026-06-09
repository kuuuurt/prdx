#!/usr/bin/env bash
# Sharded state directory helper for context-efficient agent handoff.
#
# Layout under .prdx/state/{slug}/:
#   INDEX.md              - one-line manifest of all shards
#   prd/                  - sharded PRD (problem, acceptance, approach)
#   dev-plan/             - sharded dev plan (architecture, files, phases/)
#   phases/               - developer agent outputs per phase
#   reviews/              - ac verdict, code review, fix attempts
#   final/                - rolled-up implementation summary
#
# Usage (source this file, then call functions):
#   source "$(git rev-parse --show-toplevel)/hooks/prdx/state-shard.sh"
#   shard_init my-slug
#   shard_write my-slug prd/acceptance.md "ACs only" <<< "$content"
#   shard_index_append my-slug prd/acceptance.md "Acceptance criteria"
#   shard_path my-slug                         # prints absolute dir path
#   shard_cleanup my-slug                      # rm -rf the dir

_shard_root() {
  local slug="$1"
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
  [ -z "$repo_root" ] && return 1
  echo "$repo_root/.prdx/state/$slug"
}

shard_path() {
  _shard_root "$1"
}

shard_init() {
  local slug="$1"
  [ -z "$slug" ] && { echo "shard_init: slug required" >&2; return 1; }
  local dir
  dir="$(_shard_root "$slug")" || return 1
  mkdir -p "$dir/prd" "$dir/dev-plan/phases" "$dir/phases" "$dir/reviews/fixes" "$dir/final"
  if [ ! -f "$dir/INDEX.md" ]; then
    cat > "$dir/INDEX.md" <<EOF
# $slug — state index

> One-line entries only. Agents read this first, then load only the shards they need.

## Inputs

## Outputs

## Status

- Phase: planning
EOF
  fi
}

shard_write() {
  # shard_write {slug} {relative_path} {one_line_desc}
  # Content is read from stdin.
  local slug="$1" rel="$2" desc="$3"
  [ -z "$slug" ] || [ -z "$rel" ] && { echo "shard_write: slug and path required" >&2; return 1; }
  local dir
  dir="$(_shard_root "$slug")" || return 1
  local full="$dir/$rel"
  mkdir -p "$(dirname "$full")"
  cat > "$full"
  [ -n "$desc" ] && shard_index_append "$slug" "$rel" "$desc"
}

shard_index_append() {
  # shard_index_append {slug} {relative_path} {one_line_desc}
  # Appends to Outputs section if path is under outputs (phases/, reviews/, final/, dev-plan/),
  # otherwise to Inputs (prd/). Idempotent: skips if path already listed.
  local slug="$1" rel="$2" desc="$3"
  local dir
  dir="$(_shard_root "$slug")" || return 1
  local index="$dir/INDEX.md"
  [ ! -f "$index" ] && shard_init "$slug"

  if grep -qF "- $rel —" "$index" 2>/dev/null; then
    return 0
  fi

  local section="Outputs"
  case "$rel" in
    prd/*) section="Inputs" ;;
    dev-plan/*) section="Inputs" ;;
  esac

  local tmp
  tmp="$(mktemp)"
  awk -v section="$section" -v line="- $rel — $desc" '
    BEGIN { inserted = 0 }
    /^## / && in_section { print line; in_section = 0 }
    { print }
    $0 == "## " section { in_section = 1 }
    END { if (in_section) print line }
  ' "$index" > "$tmp"
  mv "$tmp" "$index"
}

shard_set_status() {
  # shard_set_status {slug} {key} {value}
  # Replaces or appends a "- Key: value" line under ## Status.
  local slug="$1" key="$2" value="$3"
  local dir
  dir="$(_shard_root "$slug")" || return 1
  local index="$dir/INDEX.md"
  [ ! -f "$index" ] && shard_init "$slug"

  local tmp
  tmp="$(mktemp)"
  awk -v key="$key" -v val="$value" '
    BEGIN { in_status = 0; replaced = 0 }
    /^## Status/ { in_status = 1; print; next }
    /^## / && in_status { if (!replaced) print "- " key ": " val; in_status = 0; replaced = 1 }
    in_status && $0 ~ "^- " key ":" { print "- " key ": " val; replaced = 1; next }
    { print }
    END { if (in_status && !replaced) print "- " key ": " val }
  ' "$index" > "$tmp"
  mv "$tmp" "$index"
}

shard_cleanup() {
  local slug="$1"
  [ -z "$slug" ] && return 1
  local dir
  dir="$(_shard_root "$slug")" || return 1
  [ -d "$dir" ] && rm -rf "$dir"
}
