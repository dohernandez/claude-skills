#!/bin/bash
set -euo pipefail

# ============================================================================
# VALIDATE SKILL
# ============================================================================
# Validate a skill's validations.yaml by running commands.
#
# Usage:
#     ./validate-skill.sh --skill commit --mode on-stop
#     ./validate-skill.sh --skill commit --mode all
#
# INPUTS:
# Required:
#   --skill SKILL    Skill name (folder name under .claude/skills/)
#
# Optional:
#   --mode MODE      Which validations to run: "on-stop" (default) or "all"
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
    # Allow override for development
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
    # Fallback to current directory
    echo "$PWD"
}

PROJECT_ROOT="$(find_project_root)"

# Determine skills directory based on context
# In development (skills repo): anthropic/ contains skills
# In installed mode: .claude/skills/ contains skills
find_skills_dir() {
    # Development mode: if anthropic/ exists with skill files, use it
    if [[ -d "$PROJECT_ROOT/infra/skills" ]] && [[ -f "$PROJECT_ROOT/anthropic/manifest.yaml" ]]; then
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
MODE="on-stop"
SKILL=""
DEBUG_MODE="${DEBUG_MODE:-false}"

# ============================================================================
# LOGGING FUNCTIONS (inline for portability)
# ============================================================================
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;90m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" >&2; }
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
Usage: $SCRIPT_NAME --skill SKILL [OPTIONS]

Validate a skill's validations.yaml by running commands.

Required:
    --skill SKILL    Skill name (folder name under .claude/skills/)

Options:
    --mode MODE      Which validations to run: "on-stop" (default) or "all"
    --debug          Enable debug logging
    --help           Show this help message

Examples:
    $SCRIPT_NAME --skill commit --mode on-stop
    $SCRIPT_NAME --skill commit --mode all
    $SCRIPT_NAME --skill arch --debug

EOF
}

# ============================================================================
# YAML PARSING FUNCTIONS
# ============================================================================

check_yaml_parser() {
    if command -v yq >/dev/null 2>&1; then
        echo "yq"
    else
        echo "basic"
    fi
}

# Load validations from validations.yaml
load_validations() {
    local skill="$1"
    local path="$SKILLS_DIR/$skill/validations.yaml"

    # Initialize arrays
    VALIDATIONS_IDS=()
    VALIDATIONS_NAMES=()
    VALIDATIONS_TYPES=()
    VALIDATIONS_COMMANDS=()
    VALIDATIONS_MESSAGES=()
    ON_STOP_IDS=()

    if [[ ! -f "$path" ]]; then
        log_debug "No validations.yaml found at $path"
        return 0
    fi

    local parser
    parser=$(check_yaml_parser)

    if [[ "$parser" == "yq" ]]; then
        load_validations_yq "$path"
    else
        load_validations_basic "$path"
    fi
}

# Load validations using yq (preferred method)
load_validations_yq() {
    local path="$1"

    local count
    count=$(yq '.validations | length' "$path" 2>/dev/null || echo "0")

    if [[ "$count" == "0" ]] || [[ "$count" == "null" ]]; then
        log_debug "No validations found in $path"
        return 0
    fi

    for ((i=0; i<count; i++)); do
        local vid vname vtype vcmd vmsg

        vid=$(yq ".validations[$i].id // \"\"" "$path" 2>/dev/null)
        vname=$(yq ".validations[$i].name // \"\"" "$path" 2>/dev/null)
        vtype=$(yq ".validations[$i].type // \"command\"" "$path" 2>/dev/null)
        vcmd=$(yq ".validations[$i].command // \"\"" "$path" 2>/dev/null)
        vmsg=$(yq ".validations[$i].message // \"\"" "$path" 2>/dev/null)

        if [[ -z "$vid" ]] || [[ "$vid" == "null" ]]; then
            continue
        fi

        VALIDATIONS_IDS+=("$vid")
        VALIDATIONS_NAMES+=("${vname:-$vid}")
        VALIDATIONS_TYPES+=("${vtype:-command}")
        VALIDATIONS_COMMANDS+=("${vcmd:-}")
        VALIDATIONS_MESSAGES+=("${vmsg:-Validation $vid failed}")
    done

    local on_stop_count
    on_stop_count=$(yq '.on_stop | length' "$path" 2>/dev/null || echo "0")

    if [[ "$on_stop_count" != "0" ]] && [[ "$on_stop_count" != "null" ]]; then
        for ((i=0; i<on_stop_count; i++)); do
            local stop_id
            stop_id=$(yq ".on_stop[$i]" "$path" 2>/dev/null)
            if [[ -n "$stop_id" ]] && [[ "$stop_id" != "null" ]]; then
                ON_STOP_IDS+=("$stop_id")
            fi
        done
    fi
}

# Load validations using basic parsing (fallback when yq not available)
load_validations_basic() {
    local path="$1"
    local in_validations=false
    local in_on_stop=false
    local current_id=""
    local current_name=""
    local current_type="command"
    local current_command=""
    local current_message=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        local trimmed
        trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        [[ -z "$trimmed" ]] && continue
        [[ "$trimmed" =~ ^# ]] && continue

        if [[ "$trimmed" == "validations:" ]]; then
            in_validations=true
            in_on_stop=false
            continue
        fi

        if [[ "$trimmed" == "on_stop:" ]]; then
            if [[ -n "$current_id" ]]; then
                VALIDATIONS_IDS+=("$current_id")
                VALIDATIONS_NAMES+=("${current_name:-$current_id}")
                VALIDATIONS_TYPES+=("${current_type:-command}")
                VALIDATIONS_COMMANDS+=("$current_command")
                VALIDATIONS_MESSAGES+=("${current_message:-Validation $current_id failed}")
                current_id=""
                current_name=""
                current_type="command"
                current_command=""
                current_message=""
            fi
            in_validations=false
            in_on_stop=true
            continue
        fi

        if [[ "$in_validations" == true ]]; then
            if [[ "$trimmed" =~ ^-[[:space:]]*id:[[:space:]]*(.*) ]]; then
                if [[ -n "$current_id" ]]; then
                    VALIDATIONS_IDS+=("$current_id")
                    VALIDATIONS_NAMES+=("${current_name:-$current_id}")
                    VALIDATIONS_TYPES+=("${current_type:-command}")
                    VALIDATIONS_COMMANDS+=("$current_command")
                    VALIDATIONS_MESSAGES+=("${current_message:-Validation $current_id failed}")
                fi

                current_id="${BASH_REMATCH[1]}"
                current_id=$(echo "$current_id" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')
                current_name=""
                current_type="command"
                current_command=""
                current_message=""
                continue
            fi

            if [[ "$trimmed" =~ ^name:[[:space:]]*(.*) ]]; then
                current_name="${BASH_REMATCH[1]}"
                current_name=$(echo "$current_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')
            elif [[ "$trimmed" =~ ^type:[[:space:]]*(.*) ]]; then
                current_type="${BASH_REMATCH[1]}"
                current_type=$(echo "$current_type" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')
            elif [[ "$trimmed" =~ ^command:[[:space:]]*(.*) ]]; then
                current_command="${BASH_REMATCH[1]}"
                current_command=$(echo "$current_command" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')
            elif [[ "$trimmed" =~ ^message:[[:space:]]*(.*) ]]; then
                current_message="${BASH_REMATCH[1]}"
                current_message=$(echo "$current_message" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')
            fi
        fi

        if [[ "$in_on_stop" == true ]]; then
            if [[ "$trimmed" =~ ^-[[:space:]]*(.*) ]]; then
                local stop_id="${BASH_REMATCH[1]}"
                stop_id=$(echo "$stop_id" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')
                if [[ -n "$stop_id" ]]; then
                    ON_STOP_IDS+=("$stop_id")
                fi
            fi
        fi
    done < "$path"

    if [[ -n "$current_id" ]]; then
        VALIDATIONS_IDS+=("$current_id")
        VALIDATIONS_NAMES+=("${current_name:-$current_id}")
        VALIDATIONS_TYPES+=("${current_type:-command}")
        VALIDATIONS_COMMANDS+=("$current_command")
        VALIDATIONS_MESSAGES+=("${current_message:-Validation $current_id failed}")
    fi
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

get_validation_index() {
    local vid="$1"
    local i

    for ((i=0; i<${#VALIDATIONS_IDS[@]}; i++)); do
        if [[ "${VALIDATIONS_IDS[$i]}" == "$vid" ]]; then
            echo "$i"
            return 0
        fi
    done

    echo "-1"
    return 0
}

run_validation() {
    local idx="$1"

    local vid="${VALIDATIONS_IDS[$idx]}"
    local vname="${VALIDATIONS_NAMES[$idx]}"
    local vtype="${VALIDATIONS_TYPES[$idx]}"
    local vcmd="${VALIDATIONS_COMMANDS[$idx]}"
    local vmsg="${VALIDATIONS_MESSAGES[$idx]}"

    if [[ "$vtype" != "command" ]]; then
        echo "  [$vid] SKIP: type=$vtype not supported in v1"
        return 0
    fi

    if [[ -z "$vcmd" ]]; then
        return 0
    fi

    echo "  [$vid] $vname"
    echo "    Running: $vcmd"

    set +e
    # Run from PROJECT_ROOT so relative paths like .claude/Taskfile.yaml work
    (cd "$PROJECT_ROOT" && eval "$vcmd")
    local result=$?
    set -e

    if [[ $result -ne 0 ]]; then
        echo "    FAILED: $vmsg"
        return 1
    fi

    echo "    OK"
    return 0
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
            --mode)
                [[ -z "${2:-}" ]] && die "Missing argument for --mode" $ERR_INVALID_ARGS
                if [[ "$2" != "on-stop" ]] && [[ "$2" != "all" ]]; then
                    die "Invalid mode: $2. Must be 'on-stop' or 'all'" $ERR_INVALID_ARGS
                fi
                MODE="$2"
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

    if [[ -z "$SKILL" ]]; then
        die "Missing required argument: --skill" $ERR_INVALID_ARGS
    fi
}

main() {
    parse_arguments "$@"

    log_debug "PROJECT_ROOT: $PROJECT_ROOT"
    log_debug "Looking for skill: $SKILL"

    # Check skill directory exists
    if [[ ! -d "$SKILLS_DIR/$SKILL" ]]; then
        die "Skill directory not found: $SKILLS_DIR/$SKILL"
    fi

    load_validations "$SKILL"

    if [[ ${#VALIDATIONS_IDS[@]} -eq 0 ]]; then
        echo "No validations.yaml for $SKILL"
        exit $SUCCESS
    fi

    local to_run=()

    if [[ "$MODE" == "on-stop" ]]; then
        if [[ ${#ON_STOP_IDS[@]} -eq 0 ]]; then
            echo "No on_stop validations for $SKILL"
            exit $SUCCESS
        fi
        to_run=("${ON_STOP_IDS[@]}")
    else
        to_run=("${VALIDATIONS_IDS[@]}")
    fi

    echo "=== Validating $SKILL (mode=$MODE) ==="

    local failed=()

    for vid in "${to_run[@]}"; do
        local idx
        idx=$(get_validation_index "$vid")

        if [[ "$idx" == "-1" ]]; then
            echo "  [$vid] WARNING: validation not found"
            continue
        fi

        if ! run_validation "$idx"; then
            failed+=("$vid")
        fi
    done

    echo ""

    if [[ ${#failed[@]} -gt 0 ]]; then
        local failed_list
        failed_list=$(IFS=', '; echo "${failed[*]}")
        echo "FAILED: ${#failed[@]} validation(s): $failed_list"
        exit $ERR_GENERAL
    fi

    echo "=== $SKILL: OK ==="
    exit $SUCCESS
}

# ============================================================================
# SCRIPT EXECUTION
# ============================================================================
main "$@"
