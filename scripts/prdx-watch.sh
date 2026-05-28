#!/usr/bin/env bash
# prdx-watch — start the 4 PRDX watcher loops in a tmux session.
#
# Each loop runs in its own pane as an interactive `claude` session,
# so usage draws from your Claude subscription rather than the
# Agent SDK programmatic credit pool.
#
# Usage:
#   prdx-watch.sh [project-dir]
#
# Defaults:
#   project-dir = current working directory
#   session name = "prdx-<basename of project-dir>"
#
# Re-running with the same project-dir attaches to the existing session
# instead of creating a new one.

set -euo pipefail

PROJECT_DIR="${1:-$PWD}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
SESSION="prdx-${PROJECT_NAME}"

if ! command -v tmux >/dev/null 2>&1; then
  echo "prdx-watch: tmux is required but not found on PATH" >&2
  exit 1
fi
if ! command -v claude >/dev/null 2>&1; then
  echo "prdx-watch: claude CLI is required but not found on PATH" >&2
  exit 1
fi
if [ ! -d "$PROJECT_DIR/.git" ]; then
  echo "prdx-watch: $PROJECT_DIR is not a git repository" >&2
  exit 1
fi

if [ ! -f "$PROJECT_DIR/.prdx/plans-setup-done" ]; then
  echo "prdx-watch: PRDX is not initialized in $PROJECT_DIR" >&2
  echo "  Run \`/prdx:plan\` interactively once in this repo to complete first-run setup," >&2
  echo "  then re-run this script." >&2
  exit 1
fi

if ! (cd "$PROJECT_DIR" && gh auth status >/dev/null 2>&1); then
  echo "prdx-watch: \`gh auth status\` failed in $PROJECT_DIR" >&2
  echo "  Run \`gh auth login\` first." >&2
  exit 1
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "prdx-watch: session '$SESSION' already exists. Attaching."
  exec tmux attach -t "$SESSION"
fi

# Per-pane model + effort — sized to the work each loop does.
#   issues/approvals: lightweight polling, no codebase reasoning  → haiku, low
#   prd:              planning, codebase exploration, PRD drafting → opus, high
#   implement:        code changes guided by an already-written PRD → opus, medium
ISSUES_MODEL="haiku";    ISSUES_EFFORT="low"
PRD_MODEL="opus";        PRD_EFFORT="high"
APPROVALS_MODEL="haiku"; APPROVALS_EFFORT="low"
IMPLEMENT_MODEL="opus";  IMPLEMENT_EFFORT="medium"

# Each pane runs `claude` with a /loop slash command as the initial prompt.
# Adjust intervals here if you want a different polling cadence.
ISSUES_CMD='/loop 5m /prdx:watch-issues'
PRD_CMD='/loop 2m /prdx:watch-prd'
APPROVALS_CMD='/loop 1m /prdx:watch-approvals'
IMPLEMENT_CMD='/loop 2m /prdx:watch-implement'

# pane_cmd <model> <effort> <claude-prompt>
# Builds a shell command that cd's into the project and starts claude with the prompt.
pane_cmd() {
  printf 'cd %q && claude --model %q --effort %q %q' "$PROJECT_DIR" "$1" "$2" "$3"
}

# Create the session with the first pane (issues).
tmux new-session -d -s "$SESSION" -n "watchers" -c "$PROJECT_DIR" \
  "$(pane_cmd "$ISSUES_MODEL" "$ISSUES_EFFORT" "$ISSUES_CMD")"

# Split into 4 panes in a 2x2 grid.
tmux split-window -h -t "$SESSION:watchers" -c "$PROJECT_DIR" \
  "$(pane_cmd "$PRD_MODEL" "$PRD_EFFORT" "$PRD_CMD")"
tmux split-window -v -t "$SESSION:watchers.0" -c "$PROJECT_DIR" \
  "$(pane_cmd "$APPROVALS_MODEL" "$APPROVALS_EFFORT" "$APPROVALS_CMD")"
tmux split-window -v -t "$SESSION:watchers.1" -c "$PROJECT_DIR" \
  "$(pane_cmd "$IMPLEMENT_MODEL" "$IMPLEMENT_EFFORT" "$IMPLEMENT_CMD")"

tmux select-layout -t "$SESSION:watchers" tiled

# Label each pane for clarity (requires tmux >= 3.0).
tmux select-pane -t "$SESSION:watchers.0" -T "issues  (5m, $ISSUES_MODEL/$ISSUES_EFFORT)"
tmux select-pane -t "$SESSION:watchers.1" -T "prd     (2m, $PRD_MODEL/$PRD_EFFORT)"
tmux select-pane -t "$SESSION:watchers.2" -T "approve (1m, $APPROVALS_MODEL/$APPROVALS_EFFORT)"
tmux select-pane -t "$SESSION:watchers.3" -T "implem  (2m, $IMPLEMENT_MODEL/$IMPLEMENT_EFFORT)"
tmux set -t "$SESSION" pane-border-status top

echo "prdx-watch: started session '$SESSION' for $PROJECT_DIR"
echo "Attach with:  tmux attach -t $SESSION"
echo "Kill with:    tmux kill-session -t $SESSION"

if [ -t 1 ]; then
  exec tmux attach -t "$SESSION"
fi
