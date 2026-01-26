#!/bin/bash
# ============================================================================
# FRAMEWORK SKILL SETUP - Triggered by plugin SessionStart hook
# ============================================================================
# Installs the framework skill which provides:
#   /framework install <tier>  - Install skills by tier
#   /framework configure       - Configure installed skills
#   /framework list            - Show installed skills
# ============================================================================

set -uo pipefail

# Colors (disabled for hook execution - no TTY)
BLUE=''
GREEN=''
CYAN=''
NC=''

log_info() { echo "[INFO] $1"; }
log_success() { echo "[OK] $1"; }
log_header() { echo "=== $1 ==="; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-${PWD}}"

SKILL_NAME="framework"

main() {
    log_header "${SKILL_NAME} Skill Setup"

    mkdir -p "$PROJECT_ROOT/.claude/skills"

    local skill_source="$PLUGIN_ROOT/skills/$SKILL_NAME"
    if [[ -L "$skill_source" ]]; then
        skill_source=$(readlink -f "$skill_source" 2>/dev/null || readlink "$skill_source")
    fi

    local dest="$PROJECT_ROOT/.claude/skills/$SKILL_NAME"

    if [[ -d "$dest" ]]; then
        log_info "Skill already installed: $SKILL_NAME"
    else
        cp -rL "$skill_source" "$dest"
        log_success "Installed: $SKILL_NAME"
    fi

    log_header "Installation Complete"
    echo ""
    echo "Framework installed. Next steps:"
    echo ""
    echo "  /framework install minimal   - Install 11 core skills"
    echo "  /framework install standard  - Install 16 skills"
    echo "  /framework install full      - Install all 22 skills"
    echo ""
}

main "$@"
