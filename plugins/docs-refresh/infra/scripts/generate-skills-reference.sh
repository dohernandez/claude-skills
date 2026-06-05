#!/usr/bin/env bash
#
# generate-skills-reference.sh
# Generate a markdown reference document from skill.yaml files
#
# Usage:
#   ./generate-skills-reference.sh [--output PATH] [--skills-dir PATH]
#
# Options:
#   --output PATH      Output file (default: docs/skills/REFERENCE.md)
#   --skills-dir PATH  Skills directory (default: .claude/skills)
#
# The script scans all skill.yaml files and generates a markdown document
# with skill names, descriptions, ownership, and patterns.

# NOTE: intentionally no `-e`. This script does best-effort text extraction with
# grep on optional fields; a non-matching grep in a command substitution must not
# abort generation. The one hard precondition (skills dir exists) is checked below.
set -uo pipefail

# Defaults
OUTPUT_FILE="docs/skills/REFERENCE.md"
SKILLS_DIR=".claude/skills"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --skills-dir)
      SKILLS_DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Check if skills directory exists
if [[ ! -d "$SKILLS_DIR" ]]; then
  echo "Skills directory not found: $SKILLS_DIR" >&2
  exit 1
fi

# Create output directory if needed
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"

# Start generating the reference document
{
  echo "# Skills Reference"
  echo ""
  echo "> Auto-generated from skill.yaml files. Do not edit manually."
  echo ">"
  echo "> Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo ""
  echo "## Overview"
  echo ""
  echo "| Skill | Description | Kind |"
  echo "|-------|-------------|------|"

  # First pass: generate overview table
  for skill_dir in "$SKILLS_DIR"/*/; do
    [[ -d "$skill_dir" ]] || continue

    skill_name=$(basename "$skill_dir")

    # Skip if no skill.yaml
    if [[ ! -f "$skill_dir/skill.yaml" ]]; then
      # Try to get info from SKILL.md frontmatter
      if [[ -f "$skill_dir/SKILL.md" ]]; then
        description=$(grep -A 10 '^---$' "$skill_dir/SKILL.md" | grep '^description:' | sed 's/^description: *//' | sed 's/"//g' | head -1)
        [[ -z "$description" ]] && description="No description"
        echo "| \`$skill_name\` | $description | - |"
      fi
      continue
    fi

    # Extract from skill.yaml
    description=$(grep '^description:' "$skill_dir/skill.yaml" | sed 's/^description: *//' | sed 's/"//g' | head -1)
    kind=$(grep '^kind:' "$skill_dir/skill.yaml" | sed 's/^kind: *//' | head -1)

    [[ -z "$description" ]] && description="No description"
    [[ -z "$kind" ]] && kind="-"

    # Truncate long descriptions
    if [[ ${#description} -gt 80 ]]; then
      description="${description:0:77}..."
    fi

    echo "| \`$skill_name\` | $description | $kind |"
  done

  echo ""
  echo "## Skill Details"
  echo ""

  # Second pass: generate detailed sections
  for skill_dir in "$SKILLS_DIR"/*/; do
    [[ -d "$skill_dir" ]] || continue

    skill_name=$(basename "$skill_dir")
    skill_yaml="$skill_dir/skill.yaml"
    skill_md="$skill_dir/SKILL.md"

    echo "### $skill_name"
    echo ""

    if [[ -f "$skill_yaml" ]]; then
      # Extract fields from skill.yaml
      description=$(grep '^description:' "$skill_yaml" | sed 's/^description: *//' | sed 's/"//g' | head -1)
      kind=$(grep '^kind:' "$skill_yaml" | sed 's/^kind: *//' | head -1)
      version=$(grep '^version:' "$skill_yaml" | sed 's/^version: *//' | sed 's/"//g' | head -1)

      [[ -n "$description" ]] && echo "**Description:** $description"
      echo ""
      [[ -n "$kind" ]] && echo "- **Kind:** $kind"
      [[ -n "$version" ]] && echo "- **Version:** $version"

      # Extract ownership
      if grep -q '^owns:' "$skill_yaml"; then
        echo "- **Owns:**"
        grep -A 20 '^owns:' "$skill_yaml" | grep '^ *- ' | head -10 | sed 's/^ *- /  - /'
      fi

      # Check for user-invocable in SKILL.md frontmatter
      if [[ -f "$skill_md" ]]; then
        user_invocable=$(grep -A 10 '^---$' "$skill_md" | grep '^user-invocable:' | sed 's/^user-invocable: *//' | head -1)
        [[ "$user_invocable" == "true" ]] && echo "- **User-invocable:** Yes (use \`/$skill_name\`)"
      fi

    elif [[ -f "$skill_md" ]]; then
      # Fallback to SKILL.md frontmatter
      description=$(grep -A 10 '^---$' "$skill_md" | grep '^description:' | sed 's/^description: *//' | sed 's/"//g' | head -1)
      [[ -n "$description" ]] && echo "**Description:** $description"
      echo ""

      user_invocable=$(grep -A 10 '^---$' "$skill_md" | grep '^user-invocable:' | sed 's/^user-invocable: *//' | head -1)
      [[ "$user_invocable" == "true" ]] && echo "- **User-invocable:** Yes (use \`/$skill_name\`)"
    else
      echo "*No skill.yaml or SKILL.md found*"
    fi

    echo ""
    echo "---"
    echo ""
  done

  echo "## File Locations"
  echo ""
  echo "- Skills directory: \`$SKILLS_DIR\`"
  echo "- This reference: \`$OUTPUT_FILE\`"
  echo ""
  echo "## Regenerating This Document"
  echo ""
  echo "\`\`\`bash"
  echo "task -t .claude/Taskfile.skills.yaml skills-reference"
  echo "\`\`\`"

} > "$OUTPUT_FILE"

echo "Generated: $OUTPUT_FILE"
