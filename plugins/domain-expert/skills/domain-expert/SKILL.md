---
name: domain-expert
description: Domain knowledge discovery and guidance. Use when user says /domain, /domain configure, /domain learn, /domain explain, or /domain map.
user-invocable: true
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Domain Expert Skill

## Purpose

Discover, learn, and guide domain knowledge. Helps understand project concepts, terminology, and how to map requests to domain patterns.

## Quick Reference

- **Provides:** Domain knowledge, concept explanations, request mapping
- **Modes:** configure, learn, explain, map

## Modes Overview

| Mode | Command | Purpose |
|------|---------|---------|
| **configure** | `/domain configure` | Read domain knowledge from docs |
| **learn** | `/domain learn` | Infer domain from code analysis |
| **explain** | `/domain explain <concept>` | Answer questions about a concept |
| **map** | `/domain map <request>` | Map request to domain concepts |

---

### Configure Mode: `/domain configure` (Setup)

Discovers domain knowledge from existing documentation.

```bash
/domain configure
```

**What it checks:**
- CLAUDE.md (Domain section)
- README.md (Project overview)
- docs/domain.md, docs/glossary.md
- docs/ADR/*.md (Architecture Decision Records)

**Output:**
```
## Discovered Domain Knowledge

**Project:** E-commerce platform
**Confidence:** High (domain.md found)

### Glossary (12 terms)
| Term | Definition |
|------|------------|
| Customer | User who has made a purchase |
| Order | Customer's request to purchase items |
| Cart | Collection of items before checkout |

### Entities (5 found)
| Entity | Description | Key Attributes |
|--------|-------------|----------------|
| Customer | Registered user | id, email, tier |
| Order | Purchase request | id, status, items |

### Business Rules (3 found)
| Rule | Context |
|------|---------|
| Orders can only be cancelled within 24h | Order cancellation |

**Save this configuration?** [Confirm / Adjust]
```

---

### Learn Mode: `/domain learn`

Analyzes domain code to infer entities, relationships, and patterns.

```bash
# Analyze all domain code (default)
/domain learn --analyze

# Learn from specific file
/domain learn --from src/domain/order/order.ts
```

**What it analyzes by language:**

| Language | Paths Scanned | Patterns |
|----------|---------------|----------|
| TypeScript | src/domain/, src/entities/ | class, interface, type, enum |
| Python | domain/, models/ | class, @dataclass, BaseModel |
| Go | internal/domain/, pkg/domain/ | type struct, type interface |
| Rust | src/domain/, src/core/ | struct, enum, trait |
| Java | src/main/java/**/domain/ | class, interface, enum |

**Output:**
```
## Inferred Domain Knowledge

**Method:** Code analysis (23 files)
**Confidence:** Medium

### Entities (inferred)
| Name | Type | Attributes | Confidence |
|------|------|------------|------------|
| User | Entity | id, email, status | 95% |
| Order | Aggregate | id, items, total | 90% |
| Money | Value Object | amount, currency | 85% |

### Relationships
```
User ──1:N──> Order
Order ──1:N──> OrderItem
OrderItem ──N:1──> Product
```

### Naming Patterns
- Entities: PascalCase nouns (User, Order)
- Events: PascalCase past tense (OrderCreated)
- Commands: PascalCase imperative (CreateOrder)

**Save this configuration?** [Confirm / Adjust]
```

---

### Explain Mode: `/domain explain <concept>`

Explains a domain concept with full context.

```bash
/domain explain Order
/domain explain "value object"
```

**Output:**
```
## Domain Concept: Order

**Definition:** A customer's request to purchase one or more products.

**Type:** Aggregate Root

**Attributes:**
- id: Unique order identifier
- status: pending, confirmed, shipped, delivered, cancelled
- items: List of OrderItems
- total: Calculated total (Money)

**Relationships:**
- Belongs to: Customer
- Contains: OrderItem (1:N)

**Business Rules:**
- Cannot be modified after shipping
- Can only be cancelled within 24 hours
- Total must equal sum of items

**Code Location:** src/domain/order/order.ts
```

---

### Map Mode: `/domain map <request>`

Maps a user request to domain concepts (used by developer skill).

```bash
/domain map "Allow users to cancel orders and get refunds"
```

**Output:**
```
## Domain Mapping

**Request:** "Allow users to cancel orders and get refunds"

### Entities Involved
| Entity | Role |
|--------|------|
| User | Actor (who cancels) |
| Order | Target (what's cancelled) |
| Payment | Related (what's refunded) |

### Operations
| Operation | Type | Description |
|-----------|------|-------------|
| CancelOrder | Command | Change order status to cancelled |
| RefundPayment | Command | Initiate refund for payment |
| OrderCancelled | Event | Emitted after cancellation |

### Business Rules
- Can only cancel orders in pending/confirmed status
- Refund amount depends on cancellation timing
- Must notify customer of cancellation

### Code Locations
- Order: src/domain/order/order.ts
- Payment: src/domain/payment/payment.ts
```

---

## DDD Building Blocks

The skill categorizes discovered concepts using DDD patterns:

| Concept | Description | Indicators |
|---------|-------------|------------|
| **Entity** | Object with identity | Has id/uuid field |
| **Value Object** | Immutable, no identity | readonly, immutable |
| **Aggregate** | Cluster with root entity | Contains entities |
| **Repository** | Persistence interface | find, save, delete methods |
| **Service** | Stateless operations | Service suffix |
| **Event** | Something that happened | Past tense name |
| **Command** | Request to change state | Imperative name |

---

## Configuration

### Config Location

Config path depends on how the plugin was installed:

| Plugin Scope | Config File | Git |
|--------------|-------------|-----|
| **project** | `.claude/skills/domain-expert.yaml` | Committed (shared) |
| **local** | `.claude/skills/domain-expert.local.yaml` | Ignored (personal) |
| **user** | `.claude/skills/domain-expert.local.yaml` | Ignored (personal) |

**Precedence when reading** (first found wins):
1. `.claude/skills/domain-expert.local.yaml`
2. `.claude/skills/domain-expert.yaml`
3. Skill defaults

## Integration

The `domain-expert` skill integrates with:
- **developer** - Uses `/domain map` to understand requests
- **arch** - Domain is typically the innermost layer
- **code** - Domain code follows specific patterns
