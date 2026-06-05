#!/bin/bash
set -euo pipefail

# ============================================================================
# CHECK SKILL STRUCTURE
# ============================================================================
# Validate skill structure: required files exist, YAML is valid, name matches.
#
# Usage:
#     ./check-skill-structure.sh
#     ./check-skill-structure.sh --skill commit
#     ./check-skill-structure.sh --debug
#
# INPUTS:
# Optional:
#   --skill SKILL    Check a specific skill only
#   --debug          Enable debug logging
#   --help           Show usage information
#
# OUTPUTS:
#   Exit code 0 on success, 1 on failure
#
# ============================================================================

# ============================================================================
# CONSTANTS
# ============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"

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
# In development (skills repo): infra/skills/ contains skills
# In installed mode: .claude/skills/ contains skills
find_skills_dir() {
    # Development mode: if infra/skills/ exists with plugin structure
    if [[ -d "$PROJECT_ROOT/infra/skills" ]] && [[ -d "$PROJECT_ROOT/infra/.claude-plugin" ]]; then
        echo "$PROJECT_ROOT/infra/skills"
    elif [[ -d "$PROJECT_ROOT/.claude/skills" ]]; then
        echo "$PROJECT_ROOT/.claude/skills"
    else
        echo "$PROJECT_ROOT/.claude/skills"
    fi
}

SKILLS_DIR="$(find_skills_dir)"

# Exit codes
readonly SUCCESS=0
readonly ERR_GENERAL=1
readonly ERR_INVALID_ARGS=2

# Default values
SKILL=""
DEBUG_MODE="${DEBUG_MODE:-false}"

# Global arrays
ERRORS=()

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;90m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[OK]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_debug() { [[ "${DEBUG_MODE:-false}" == "true" ]] && echo -e "${GRAY}[DEBUG]${NC} $1" >&2 || true; }

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

die() {
    log_error "$1"
    exit "${2:-$ERR_GENERAL}"
}

show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Validate skill structure: required files exist, YAML is valid, name matches.

Options:
    --skill SKILL    Check a specific skill only
    --debug          Enable debug logging
    --help           Show this help message

Examples:
    $SCRIPT_NAME
    $SCRIPT_NAME --skill commit
    $SCRIPT_NAME --debug

EOF
}

has_yq() {
    command -v yq >/dev/null 2>&1
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

check_required_files() {
    local skill_dir="$1"
    local skill_name="$2"
    local has_error=false

    # Required files
    local required_files=("SKILL.md" "skill.yaml")

    for file in "${required_files[@]}"; do
        if [[ ! -f "$skill_dir/$file" ]]; then
            ERRORS+=("$skill_name: Missing required file: $file")
            has_error=true
        fi
    done

    if [[ "$has_error" == false ]]; then
        log_debug "$skill_name: Required files present"
    fi
}

check_yaml_syntax() {
    local skill_dir="$1"
    local skill_name="$2"

    for yaml_file in "$skill_dir"/*.yaml; do
        if [[ -f "$yaml_file" ]]; then
            local filename
            filename=$(basename "$yaml_file")

            if has_yq; then
                if ! yq e '.' "$yaml_file" > /dev/null 2>&1; then
                    ERRORS+=("$skill_name: Invalid YAML syntax in $filename")
                else
                    log_debug "$skill_name: $filename syntax OK"
                fi
            else
                # Basic check: try to parse with ruby if available
                if command -v ruby >/dev/null 2>&1; then
                    if ! ruby -e "require 'yaml'; YAML.load_file('$yaml_file')" 2>/dev/null; then
                        ERRORS+=("$skill_name: Invalid YAML syntax in $filename")
                    fi
                fi
            fi
        fi
    done
}

check_name_consistency() {
    local skill_dir="$1"
    local skill_name="$2"

    local yaml_name=""

    if has_yq; then
        yaml_name=$(yq e '.name // ""' "$skill_dir/skill.yaml" 2>/dev/null || echo "")
    else
        yaml_name=$(grep -m1 "^name:" "$skill_dir/skill.yaml" 2>/dev/null | sed 's/name: *//' | tr -d '"' || echo "")
    fi

    if [[ -n "$yaml_name" ]] && [[ "$yaml_name" != "$skill_name" ]]; then
        ERRORS+=("$skill_name: Folder name doesn't match skill.yaml name ($yaml_name)")
    else
        log_debug "$skill_name: Name consistency OK"
    fi
}

check_validations_integrity() {
    local skill_dir="$1"
    local skill_name="$2"

    local validations_file="$skill_dir/validations.yaml"

    if [[ ! -f "$validations_file" ]]; then
        log_debug "$skill_name: No validations.yaml (optional)"
        return 0
    fi

    if has_yq; then
        # Check on_stop references exist in validations
        local on_stop_count
        on_stop_count=$(yq '.on_stop | length' "$validations_file" 2>/dev/null || echo "0")

        if [[ "$on_stop_count" != "0" ]] && [[ "$on_stop_count" != "null" ]]; then
            for ((i=0; i<on_stop_count; i++)); do
                local stop_id
                stop_id=$(yq ".on_stop[$i]" "$validations_file" 2>/dev/null)

                if [[ -n "$stop_id" ]] && [[ "$stop_id" != "null" ]]; then
                    # Check if this ID exists in validations
                    local exists
                    exists=$(yq ".validations[] | select(.id == \"$stop_id\") | .id" "$validations_file" 2>/dev/null || echo "")

                    if [[ -z "$exists" ]]; then
                        ERRORS+=("$skill_name: on_stop references non-existent validation ID: $stop_id")
                    fi
                fi
            done
        fi
    fi

    log_debug "$skill_name: Validations integrity OK"
}

check_skill() {
    local skill_dir="$1"
    local skill_name
    skill_name=$(basename "$skill_dir")

    log_info "Checking: $skill_name"

    check_required_files "$skill_dir" "$skill_name"
    check_yaml_syntax "$skill_dir" "$skill_name"
    check_name_consistency "$skill_dir" "$skill_name"
    check_validations_integrity "$skill_dir" "$skill_name"
}

# ============================================================================
# MAIN FUNCTIONS
# ============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skill)
                [[ -z "${2:-}" ]] && die "Missing argument for --skill" $ERR_INVALID_ARGS
                SKILL="$2"
                shift 2
                ;;
            --debug)
                DEBUG_MODE=true
                export DEBUG_MODE
                shift
                ;;
            --help|-h)
                show_usage
                exit $SUCCESS
                ;;
            *)
                die "Unknown option: $1" $ERR_INVALID_ARGS
                ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    if [[ ! -d "$SKILLS_DIR" ]]; then
        die "Skills directory not found: $SKILLS_DIR"
    fi

    echo "=== Checking Skill Structure ==="
    echo ""

    if [[ -n "$SKILL" ]]; then
        # Check specific skill
        if [[ ! -d "$SKILLS_DIR/$SKILL" ]]; then
            die "Skill not found: $SKILL"
        fi
        check_skill "$SKILLS_DIR/$SKILL"
    else
        # Check all skills
        for skill_dir in "$SKILLS_DIR"/*/; do
            if [[ -d "$skill_dir" ]]; then
                # Skip _framework directory
                local dirname
                dirname=$(basename "$skill_dir")
                if [[ "$dirname" == "_framework" ]]; then
                    continue
                fi
                check_skill "$skill_dir"
            fi
        done
    fi

    echo ""

    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        echo "=== ERRORS FOUND ==="
        for error in "${ERRORS[@]}"; do
            log_error "$error"
        done
        echo ""
        echo "Total errors: ${#ERRORS[@]}"
        exit $ERR_GENERAL
    fi

    log_success "All skills passed structure check"
    exit $SUCCESS
}

# ============================================================================
# SCRIPT EXECUTION
# ============================================================================
main "$@"
