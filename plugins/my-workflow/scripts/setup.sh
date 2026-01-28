#!/bin/bash
# ============================================================================
# MY-WORKFLOW SETUP - Detects marketplace root and installs the skill
# ============================================================================
# This script runs on plugin install. It:
# 1. Installs the my-workflow skill to .claude/skills/my-workflow/
# 2. Detects the marketplace root (cache or local dev) for later use
# 3. Saves the marketplace root path for /my-workflow install commands
# ============================================================================
set -uo pipefail

log_info() { echo "[INFO] $1"; }
log_success() { echo "[OK] $1"; }
log_warning() { echo "[WARN] $1"; }
log_error() { echo "[ERROR] $1"; }
log_header() { echo "=== $1 ==="; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-${PWD}}"

SKILL_NAME="my-workflow"

# ============================================================================
# DETECT MARKETPLACE ROOT
# ============================================================================
# The marketplace root is where sibling plugin directories live.
#
# Cache layout (after /plugin install):
#   ~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/
#   Marketplace root = ~/.claude/plugins/cache/<marketplace>/
#
# Local dev layout (this repo):
#   <repo>/plugins/<plugin>/
#   Marketplace root = <repo>/
# ============================================================================
detect_marketplace_root() {
    local current="$PLUGIN_ROOT"

    # Strategy 1: Cache layout
    # PLUGIN_ROOT = ~/.claude/plugins/cache/<marketplace>/<plugin>/<version>
    # Go up 2 levels to get marketplace root, verify sibling plugins exist
    local cache_candidate
    cache_candidate=$(cd "$current/../.." 2>/dev/null && pwd)

    if [[ -d "$cache_candidate" ]]; then
        # Check for known sibling plugin directories (cache layout: <root>/<plugin>/<version>/)
        for sibling in commit pr-create linear; do
            local sibling_path="$cache_candidate/$sibling"
            if [[ -d "$sibling_path" ]]; then
                echo "$cache_candidate"
                return 0
            fi
        done
    fi

    # Strategy 2: Local dev layout
    # PLUGIN_ROOT = <repo>/plugins/my-workflow
    # Go up 2 levels to get repo root, verify plugins/ directory exists
    local local_candidate
    local_candidate=$(cd "$current/../.." 2>/dev/null && pwd)

    if [[ -d "$local_candidate/plugins" ]]; then
        for sibling in commit pr-create linear; do
            if [[ -d "$local_candidate/plugins/$sibling" ]]; then
                echo "$local_candidate"
                return 0
            fi
        done
    fi

    return 1
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

    # Detect and save marketplace root
    local marketplace_root
    if marketplace_root=$(detect_marketplace_root); then
        local marker_file="$PROJECT_ROOT/.claude/skills/$SKILL_NAME/.marketplace-root"
        echo "$marketplace_root" > "$marker_file"
        log_success "Marketplace root: $marketplace_root"
    else
        log_warning "Could not detect marketplace root. /my-workflow install will attempt detection at runtime."
    fi

    log_header "Installation Complete"
    echo "Skill is now available as: /$SKILL_NAME"
    echo ""
    echo "Next steps:"
    echo "  /my-workflow install minimal   - Install 7 essential skills"
    echo "  /my-workflow install standard  - Install 17 dev workflow skills"
    echo "  /my-workflow install advanced  - Install all 22 skills"
    echo ""
    echo "  /my-workflow list              - Show available tiers"
    echo "  /my-workflow status            - Show installed vs available"
    echo ""
}

main "$@"
