# Minimal Execution Framework v1.0

## Scope

Phase3-9.5 introduces the first deliberately constrained executable path for GaRXY FeNX. It can submit one market order for `USDJPY` only, using `RANGE_MEAN_REVERSION` only. It does not implement grids, averaging, martingale, pyramiding, multi-symbol execution, adaptive layers, or position-closing logic.

Execution is disabled by default. Enable `InpExecutionEnabled` only in Strategy Tester after compiling and reviewing the safety controls.

## Components and lifecycle

`CExecutionEngine` is registered after `CStandbyEngine` and `CRiskEngine`. On each framework update the existing analysis, selection, allocation, style, strategy, Standby, and Risk engines publish their snapshots first. The execution engine then follows this sequence:

1. `CExecutionGate` verifies the StateManager state and all required, fresh DataBus permissions.
2. `CRangeMeanReversionStrategy` inspects one completed candle and produces an intent only.
3. `CPositionManager` blocks a new order when any USDJPY position exists.
4. `CDuplicateOrderGuard` enforces cooldown, request identity, near-price, and optional one-order-per-bar rules.
5. `COrderExecutor` is the sole component that may use `CTrade` to submit a BUY or SELL.

`CTradeResultLogger` suppresses repeated identical messages while retaining initialization, blocks, requests, results, observed position changes, and shutdown totals.

## Non-negotiable execution gate

An entry requires all of the following: `NORMAL` framework state; execution symbol `USDJPY`; spread within the configured maximum; fresh and valid range, market selection, ranking, allocation, trading-style, strategy-selection, Standby, and Risk snapshots; a `RANGING` market; eligible, ranked, and allocated symbol; valid `RANGE` style; valid `RANGE_MEAN_REVERSION` strategy; inactive Standby; approved new entries; Risk system trading and new-entry permission; and Risk action `ALLOW` or `ALLOW_REDUCED`.

Risk is authoritative. For `ALLOW_REDUCED`, the requested fixed lot is multiplied by the lower of the symbol and system allocation multipliers, never increased, and then normalized. A volume below the broker minimum is rejected.

## Requests and protection

The initial volume is the configurable fixed lot (default `0.01`), validated against `SYMBOL_VOLUME_MIN`, `SYMBOL_VOLUME_MAX`, and `SYMBOL_VOLUME_STEP`.

`RANGE_BASED` is the default exit mode:

- BUY: stop below `RangeLower` by `InpExecutionRangeStopBufferPoints`; take profit at `RangeMidpoint`.
- SELL: stop above `RangeUpper` by the same buffer; take profit at `RangeMidpoint`.

`FIXED_POINTS` uses the configured fixed stop-loss and take-profit distances instead. Before a request is sent, prices are normalized to symbol digits and must satisfy `SYMBOL_TRADE_STOPS_LEVEL`. Invalid protection is blocked, never silently adjusted.

## Position safety

FeNX positions are identified by configured magic number and USDJPY symbol. The implementation permits at most one FeNX position. It also conservatively blocks a new entry if *any* USDJPY position exists, including a manual or another-EA position; it never modifies, closes, or otherwise interferes with that position. Standby and Risk blocks prevent new entries only and do not close existing positions.

## DataBus contract

Per symbol in namespace `Execution`: `ExecutionGateAllowed`, `ExecutionGateReason`, `EntrySignal`, `EntrySignalScore`, `EntrySignalConfidence`, `RequestedDirection`, `RequestedVolume`, `RequestedEntryPrice`, `RequestedStopLoss`, `RequestedTakeProfit`, `DuplicateOrderBlocked`, `ExistingPositionDetected`, `LastOrderRequestAt`, `LastExecutionResult`, `LastExecutionRetcode`, `LastExecutionDealTicket`, `ExecutionDataValid`, and `ExecutionUpdatedAt`.

Global keys: `ExecutionSystemEnabled`, `ExecutionSystemReady`, `ExecutionSystemValid`, `OpenFeNXPositionCount`, `SuccessfulOrderCount`, `FailedOrderCount`, `BlockedOrderCount`, and `LastGlobalExecutionAt`.

The DataBus capacity is raised from 320 to 336 entries. The execution layer adds eighteen per-symbol fields for its sole USDJPY symbol and eight global fields, while retaining headroom for existing framework snapshots.

## Configuration

All execution inputs begin with `InpExecution` in `GaRXY_FeNX.mq5` and are copied into `CParameterManager` through `ConfigureExecution`. They cover enablement, the locked USDJPY symbol, magic number, fixed lot, spread, boundary distance, exit mode, stop/take-profit parameters, quality/confidence thresholds, cooldown, one-order-per-bar control, one-position limit, directions, slippage, bounded transient retry count, and comment.

`InpExecutionSymbol` must remain exactly `USDJPY` and `InpExecutionMaximumOpenPositionsPerSymbol` must remain `1`; invalid execution configuration fails initialization. This intentional restriction keeps Phase3-9.5 safely minimal.

## Explicit limitations

Only `REQUOTE`, `PRICE_CHANGED`, and `PRICE_OFF` responses may be retried, up to `InpExecutionTransientRetryLimit` (default `1`) after a fresh stop-level validation. There is no trailing stop, break-even, partial close, manual exit, emergency liquidation, account/balance/margin calculation, or multi-symbol support. A position-count transition may indicate an SL/TP closure, but this version does not inspect trade transactions to attribute the exact close reason.
