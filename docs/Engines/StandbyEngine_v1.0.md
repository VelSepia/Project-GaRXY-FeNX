# Standby Engine v1.0

Status: Phase3-8

## Purpose and responsibility

`CStandbyEngine` is an intermediate protective-state coordinator. It determines whether an allocated symbol should temporarily pause *new-entry permission* while preserving existing positions by default. It publishes recommendations through `CDataBus` and never places, changes, or closes a trade.

The engine reads factual Environment, Market Selection, Pair Ranking, Capital Allocation, Trading Style, and Strategy Selection outputs only from `CDataBus`. It does not call another engine directly and does not read account, margin, order, position, or live-price APIs.

## Per-symbol state machine

```text
NORMAL
  -> ENTERING_STANDBY    temporary condition detected
  -> STANDBY             entry condition confirmed on closed bars
STANDBY
  -> RECOVERY_PENDING    recovery condition detected after cooldown
  -> ESCALATION_PENDING  duration, trend, volatility, or confidence is structural
  -> RISK_STOP_PENDING   severe condition needs future Risk Engine review
RECOVERY_PENDING
  -> NORMAL              recovery confirmed on closed bars
  -> STANDBY             temporary condition returns
ESCALATION_PENDING
  -> RECOVERY_PENDING    conditions improve after cooldown
RISK_STOP_PENDING
  -> held for Phase3-10 Risk Engine ownership
```

The standard state names are deliberately published as text: `NORMAL`, `ENTERING_STANDBY`, `STANDBY`, `RECOVERY_PENDING`, `ESCALATION_PENDING`, and `RISK_STOP_PENDING`.

## Entry, recovery, and escalation

Standby entry is considered for allocated symbols when any temporary condition occurs: a boundary-buffer breach, `TRANSITION` market state, temporary eligibility or pipeline degradation, an invalid/standby strategy recommendation, reduced confidence, or stale-but-within-grace data. The condition must persist for the configured number of completed bars before `STANDBY` is active.

Recovery requires fresh and valid pipeline data, a valid range with sufficient `RangeScore`, adequate market and strategy confidence, a recovered inside-range buffer, and trend/volatility below escalation thresholds. Recovery also needs the configured number of newly completed bars.

Escalation is requested when standby exceeds its maximum duration, trend strength or volatility crosses its escalation limit, or the combined escalation score indicates structural change. Critical data loss, severe volatility, or extreme confidence failure produces `RISK_STOP_PENDING`; Phase3-10 will own the final risk action.

## Closed-bar, hysteresis, and cooldown behavior

The engine uses `Environment.Range.ClosedBarTime`, published by `CRangeDetector`, to increment entry and recovery confirmations exactly once per completed candle. `RangePosition` is intentionally clamped by the Range Detector, so this engine treats a value at either edge plus insufficient inside-range buffer as a boundary-breach signal; it does not infer an unobservable excursion beyond the range.

The buffer is the larger of `StandbyBreakoutDistancePoints` and the configured ATR multiple converted through the published range width. State changes apply a configurable cooldown, and repeated updates for the same completed bar cannot add confirmations. These measures prevent state flapping and avoid look-ahead bias.

## StateManager integration

The engine submits high-level recommendations through `CStateManager::RequestTransition`; it never changes framework state directly. The aggregate mapping is:

- active standby or recovery -> `STANDBY`;
- escalation pending -> `DYNAMIC_ZONE` after the framework is in `STANDBY`;
- risk-stop pending -> `RISK_STOP`; and
- no active standby states -> `NORMAL`.

`DYNAMIC_ZONE` and `RISK_STOP` are recommendations and handoff points only. Detailed dynamic-zone handling and risk enforcement remain future responsibilities.

## Position preservation and outputs

`PreserveExistingPositions` is always `true`. `AreNewEntriesAllowed` is only a non-executable recommendation and is `false` whenever a symbol is in any standby state or inputs are unsafe.

For each configured symbol the engine publishes `StandbyState`, `IsStandbyActive`, `AreNewEntriesAllowed`, `PreserveExistingPositions`, `StandbyReason`, `StandbyConfidence`, `StandbyEnteredAt`, `StandbyDurationSeconds`, `RecoveryProgress`, `EscalationScore`, `RecommendedNextState`, `StandbyDataValid`, and `StandbyUpdatedAt`. It also publishes aggregate active, recovery, escalation, and risk-stop counts plus system validity and update time.

## Parameters

`CParameterManager` centralizes:

- entry and recovery confirmation bars;
- maximum standby duration;
- point and ATR-multiple boundary buffers;
- minimum range recovery score;
- trend and volatility escalation thresholds;
- recovery and failure confidence thresholds;
- transition cooldown; and
- stale-data grace period.

The existing Strategy Selection stale-data limit provides the base freshness window. The standby grace period distinguishes temporarily stale data from data that requires risk review.

An empty configured symbol list is valid: the engine publishes a zero-count global snapshot and makes no state-transition request.
