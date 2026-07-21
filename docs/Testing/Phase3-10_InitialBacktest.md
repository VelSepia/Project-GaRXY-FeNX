# Phase3-10 Initial Backtest Preparation

## Safety first

Phase3-9.5 is an initial, minimal execution path intended for controlled Strategy Tester use. It is disabled by default and must not be treated as production-ready or used for unsupervised live trading. Start with visual testing and a demo environment only.

## Compile and configure

1. In MetaEditor, open `GaRXY_FeNX.mq5` from the project source tree and compile it with the MQL5 compiler.
2. Resolve any environment-specific standard-library or broker-symbol issues reported by MetaEditor before testing.
3. In MetaTrader 5 Strategy Tester, select the EA and a broker symbol named exactly `USDJPY`. This phase intentionally rejects suffixes such as `USDJPY.a`.
4. On Inputs, set `InpExecutionEnabled` to `true`. Keep `InpExecutionSymbol=USDJPY`, `InpExecutionMaximumOpenPositionsPerSymbol=1`, and initial `InpExecutionFixedLot=0.01`.
5. Begin with `InpExecutionExitMode=RANGE_BASED`, 20 maximum spread points, 60-second cooldown, and one order per bar enabled.

Native MetaEditor compilation is not performed by this repository-side implementation; perform the first step in the target MT5 installation.

## Suggested initial run

Use USDJPY on H1 first, with a quiet historical period that contains visible range-bound sections—for example, a one-to-three-month sample. Use a realistic spread model and enable visual mode for the first run. Start from the default threshold values and do not relax Risk or Standby controls merely to force trades.

## Expected behavior

The EA should normally block most ticks until all upstream phases have valid fresh snapshots. An order can occur only after a completed candle closes near a detected range boundary and all final permissions agree. A close near RangeLower may create a BUY intent; a close near RangeUpper may create a SELL intent; midpoint or non-boundary closes produce no trade. Each order has a broker-validated SL and TP. No second FeNX order can open while a USDJPY position exists.

## Logs and checks

Inspect tester logs for:

- `ExecutionEngine initialized` and whether execution is enabled.
- `Execution Gate blocked` reasons, especially stale data, Standby, or Risk blocks.
- `Execution request created`, accepted, or rejected results and retcodes.
- duplicate/cooldown blocks and existing-position detection.
- observed position-count changes after broker SL or TP closure.

Exercise BUY, SELL, midpoint no-trade, Standby block, Risk block, stale-data block, invalid SL/TP, reduced-risk volume, one-order-per-bar, and existing-position scenarios. Results should be deterministic for identical history, inputs, and tester conditions.

## Known limitations

There is no native compile result included here, no dynamic position management, no close-on-Standby, no exact transaction-level SL/TP attribution, no symbol suffix support, and no account/margin-aware sizing. Only bounded transient price-response retries are supported. No grids, martingale, averaging, pyramiding, multi-strategy, or multi-symbol execution is implemented.
