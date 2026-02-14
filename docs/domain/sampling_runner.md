# Sampling Runner — Domain Specification

## Purpose

The Sampling Runner is the orchestration layer responsible for executing the
flight sampling pipeline.

It coordinates multiple domain components in a deterministic order to produce
a bounded set of normalized flight samples for a given search intent.

The runner does not implement business rules or heuristics itself.

---

## Responsibilities

The Sampling Runner is responsible for:

1. Generating all valid departure/return date pairs using `DateGrid`
2. Selecting a bounded subset of date pairs using `CandidateSelector`
3. Executing provider sampling via `Sampler`
4. Enforcing sampling limits (`max_candidates`)
5. Preserving deterministic execution and result ordering
6. Failing fast on domain or provider contract violations

---

## Non-Responsibilities

The Sampling Runner must NOT:

- Persist results
- Score or rank samples
- Retry provider failures
- Catch or swallow provider or domain errors
- Perform pricing analysis or heuristics
- Apply optimizations or recommendations
- Implement async or background execution

---

## Execution Pipeline

The runner executes the following pipeline in order:

Search Intent  
→ `DateGrid.generate`  
→ `CandidateSelector.select`  
→ `Sampler.call`  
→ Normalized Samples

Each step must complete successfully before the next step is executed.

---

## Inputs

The runner accepts the following inputs:

- `origin`
- `destination`
- `earliest_departure_date`
- `latest_departure_date`
- `min_stay_days`
- `max_stay_days`
- `max_candidates`
- `passengers`
- `cabin_class`
- `provider`

All inputs are required unless a default is explicitly defined.

---

## Outputs

- An array of normalized sample hashes
- An empty array if no valid date pairs or candidates exist

The runner does not return metadata, scores, or analysis results.

---

## Failure Modes

The runner must fail fast in the following situations:

- Provider returns a value that violates its contract
- Provider raises a runtime exception
- Domain collaborators raise errors
- Invalid domain inputs are provided

The runner must not rescue or suppress these failures.

---

## Ordering Guarantees

The Sampling Runner guarantees that:

- The order of date pairs produced by `DateGrid` is preserved
- The order of selected candidates from `CandidateSelector` is preserved
- The order of samples returned by `Sampler` is preserved

No internal reordering is allowed.

---

## Design Notes

The Sampling Runner exists to isolate orchestration logic from domain rules and
infrastructure concerns.

It provides a stable coordination boundary that allows future extensions such as:

- Asynchronous execution
- Retry strategies
- Persistence layers
- Multi-provider sampling
- Observability and metrics

The implementation is intentionally thin and should remain small and readable.