# Market Selection Engine v1.0

Status: Phase3-3

## Mission

Evaluate each configured FX symbol independently for participation suitability. The engine publishes factual eligibility results only; it does not rank candidates, allocate capital, choose a strategy, or execute trades.

## Configuration and scope

`CParameterManager` owns the symbol list, currently defaulting to the attached chart symbol and supporting up to four configured symbols. It also controls the minimum history, maximum point spread, maximum spread-to-ATR ratio, acceptable volatility band, minimum selection score, and the transition-state penalty.

Phase3-2 Environment Engines currently publish one attached-symbol snapshot. Market Selection consumes that snapshot only through `CDataBus` as a shared environment gate while it independently reads each configured symbol's availability, trade mode, history, and current bid/ask. Extending environment analysis to separate per-symbol snapshots is intentionally outside Phase3-3.

## Eligibility and score

The engine rejects a symbol safely when it is unavailable, cannot be selected for market data, is not open-tradable, lacks history, has invalid bid/ask data, exceeds a spread limit, lacks valid Environment data, or is in the `VOLATILE` market state.

For valid candidates, `MarketSelectionScore` is normalized to 0–100 and combines:

- point spread and spread relative to ATR (35%);
- volatility suitability within the configured band (25%); and
- range/trend suitability for the published market state (40%).

`TRANSITION` does not force rejection, but applies the configured score penalty. `MarketSelectionConfidence` combines environment confidence, available history depth, and the resulting selection score. A candidate must meet the configured selection-score threshold to be eligible.

## DataBus contract

Results are stored under `MarketSelection.<symbol>.<field>` and include `Symbol`, `IsMarketEligible`, `MarketSelectionScore`, `MarketSelectionConfidence`, `SpreadPoints`, `SpreadToATRRatio`, `RejectionReason`, and `MarketSelectionUpdatedAt`.

Phase3-4 will compare only these published eligibility facts. No pair-ranking logic exists in this engine.

