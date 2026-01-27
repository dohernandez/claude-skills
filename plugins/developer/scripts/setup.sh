#!/bin/bash
# ============================================================================
# SKILL SETUP - With user tasks (test, lint, precommit)
# ============================================================================
set -uo pipefail

log_info() { echo "[INFO] $1"; }
log_success() { echo "[OK] $1"; }
log_error() { echo "[ERROR] $1"; }
log_header() { echo "=== $1 ==="; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-${PWD}}"

MARKETPLACE_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
FRAMEWORK_ROOT="$MARKETPLACE_ROOT/framework"

GITHUB_RAW_BASE="https://raw.githubusercontent.com/dohernandez/claude-skills/main/framework"

INFRA_SCRIPTS=(
    "add-skill-to-claudemd.sh"
    "audit-skills.sh"
    "check-skill-structure.sh"
    "check-skill-yaml.sh"
    "generate-skills-reference.sh"
    "get-config-path.sh"
    "list-skills.sh"
    "post-install.sh"
    "validate-skill.sh"
)

SKILL_NAME="developer"

download_file() {
    local url="$1"
    local dest="$2"
    curl -fsSL "$url" -o "$dest" 2>/dev/null
}

install_infrastructure() {
    local use_local=false

    if [[ -d "$FRAMEWORK_ROOT" ]] && [[ -f "$FRAMEWORK_ROOT/Taskfile.yaml" ]]; then
        use_local=true
        log_info "Using local framework"
    else
        log_info "Downloading infrastructure from GitHub"
    fi

    # User tasks Taskfile
    if [[ ! -f "$PROJECT_ROOT/.claude/Taskfile.yaml" ]]; then
        if [[ "$use_local" == true ]]; then
            cp "$FRAMEWORK_ROOT/Taskfile.yaml" "$PROJECT_ROOT/.claude/Taskfile.yaml"
            log_success "Installed: Taskfile.yaml"
        else
            if download_file "$GITHUB_RAW_BASE/Taskfile.yaml" "$PROJECT_ROOT/.claude/Taskfile.yaml"; then
                log_success "Downloaded: Taskfile.yaml"
            else
                log_error "Failed to download Taskfile.yaml"
            fi
        fi
    fi

    # Skill tasks Taskfile
    if [[ ! -f "$PROJECT_ROOT/.claude/Taskfile.skills.yaml" ]]; then
        if [[ "$use_local" == true ]]; then
            cp "$FRAMEWORK_ROOT/Taskfile.skills.yaml" "$PROJECT_ROOT/.claude/Taskfile.skills.yaml"
            log_success "Installed: Taskfile.skills.yaml"
        else
            if download_file "$GITHUB_RAW_BASE/Taskfile.skills.yaml" "$PROJECT_ROOT/.claude/Taskfile.skills.yaml"; then
                log_success "Downloaded: Taskfile.skills.yaml"
            else
                log_error "Failed to download Taskfile.skills.yaml"
            fi
        fi
    fi

    # Scripts
    mkdir -p "$PROJECT_ROOT/.claude/scripts"
    for script_name in "${INFRA_SCRIPTS[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/.claude/scripts/$script_name" ]]; then
            if [[ "$use_local" == true ]] && [[ -f "$FRAMEWORK_ROOT/scripts/$script_name" ]]; then
                cp "$FRAMEWORK_ROOT/scripts/$script_name" "$PROJECT_ROOT/.claude/scripts/"
                chmod +x "$PROJECT_ROOT/.claude/scripts/$script_name"
                log_success "Installed: scripts/$script_name"
            else
                if download_file "$GITHUB_RAW_BASE/scripts/$script_name" "$PROJECT_ROOT/.claude/scripts/$script_name"; then
                    chmod +x "$PROJECT_ROOT/.claude/scripts/$script_name"
                    log_success "Downloaded: scripts/$script_name"
                else
                    log_error "Failed to download scripts/$script_name"
                fi
            fi
        fi
    done
}

add_to_claudemd() {
    local script="$PROJECT_ROOT/.claude/scripts/add-skill-to-claudemd.sh"
    if [[ -x "$script" ]]; then
        "$script" --skill "$SKILL_NAME"
    fi
}

main() {
    log_header "$SKILL_NAME Skill Setup"

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

    install_infrastructure
    add_to_claudemd

    log_header "Installation Complete"
    echo "Skill is now available as: /$SKILL_NAME"
    echo ""
}

main "$@"
