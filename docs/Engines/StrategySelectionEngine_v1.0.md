# Strategy Selection Engine v1.0

Status: Phase3-7

## Mission

Select one recommended strategy for each valid, allocated symbol using only published `CDataBus` facts. The supported recommendations are `RANGE_MEAN_REVERSION`, `TREND_FOLLOWING`, `BREAKOUT`, `HYBRID_ADAPTIVE`, and `NO_TRADE`. This engine does not define entry or exit conditions, calculate stops, targets, lots, risk, or capital, access account state, or execute trades.

## Inputs and safety validation

The engine consumes Trading Style, Environment, Pair Ranking, and Capital Allocation records through `CDataBus` only. Environment range/trend validity, all upstream global validity flags, and every required timestamp must be valid and fresh. Any missing, malformed, invalid, or stale record publishes `NO_TRADE` with `IsStrategySelectionValid=false`.

Complete source data can still yield a valid `NO_TRADE` recommendation. This happens when Trading Style is `STANDBY`, a symbol is unallocated or unranked, allocation or Pair Ranking score is below its threshold, the raw style confidence is too low, post-penalty confidence is below the safety threshold, or no mapping matches the factual market state.

## Strategy mapping

1. `BREAKOUT` takes precedence when volatility meets the breakout threshold and either a `TREND` style has strong directional evidence in `TRENDING`, or a `HYBRID` style has mixed range/trend evidence in `TRANSITION`.
2. `RANGE_MEAN_REVERSION` requires `RANGE` style, `RANGING` state, and a RangeScore at or above the range threshold.
3. `TREND_FOLLOWING` requires `TREND` style, `TRENDING` state, and a TrendScore at or above the trend threshold.
4. `HYBRID_ADAPTIVE` requires `HYBRID` style and `TRANSITION` state with both range and trend evidence at least 70% of their configured thresholds.
5. All other cases are `NO_TRADE`.

`StrategySelectionConfidence` begins with Trading Style confidence, declines proportionally toward zero at the stale-data limit, and receives the transition penalty in `TRANSITION`. `StrategySelectionScore` is a normalized blend of market signal (40%), Trading Style score (25%), Pair Ranking score (20%), and selection confidence (15%).

## Parameters

- `StrategySelectionMinConfidence` rejects low-confidence Trading Style input.
- `StrategySelectionMinAllocationPercent` and `StrategySelectionMinRankingScore` prevent recommendations for weakly funded or ranked symbols.
- `StrategySelectionRangeThreshold` and `StrategySelectionTrendThreshold` control the range/trend mappings.
- `StrategySelectionBreakoutVolatilityThreshold` controls the strong-volatility breakout gate.
- `StrategySelectionTransitionPenalty` reduces confidence in transition conditions.
- `StrategySelectionStaleDataLimitSeconds` rejects stale records.
- `StrategySelectionNoTradeSafetyThreshold` is the post-penalty confidence floor.

## DataBus contract

Per-symbol results are published under `StrategySelection.<symbol>.<field>`: `SelectedStrategy`, `StrategySelectionScore`, `StrategySelectionConfidence`, `StrategySelectionReason`, `IsStrategySelectionValid`, and `StrategySelectionUpdatedAt`.

Global results are `ActiveStrategyCount`, `NoTradeSymbolCount`, `StrategySelectionDataValid`, and `StrategySelectionUpdatedAt`.

Phase3-8 may consume these recommendations to coordinate priority decisions. This engine does not choose entries or execute trades.

