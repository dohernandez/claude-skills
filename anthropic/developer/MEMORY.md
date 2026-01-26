# Developer Memory

Learnings captured from implementation sessions.

## Domain Implementation Patterns

- Domain entities cache stable data (identity) but fetch volatile data (status) on demand
- Factory functions: synchronous `fromX()` for simple construction, async `fromX()` when resolution is needed
- Separate state fetching into dedicated module (`state.ts`) - keeps entity class focused on coordination
- Use branded types for domain identifiers for type safety
- Context parameter should be first parameter on all async methods for consistency

## Review Process

- Always run pre-commit validation before committing
- Run linter before committing - fixes many style issues automatically
- Compare new implementations with existing modules for consistency
- Test coverage should include entity methods, factory functions, and edge cases

## Git Workflow

- **ALWAYS use `/commit` skill** for commits - it has validation rules and conventional commit formatting
- **ALWAYS use `/pr-create` skill** for PRs - it validates PR titles against CI checks and uses proper templates
- Never use raw `git commit` or `gh pr create` directly - the skills contain important instructions