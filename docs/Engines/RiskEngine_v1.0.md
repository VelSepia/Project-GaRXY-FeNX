# Risk Engine v1.0

Status: Phase3-9

## Purpose and boundary

`CRiskEngine` is the final safety authority before a future execution layer. It reads only factual and recommendation data from `CDataBus`, evaluates symbol and system risk, publishes final risk recommendations, and requests framework state transitions through `CStateManager::RequestTransition`.

It does not place, modify, or close orders; inspect positions; calculate lots, stops, or targets; change Phase3-5 allocations; or access account, balance, equity, margin, leverage, or free-margin APIs.

## Symbol risk states and actions

| Risk state | Final multiplier | Typical action |
| --- | ---: | --- |
| `SAFE` | 1.00 | `ALLOW` |
| `CAUTION` | configurable, below 1.00 | `ALLOW_REDUCED` |
| `REDUCED` | lower configurable value | `ALLOW_REDUCED` |
| `SUSPENDED` | 0.00 | `BLOCK_NEW_ENTRIES` |
| `RISK_STOP_REQUIRED` | 0.00 | `REQUEST_RISK_STOP` |

`ESCALATE_DYNAMIC_ZONE` is used when Standby reports a structural escalation. A Risk Engine recommendation never executes an action itself. `PreserveExistingPositions` is always `true`; even `RISK_STOP_REQUIRED` does not force a position closure in this phase.

## Scoring model

`RiskScore` is normalized from 0 to 100, with higher values representing greater risk. For valid data it blends independent dimensions: volatility above its threshold (15%), environment confidence (10%), ranking confidence (10%), allocation excess above the risk cap (10%), strategy confidence (10%), Standby escalation (15%), market regime (`TRANSITION` or `VOLATILE`, 10%), conflicting recommendations (10%), and Trading Style confidence (10%).

Invalid, missing, or stale records score 100 and require `RISK_STOP_REQUIRED`. The engine does not alter `CapitalAllocationPercent`; `RecommendedAllocationMultiplier` is a separate final safety recommendation.

## System risk states

System states are `SYSTEM_SAFE`, `SYSTEM_CAUTION`, `SYSTEM_REDUCED`, `SYSTEM_SUSPENDED`, and `SYSTEM_RISK_STOP`. The aggregate score considers suspended and risk-stop ratios, total allocation above the aggregate cap, single-symbol concentration, invalid-record ratio, standby/escalation proportion, global data validity, and contradictory standby counts.

All-invalid data safely produces non-trading risk recommendations. With zero configured symbols the engine publishes a valid `SYSTEM_SAFE` zero-count snapshot and requests no state change. Zero allocated symbols remain supported because risk recommendations are separate from capital allocation.

## Recovery hysteresis and logging

Unsafe non-critical risk must persist for `RiskUnsafeConfirmationCount` updates before it can worsen the published state. Critical `RISK_STOP_REQUIRED` conditions bypass that delay. Recovery requires `RiskRecoveryConfirmationCount` stable updates plus the transition cooldown, then improves only one severity level at a time. This prevents an immediate jump from a protective state to `SAFE` and avoids flapping.

Meaningful deteriorations are logged as warnings; stable recovery transitions are logged as information. Invalid upstream system data emits one error until it becomes valid again, avoiding repeated log spam.

## StateManager and Standby interaction

The engine uses only `RequestTransition` and retains the last successful request to avoid repeated identical requests:

- `SYSTEM_RISK_STOP` requests `RISK_STOP`.
- A Standby `DYNAMIC_ZONE` recommendation requests `DYNAMIC_ZONE`.
- Temporary non-safe risk or blocked entries requests `STANDBY`.
- Stable system safety can request `NORMAL`.

`StandbyState`, `AreNewEntriesAllowed`, `EscalationScore`, and `RecommendedNextState` are risk inputs, not direct engine calls. Standby remains responsible for its own temporary protective analysis; Risk Engine makes the final safety recommendation.

## Parameters and DataBus contract

`CParameterManager` supplies the four risk thresholds, volatility and confidence thresholds, per-symbol and aggregate allocation caps, concentration and invalid-ratio limits, Standby escalation limit, unsafe/recovery confirmations, cooldown, stale-data limit, and caution/reduced multipliers.

Per-symbol output is published under `Risk.<symbol>.<field>`: `SymbolRiskState`, `RiskAction`, `IsRiskApproved`, `AreNewEntriesRiskApproved`, `RecommendedAllocationMultiplier`, `RiskScore`, `RiskConfidence`, `RiskReason`, `PreserveExistingPositions`, `RiskEscalationRequired`, `RiskDataValid`, and `RiskUpdatedAt`.

Global output is `SystemRiskState`, `SystemRiskScore`, `SystemRiskConfidence`, `SystemTradingAllowed`, `SystemNewEntriesAllowed`, `SystemAllocationMultiplier`, `SuspendedSymbolCount`, `RiskStopRequiredCount`, `InvalidRiskSymbolCount`, `SystemRiskReason`, `SystemRiskDataValid`, and `SystemRiskUpdatedAt`.

The DataBus capacity increases from 256 to 320 because the existing worst-case 239 records plus 48 per-symbol Risk records and 12 global Risk records require 299 records for four configured symbols.

## Future execution-layer responsibilities

A future execution layer may consume these recommendations to decide whether it can send trade requests. Emergency liquidation, existing-position changes, account-aware checks, margin checks, sizing, stop placement, and all actual trade execution remain explicitly out of scope.
