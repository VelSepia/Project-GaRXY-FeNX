# Market State Integrator v1.0

Status: Phase3-2.4

## Mission

Combine the published outputs of the Volatility Analyzer, Range Detector, and Trend Detector into one factual `MarketState`. The integrator does not read analyzer objects, execute trades, inspect positions, or access account data.

## Inputs and timing

Inputs are read only through `CDataBus`: `RangeScore`, `IsRange`, `TrendScore`, `TrendStrength`, `VolatilityScore`, `ATR`, and the closed-bar ADX published by the Trend Detector. The integrator does not calculate bars or indicators itself, so it preserves the completed-candle, no-look-ahead behavior of its upstream analyzers.

## Classification

The default parameterized rule order is:

1. `RANGING` when `IsRange` is true, `RangeScore` exceeds 70, and the absolute `TrendScore` is below 40.
2. `TRENDING` when the absolute `TrendScore` exceeds 70 and ADX meets its minimum.
3. `VOLATILE` when `VolatilityScore` exceeds 80.
4. `TRANSITION` otherwise.

`TrendScore` is signed by the Trend Detector; the integrator uses its absolute value so strong downward and upward trends are treated symmetrically.

## Outputs

The engine publishes `MarketState`, `MarketConfidence`, `RecommendedTradingStyle`, `RecommendedRiskLevel`, and `MarketUpdatedAt`. Trading-style recommendations are descriptive only: `Range`, `Trend`, or `Standby`. Risk levels are `Low`, `Medium`, or `High`; they do not alter orders or account state.

## Parameters

`CParameterManager` controls range, trend, and volatility thresholds, the maximum trend score permitted for a range, and the minimum ADX for the trending state.

