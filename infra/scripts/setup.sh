#!/bin/bash
# ============================================================================
# FRAMEWORK SETUP - Triggered by Claude Code SessionStart hook
# ============================================================================
# Copies shared infrastructure (hooks, scripts, Taskfile) and the framework
# skill to the project's .claude/ directory.
#
# Individual skills are installed via: /framework install <tier>
# which uses: claude plugin install <skill>@dohernandez-claude-skills
# ============================================================================

# Debug: log to file for troubleshooting
DEBUG_LOG="${HOME}/.claude/framework-setup-debug.log"
echo "=== Setup started at $(date) ===" >> "$DEBUG_LOG"
echo "PWD: ${PWD}" >> "$DEBUG_LOG"
echo "CLAUDE_PLUGIN_ROOT: ${CLAUDE_PLUGIN_ROOT:-not set}" >> "$DEBUG_LOG"
echo "CLAUDE_PROJECT_DIR: ${CLAUDE_PROJECT_DIR:-not set}" >> "$DEBUG_LOG"

set -uo pipefail  # Removed -e to prevent silent exits

# Colors (disabled for hook execution - no TTY)
RED=''
GREEN=''
YELLOW=''
BLUE=''
CYAN=''
NC=''

log_info() { echo "[INFO] $1"; echo "[INFO] $1" >> "$DEBUG_LOG"; }
log_success() { echo "[OK] $1"; echo "[OK] $1" >> "$DEBUG_LOG"; }
log_warning() { echo "[WARN] $1"; echo "[WARN] $1" >> "$DEBUG_LOG"; }
log_error() { echo "[ERROR] $1"; echo "[ERROR] $1" >> "$DEBUG_LOG"; }
log_header() { echo "=== $1 ==="; echo "=== $1 ====" >> "$DEBUG_LOG"; }

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

# ============================================================================
# MAIN SETUP
# ============================================================================

main() {
    echo "Inside main()" >> "$DEBUG_LOG"
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

    # ========================================================================
    # INSTALL FRAMEWORK SKILL ONLY
    # ========================================================================
    # The framework skill provides /framework install, /framework configure, etc.
    # Other skills are installed via: /framework install <tier>

    log_info "Installing framework skill..."
    echo "Installing framework skill..." >> "$DEBUG_LOG"

    local framework_src="$PLUGIN_ROOT/skills/framework"
    local framework_dest="$PROJECT_ROOT/.claude/skills/framework"

    if [[ -d "$framework_src" ]]; then
        if [[ ! -d "$framework_dest" ]] || [[ "$force_reinstall" == true ]]; then
            rm -rf "$framework_dest" 2>/dev/null || true
            if cp -rL "$framework_src" "$framework_dest" 2>> "$DEBUG_LOG"; then
                log_success "Installed: framework"
            else
                log_error "Failed to install framework skill"
            fi
        else
            log_info "Framework skill already installed"
        fi
    else
        log_error "Framework skill not found at: $framework_src"
    fi

    # ========================================================================
    # INSTALL SHARED INFRASTRUCTURE
    # ========================================================================
    # These are used by all skills regardless of tier

    log_info "Installing shared infrastructure..."
    echo "Installing infrastructure..." >> "$DEBUG_LOG"

    # Hooks (use -L to follow symlinks)
    echo "Checking hooks dir: $PLUGIN_ROOT/hooks" >> "$DEBUG_LOG"
    if [[ -d "$PLUGIN_ROOT/hooks" ]]; then
        # Don't copy hooks.json (that's for the plugin itself)
        # Copy any other hook scripts if they exist
        for hook_file in "$PLUGIN_ROOT/hooks"/*; do
            if [[ -f "$hook_file" ]] && [[ "$(basename "$hook_file")" != "hooks.json" ]]; then
                echo "  Copying hook: $hook_file" >> "$DEBUG_LOG"
                cp -L "$hook_file" "$PROJECT_ROOT/.claude/hooks/"
            fi
        done
        log_success "Checked hooks"
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
    fi

    # Note: Taskfiles (Taskfile.dev.yaml, Taskfile.skills.yaml) are installed by
    # individual skill plugins (setup, developer, task, test, etc.), not by the
    # framework plugin. Each skill's setup.sh copies from infra/ to .claude/.

    # Docs and GitHub templates are bundled with individual skills
    # (e.g., git-workflow.md is in pr-create skill)
    # GitHub templates are offered during /framework configure

    # Note: framework skill is NOT added to CLAUDE.md
    # Only user-facing skills (commit, test, etc.) are added by their setup.sh

    echo "=== Setup completed at $(date) ===" >> "$DEBUG_LOG"

    # ========================================================================
    # SHOW SUCCESS MESSAGE
    # ========================================================================
    log_header "Setup Complete"
    echo ""
    echo "Framework installed. Next steps:"
    echo ""
    echo "  /framework install minimal   - Install 11 core skills"
    echo "  /framework install standard  - Install 16 skills"
    echo "  /framework install full      - Install all 22 skills"
    echo ""
    echo "  /framework list              - Show available skills"
    echo "  /framework configure         - Configure installed skills"
    echo ""
}

# ============================================================================
# RUN
# ============================================================================

echo "About to call main..." >> "$DEBUG_LOG"
main "$@"
echo "Main completed" >> "$DEBUG_LOG"
