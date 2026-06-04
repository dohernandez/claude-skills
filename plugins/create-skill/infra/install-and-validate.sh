#!/bin/bash
# ============================================================================
# create-skill — Stop-hook entrypoint
# ============================================================================
# Runs as a Stop hook process, so $CLAUDE_PLUGIN_ROOT is available here (it is
# NOT available to the model's own Bash calls during the skill procedure).
#
# Two jobs:
#   1. Install the bundled skill-validation infra (Taskfile.skills.yaml + the
#      validation scripts) into the target project's .claude/ — idempotent.
#      This is what lets skills SCAFFOLDED by create-skill work: their Stop
#      hooks call `task -t .claude/Taskfile.skills.yaml validate-skill ...`,
#      which needs that infra present in the project.
#   2. Validate the structure of all skills currently in the project.
#
# Exit 0 = all good (or nothing to validate yet); exit 1 = a skill is invalid.
# ============================================================================
set -uo pipefail

# Plugin root: set by the hook runtime; fall back to this script's location.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# Project root: set by the hook runtime; fall back to cwd.
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

INFRA_SRC="$PLUGIN_ROOT/infra"
CLAUDE_DIR="$PROJECT_ROOT/.claude"

log() { echo "[create-skill] $1"; }

# ---------------------------------------------------------------------------
# 1. Install validation infra into the project (idempotent)
# ---------------------------------------------------------------------------
mkdir -p "$CLAUDE_DIR/scripts"

if [[ ! -f "$CLAUDE_DIR/Taskfile.skills.yaml" ]]; then
    cp "$INFRA_SRC/Taskfile.skills.yaml" "$CLAUDE_DIR/Taskfile.skills.yaml"
    log "Installed .claude/Taskfile.skills.yaml"
fi

for src in "$INFRA_SRC"/scripts/*.sh; do
    [[ -e "$src" ]] || continue
    dest="$CLAUDE_DIR/scripts/$(basename "$src")"
    if [[ ! -f "$dest" ]]; then
        cp "$src" "$dest"
        chmod +x "$dest"
        log "Installed .claude/scripts/$(basename "$src")"
    fi
done

# ---------------------------------------------------------------------------
# 2. Validate all skills in the project
# ---------------------------------------------------------------------------
if [[ ! -d "$CLAUDE_DIR/skills" ]]; then
    log "No .claude/skills/ yet — nothing to validate."
    exit 0
fi

cd "$PROJECT_ROOT"

if command -v task >/dev/null 2>&1; then
    task -t "$CLAUDE_DIR/Taskfile.skills.yaml" check-structure
else
    # go-task not installed — run the bundled checker directly.
    log "task (go-task) not found; running structure check directly."
    "$CLAUDE_DIR/scripts/check-skill-structure.sh"
fi
