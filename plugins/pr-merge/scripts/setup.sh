#!/bin/bash
# ============================================================================
# SKILL SETUP - Copies skill and ensures infrastructure exists
# ============================================================================
set -uo pipefail

# Colors (disabled for hook execution - no TTY)
log_info() { echo "[INFO] $1"; }
log_success() { echo "[OK] $1"; }
log_header() { echo "=== $1 ==="; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-${PWD}}"

# Navigate to marketplace root to find framework
# Structure: .../dohernandez-claude-skills/plugins/<skill>/
#            .../dohernandez-claude-skills/framework/
MARKETPLACE_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
FRAMEWORK_ROOT="$MARKETPLACE_ROOT/framework"

SKILL_NAME="pr-merge"

# ============================================================================
# INSTALL INFRASTRUCTURE (if missing)
# ============================================================================
install_infrastructure() {
    # Only install if framework exists in marketplace
    if [[ ! -d "$FRAMEWORK_ROOT" ]]; then
        log_info "Framework not found - skipping infrastructure"
        return
    fi

    # Taskfile
    if [[ ! -f "$PROJECT_ROOT/.claude/Taskfile.yaml" ]]; then
        if [[ -f "$FRAMEWORK_ROOT/Taskfile.yaml" ]]; then
            cp "$FRAMEWORK_ROOT/Taskfile.yaml" "$PROJECT_ROOT/.claude/Taskfile.yaml"
            log_success "Installed: Taskfile.yaml"
        fi
    fi

    # Scripts directory
    if [[ -d "$FRAMEWORK_ROOT/scripts" ]]; then
        mkdir -p "$PROJECT_ROOT/.claude/scripts"
        for script in "$FRAMEWORK_ROOT/scripts"/*.sh; do
            if [[ -f "$script" ]] && [[ "$(basename "$script")" != "setup.sh" ]]; then
                local script_name=$(basename "$script")
                if [[ ! -f "$PROJECT_ROOT/.claude/scripts/$script_name" ]]; then
                    cp "$script" "$PROJECT_ROOT/.claude/scripts/"
                    chmod +x "$PROJECT_ROOT/.claude/scripts/$script_name"
                    log_success "Installed: scripts/$script_name"
                fi
            fi
        done
    fi
}

# ============================================================================
# ADD SKILL TO CLAUDE.MD
# ============================================================================
add_to_claudemd() {
    local script="$PROJECT_ROOT/.claude/scripts/add-skill-to-claudemd.sh"
    if [[ -x "$script" ]]; then
        "$script" --skill "$SKILL_NAME"
    fi
}

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

    # Install infrastructure if missing
    install_infrastructure

    # Add skill to CLAUDE.md
    add_to_claudemd

    log_header "Installation Complete"
    echo "Skill is now available as: /$SKILL_NAME"
    echo ""
}

main "$@"
