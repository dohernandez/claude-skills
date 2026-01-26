#!/bin/bash
set -uo pipefail

# ============================================================================
# LIST SKILLS
# ============================================================================
# List all available skills with their descriptions.
#
# Usage:
#     ./list-skills.sh
#
# ============================================================================

# Find project root - can be overridden by environment variable
find_project_root() {
    if [[ -n "${PROJECT_ROOT:-}" ]]; then
        echo "$PROJECT_ROOT"
        return 0
    fi

    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.claude/skills" ]] || [[ -f "$dir/CLAUDE.md" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    echo "$PWD"
}

PROJECT_ROOT="$(find_project_root)"

# Determine skills directory based on context
# In development (skills repo): anthropic/ contains skills
# In installed mode: .claude/skills/ contains skills
find_skills_dir() {
    # Development mode: if anthropic/ exists with skill files, use it
    if [[ -d "$PROJECT_ROOT/anthropic/skills" ]] && [[ -f "$PROJECT_ROOT/anthropic/manifest.yaml" ]]; then
        echo "$PROJECT_ROOT/anthropic/skills"
    elif [[ -d "$PROJECT_ROOT/.claude/skills" ]]; then
        echo "$PROJECT_ROOT/.claude/skills"
    else
        echo "$PROJECT_ROOT/.claude/skills"
    fi
}

SKILLS_DIR="$(find_skills_dir)"

has_yq() {
    command -v yq >/dev/null 2>&1
}

echo ""
echo "Available Skills"
echo "================"

for skill_dir in "$SKILLS_DIR"/*/; do
    if [[ -d "$skill_dir" ]]; then
        skill_name=$(basename "$skill_dir")

        # Skip _framework
        if [[ "$skill_name" == "_framework" ]]; then
            continue
        fi

        if [[ -f "$skill_dir/skill.yaml" ]]; then
            if has_yq; then
                kind=$(yq e '.kind // "unknown"' "$skill_dir/skill.yaml" 2>/dev/null) || kind="unknown"
                desc=$(yq e '.description // "-"' "$skill_dir/skill.yaml" 2>/dev/null) || desc="-"
            else
                kind=$(grep -m1 "^kind:" "$skill_dir/skill.yaml" 2>/dev/null | sed 's/kind:[[:space:]]*//' | tr -d '"') || kind="unknown"
                desc=$(grep -m1 "^description:" "$skill_dir/skill.yaml" 2>/dev/null | sed 's/description:[[:space:]]*//' | tr -d '"') || desc="-"
            fi
            # Truncate description to 55 chars
            desc="${desc:0:55}"
            printf "  %-20s [%-10s] %s\n" "$skill_name" "$kind" "$desc"
        fi
    fi
done

echo ""
