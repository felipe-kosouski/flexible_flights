# Domain Spec — SearchExecution (MVP)

**Governing documents:**

- PRODUCT_GUIDE.md
- PRD.md
- docs/domain/search_run.md
- docs/domain/scoring.md
- docs/domain/analysis.md

If conflicts exist, higher-level documents prevail.

---

## 1. Purpose

SearchExecution coordinates the **full pipeline** for one Smart Search.

It is responsible for:

- Orchestrating the sampling, mapping, analysis, scoring, explaining, and ranking phases
- Bridging raw sampling output to domain models
- Tracking overall pipeline state
- Producing structured results for the repository layer

SearchExecution is the **boundary object** between the repository and the domain pipeline.

---

## 2. Inputs

A SearchExecution is initialized with:

- **search_run** (Search::SearchRun) — a configured, unexecuted SearchRun
- **intent** (Search::Models::SearchIntent) — the domain search intent for scoring

---

## 3. Outputs

After execution, SearchExecution exposes:

- **results** — raw sampling hashes (delegated from SearchRun)
- **flight_samples** — Array of Search::Models::FlightSample domain objects
- **analysis_snapshot** — Search::Models::AnalysisSnapshot or nil
- **scored_results** — Array of Search::Scoring::ScoreResult objects (one per flight sample), or empty
- **explanations** — Array of Search::Explanation::FlightExplanation or nil (one per flight sample, nils preserved), or empty
- **ranked_results** — Array of Search::Ranking::RankedFlight objects, ordered by sort rules (see scoring.md Section 10), or empty

---

## 4. Pre-Conditions

- SearchRun must be in :initialized state
- SearchIntent must be a valid domain object
- No input validation occurs at this layer

---

## 5. Execution Lifecycle

### 5.1 States

- `initialized`
- `sampling`
- `mapping`
- `analyzing`
- `scoring`
- `explaining`
- `ranking`
- `completed`
- `failed`

### 5.2 Lifecycle Rules

1. A newly created SearchExecution starts in `initialized`
2. Calling `execute` transitions through phases in order
3. On successful completion, state becomes `completed`
4. If any error is raised at any phase, state becomes `failed`
5. The error is re-raised

---

## 6. Execution Flow

When `execute` is called:

1. Transition to `sampling` — execute the SearchRun
2. Transition to `mapping` — convert raw hashes to FlightSample domain models via FlightSampleMapper
3. Transition to `analyzing` — build AnalysisSnapshot from flight samples
4. Transition to `scoring` — score each flight sample (skipped if analysis is nil); produces ScoreResult objects
5. Transition to `explaining` — build a FlightExplanation (or nil) for each scored flight, preserving array length (skipped if analysis is nil)
6. Transition to `ranking` — sort by final_score DESC, price_cents ASC, stops ASC (per scoring.md Section 10); produce RankedFlight list
7. Transition to `completed`
8. Return `self`

If an error occurs at any step:

- Set error
- Transition to `failed`
- Re-raise the error

---

## 7. Collaborators

SearchExecution depends on:

- `Search::SearchRun`
- `Search::Mappers::FlightSampleMapper`
- `Search::Analysis::SnapshotBuilder`
- `Search::Scoring::Scorer`
- `Search::Explanation::Builder`
- `Search::Ranking::Ranker`

---

## 8. Nil Analysis Handling

When SnapshotBuilder returns nil (insufficient data):

- analysis_snapshot remains nil
- scored_results remains empty
- explanations remains empty
- ranked_results remains empty
- Execution completes successfully
- No scoring, explaining, or ranking is attempted

---

## 9. What SearchExecution Must NOT Do

- Persist data
- Perform I/O
- Retry failed operations
- Run asynchronously
- Modify sampling output
- Know about ActiveRecord

It delegates all domain logic to its collaborators.

---

## 10. Determinism

Given identical inputs and identical collaborator behavior:

- All outputs must be identical
- Phase ordering must be identical
- No randomness is allowed

---

## 11. Domain Object Definition

**Namespace:** Search::SearchExecution

**Public API:**

```ruby
def initialize(search_run:, intent:)
end

def execute
  # executes full pipeline, returns self
end
```

---

## 12. Implementation Instructions

When implementing:

- Follow this document strictly
- Do not add persistence
- Do not add retries or async
- Ask before extending behavior

---

End of document.
