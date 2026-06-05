#!/bin/bash
# ============================================================================
# docs-refresh — Stop-hook entrypoint
# ============================================================================
# Runs as a Stop hook process, so $CLAUDE_PLUGIN_ROOT is available here (it is
# NOT available to the model's own Bash calls during the skill procedure).
#
# Three jobs:
#   1. Install the bundled skill infra (Taskfile.skills.yaml + scripts) into the
#      project's .claude/ — idempotent. Lets the user / future runs invoke
#      `task -t .claude/Taskfile.skills.yaml skills-reference` manually.
#   2. Regenerate the skills reference doc from the project's .claude/skills/*,
#      using the bundled generator (the deterministic "skills-reference" job).
#   3. Validate skill YAML across the project (the on_stop check).
#
# Exit 0 = all good; exit 1 = skill YAML validation failed.
# Reference generation problems are logged but non-fatal.
# ============================================================================
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

INFRA_SRC="$PLUGIN_ROOT/infra"
CLAUDE_DIR="$PROJECT_ROOT/.claude"

log() { echo "[docs-refresh] $1"; }

# ---------------------------------------------------------------------------
# 1. Install skill infra into the project (idempotent)
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

cd "$PROJECT_ROOT"

# ---------------------------------------------------------------------------
# 2. Regenerate the skills reference (best-effort; non-fatal)
# ---------------------------------------------------------------------------
if [[ -d "$CLAUDE_DIR/skills" ]]; then
    # Honor an optional output override from the skill config, else default.
    ref_output="docs/skills/REFERENCE.md"
    for cfg in "$CLAUDE_DIR/skills/docs-refresh.local.yaml" "$CLAUDE_DIR/skills/docs-refresh.yaml"; do
        if [[ -f "$cfg" ]] && command -v yq >/dev/null 2>&1; then
            v=$(yq e '.skills_reference_output // ""' "$cfg" 2>/dev/null)
            if [[ -n "$v" && "$v" != "null" ]]; then ref_output="$v"; break; fi
        fi
    done

    if "$INFRA_SRC/scripts/generate-skills-reference.sh" \
            --skills-dir "$CLAUDE_DIR/skills" \
            --output "$ref_output"; then
        log "Regenerated skills reference: $ref_output"
    else
        log "WARN: skills reference generation failed (continuing)."
    fi
else
    log "No .claude/skills/ — skipping skills reference generation."
fi

# ---------------------------------------------------------------------------
# 3. Validate skill YAML across the project (authoritative)
# ---------------------------------------------------------------------------
if [[ ! -d "$CLAUDE_DIR/skills" ]]; then
    log "No .claude/skills/ — nothing to validate."
    exit 0
fi

if command -v task >/dev/null 2>&1; then
    task -t "$CLAUDE_DIR/Taskfile.skills.yaml" validate-skill-yaml
else
    log "task (go-task) not found; running skill-yaml check directly."
    "$CLAUDE_DIR/scripts/check-skill-yaml.sh"
fi
