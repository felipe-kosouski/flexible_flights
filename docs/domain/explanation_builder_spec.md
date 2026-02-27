# Domain Test Spec — Explanation Builder (MVP)

**Governing documents:**

- Domain Spec — [Explanation Builder](explanation_builder.md)
- Domain Spec — [Scoring](../domain/scoring.md)
- Domain Spec — [Analysis](../domain/analysis.md)
- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [PRODUCT_GUIDE.md](../PRODUCT_GUIDE.md)

If conflicts exist, higher-level documents prevail.

---

## 1. Purpose of This Spec

This document defines **behavioral expectations and invariants** for the Explanation Builder domain.

It is not an implementation guide.
It defines **what must be true**, not how it is achieved.

---

## 2. Subject Under Test

```ruby
Search::Explanation::Builder
```

This spec validates:
- Deterministic explanation construction
- Correct decomposition of FinalScore
- Proper handling of baselines and tradeoffs
- Failure semantics

---

## 3. Required Collaborators (Test Doubles)

The Builder depends on the following domain inputs, all of which must be stubbed or constructed as domain objects:

- FlightSample
- SearchIntent
- AnalysisSnapshot
- ScoreResult (containing final score value and component scores)

No real providers, repositories, or Rails objects are allowed.
The Builder does not call scoring classes directly — component scores come from the ScoreResult.

---

## 4. Happy Path Behavior

### 4.1 Builds an Explanation for a Valid Flight

**Given**

- A valid FlightSample
- A SearchIntent
- A non-nil AnalysisSnapshot
- A FinalScore containing all component scores

**When**

- Builder.call is invoked

**Then**

- A FlightExplanation is returned
- The result is immutable
- The explanation references exactly one flight
- No domain state is modified

---

### 4.2 Includes a Complete Score Breakdown

**Given**

- A FinalScore with N component scores

**Then**

- score_breakdown contains exactly N entries
- Each entry includes:
  - dimension
  - raw_score
  - normalized_score
  - weight
  - weighted_contribution

**And**

- No inferred or synthetic dimensions appear
- Ordering is deterministic

---

### 4.3 Score Breakdown Matches FinalScore Math

**Then**

- Sum of weighted_contribution equals final_score.value (within rounding tolerance)
- Each weighted_contribution equals `normalized_score × weight`

---

## 5. Summary Construction

### 5.1 Summary Is Deterministic

**Given**

- Identical inputs

**Then**

- summary output must be identical across runs

---

### 5.2 Summary Reflects Dominant Factors

**Given**

- One or more dimensions contribute materially more than others

**Then**

- summary references those dominant dimensions via explanation keys
- summary does not mention insignificant dimensions

---

### 5.3 Summary Does Not Invent Information

**Then**

- summary content must be fully derivable from:
  - score_breakdown
  - detected tradeoffs
- No external data or heuristics are allowed

---

## 6. Tradeoff Detection

### 6.1 Detects Tradeoffs When Conditions Are Met

**Given**

- One dimension materially above baseline
- Another dimension materially below baseline
- Both meaningfully affect final score

**Then**

- At least one tradeoff is emitted
- Each tradeoff includes:
  - gained_dimension
  - sacrificed_dimension
  - severity
  - explanation_key

---

### 6.2 Does Not Emit Tradeoffs When Not Applicable

**Given**

- All dimensions near baseline
- Or imbalances do not affect final score materially

**Then**

- tradeoffs collection is empty

---

### 6.3 Tradeoff Severity Is Deterministic

**Then**

- Given identical inputs, severity must always resolve to the same value
- No random thresholds or adaptive behavior is allowed

---

## 7. Baseline Usage

### 7.1 Uses Baselines from AnalysisSnapshot Only

**Then**

- Price and duration baselines are read from AnalysisSnapshot
- No baseline recomputation occurs inside Builder

---

### 7.2 Handles Missing Baselines Gracefully

**Given**

- AnalysisSnapshot lacks a baseline value

**Then**

- Tradeoff detection degrades safely
- No exception is raised
- Explanation may omit certain tradeoffs

---

## 8. Failure Semantics

### 8.1 Returns Nil When FinalScore Is Missing

**Given**

- final_score is nil

**Then**

- Builder.call returns nil

---

### 8.2 Returns Nil When Component Scores Are Missing

**Given**

- FinalScore exists but lacks required component scores

**Then**

- Builder.call returns nil

---

### 8.3 Does Not Raise Domain Exceptions

**Then**

- Builder.call must not raise for invalid or incomplete input
- All failures are expressed via nil

---

## 9. Determinism

### 9.1 No Randomness

**Then**

- Builder must not use randomness, time, or external state

---

### 9.2 Pure Function Behavior

**Then**

- Builder output depends solely on provided inputs
- Identical inputs always produce identical output

---

## 10. Immutability Guarantees

### 10.1 Output Is Immutable

**Then**

- Attempting to mutate FlightExplanation raises or fails silently
- Collections inside explanation are frozen

---

### 10.2 Inputs Are Not Mutated

**Then**

- Builder does not modify:
  - FlightSample
  - SearchIntent
  - AnalysisSnapshot
  - FinalScore

---

## 11. Explicit Non-Goals (Test Scope)

This spec does NOT test:

- UI formatting
- Copy wording
- Internationalization
- Confidence aggregation
- Multi-flight comparison
- Persistence

---

## 12. Expected Test Structure

Tests should be organized as:

```text
spec/domain/search/explanation/builder_spec.rb
```

With contexts:
- happy path
- missing inputs
- tradeoff detection
- determinism
- immutability

---