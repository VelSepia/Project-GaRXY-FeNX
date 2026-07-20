# Trend Detector v1.0

Status: Phase3-2.3

## Mission

Detect factual trend direction and quality, then publish the results through `CDataBus`. `CTrendDetector` does not classify the final market state and does not create, modify, or close trades.

## Closed-bar data and indicators

All `CopyRates` and `CopyBuffer` calls start at bar shift `1`, which excludes the current forming candle. Requested values are processed oldest to newest, so the final element is the most recently closed value. EMA and ADX handles are created once during initialization and released during shutdown.

## Trend evaluation

The detector combines five components:

- EMA slope, normalized by ATR, for directional slope strength;
- higher highs/higher lows versus lower highs/lower lows for market structure;
- ADX and plus/minus DI for directional strength;
- net closed-price movement normalized by ATR; and
- an ATR-based noise band that filters insignificant candle-to-candle movement.

`TrendScore` is signed from -100 to 100, where positive values favor `UP` and negative values favor `DOWN`. `TrendStrength` is the strongest directional evidence. `TrendConfidence` measures the agreement of slope, structure, DI, and net movement after noise filtering. `TrendAdx` publishes the last completed-bar ADX for DataBus consumers. `IsTrend` requires direction, ADX, strength, and confidence to meet their configured thresholds.

## Parameters

`CParameterManager` supplies the lookback, EMA period, slope window, ADX period, minimum ADX, ATR-normalized slope and movement thresholds, noise fraction, and direction, strength, and confidence thresholds. ATR is read only from the existing `Environment.Volatility.ATR` DataBus field.

