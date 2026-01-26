#!/bin/bash
# ============================================================================
# COMMIT SKILL SETUP - Triggered by Claude Code Setup hook (claude --init)
# ============================================================================
set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_header() { echo -e "\n${CYAN}=== $1 ===${NC}\n"; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_ROOT="${PWD}"

main() {
    log_header "Commit Skill Setup"

    mkdir -p "$PROJECT_ROOT/.claude/skills"

    # The skill is a symlink in the plugin, resolve it
    local skill_source="$PLUGIN_ROOT/skills/commit"

    # Follow symlink if it is one
    if [[ -L "$skill_source" ]]; then
        skill_source=$(readlink -f "$skill_source" 2>/dev/null || readlink "$skill_source")
    fi

    local dest="$PROJECT_ROOT/.claude/skills/commit"

    if [[ -d "$dest" ]]; then
        log_info "Skill already installed: commit"
    else
        cp -r "$skill_source" "$dest"
        log_success "Installed: commit"
    fi

    log_header "Installation Complete"
    echo "Skill is now available as: /commit"
    echo ""
}

main "$@"
