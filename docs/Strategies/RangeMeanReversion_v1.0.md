# Range Mean-Reversion Strategy v1.0

## Responsibility

`CRangeMeanReversionStrategy` converts published environment facts into a non-executable entry intent. It does not inspect Risk, Standby, account, positions, orders, or another engine. `CExecutionGate` must approve the wider framework before this intent can become an order request.

## Completed-bar rule

The strategy calls `CopyRates(symbol, PERIOD_CURRENT, 1, 1)`. Index `1` is the most recently completed candle; index `0`, the forming candle, is never used. This prevents look-ahead and repeated intra-bar signal changes.

## Entry mapping

The strategy requires valid range data, `IsRange`, positive ATR, and `RangeScore` at least `InpExecutionMinimumRangeScore`.

- A completed close within `max(entry_boundary_distance_points * Point, ATR * entry_boundary_distance_atr_ratio)` of `RangeLower` produces a BUY intent when buys are enabled.
- A completed close within the same distance of `RangeUpper` produces a SELL intent when sells are enabled.
- A close away from both boundaries, including the midpoint area, produces `NONE`.

No intent is an order. The execution engine evaluates each completed bar at most once and its duplicate guard still blocks a repeated approved request.

## Initial protection

For `RANGE_BASED`, BUY protection is RangeLower minus the configured buffer with take profit at RangeMidpoint; SELL protection is RangeUpper plus the buffer with take profit at RangeMidpoint. `FIXED_POINTS` is available for tester comparison. The executor validates price direction, precision, and broker stop levels before submitting anything.

## Limitations

This is a deliberately simple initial strategy. It has no candle-pattern confirmation, trend override, dynamic exit, scale-in/out, or management rules. Standby and Risk always override a valid boundary intent.
