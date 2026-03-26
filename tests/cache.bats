#!/usr/bin/env bats
# Tests for PRDX exploration cache behavior

load helpers/test_helper

@test "code-explorer agent contains cache-write section" {
    local agent_file="$REPO_ROOT/agents/code-explorer.md"

    # Should have a Cache Write section
    run grep -q "## Cache Write" "$agent_file"
    [ "$status" -eq 0 ]
}

@test "code-explorer agent instructs writing to .prdx/cache directory" {
    local agent_file="$REPO_ROOT/agents/code-explorer.md"

    # Should reference the cache directory path pattern
    run grep -q "\.prdx/cache" "$agent_file"
    [ "$status" -eq 0 ]
}

@test "code-explorer agent instructs computing a query hash" {
    local agent_file="$REPO_ROOT/agents/code-explorer.md"

    # Should mention md5 hashing for query cache keying
    run grep -qE "md5" "$agent_file"
    [ "$status" -eq 0 ]
}

@test "code-explorer agent instructs including git SHA in cache metadata" {
    local agent_file="$REPO_ROOT/agents/code-explorer.md"

    # Should reference git SHA in cache metadata
    run grep -q "git_sha" "$agent_file"
    [ "$status" -eq 0 ]
}

@test "code-explorer agent instructs YAML frontmatter with required fields" {
    local agent_file="$REPO_ROOT/agents/code-explorer.md"

    # Should include query_hash field
    run grep -q "query_hash" "$agent_file"
    [ "$status" -eq 0 ]

    # Should include created field
    run grep -q "created" "$agent_file"
    [ "$status" -eq 0 ]

    # Should include slug field
    run grep -q "slug" "$agent_file"
    [ "$status" -eq 0 ]
}

@test "code-explorer agent instructs extracting slug from prompt" {
    local agent_file="$REPO_ROOT/agents/code-explorer.md"

    # Should instruct agent to read the Slug field from its prompt
    run grep -q "Slug:" "$agent_file"
    [ "$status" -eq 0 ]
}

@test "code-explorer agent instructs creating cache directory before writing" {
    local agent_file="$REPO_ROOT/agents/code-explorer.md"

    # Should instruct mkdir -p for directory creation
    run grep -q "mkdir" "$agent_file"
    [ "$status" -eq 0 ]
}

@test "code-explorer agent cache write comes after output section" {
    local agent_file="$REPO_ROOT/agents/code-explorer.md"

    # Both Output and Cache Write sections should exist
    run grep -q "## Output" "$agent_file"
    [ "$status" -eq 0 ]

    run grep -q "## Cache Write" "$agent_file"
    [ "$status" -eq 0 ]

    # Cache Write should appear after Output in the file
    local output_line cache_line
    output_line=$(grep -n "^## Output" "$agent_file" | head -1 | cut -d: -f1)
    cache_line=$(grep -n "^## Cache Write" "$agent_file" | head -1 | cut -d: -f1)

    [ -n "$output_line" ]
    [ -n "$cache_line" ]
    [ "$cache_line" -gt "$output_line" ]
}

# --- dev-planner cache-read tests ---

@test "dev-planner agent contains cache-read section" {
    local agent_file="$REPO_ROOT/agents/dev-planner.md"

    run grep -q "Cache Read" "$agent_file"
    [ "$status" -eq 0 ]
}

@test "dev-planner agent instructs checking .prdx/cache directory before spawning code-explorer" {
    local agent_file="$REPO_ROOT/agents/dev-planner.md"

    # Should reference the cache directory
    run grep -q "\.prdx/cache" "$agent_file"
    [ "$status" -eq 0 ]
}

@test "dev-planner agent instructs computing query hash for cache lookup" {
    local agent_file="$REPO_ROOT/agents/dev-planner.md"

    # Should mention md5 hashing (same as code-explorer)
    run grep -qE "md5" "$agent_file"
    [ "$status" -eq 0 ]
}

@test "dev-planner agent instructs validating git SHA on cache hit" {
    local agent_file="$REPO_ROOT/agents/dev-planner.md"

    # Should reference git_sha validation
    run grep -q "git_sha" "$agent_file"
    [ "$status" -eq 0 ]

    # Should reference git rev-parse HEAD for current SHA
    run grep -q "git rev-parse HEAD" "$agent_file"
    [ "$status" -eq 0 ]
}

@test "dev-planner agent instructs skipping code-explorer spawn on cache hit" {
    local agent_file="$REPO_ROOT/agents/dev-planner.md"

    # Should describe skipping or not spawning code-explorer on a cache hit
    run grep -qE "cache hit|skip.*code-explorer|skip.*spawning" "$agent_file"
    [ "$status" -eq 0 ]
}

@test "dev-planner agent instructs passing Slug in code-explorer prompt" {
    local agent_file="$REPO_ROOT/agents/dev-planner.md"

    # dev-planner must pass Slug: {slug} so code-explorer can write to correct cache path
    run grep -q "Slug:" "$agent_file"
    [ "$status" -eq 0 ]
}

@test "dev-planner agent cache-read section appears before code-explorer task call" {
    local agent_file="$REPO_ROOT/agents/dev-planner.md"

    # Cache Read section should exist before the code-explorer Task tool call
    local cache_line explorer_line
    cache_line=$(grep -n "Cache Read" "$agent_file" | head -1 | cut -d: -f1)
    explorer_line=$(grep -n "code-explorer" "$agent_file" | head -1 | cut -d: -f1)

    [ -n "$cache_line" ]
    [ -n "$explorer_line" ]
    [ "$cache_line" -lt "$explorer_line" ]
}

@test "dev-planner agent respects NO_CACHE env var to skip cache read" {
    local agent_file="$REPO_ROOT/agents/dev-planner.md"

    run grep -q "NO_CACHE" "$agent_file"
    [ "$status" -eq 0 ]
}

# --- implement command --no-cache flag tests ---

@test "implement command usage section documents --no-cache flag" {
    local cmd_file="$REPO_ROOT/commands/implement.md"

    # The Usage section should show --no-cache as an option
    run grep -q "\-\-no-cache" "$cmd_file"
    [ "$status" -eq 0 ]
}

@test "implement command --no-cache appears in usage examples" {
    local cmd_file="$REPO_ROOT/commands/implement.md"

    # Should have a usage example showing --no-cache
    run grep -qE "implement.*--no-cache|--no-cache.*implement" "$cmd_file"
    [ "$status" -eq 0 ]
}

@test "implement command parses --no-cache flag from slug argument" {
    local cmd_file="$REPO_ROOT/commands/implement.md"

    # Should describe stripping --no-cache from the slug argument
    run grep -qE "no.cache|NO_CACHE" "$cmd_file"
    [ "$status" -eq 0 ]
}

@test "implement command passes NO_CACHE to dev-planner agent prompt" {
    local cmd_file="$REPO_ROOT/commands/implement.md"

    # The dev-planner agent prompt in Step 5a should reference NO_CACHE
    run grep -q "NO_CACHE" "$cmd_file"
    [ "$status" -eq 0 ]
}

@test "implement command --no-cache flag parsing appears before Step 5a" {
    local cmd_file="$REPO_ROOT/commands/implement.md"

    # NO_CACHE parsing should appear before Step 5a (dev-planner invocation)
    local nocache_line step5a_line
    nocache_line=$(grep -n "no-cache\|NO_CACHE" "$cmd_file" | head -1 | cut -d: -f1)
    step5a_line=$(grep -n "Step 5a" "$cmd_file" | head -1 | cut -d: -f1)

    [ -n "$nocache_line" ]
    [ -n "$step5a_line" ]
    [ "$nocache_line" -lt "$step5a_line" ]
}
