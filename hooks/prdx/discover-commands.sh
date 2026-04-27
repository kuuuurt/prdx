#!/bin/bash
# Discover project commands (test, typecheck, lint) across runtimes.
# Source this file, then call the discover_* functions.
# Each function echoes a command string or empty if not detected.

discover_test_cmd() {
    if [ -f "Makefile" ] && grep -q "^test:" Makefile 2>/dev/null; then
        echo "make test"
    elif [ -f "bun.lockb" ] || [ -f "bunfig.toml" ]; then
        echo "bun test"
    elif [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
        echo "npm test"
    elif [ -f "build.gradle.kts" ] || [ -f "build.gradle" ]; then
        echo "./gradlew test"
    elif [ -f "Cargo.toml" ]; then
        echo "cargo test"
    elif [ -f "go.mod" ]; then
        echo "go test ./..."
    elif [ -f "Package.swift" ] || ls *.xcodeproj 1>/dev/null 2>&1; then
        if [ -f "Package.swift" ]; then
            echo "swift test"
        else
            local xcodeproj scheme sim_name sim_dest
            xcodeproj=$(ls -d *.xcodeproj 2>/dev/null | head -1)
            scheme=$(xcodebuild -list -project "$xcodeproj" 2>/dev/null | awk '/Schemes:/{found=1; next} found && /^$/{exit} found{gsub(/^[[:space:]]+/,""); print; exit}')
            if [ -n "$scheme" ]; then
                sim_name=$(xcrun simctl list devices available 2>/dev/null | grep -E "iPhone [0-9]" | tail -1 | sed 's/^[[:space:]]*//' | sed 's/ (.*//')
                sim_dest="${sim_name:-iPhone 16}"
                echo "xcodebuild test -project $xcodeproj -scheme $scheme -destination 'platform=iOS Simulator,name=$sim_dest'"
            fi
        fi
    elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "setup.cfg" ]; then
        echo "pytest"
    fi
}

discover_typecheck_cmd() {
    if [ -f "Makefile" ] && grep -q "^typecheck:" Makefile 2>/dev/null; then
        echo "make typecheck"
    elif [ -f "package.json" ] && grep -q '"typecheck"' package.json 2>/dev/null; then
        if [ -f "bun.lockb" ] || [ -f "bunfig.toml" ]; then
            echo "bun run typecheck"
        else
            echo "npm run typecheck"
        fi
    elif [ -f "tsconfig.json" ] && command -v tsc >/dev/null 2>&1; then
        echo "tsc --noEmit"
    elif [ -f "Cargo.toml" ]; then
        echo "cargo check"
    elif [ -f "go.mod" ]; then
        echo "go vet ./..."
    elif [ -f "pyproject.toml" ] && grep -q '\[tool\.mypy\]' pyproject.toml 2>/dev/null && command -v mypy >/dev/null 2>&1; then
        echo "mypy ."
    fi
}

discover_lint_cmd() {
    if [ -f "Makefile" ] && grep -q "^lint:" Makefile 2>/dev/null; then
        echo "make lint"
    elif [ -f "package.json" ] && grep -q '"lint"' package.json 2>/dev/null; then
        if [ -f "bun.lockb" ] || [ -f "bunfig.toml" ]; then
            echo "bun run lint"
        else
            echo "npm run lint"
        fi
    elif [ -f "Cargo.toml" ] && command -v cargo-clippy >/dev/null 2>&1; then
        echo "cargo clippy -- -D warnings"
    elif [ -f ".golangci.yml" ] || [ -f ".golangci.yaml" ]; then
        echo "golangci-lint run"
    elif { [ -f "pyproject.toml" ] && grep -q '\[tool\.ruff\]' pyproject.toml 2>/dev/null; } && command -v ruff >/dev/null 2>&1; then
        echo "ruff check ."
    fi
}
