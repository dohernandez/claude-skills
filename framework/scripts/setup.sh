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

# Skills that have configure mode
CONFIGURABLE_SKILLS=(
    "debugger"
    "deploy"
    "deploy-verify"
    "developer"
    "docs-refresh"
    "framework"
    "task"
    "tdd"
    "workflow-finish"
    "workflow-setup"
)

# ============================================================================
# MAIN SETUP
# ============================================================================

main() {
    log_header "Claude Code Framework Setup"

    echo "Plugin source: $PLUGIN_ROOT"
    echo "Project target: $PROJECT_ROOT"
    echo ""

    # Check if already installed
    if [[ -d "$PROJECT_ROOT/.claude/skills" ]] && [[ "$(ls -A "$PROJECT_ROOT/.claude/skills" 2>/dev/null)" ]]; then
        local skill_count=$(ls -d "$PROJECT_ROOT/.claude/skills"/*/ 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$skill_count" -gt 5 ]]; then
            log_info "Framework already installed ($skill_count skills found)"
            log_info "Run with --force to reinstall, or use /framework configure"

            # Still show configure reminder
            show_configure_reminder
            return 0
        fi
    fi

    # Create directories
    mkdir -p "$PROJECT_ROOT/.claude/skills"
    mkdir -p "$PROJECT_ROOT/.claude/hooks"
    mkdir -p "$PROJECT_ROOT/.claude/scripts"

    # Install skills
    log_info "Installing skills..."
    local installed=0
    for skill_dir in "$PLUGIN_ROOT/skills"/*/; do
        if [[ -d "$skill_dir" ]]; then
            local skill_name=$(basename "$skill_dir")
            local dest="$PROJECT_ROOT/.claude/skills/$skill_name"

            if [[ ! -d "$dest" ]]; then
                cp -r "$skill_dir" "$dest"
                log_success "Installed: $skill_name"
                ((installed++))
            fi
        fi
    done

    if [[ $installed -eq 0 ]]; then
        log_info "All skills already installed"
    else
        log_success "Installed $installed skills"
    fi

    # Install infrastructure
    log_info "Installing infrastructure..."

    # Hooks
    if [[ -d "$PLUGIN_ROOT/hooks" ]]; then
        cp -r "$PLUGIN_ROOT/hooks/"* "$PROJECT_ROOT/.claude/hooks/" 2>/dev/null || true
        log_success "Installed hooks"
    fi

    # Scripts (except setup.sh itself)
    if [[ -d "$PLUGIN_ROOT/scripts" ]]; then
        for script in "$PLUGIN_ROOT/scripts"/*.sh; do
            if [[ -f "$script" ]] && [[ "$(basename "$script")" != "setup.sh" ]]; then
                cp "$script" "$PROJECT_ROOT/.claude/scripts/"
                chmod +x "$PROJECT_ROOT/.claude/scripts/$(basename "$script")"
            fi
        done
        log_success "Installed scripts"
    fi

    # Taskfile
    if [[ -f "$PLUGIN_ROOT/Taskfile.yaml" ]] && [[ ! -f "$PROJECT_ROOT/.claude/Taskfile.yaml" ]]; then
        cp "$PLUGIN_ROOT/Taskfile.yaml" "$PROJECT_ROOT/.claude/Taskfile.yaml"
        log_success "Installed Taskfile"
    fi

    # Show success and configure reminder
    log_header "Installation Complete"
    echo "Skills are now available as: /commit, /linear, /tdd, etc."
    echo ""

    show_configure_reminder
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
