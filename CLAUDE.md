# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Development server
bin/dev                          # Starts Rails + Tailwind watcher (via Procfile.dev)

# Tests
bundle exec rspec                # Full test suite
bundle exec rspec spec/domain/   # Domain specs only
bundle exec rspec spec/path/to/file_spec.rb  # Single spec file

# Linting
bin/rubocop                      # Ruby style check
bin/rubocop -a                   # Auto-fix offenses

# Security scanning
bin/brakeman --no-pager          # Rails security static analysis
bin/bundler-audit                # Gem vulnerability scan

# Database
bin/rails db:migrate
```

## Architecture

This is a **modular monolith** with a rich domain layer. The strict layering is:

```
Controllers / Jobs
    ↓
Repositories  (only place transactions are opened, domain execution triggered, persistence coordinated)
    ↓
Domain Layer  (pure Ruby, no ActiveRecord, no DB access, no side effects)
    ↓
ActiveRecord Models  (validation + associations only — no business logic)
```

Dependencies only flow downward. Domain objects must never call repositories.

### Folder layout

```
app/
├── domain/search/               # All business logic lives here
│   ├── search_run.rb            # Aggregate root (states: initialized → sampling → completed/failed)
│   ├── search_execution.rb      # Pipeline orchestrator
│   ├── models/                  # Domain read models (NOT ActiveRecord — immutable projections)
│   ├── sampling/                # DateGrid → CandidateSelector → Sampler
│   ├── analysis/                # SnapshotBuilder (price percentiles, volatility, confidence)
│   ├── scoring/                 # PriceScore + TimeComfortScore + TripFit → FinalScore (0–100)
│   ├── explanation/             # Builder → human-readable flight explanations
│   ├── ranking/                 # Ranker → RankedFlight (score DESC, price ASC, stops ASC)
│   ├── factories/               # persistence → domain (one-way: from_record)
│   ├── mappers/                 # domain → persistence (one-way: apply)
│   └── repositories/            # SearchRunRepository wraps domain execution in transaction
│
└── models/                      # ActiveRecord: SearchRun, SearchIntent, FlightSample, AnalysisSnapshot
```

### Execution pipeline

```
Repository.execute(ar_record)
  → Factory.from_record → domain SearchRun
  → SearchExecution.execute
      → Sampling::Runner (DateGrid → CandidateSelector → Sampler → raw flights)
      → FlightSampleMapper (raw → domain FlightSample objects)
      → Analysis::SnapshotBuilder (market statistics)
      → Scoring::Scorer per flight
      → Explanation::Builder per flight
      → Ranking::Ranker
      → Insights::Builder (SearchInsights)
  → SearchRunMapper.apply (domain state → AR)
  → Persist FlightSamples + AnalysisSnapshot
  → Commit transaction
```

On failure: transaction rolls back, failed state is persisted **outside** the transaction, error is re-raised.

### Domain layer rules (non-negotiable)

The domain layer MUST NEVER:
- Use ActiveRecord or Rails APIs
- Perform I/O or read/write the database
- Call repositories
- Know about jobs, controllers, or background execution

Violations are architectural bugs, not style issues.

### Persistence pattern

Each domain module owns its adapters: Factory + Mapper + Repository.

- **Factory** — AR → Domain (one-way). Must not mutate AR objects. No saving, no transactions.
- **Mapper** — Domain → AR (one-way). No domain logic, no side effects beyond assignment.
- **Repository** — owns transactions, coordinates domain execution + persistence + error handling. Returns domain objects, never AR objects.

### State rules

- State transitions are explicit and spec-driven
- Terminal states (`completed`, `failed`) cannot be exited
- Domain objects manage in-memory state; AR reflects state after execution

### Validation split

- Domain validates **business invariants** (e.g. `max_stops >= 0`)
- ActiveRecord validates **data constraints** (e.g. presence, uniqueness)
- Overlap is allowed but intentional

### Naming rules

- Names must reflect business intent
- Avoid technical suffixes in domain code: no `Service`, no `Manager`
- Good: `SearchRun`, `Sampler`, `CandidateSelector` — Bad: `SearchRunService`, `SearchManager`
- `state` (not `status`) on SearchRun AR model
- `finished_at` (not `completed_at`)

### Authority hierarchy (conflict resolution)

1. `.cursor/rules/architecture.mdc`
2. Domain specs in `docs/domain/**`
3. `docs/PRD.md`
4. Implementation

Higher-level documents prevail.

## Testing Philosophy

Domain specs use **no database, no Rails, no mocks** — pure Ruby, deterministic, fast.

| Layer       | Stub         | Real   |
|-------------|--------------|--------|
| Domain      | nothing      | all    |
| Repository  | domain calls | AR     |
| Controllers | repository   | —      |

- Do not stub domain methods in domain specs
- Do not remove `pending` specs — they represent planned behavior
- Specs define behavior, not implementation
- Anti-patterns: over-mocking, testing private methods, testing Rails internals, specs that "pass by coincidence"

## Coding Guidelines

- Prefer guard clauses over nested conditionals
- Methods should be ≤ 10 lines; extract if longer
- Duplicate code is acceptable until the shared concept is clear — do not prematurely abstract
- Names must reflect business intent; avoid technical names in domain code
- Avoid magic numbers — use named constants
- Comments explain WHY, not WHAT; code explains WHAT
- Refactors must not change behavior; specs must remain green
- Do not invent behavior not described in domain specs or docs — ask when unsure
- `docs/` contains authoritative domain specs — consult before implementing anything in `app/domain/`
- `docs/PRODUCT_GUIDE.md` is the single source of truth for product behavior
