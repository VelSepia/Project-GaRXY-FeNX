# Capital Allocation Engine v1.0

Status: Phase3-5

## Mission

Distribute a normalized recommendation budget among eligible, ranked FX symbols. The engine produces percentages only. It does not read account data, calculate lots, calculate leverage or margin, inspect positions, or execute trades.

## Inputs and validation

The engine reads Market Selection eligibility, per-symbol Pair Ranking facts, Pair Ranking global validity, and the shared Environment market state and volatility only through `CDataBus`. Each required timestamp must be within the configured stale-data limit. Symbols are rejected safely when source data is missing, invalid, stale, ineligible, unranked, below the confidence threshold, or in a `VOLATILE` market state.

## Allocation score and penalties

`CapitalAllocationScore` begins with `PairRankingScore` scaled by `PairRankingConfidence`. It is then reduced by:

- a proportional high-volatility penalty above the configured high-volatility score;
- the transition-state penalty when `MarketState` is `TRANSITION`; and
- a freshness factor that declines toward zero at the stale-data limit.

`CapitalAllocationConfidence` is Pair Ranking confidence reduced only by freshness. These are factual allocation recommendations, not trading instructions.

## Normalization and caps

Candidates are ordered deterministically by allocation score, allocation confidence, lower pair rank, then symbol name. Only the configured maximum number is considered for funding. Their allocation scores are normalized over the total allocation budget with iterative redistribution when a candidate reaches its cap.

The effective per-symbol cap is the lower of `MaxPerSymbol` and `TotalBudget × ConcentrationLimit`. The concentration limit must be below 100%, so a single symbol cannot consume the entire budget. Allocations below the minimum threshold are removed and the remaining candidates are redistributed. This guarantees that funded allocations are at least the threshold, no allocation exceeds its cap, and total allocation never exceeds 100.0. Any unused normalized capacity remains in `UnallocatedPercent`.

## DataBus contract

Per-symbol results are written under `CapitalAllocation.<symbol>.<field>`: `Symbol`, `IsCapitalAllocated`, `CapitalAllocationPercent`, `CapitalAllocationScore`, `CapitalAllocationConfidence`, `CapitalAllocationReason`, and `CapitalAllocationUpdatedAt`.

Global results are `AllocatedSymbolCount`, `TotalAllocatedPercent`, `UnallocatedPercent`, `TopAllocatedSymbol`, `AllocationDataValid`, and `AllocationUpdatedAt`.

Phase3-9 Risk Engine will apply future safety controls. This engine does not make lot, margin, account, position, or order decisions.
