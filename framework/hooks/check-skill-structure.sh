#!/bin/bash
set -euo pipefail

# ============================================================================
# CHECK SKILL STRUCTURE (Hook)
# ============================================================================
# PostToolUse hook: Validate skill structure after creating/editing skill files.
# Runs after Write/Edit on .claude/skills/** to catch broken skills immediately.
#
# This is designed to be used as a Claude Code PostToolUse hook that receives
# JSON input via stdin with tool_input containing the file_path.
#
# Usage (as hook):
#     echo '{"tool_input":{"file_path":".claude/skills/code/skill.yaml"}}' | ./check-skill-structure.sh
#
# INPUTS:
#   stdin: JSON with tool_input.file_path or tool_input.filePath
#
# OUTPUTS:
#   Exit code 0 on success or when file is not a skill file
#   Exit code 2 on validation failure (with error messages to stderr)
#
# ============================================================================

# ============================================================================
# CONSTANTS
# ============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Exit codes
readonly SUCCESS=0
readonly ERR_VALIDATION=2

# ============================================================================
# FIND PROJECT ROOT
# ============================================================================
find_project_root() {
    local dir="${CLAUDE_PROJECT_DIR:-$SCRIPT_DIR}"

    # Walk up looking for .claude/ directory
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.claude" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done

    # Fallback to SCRIPT_DIR parent (assumes .claude/hooks/)
    echo "$(cd "$SCRIPT_DIR/../.." && pwd)"
}

# ============================================================================
# MAIN LOGIC
# ============================================================================

PROJECT_ROOT="$(find_project_root)"

# Read JSON from stdin
INPUT=$(cat)

# Extract file path from tool_input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty')

# Exit early if no file path or not in .claude/skills/
if [[ -z "$FILE_PATH" || ! "$FILE_PATH" =~ \.claude/skills/ ]]; then
    exit $SUCCESS
fi

# Only check on skill definition files (not arbitrary files in skills/)
case "$FILE_PATH" in
    *skill.yaml|*SKILL.md|*validations.yaml|*collaboration.yaml|*sharp-edges.yaml)
        # Continue with validation
        ;;
    *)
        # Not a skill definition file
        exit $SUCCESS
        ;;
esac

# Change to project directory for task commands
cd "$PROJECT_ROOT"

# Check if Taskfile exists
if [[ ! -f ".claude/Taskfile.yaml" ]]; then
    echo "Warning: .claude/Taskfile.yaml not found, skipping validation" >&2
    exit $SUCCESS
fi

# Run structural validation (YAML parsing + required files)
if ! task -t .claude/Taskfile.yaml claude:check-structure >/dev/null 2>&1; then
    echo "Skill structure validation failed" >&2
    echo "" >&2
    echo "Run 'task -t .claude/Taskfile.yaml claude:check-structure' for details:" >&2
    task -t .claude/Taskfile.yaml claude:check-structure 2>&1 | head -20 >&2
    exit $ERR_VALIDATION
fi

exit $SUCCESS
