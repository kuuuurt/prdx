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
