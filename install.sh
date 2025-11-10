#!/bin/bash

# PRD System Installer for Claude Code
# This script installs the PRD (Product Requirements Document) workflow system
# into a project's .claude directory

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-.claude}"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  PRD System Installer for Claude Code${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

# Function to check if directory exists and create if not
ensure_directory() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_success "Created directory: $dir"
    else
        print_info "Directory exists: $dir"
    fi
}

# Function to copy files with backup
copy_with_backup() {
    local source=$1
    local dest=$2
    local backup_suffix=".backup.$(date +%Y%m%d-%H%M%S)"

    if [ -e "$dest" ]; then
        mv "$dest" "${dest}${backup_suffix}"
        print_warning "Backed up existing file: ${dest}${backup_suffix}"
    fi

    cp "$source" "$dest"
    print_success "Installed: $(basename $dest)"
}

# Function to copy directory recursively
copy_directory() {
    local source=$1
    local dest=$2
    local name=$3

    if [ ! -d "$source" ]; then
        print_error "Source directory not found: $source"
        return 1
    fi

    ensure_directory "$dest"

    local count=0
    for file in "$source"/*; do
        if [ -f "$file" ]; then
            copy_with_backup "$file" "$dest/$(basename $file)"
            ((count++))
        fi
    done

    print_success "Installed $count $name files"
}

# Main installation function
install_prd_system() {
    print_header

    # Validate script directory
    if [ ! -d "$SCRIPT_DIR/commands" ] || [ ! -d "$SCRIPT_DIR/skills" ] || [ ! -d "$SCRIPT_DIR/agents" ]; then
        print_error "Invalid installation package. Missing required directories."
        print_info "Expected structure:"
        print_info "  - commands/"
        print_info "  - skills/"
        print_info "  - agents/"
        exit 1
    fi

    # Resolve target directory
    if [ "$TARGET_DIR" = ".claude" ]; then
        # Use current directory's .claude
        TARGET_DIR="$(pwd)/.claude"
    else
        # Use provided path
        TARGET_DIR="$(cd "$(dirname "$TARGET_DIR")" && pwd)/$(basename "$TARGET_DIR")"
    fi

    print_info "Installation target: $TARGET_DIR"
    echo ""

    # Confirm installation
    read -p "$(echo -e ${YELLOW}Do you want to proceed with installation? [y/N]:${NC} )" -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Installation cancelled"
        exit 0
    fi

    echo ""
    print_info "Installing PRD system components..."
    echo ""

    # Install commands
    print_info "[1/3] Installing PRD commands..."
    copy_directory "$SCRIPT_DIR/commands" "$TARGET_DIR/commands/prd" "command"
    echo ""

    # Install skills
    print_info "[2/3] Installing PRD skills..."
    copy_directory "$SCRIPT_DIR/skills" "$TARGET_DIR/skills" "skill"
    echo ""

    # Install agents
    print_info "[3/3] Installing agents..."
    copy_directory "$SCRIPT_DIR/agents" "$TARGET_DIR/agents" "agent"
    echo ""

    # Installation complete
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo ""

    print_success "PRD system installed successfully"
    echo ""
    print_info "Available PRD commands:"
    echo "  /prd:wizard          - Interactive PRD creation"
    echo "  /prd:plan            - Plan feature implementation"
    echo "  /prd:dev:start       - Start implementation"
    echo "  /prd:dev:check       - Verify implementation"
    echo "  /prd:dev:push        - Create pull request"
    echo "  /prd:publish         - Publish as GitHub issue"
    echo "  /prd:sync            - Sync with GitHub"
    echo "  /prd:list            - List all PRDs"
    echo "  /prd:search          - Search PRDs"
    echo "  /prd:update          - Update PRD"
    echo "  /prd:close           - Close PRD"
    echo "  /prd:status          - View status dashboard"
    echo "  /prd:deps            - Manage dependencies"
    echo "  /prd:help            - Show help"
    echo ""
    print_info "Installed agents:"
    ls "$TARGET_DIR/agents" | grep -E "\.md$" | sed 's/.md$//' | sed 's/^/  - /'
    echo ""
    print_info "Next steps:"
    echo "  1. Run '/prd:help' to learn about the PRD system"
    echo "  2. Run '/prd:wizard' to create your first PRD"
    echo "  3. Customize agents in .claude/agents/ for your project"
    echo ""
}

# Run installation
install_prd_system
