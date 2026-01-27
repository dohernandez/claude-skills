#!/bin/bash
# ============================================================================
# SKILL SETUP - Standalone skill (no infrastructure needed)
# ============================================================================
set -uo pipefail

log_info() { echo "[INFO] $1"; }
log_success() { echo "[OK] $1"; }
log_header() { echo "=== $1 ==="; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-${PWD}}"

SKILL_NAME="arch"

# ============================================================================
# MAIN
# ============================================================================
main() {
    log_header "$SKILL_NAME Skill Setup"

    mkdir -p "$PROJECT_ROOT/.claude/skills"

    # Install skill
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
    echo "Skill is now available as: /$SKILL_NAME"
    echo ""
}

main "$@"
