#!/bin/bash
# ============================================================================
# FRAMEWORK SETUP - Triggered by Claude Code SessionStart hook
# ============================================================================
# Copies skills from plugin cache into the project's .claude/ directory.
# This enables direct skill invocation: /commit instead of /framework:commit
# ============================================================================

# Debug: log to file for troubleshooting
DEBUG_LOG="${HOME}/.claude/framework-setup-debug.log"
echo "=== Setup started at $(date) ===" >> "$DEBUG_LOG"
echo "PWD: ${PWD}" >> "$DEBUG_LOG"
echo "CLAUDE_PLUGIN_ROOT: ${CLAUDE_PLUGIN_ROOT:-not set}" >> "$DEBUG_LOG"
echo "CLAUDE_PROJECT_DIR: ${CLAUDE_PROJECT_DIR:-not set}" >> "$DEBUG_LOG"

set -euo pipefail

echo "After pipefail" >> "$DEBUG_LOG"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "\n${CYAN}=== $1 ===${NC}\n"; }

# ============================================================================
# CONFIGURATION
# ============================================================================

# Plugin root is set by Claude Code
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Project root - use CLAUDE_PROJECT_DIR if available, otherwise PWD
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-${PWD}}"

# Debug: log paths
echo "PLUGIN_ROOT: ${PLUGIN_ROOT}" >> "$DEBUG_LOG"
echo "PROJECT_ROOT: ${PROJECT_ROOT}" >> "$DEBUG_LOG"

# Skills that have configure mode (17 total)
CONFIGURABLE_SKILLS=(
    "arch"
    "code"
    "debugger"
    "deploy"
    "deploy-verify"
    "developer"
    "docs-refresh"
    "domain-expert"
    "framework"
    "linear"
    "setup"
    "task"
    "test"
    "tdd"
    "workflow-finish"
    "workflow-setup"
)

# ============================================================================
# MAIN SETUP
# ============================================================================

main() {
    echo "Inside main()" >> "$DEBUG_LOG"
    local force_reinstall=false
    if [[ "${1:-}" == "--force" ]]; then
        force_reinstall=true
    fi

    echo "About to log_header" >> "$DEBUG_LOG"
    log_header "Claude Code Framework Setup"

    echo "Plugin source: $PLUGIN_ROOT"
    echo "Project target: $PROJECT_ROOT"
    echo ""

    # Create directories
    mkdir -p "$PROJECT_ROOT/.claude/skills"
    mkdir -p "$PROJECT_ROOT/.claude/hooks"
    mkdir -p "$PROJECT_ROOT/.claude/scripts"

    # Check existing installation
    local existing_count=0
    if [[ -d "$PROJECT_ROOT/.claude/skills" ]]; then
        existing_count=$(ls -d "$PROJECT_ROOT/.claude/skills"/*/ 2>/dev/null | wc -l | tr -d ' ')
    fi

    # Install skills (always check for new skills)
    # NOTE: Skill definitions are in directories: .claude/skills/<skill>/
    #       Skill configs are in files: .claude/skills/<skill>.yaml
    #       This script only touches directories, configs are preserved.
    log_info "Checking skills..."
    echo "Checking skills in: $PLUGIN_ROOT/skills/" >> "$DEBUG_LOG"
    echo "Skills found: $(ls -la "$PLUGIN_ROOT/skills/" 2>&1)" >> "$DEBUG_LOG"

    local installed=0
    local skipped=0
    local updated=0

    for skill_dir in "$PLUGIN_ROOT/skills"/*/; do
        echo "Processing: $skill_dir" >> "$DEBUG_LOG"
        if [[ -d "$skill_dir" ]]; then
            local skill_name=$(basename "$skill_dir")
            local dest="$PROJECT_ROOT/.claude/skills/$skill_name"
            echo "  skill_name: $skill_name, dest: $dest" >> "$DEBUG_LOG"

            if [[ ! -d "$dest" ]]; then
                # New skill - install it (use -L to follow symlinks)
                echo "  Installing (cp -rL $skill_dir $dest)..." >> "$DEBUG_LOG"
                if cp -rL "$skill_dir" "$dest" 2>> "$DEBUG_LOG"; then
                    log_success "Installed: $skill_name"
                    echo "  Success: $skill_name" >> "$DEBUG_LOG"
                    ((installed++))
                else
                    log_error "Failed to install: $skill_name"
                    echo "  FAILED: $skill_name" >> "$DEBUG_LOG"
                fi
            elif [[ "$force_reinstall" == true ]]; then
                # Force reinstall - replace skill definition only
                # Config file (.claude/skills/<skill>.yaml) is preserved
                rm -rf "$dest"
                cp -rL "$skill_dir" "$dest"
                log_success "Updated: $skill_name"
                ((updated++))
            else
                echo "  Skipped (already exists): $skill_name" >> "$DEBUG_LOG"
                ((skipped++))
            fi
        else
            echo "  Not a directory: $skill_dir" >> "$DEBUG_LOG"
        fi
    done

    # Report results
    if [[ $installed -gt 0 ]]; then
        log_success "Installed $installed new skill(s)"
    fi
    if [[ $updated -gt 0 ]]; then
        log_success "Updated $updated skill(s)"
    fi
    if [[ $skipped -gt 0 ]] && [[ $installed -eq 0 ]] && [[ $updated -eq 0 ]]; then
        log_info "All $skipped skills already installed (use --force to reinstall)"
    fi

    # Install infrastructure (always update)
    log_info "Updating infrastructure..."
    echo "Installing infrastructure..." >> "$DEBUG_LOG"

    # Hooks (use -L to follow symlinks)
    echo "Checking hooks dir: $PLUGIN_ROOT/hooks" >> "$DEBUG_LOG"
    if [[ -d "$PLUGIN_ROOT/hooks" ]]; then
        echo "  Hooks dir exists, copying..." >> "$DEBUG_LOG"
        cp -rL "$PLUGIN_ROOT/hooks/"* "$PROJECT_ROOT/.claude/hooks/" 2>> "$DEBUG_LOG" || echo "  Hooks copy failed" >> "$DEBUG_LOG"
        log_success "Updated hooks"
    else
        echo "  No hooks dir found" >> "$DEBUG_LOG"
    fi

    # Scripts (except setup.sh itself)
    echo "Checking scripts dir: $PLUGIN_ROOT/scripts" >> "$DEBUG_LOG"
    if [[ -d "$PLUGIN_ROOT/scripts" ]]; then
        echo "  Scripts dir exists" >> "$DEBUG_LOG"
        for script in "$PLUGIN_ROOT/scripts"/*.sh; do
            if [[ -f "$script" ]] && [[ "$(basename "$script")" != "setup.sh" ]]; then
                echo "  Copying script: $script" >> "$DEBUG_LOG"
                cp "$script" "$PROJECT_ROOT/.claude/scripts/"
                chmod +x "$PROJECT_ROOT/.claude/scripts/$(basename "$script")"
            fi
        done
        log_success "Updated scripts"
    else
        echo "  No scripts dir found" >> "$DEBUG_LOG"
    fi

    # Taskfile (always update to get new tasks)
    echo "Checking Taskfile: $PLUGIN_ROOT/Taskfile.yaml" >> "$DEBUG_LOG"
    if [[ -f "$PLUGIN_ROOT/Taskfile.yaml" ]]; then
        echo "  Taskfile exists, copying..." >> "$DEBUG_LOG"
        cp "$PLUGIN_ROOT/Taskfile.yaml" "$PROJECT_ROOT/.claude/Taskfile.yaml"
        log_success "Updated Taskfile"
    else
        echo "  No Taskfile found" >> "$DEBUG_LOG"
    fi

    echo "=== Setup completed at $(date) ===" >> "$DEBUG_LOG"

    # Show success and configure reminder
    log_header "Setup Complete"
    local total_skills=$(ls -d "$PROJECT_ROOT/.claude/skills"/*/ 2>/dev/null | wc -l | tr -d ' ')
    echo "Total skills installed: $total_skills"
    echo "Skills are available as: /commit, /test, /tdd, etc."
    echo ""

    # Only show configure reminder if new skills were installed
    if [[ $installed -gt 0 ]]; then
        show_configure_reminder
    fi
}

show_configure_reminder() {
    log_header "Configuration"
    echo "The following skills have configure mode:"
    echo ""
    for skill in "${CONFIGURABLE_SKILLS[@]}"; do
        if [[ "$skill" != "framework" ]]; then
            echo "  /$skill configure"
        fi
    done
    echo ""
    echo "Run /framework configure to configure all skills at once."
    echo ""
}

# ============================================================================
# RUN
# ============================================================================

echo "About to call main..." >> "$DEBUG_LOG"
main "$@"
echo "Main completed" >> "$DEBUG_LOG"
