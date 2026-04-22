---
description: "Strip extended descriptions and co-author trailers from recent commits"
argument-hint: "[range]"
---

# /prdx:sanitize

Rewrite recent commits to subject-line only. Drop extended description, `Co-Authored-By:`, `🤖 Generated with [Claude Code]`, other trailers.

Manual. Always confirm before rewrite.

## Usage

```bash
/prdx:sanitize              # unpushed commits
/prdx:sanitize HEAD~3       # last 3
/prdx:sanitize main..HEAD   # explicit range
```

## Workflow

### 1. Resolve range

No arg → unpushed commits:

```bash
UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
if [ -n "$UPSTREAM" ]; then
  BASE=$(git merge-base HEAD "$UPSTREAM")
else
  BASE=$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master)
fi
RANGE="${BASE}..HEAD"
```

`HEAD~N` → `HEAD~N..HEAD`. `a..b` → as-is.

### 2. Preview

```bash
git log --format='%h %s%n%b%n---' "$RANGE"
```

Show commits + what drops per commit. Ask `Proceed? (y/n)`.

Commit reachable from `@{u}` → warn: already pushed, rewrite needs force-push. Bail on no.

### 3. Rewrite

```bash
git rebase "$BASE" --exec 'git commit --amend --no-edit -m "$(git log -1 --pretty=%s)"'
```

Range from root commit → use `--root`.

### 4. Result

Print sanitized count + `git log --oneline $BASE..HEAD`.

Pushed commits → remind: `git push --force-with-lease`. Never auto-push.

## Safety

- Refuse on `main`/`master`
- Refuse on dirty tree (`git status --porcelain` non-empty) — user stash first
- Never auto-force-push
- Rebase fails → surface error, user resolves or `git rebase --abort`

## Drops

Everything past subject: body, `🤖 Generated...`, `Co-Authored-By:`, `Signed-off-by:`, `Refs:`, all trailers. Subject preserved verbatim.
