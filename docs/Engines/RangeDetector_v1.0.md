# Range Detector v1.0

Status: Phase3-2.2

## Mission

Detect stable, non-directional price ranges and publish factual range measurements through `CDataBus`. The detector never makes or executes trading decisions.

## Closed-bar data and boundaries

`CRangeDetector` calls `CopyRates` with `start_pos = 1`, so the current forming candle is excluded. MQL5 copies the requested closed bars from oldest to newest in the target array; the latest array element is therefore the most recently closed candle.

The detector derives stable lower and upper boundaries from trimmed low and high percentiles. The trim fraction reduces the effect of isolated spikes before containment, touches, and break events are measured.

## RangeScore

`RangeScore` is normalized to 0–100. It combines five factors:

- 30% closed-price containment within the stable boundaries;
- 20% touches of both boundaries;
- 25% low directional efficiency, calculated as net movement versus total close-to-close movement;
- 15% range width relative to ATR; and
- 10% false-break and excessive-break penalties.

`IsRange` requires the score threshold, both boundary-touch requirements, and an ATR-relative width inside the configured range. `IsRangeDataValid` distinguishes unavailable or invalid history from a valid analysis that simply does not qualify as a range.

## Parameters

`CParameterManager` controls the detector with the range lookback, boundary trim fraction, minimum boundary touches, minimum absolute and ATR-relative width, touch tolerance, break buffer, maximum weighted break events, and score threshold. ATR is read only from the existing `Environment.Volatility.ATR` DataBus field.

## Closed-bar timestamp

`Environment.Range.ClosedBarTime` is the open time of the newest completed candle used for the snapshot. It is published alongside the range facts so downstream engines can require confirmations exactly once per completed bar without reading price data directly.
