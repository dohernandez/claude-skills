#!/bin/bash
# ============================================================================
# GET CONFIG PATH
# ============================================================================
# Determines the config file path based on plugin installation scope.
#
# Usage:
#     ./get-config-path.sh --skill commit
#     ./get-config-path.sh --skill commit --marketplace dohernandez-claude-skills
#
# Output:
#     Prints the config file path to stdout:
#     - .claude/skills/commit.yaml (if installed at project scope)
#     - .claude/skills/commit.local.yaml (if installed at local or user scope)
#
# Precedence when reading (not this script's job):
#     1. .claude/skills/<skill>.local.yaml
#     2. .claude/skills/<skill>.yaml
#     3. Skill defaults
# ============================================================================

set -uo pipefail

SKILL_NAME=""
MARKETPLACE="dohernandez-claude-skills"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-${PWD}}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skill)
            SKILL_NAME="$2"
            shift 2
            ;;
        --marketplace)
            MARKETPLACE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [[ -z "$SKILL_NAME" ]]; then
    echo ".claude/skills/config.yaml"
    exit 0
fi

PLUGIN_REF="${SKILL_NAME}@${MARKETPLACE}"

# Check installation scope
# Priority: project > local > user
# project scope = shared config (.yaml)
# local/user scope = personal config (.local.yaml)

is_project_scope() {
    local settings_file="$PROJECT_ROOT/.claude/settings.json"
    if [[ -f "$settings_file" ]]; then
        grep -q "$PLUGIN_REF" "$settings_file" 2>/dev/null
        return $?
    fi
    return 1
}

is_local_scope() {
    local settings_file="$PROJECT_ROOT/.claude/settings.local.json"
    if [[ -f "$settings_file" ]]; then
        grep -q "$PLUGIN_REF" "$settings_file" 2>/dev/null
        return $?
    fi
    return 1
}

is_user_scope() {
    local settings_file="$HOME/.claude/settings.json"
    if [[ -f "$settings_file" ]]; then
        grep -q "$PLUGIN_REF" "$settings_file" 2>/dev/null
        return $?
    fi
    return 1
}

# Determine config path based on scope
if is_project_scope; then
    # Project scope = shared config
    echo ".claude/skills/${SKILL_NAME}.yaml"
else
    # Local or user scope = personal config
    echo ".claude/skills/${SKILL_NAME}.local.yaml"
fi
