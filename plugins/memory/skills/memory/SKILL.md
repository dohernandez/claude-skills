---
name: memory
description: Orchestrate knowledge capture across skills. Routes learnings to appropriate MEMORY.md files. Use when user says /memory.
user-invocable: true
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]
---

# Memory

## Purpose

Centralized knowledge management for the skill ecosystem. Captures learnings from development sessions and routes them to the appropriate skill's MEMORY.md file based on knowledge type.

## Quick Reference

- **Capture**: `/memory capture "learned X"` - Route learning to appropriate skill
- **Review**: `/memory review [skill]` - Show accumulated knowledge
- **Consolidate**: `/memory consolidate` - Deduplicate and organize

## Commands

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/memory capture "..."` | Capture a learning | During/after development when something is learned |
| `/memory review` | Review all learnings | To refresh knowledge before starting work |
| `/memory review <skill>` | Review skill-specific learnings | Before using a specific skill |
| `/memory consolidate` | Clean up and organize | Periodically, or when memory feels cluttered |

---

## Memory Scopes

Knowledge is routed based on its type:

### Sub-Skill Memory (HOW knowledge)

Domain-specific knowledge about how to do things.

| Skill | Content Types |
|-------|---------------|
| `bugfix` | Debugging patterns, root cause analysis techniques |
| `tdd` | Test patterns, TDD workflow refinements |
| `arch` | Architecture decisions, layer boundary learnings |
| `code` | Code style patterns, language idioms |
| `debugger` | Production debugging, log analysis techniques |

### Orchestrator Memory (WHEN/ORDER knowledge)

Workflow knowledge about when and in what order to do things.

| Skill | Content Types |
|-------|---------------|
| `developer` | Development workflow orchestration |
| `task` | Task management and prioritization |
| `workflow` | Multi-skill coordination patterns |

---

## /memory capture

Capture a learning and route it to the appropriate skill's MEMORY.md.

### Usage

```
/memory capture "Always run tests before commit"
```

### Routing Logic

The skill analyzes your learning to determine where it belongs:

```
Is this about HOW to do something?
├── Yes → Sub-skill memory
│   ├── Debugging → bugfix
│   ├── Testing → tdd
│   ├── Architecture → arch
│   ├── Code style → code
│   └── Production → debugger
└── No → Is this about WHEN/ORDER?
    ├── Yes → Orchestrator memory
    │   ├── Development process → developer
    │   ├── Task organization → task
    │   └── Skill coordination → workflow
    └── Unclear → Ask user to clarify
```

### Routing Indicators

**Sub-skill indicators:**
- "I learned that..."
- "The trick to..."
- "When doing X, always..."
- "Never do X because..."
- "Pattern: ..."
- "Gotcha: ..."

**Orchestrator indicators:**
- "Before doing X, first..."
- "After X, always do Y..."
- "The order should be..."
- "When X happens, trigger Y..."

### Example Routing

| Learning | Scope | Target |
|----------|-------|--------|
| "Use vi.fn() for mocking in vitest" | HOW | tdd |
| "Run /arch check before implementation" | WHEN | developer |
| "Mock at boundaries, not internals" | HOW | tdd |
| "Debug async by logging promise chain" | HOW | bugfix |
| "Always do TDD before writing handlers" | WHEN | developer |

### When Routing is Unclear

If the learning could apply to multiple skills, the memory skill will ask:

```
This learning could apply to:
- code (style enforcement)
- arch (layer boundary rule)

Which scope is most appropriate?
```

---

## /memory review

Review accumulated knowledge, either all or for a specific skill.

### Usage

```
# Review all knowledge
/memory review

# Review specific skill
/memory review tdd
```

### Output Format

```
## TDD Learnings

### Patterns (3)
- Use describe blocks for logical grouping...
- Mock at boundaries, not internal functions...
- Always test edge cases: null, empty, boundary values

### Gotchas (2)
- Vitest requires explicit reset between tests...
- Don't mock what you don't own...

### Best Practices (1)
- Test behavior, not implementation...
```

---

## /memory consolidate

Deduplicate and organize learnings across all MEMORY.md files.

### Usage

```
/memory consolidate
```

### What It Does

1. Scans all skill directories for MEMORY.md files
2. Parses all entries
3. Identifies duplicates and near-duplicates
4. Proposes merges and reorganizations
5. Waits for user approval
6. Applies approved changes

### Example Output

```
Scanning 8 MEMORY.md files...

Found:
- 23 total entries
- 3 exact duplicates
- 5 near-duplicates (similar content)

Proposed changes:
- Merge 2 entries in tdd/MEMORY.md (same concept, different wording)
- Remove 1 duplicate in bugfix/MEMORY.md
- Recategorize 2 entries in developer/MEMORY.md (workflow -> pattern)

Apply changes? [Y/n]
```

---

## MEMORY.md Format

Entries are stored in a consistent format:

```markdown
## 2024-01-26 - pattern

**Context**: Debugging async race conditions in test suite

**Learning**: Always log the promise chain order first before adding
breakpoints. The execution order is often not what you expect.

**Tags**: #debugging #async #testing

---
```

### Categories

| Category | Description |
|----------|-------------|
| `pattern` | Reusable approach that works |
| `gotcha` | Edge case or pitfall to avoid |
| `best_practice` | Recommended approach |
| `anti_pattern` | What NOT to do |
| `workflow` | Process/sequencing knowledge |
| `tool` | Tool-specific knowledge |
| `project` | Project-specific (not universal) |

---

## Best Practices

### Be Specific

```
Bad:  "Remember to test edge cases"
Good: "When testing date parsing, always include: empty string, null,
       invalid format, timezone edge cases (midnight, DST transitions)"
```

### Include Context

```
Bad:  "Use retry logic"
Good: "When calling external APIs in handlers, use retry with exponential
       backoff (3 attempts, 100ms base) - learned from production timeout
       issues in payment service"
```

### Tag Appropriately

- `#project` - Project-specific (won't apply elsewhere)
- `#universal` - General pattern (applies broadly)
- `#language:go` - Language-specific
- `#tool:vitest` - Tool-specific

---

## Anti-Patterns

| Don't | Why | Do Instead |
|-------|-----|------------|
| Capture without routing | Becomes unsearchable | Let memory skill route appropriately |
| Add duplicates | Clutters memory | Run `/memory consolidate` periodically |
| Vague learnings | Not actionable later | Include specific context and examples |
| Wrong scope | Won't be found | HOW = sub-skill, WHEN = orchestrator |

---

## Integration with Skills

The memory skill works with all other skills. Each skill can have its own MEMORY.md file:

```
.claude/skills/
├── bugfix/
│   ├── SKILL.md
│   ├── skill.yaml
│   └── MEMORY.md      <- Debugging knowledge
├── tdd/
│   ├── SKILL.md
│   ├── skill.yaml
│   └── MEMORY.md      <- Testing knowledge
├── developer/
│   ├── SKILL.md
│   ├── skill.yaml
│   └── MEMORY.md      <- Workflow knowledge
└── memory/
    ├── SKILL.md
    └── skill.yaml     <- This skill (routes to others)
```

---

## Example Session

```
User: /memory capture "When using vitest, always call vi.clearAllMocks()
       in beforeEach to avoid test pollution"

Memory: Analyzing learning...
        - Topic: Testing/mocking
        - Scope: HOW to handle mocks correctly
        - Tool: vitest

        Routing to: tdd/MEMORY.md
        Category: gotcha

        Added entry:

        ## 2024-01-26 - gotcha

        **Context**: Vitest mock behavior between tests

        **Learning**: Always call vi.clearAllMocks() in beforeEach
        to avoid test pollution. Mock state persists between tests
        by default.

        **Tags**: #vitest #mocking #testing #universal

        ---

User: /memory review tdd

Memory: ## TDD Learnings (4 entries)

        ### Gotchas (2)
        - vi.clearAllMocks() in beforeEach...
        - Mock timers need vi.useRealTimers() cleanup...

        ### Patterns (2)
        - Use describe blocks to group related tests...
        - Mock at boundaries (API clients, not internal)...
```
