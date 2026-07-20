# Trading Style Engine v1.0

Status: Phase3-6

## Mission

Select one non-executable style recommendation for each configured, capital-allocated symbol. The engine publishes `RANGE`, `TREND`, `HYBRID`, or `STANDBY` only. It does not select a strategy, alter capital, calculate lots or risk, access account state, or execute trades.

## Inputs and freshness

The engine consumes only factual records from `CDataBus`: the unified Environment state, range/trend validity and scores, volatility, Environment and upstream confidence, Pair Ranking rank/score/confidence, and Capital Allocation percent/score/confidence. Environment, Pair Ranking, and Capital Allocation global validity records plus all required timestamps must be valid and fresh. Missing, malformed, or stale input produces `STANDBY` with `IsTradingStyleValid=false`.

Symbols with complete data but no active allocation also receive `STANDBY`; this is a valid non-participation recommendation and keeps `StyleDataValid=true` when the source records are sound.

## Decision tree

1. `STANDBY` when data is invalid or stale, the symbol is unallocated or unranked, its allocation is below the minimum, the market is `VOLATILE`, or volatility is above the configured limit.
2. `RANGE` when `MarketState=RANGING`, `RangeScore`, and the combined style confidence meet the range-confidence threshold.
3. `TREND` when `MarketState=TRENDING`, `TrendScore`, `TrendConfidence`, and combined style confidence meet the trend-confidence threshold.
4. `HYBRID` only in `TRANSITION` when both range and trend evidence meet 70% of their configured thresholds after the transition penalty.
5. Otherwise, publish a valid `STANDBY` recommendation.

`TradingStyleScore` is a normalized blend of the relevant environment signal (50%), Pair Ranking score (20%), Capital Allocation score (20%), and adjusted style confidence (10%). Style confidence is the lowest Environment, Pair Ranking, and Capital Allocation confidence, reduced progressively by data age and, in `TRANSITION`, by the transition penalty.

## Parameters

- `TradingStyleTrendConfidenceThreshold` controls the strong-trend gate.
- `TradingStyleRangeConfidenceThreshold` controls the range gate; `RangeScore` is the available Phase3-2 range-confidence measure.
- `TradingStyleMaxVolatilityScore` defines the unsafe volatility boundary.
- `TradingStyleTransitionPenalty` reduces confidence in mixed transition conditions.
- `TradingStyleStaleDataLimitSeconds` rejects stale records, while `TradingStyleStaleDataPenalty` progressively reduces confidence before that limit.
- `TradingStyleMinAllocationPercent` prevents a style recommendation from activating on a negligible allocation.

## DataBus contract

Per-symbol results are published under `TradingStyle.<symbol>.<field>`: `TradingStyle`, `TradingStyleScore`, `TradingStyleConfidence`, `TradingStyleReason`, `TradingStyleUpdatedAt`, and `IsTradingStyleValid`.

Global results are `ActiveTradingStyleCount`, `StyleDataValid`, and `TradingStyleUpdatedAt`.

Phase3-7 may consume these recommendations to select a strategy. This engine makes no strategy or trading decision.

