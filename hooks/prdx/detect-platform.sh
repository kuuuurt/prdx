#!/bin/bash
# detect-platform.sh — Detect platform contexts from filesystem and emit branch-prefix conventions.
# Usage:
#   source hooks/prdx/detect-platform.sh
#   echo "$DETECTED_CONTEXTS"   # space-separated list (e.g., "backend cli")
#   echo "$BRANCH_PREFIX_FEAT"  # dominant prefix for feature branches (feat or feature)
#   echo "$BRANCH_PREFIX_FIX"   # dominant prefix for fix branches (fix, bugfix, or hotfix)
#
# Description-keyword detection stays in commands/plan.md — the model parses the user's
# description directly. This hook covers filesystem heuristics + branch-convention scanning,
# which are mechanical and benefit from being executed once.

set +e

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || return 1

CONTEXTS=()
add() { case " ${CONTEXTS[*]} " in *" $1 "*) ;; *) CONTEXTS+=("$1") ;; esac; }

# Filesystem heuristics
{ [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ] || ls *.py >/dev/null 2>&1; } && add python
[ -f "go.mod" ] && add go
[ -f "Cargo.toml" ] && add rust
[ -f "pubspec.yaml" ] && add flutter
{ [ -f "pom.xml" ] || [ -f "build.gradle" ]; } && [ ! -f "build.gradle.kts" ] && add java
{ [ -f "build.gradle.kts" ] || [ -d "android" ]; } && add android
{ [ -f "Package.swift" ] || [ -d "ios" ]; } && add ios
[ -f "react-native.config.js" ] && add react-native

if [ -f "package.json" ]; then
  if grep -qE '"(react|vue|svelte|next|@angular)"' package.json 2>/dev/null; then
    add frontend
  fi
  if grep -qE '"(express|fastify|hono|koa|@nestjs)"' package.json 2>/dev/null; then
    add backend
  fi
fi
[ -f "tsconfig.json" ] && [ ! -f "package.json" ] && add backend

{ [ -d "terraform" ] || [ -d "ansible" ] || ls *.tf >/dev/null 2>&1; } && add infra
{ [ -d "backend" ] || [ -d "server" ] || [ -d "api" ]; } && add backend
{ [ -d "frontend" ] || [ -d "web" ] || [ -d "client" ]; } && add frontend

if [ "${#CONTEXTS[@]}" -eq 0 ]; then
  [ -f "Dockerfile" ] && add infra
  [ -f "Makefile" ] && add cli
fi

export DETECTED_CONTEXTS="${CONTEXTS[*]}"

# Branch convention detection — dominant prefix wins (>=2 hits, >50% share)
BRANCHES="$(git branch -a --format='%(refname:short)' 2>/dev/null | head -50)"
count() { echo "$BRANCHES" | grep -cE "^(origin/)?$1" || true; }

FEAT_FULL=$(count 'feature/'); FEAT_SHORT=$(count 'feat/')
FIX=$(count 'fix/'); BUGFIX=$(count 'bugfix/'); HOTFIX=$(count 'hotfix/')

if [ "$FEAT_FULL" -ge 2 ] && [ "$FEAT_FULL" -gt "$FEAT_SHORT" ]; then
  export BRANCH_PREFIX_FEAT="feature"
else
  export BRANCH_PREFIX_FEAT="feat"
fi

if [ "$BUGFIX" -ge 2 ] && [ "$BUGFIX" -gt "$FIX" ] && [ "$BUGFIX" -gt "$HOTFIX" ]; then
  export BRANCH_PREFIX_FIX="bugfix"
elif [ "$HOTFIX" -ge 2 ] && [ "$HOTFIX" -gt "$FIX" ]; then
  export BRANCH_PREFIX_FIX="hotfix"
else
  export BRANCH_PREFIX_FIX="fix"
fi
