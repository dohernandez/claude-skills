#!/bin/bash
# ============================================================================
# FRAMEWORK SETUP - Triggered by Claude Code Setup hook (claude --init)
# ============================================================================
# Copies skills from plugin cache into the project's .claude/ directory.
# This enables direct skill invocation: /commit instead of /framework:commit
# ============================================================================

set -euo pipefail

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

# Project root is current working directory (where claude --init was run)
PROJECT_ROOT="${PWD}"

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
    local force_reinstall=false
    if [[ "${1:-}" == "--force" ]]; then
        force_reinstall=true
    fi

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
    local installed=0
    local skipped=0
    local updated=0

    for skill_dir in "$PLUGIN_ROOT/skills"/*/; do
        if [[ -d "$skill_dir" ]]; then
            local skill_name=$(basename "$skill_dir")
            local dest="$PROJECT_ROOT/.claude/skills/$skill_name"

            if [[ ! -d "$dest" ]]; then
                # New skill - install it (use -L to follow symlinks)
                cp -rL "$skill_dir" "$dest"
                log_success "Installed: $skill_name"
                ((installed++))
            elif [[ "$force_reinstall" == true ]]; then
                # Force reinstall - replace skill definition only
                # Config file (.claude/skills/<skill>.yaml) is preserved
                rm -rf "$dest"
                cp -rL "$skill_dir" "$dest"
                log_success "Updated: $skill_name"
                ((updated++))
            else
                ((skipped++))
            fi
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

    # Hooks (use -L to follow symlinks)
    if [[ -d "$PLUGIN_ROOT/hooks" ]]; then
        cp -rL "$PLUGIN_ROOT/hooks/"* "$PROJECT_ROOT/.claude/hooks/" 2>/dev/null || true
        log_success "Updated hooks"
    fi

    # Scripts (except setup.sh itself)
    if [[ -d "$PLUGIN_ROOT/scripts" ]]; then
        for script in "$PLUGIN_ROOT/scripts"/*.sh; do
            if [[ -f "$script" ]] && [[ "$(basename "$script")" != "setup.sh" ]]; then
                cp "$script" "$PROJECT_ROOT/.claude/scripts/"
                chmod +x "$PROJECT_ROOT/.claude/scripts/$(basename "$script")"
            fi
        done
        log_success "Updated scripts"
    fi

    # Taskfile (always update to get new tasks)
    if [[ -f "$PLUGIN_ROOT/Taskfile.yaml" ]]; then
        cp "$PLUGIN_ROOT/Taskfile.yaml" "$PROJECT_ROOT/.claude/Taskfile.yaml"
        log_success "Updated Taskfile"
    fi

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

main "$@"
