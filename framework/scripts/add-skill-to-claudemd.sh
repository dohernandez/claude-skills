#!/bin/bash
# ============================================================================
# ADD SKILL TO CLAUDE.MD
# ============================================================================
# Ensures a skill is documented in CLAUDE.md
#
# Usage:
#     ./add-skill-to-claudemd.sh --skill commit
#     ./add-skill-to-claudemd.sh --skill commit --description "Git commits"
#
# If no description provided, reads from .claude/skills/<skill>/SKILL.md
# If CLAUDE.md doesn't have a skills table, creates one.
# If skill is already listed, does nothing.
# ============================================================================

set -uo pipefail

log_info() { echo "[INFO] $1"; }
log_success() { echo "[OK] $1"; }

SKILL_NAME=""
SKILL_DESCRIPTION=""
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-${PWD}}"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
SKILLS_DIR="$PROJECT_ROOT/.claude/skills"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skill)
            SKILL_NAME="$2"
            shift 2
            ;;
        --description)
            SKILL_DESCRIPTION="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [[ -z "$SKILL_NAME" ]]; then
    exit 0  # No skill specified, silently exit
fi

# Try to get description from SKILL.md if not provided
if [[ -z "$SKILL_DESCRIPTION" ]]; then
    local_skillmd="$SKILLS_DIR/$SKILL_NAME/SKILL.md"
    if [[ -f "$local_skillmd" ]]; then
        # Extract description from frontmatter
        SKILL_DESCRIPTION=$(sed -n '/^---$/,/^---$/p' "$local_skillmd" | grep -E '^description:' | sed 's/^description:[[:space:]]*//' | sed 's/^"//;s/"$//' | head -1)
    fi
fi

# Default description if still not found
if [[ -z "$SKILL_DESCRIPTION" ]]; then
    SKILL_DESCRIPTION="Use /$SKILL_NAME for assistance"
fi

# Truncate description if too long for table
if [[ ${#SKILL_DESCRIPTION} -gt 80 ]]; then
    SKILL_DESCRIPTION="${SKILL_DESCRIPTION:0:77}..."
fi

# Skills table header
SKILLS_TABLE_HEADER="## Available Skills

| Skill | When to Use |
|-------|-------------|"

# Check if CLAUDE.md exists
if [[ ! -f "$CLAUDE_MD" ]]; then
    log_info "Creating CLAUDE.md with skills table..."
    cat > "$CLAUDE_MD" << EOF
# CLAUDE.md

Project instructions for Claude Code.

$SKILLS_TABLE_HEADER
| \`$SKILL_NAME\` | $SKILL_DESCRIPTION |
EOF
    log_success "Created CLAUDE.md with skill: $SKILL_NAME"
    exit 0
fi

# Check if skill is already documented
if grep -q "\`$SKILL_NAME\`" "$CLAUDE_MD" 2>/dev/null; then
    # Skill already documented
    exit 0
fi

# Check if skills table exists
if grep -q "## Available Skills" "$CLAUDE_MD" 2>/dev/null || grep -q "| Skill |" "$CLAUDE_MD" 2>/dev/null; then
    # Table exists, add skill to it
    if grep -q "|-------|" "$CLAUDE_MD"; then
        # Insert after the header separator line
        # Use a temp file for compatibility
        tmp_file=$(mktemp)
        awk -v skill="$SKILL_NAME" -v desc="$SKILL_DESCRIPTION" '
            /\|-------\|/ { print; print "| `" skill "` | " desc " |"; next }
            { print }
        ' "$CLAUDE_MD" > "$tmp_file"
        mv "$tmp_file" "$CLAUDE_MD"
        log_success "Added $SKILL_NAME to CLAUDE.md skills table"
    fi
else
    # No skills table, append one at the end
    cat >> "$CLAUDE_MD" << EOF

$SKILLS_TABLE_HEADER
| \`$SKILL_NAME\` | $SKILL_DESCRIPTION |
EOF
    log_success "Added skills table to CLAUDE.md with: $SKILL_NAME"
fi
