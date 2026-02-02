#!/bin/bash
# Main test runner for PRDX automated tests
# Usage: ./tests/run-tests.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================="
echo "PRDX Automated Test Suite"
echo "================================="
echo ""

# Check if bats is installed
if ! command -v bats &> /dev/null; then
    echo -e "${RED}ERROR: bats-core is not installed${NC}"
    echo ""
    echo "Install with:"
    echo "  brew install bats-core  # macOS"
    echo "  npm install -g bats     # npm"
    echo ""
    exit 1
fi

# Create tmp directory for test isolation
mkdir -p "$SCRIPT_DIR/tmp"

# Run all BATS test files
echo -e "${YELLOW}Running tests...${NC}"
echo ""

# Track test results
FAILED=0

# Run each test file
for test_file in "$SCRIPT_DIR"/*.bats; do
    if [ -f "$test_file" ]; then
        echo "Running $(basename "$test_file")..."
        if bats "$test_file"; then
            echo -e "${GREEN}✓ $(basename "$test_file") passed${NC}"
        else
            echo -e "${RED}✗ $(basename "$test_file") failed${NC}"
            FAILED=1
        fi
        echo ""
    fi
done

# Clean up tmp directory
rm -rf "$SCRIPT_DIR/tmp"

# Report results
echo "================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi
