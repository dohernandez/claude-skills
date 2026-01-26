#!/bin/bash
# ============================================================================
# POST-INSTALL SETUP
# ============================================================================
# Runs when user executes `claude --init` after installing the plugin.
# Validates prerequisites and guides users to run configuration.
#
# This hook:
# 1. Checks for required tools (Task)
# 2. Validates plugin structure
# 3. Reminds user to run /framework configure
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Claude Code Developer Framework - Post-Install Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# ============================================================================
# CHECK PREREQUISITES
# ============================================================================

ERRORS=0

# Check for Task (required for validation scripts)
if command -v task &> /dev/null; then
    echo -e "${GREEN}✓${NC} Task is installed"
else
    echo -e "${RED}✗${NC} Task is not installed"
    echo "  Install from: https://taskfile.dev/installation/"
    ERRORS=$((ERRORS + 1))
fi

# Check for jq (used by some scripts)
if command -v jq &> /dev/null; then
    echo -e "${GREEN}✓${NC} jq is installed"
else
    echo -e "${YELLOW}!${NC} jq is not installed (optional, but recommended)"
    echo "  Install: brew install jq (macOS) or apt install jq (Linux)"
fi

# Check for gh CLI (for PR skills)
if command -v gh &> /dev/null; then
    echo -e "${GREEN}✓${NC} GitHub CLI (gh) is installed"
else
    echo -e "${YELLOW}!${NC} GitHub CLI (gh) is not installed (required for PR skills)"
    echo "  Install from: https://cli.github.com/"
fi

echo ""

# ============================================================================
# VALIDATE PLUGIN STRUCTURE
# ============================================================================

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

if [[ -d "$PLUGIN_ROOT/skills" ]]; then
    SKILL_COUNT=$(find "$PLUGIN_ROOT/skills" -maxdepth 1 -type d | wc -l)
    SKILL_COUNT=$((SKILL_COUNT - 1))  # Subtract 1 for the skills directory itself
    echo -e "${GREEN}✓${NC} Found $SKILL_COUNT skills in plugin"
else
    echo -e "${RED}✗${NC} Skills directory not found"
    ERRORS=$((ERRORS + 1))
fi

if [[ -f "$PLUGIN_ROOT/Taskfile.yaml" ]]; then
    echo -e "${GREEN}✓${NC} Taskfile.yaml found"
else
    echo -e "${RED}✗${NC} Taskfile.yaml not found"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# ============================================================================
# SETUP INSTRUCTIONS
# ============================================================================

if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  Setup incomplete - please fix the errors above${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    exit 1
fi

echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Prerequisites verified successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "  1. Run the framework configuration wizard:"
echo ""
echo -e "     ${BLUE}/framework configure${NC}"
echo ""
echo "  This will:"
echo "    • Ask for project settings (name, lint/test commands)"
echo "    • Run /skill configure for each customizable skill"
echo "    • Save configuration to .claude/skills-config.env"
echo ""
echo "  Alternatively, configure individual skills:"
echo ""
echo -e "     ${BLUE}/tdd configure${NC}"
echo -e "     ${BLUE}/arch configure${NC}"
echo -e "     ${BLUE}/commit configure${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

exit 0
