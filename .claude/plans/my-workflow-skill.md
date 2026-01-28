# Plan: my-workflow Skill Plugin

## Summary

Create a new `my-workflow` skill plugin, installed via the Claude Code plugin system (`/plugin install my-workflow@dohernandez-claude-skills`). When invoked (e.g., `/my-workflow install minimal`), it copies skills from the marketplace cache into the current project's `.claude/skills/` directory. Three tiers: Minimal, Standard, Advanced.

---

## Tier Composition

### Minimal (7 skills) — Essential tooling
Needs skill-tasks infrastructure (create-skill, docs-refresh).

| Skill | Configure? | Infra? |
|-------|-----------|--------|
| commit | no | — |
| pr-create | no | — |
| pr-merge | no | — |
| linear | no | — |
| memory | no | — |
| create-skill | no | skill-tasks |
| docs-refresh | yes | skill-tasks |

### Standard (17 skills) — Complete dev workflow
Extends Minimal (+10). Adds user-tasks infrastructure.

| Added Skill | Configure? | Infra? |
|-------------|-----------|--------|
| code | yes | — |
| bugfix | no | — |
| tdd | yes | — |
| arch | yes | — |
| domain-expert | no | — |
| task | yes | user-tasks |
| test | yes | user-tasks |
| setup | no | user-tasks |
| deploy | yes | — |
| deploy-verify | yes | — |

### Advanced (22 skills) — Everything
Extends Standard (+5).

| Added Skill | Configure? | Infra? |
|-------------|-----------|--------|
| developer | yes | user-tasks |
| workflow | no | — |
| workflow-setup | yes | — |
| workflow-finish | yes | — |
| debugger | yes | — |

Note: `slack` is excluded from all tiers (planned for future).

---

## Files to Create (8 new, 1 modified)

All new files under `plugins/my-workflow/`:

```
plugins/my-workflow/
├── .claude-plugin/plugin.json      # Plugin metadata
├── hooks/hooks.json                # Setup hook config
├── scripts/setup.sh                # Detects marketplace root, copies skill
└── skills/my-workflow/
    ├── SKILL.md                    # Usage docs + full procedure
    ├── skill.yaml                  # Tier defs, infra mappings, procedure
    ├── collaboration.yaml          # Triggers and boundaries
    ├── sharp-edges.yaml            # Edge cases (missing cache, permissions, etc.)
    └── validations.yaml            # Pre/post checks
```

Modified: `.claude-plugin/marketplace.json` — add `my-workflow` (and `memory`) entries.

---

## Key Design Decisions

### Source path detection
`setup.sh` detects the marketplace root from `CLAUDE_PLUGIN_ROOT`:
- **Marketplace cache**: go up to find the cache root containing sibling plugin directories
- **Local dev**: go up from `plugins/my-workflow/` to repo root
- Verify by checking for a known sibling (e.g., `commit/` or `plugins/commit/`)
- Save path to `.claude/skills/my-workflow/.marketplace-root`

### Skill source resolution
From the marketplace root, locate skill source files:
- Cache layout: `<root>/<skill-name>/<version>/skills/<skill-name>/`
- Local layout: `<root>/plugins/<skill-name>/skills/<skill-name>/`

### Already-installed handling
**Skip** — never overwrite. Report "Already installed: X (skipping)". User must delete the directory manually to reinstall.

### Infrastructure
Installed automatically when any selected skill needs it:
- **user-tasks** (developer, setup, task, test): `Taskfile.yaml` + `Taskfile.skills.yaml` + 9 scripts
- **skill-tasks** (create-skill, docs-refresh): `Taskfile.skills.yaml` + 9 scripts
- Source: `framework/` directory (local) or GitHub raw download fallback

### Configure offering
After installation, for each newly installed skill that has configure (12 total), ask the user one-by-one: "Run /X configure now? [y/n]". Show summary of unconfigured skills at the end.

---

## Commands

| Command | Purpose |
|---------|---------|
| `/my-workflow install` | Interactive wizard — choose tier or pick individual skills |
| `/my-workflow install minimal` | Install 7 essential skills |
| `/my-workflow install standard` | Install 17 dev workflow skills |
| `/my-workflow install advanced` | Install all 22 skills |
| `/my-workflow install <skill>` | Install a single specific skill |
| `/my-workflow list` | Show tiers and their skills |
| `/my-workflow status` | Show installed vs available |

### Wizard flow (`/my-workflow install`)
1. Show the 3 tiers with skill counts and descriptions
2. Ask: "Choose a tier, or select individual skills?"
3. If tier: install all skills in that tier
4. If individual: show all 22 skills, let user pick which ones to install

---

## Implementation Order

1. `plugins/my-workflow/.claude-plugin/plugin.json`
2. `plugins/my-workflow/hooks/hooks.json`
3. `plugins/my-workflow/scripts/setup.sh`
4. `plugins/my-workflow/skills/my-workflow/skill.yaml` (tier definitions, procedure)
5. `plugins/my-workflow/skills/my-workflow/SKILL.md` (usage docs, full procedure for AI)
6. `plugins/my-workflow/skills/my-workflow/collaboration.yaml`
7. `plugins/my-workflow/skills/my-workflow/sharp-edges.yaml`
8. `plugins/my-workflow/skills/my-workflow/validations.yaml`
9. Update `.claude-plugin/marketplace.json`

---

## Verification

1. Check plugin structure: all 8 files exist under `plugins/my-workflow/`
2. Verify `marketplace.json` is valid JSON with my-workflow entry
3. Verify tier counts: minimal=7, standard=17, advanced=22
4. Verify infrastructure mappings match analysis report
5. Verify configurable skills list matches the 12 from analysis report