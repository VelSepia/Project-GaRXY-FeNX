# Task #003 Backtest Validation and Bottleneck Report

## Scope

Task #003 validates the Task #001 and Task #002 execution pipeline without
changing any trading decision, engine threshold, state transition, order
request, or position-management rule.

The validation instrumentation adds:

- an ordered pipeline trace from Environment through Execution;
- per-stage blocked-tick and block-transition counters;
- order, close, position, rejection, and retry counters;
- Strategy Tester financial statistics and average holding time; and
- a validation-only `.set` file under `Test/StrategyTester/Task003`.

## Test configuration

- Expert: `GaRXY_FeNX`
- Symbol/timeframe: `USDJPY`, `H1`
- Model: 1-minute OHLC
- Deposit/leverage: USD 10,000 / 1:100
- Validation periods: Q1, Q2, Q3, Q4, and continuous full-year 2024
- Execution: enabled
- Fixed lot: 0.01
- Exit mode: fixed points, 1,000-point TP and SL
- Maximum spread: 100 points
- Range, strategy, and risk execution confidence thresholds: 0

The relaxed inputs are validation-only. They do not change the EA defaults.

## Build result

MetaEditor build completed with `0 errors, 1 warning`.

The remaining warning is the pre-existing MQL5 Market version-format warning
for `#property version "0.1.0"`.

## Backtest summary

### Independent quarterly runs

Each quarter starts with a fresh EA and framework state.

| Run | Trades | Wins | Losses | Win rate | Profit factor | Net profit | Balance DD | Equity DD | Average holding |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Q1 | 1 | 0 | 1 | 0.00% | 0.000000 | -7.01 | 7.01 (0.07%) | 8.86 (0.09%) | 106,000.00 s |
| Q2 | 22 | 12 | 10 | 54.55% | 0.448956 | -4.75 | 7.20 (0.07%) | 8.17 (0.08%) | 32,740.00 s |
| Q3 | 3 | 1 | 2 | 33.33% | 0.160355 | -10.42 | 10.42 (0.10%) | 11.50 (0.11%) | 112,646.67 s |
| Q4 | 4 | 2 | 2 | 50.00% | 0.448859 | -7.49 | 7.49 (0.07%) | 12.00 (0.12%) | 36,260.00 s |
| Total/weighted | 30 | 15 | 15 | 50.00% | n/a (independent balances) | -29.67 | max 10.42 (0.10%) | max 12.00 (0.12%) | 43,642.00 s |

Across these runs:

- order requests/accepted/rejected: 30 / 30 / 0;
- explicit close requests/accepted/rejected: 24 / 24 / 0;
- broker stop-loss closes: 6;
- take-profit closes: 0;
- entry retries: 0;
- close retries: 0; and
- all 30 opened positions were observed as closed.

### Continuous full-year run

The continuous run is the authoritative normal-operation result because it
does not reset framework state at quarter boundaries.

| Trades | Wins | Losses | Win rate | Profit factor | Net profit | Balance DD | Equity DD | Average holding |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0 | 1 | 0.00% | 0.000000 | -7.01 | 7.01 (0.07%) | 8.86 (0.09%) | 106,000.00 s |

The full-year run submitted and accepted one SELL order, observed the open
position, and observed its stop-loss close. No order rejection, failed close,
or retry occurred.

### Final-code Q2 rerun

The final instrumentation was rerun over Q2 to exercise post-signal blocking:

- 30 entry signals;
- 8 entry blocks before order submission;
- 22 requests and 22 accepted orders;
- 0 rejected orders;
- 21 explicit close requests and 21 accepted closes;
- 0 failed closes; and
- 0 entry or close retries.

## Pipeline observations

### Independent-quarter gate stops

| Stage | Blocked ticks | Block-transition events |
|---|---:|---:|
| Environment | 41,913 | 43 |
| Market Selection | 703 | 30 |
| Pair Ranking | 0 | 0 |
| Capital Allocation | 0 | 0 |
| Trading Style | 0 | 0 |
| Strategy Selection | 0 | 0 |
| Standby | 0 | 0 |
| Risk | 1,336,239 | 87 |
| Execution (spread gate only) | 127 | 15 |

Exact transition reasons were:

- Risk: framework state was not `NORMAL` — 45 events;
- Environment: market state was not `RANGING` — 43 events;
- Risk: new-entry permissions were blocked — 42 events;
- Market Selection: symbol rejected — 30 events; and
- Execution: spread exceeded the configured limit — 15 events.

There were 238 `NORMAL -> ENTERING_STANDBY` activations. Standby was never the
earliest gate stop because an earlier stage, primarily the framework/Risk
state, stopped those entry evaluations first. Trading Style and Strategy
Selection caused zero direct gate stops.

### Continuous-run stop

On 2024-01-05 18:00:00, the log recorded:

1. `StandbyEngine USDJPY: NORMAL -> RISK_STOP_PENDING`;
2. `State transition: NORMAL -> RISK_STOP`; and
3. `stop=Risk; reason=Framework state is not NORMAL`.

There was no `RISK_STOP` recovery transition for the remainder of the year.
The only later core transition was `RISK_STOP -> SHUTDOWN` at tester
deinitialization.

Consequently, Risk blocked 1,447,159 of 1,466,584 execution updates
(98.68%). Restarting at each quarter temporarily removed the latch and exposed
29 additional trades, but did not demonstrate continuous recovery.

## Bottleneck report

### 1. Core Risk Stop has no runtime recovery request

- Component: `RiskEngine` / `StateManager` integration.
- Evidence: every independent run stopped permanently after its first core
  `NORMAL -> RISK_STOP` transition. The dates were 2024-01-05, 2024-04-10,
  2024-07-05, and 2024-10-10.
- Cause: `StateManager` permits `RISK_STOP -> STANDBY`, but
  `RiskEngine::RequestCoreState()` returns immediately whenever the current
  state is `RISK_STOP`. It therefore never requests the permitted recovery
  path, even when the internal Risk state later recovers.
- Proposed fix: in a separate task, add a confirmed recovery handshake that
  requests `RISK_STOP -> STANDBY`, then `STANDBY -> NORMAL` only after stable
  Risk and Standby recovery. Do not add a direct unsafe jump to `NORMAL`.
- Estimated impact: removes the permanent post-trigger lock. The isolated
  runs show up to 29 additional trades that become reachable after resets;
  the exact continuous impact requires a full-year retest after the fix.

### 2. Risk input freshness repeatedly triggers protective states

- Component: `RiskEngine` input validation.
- Evidence: the continuous log recorded 1,109 invalid/missing/stale upstream
  events and 1,071 transitions into `RISK_STOP_REQUIRED`. The configured
  staleness limit is five seconds.
- Cause recorded by the engine: required upstream or symbol-level Risk records
  were invalid, unavailable, or stale. Existing logs do not identify the
  individual failing timestamp, so a narrower root cause cannot be claimed.
- Proposed fix: add field-level age diagnostics, then align producer timestamps
  and snapshot publication with the five-second consumer rule or revise the
  threshold only with measured timing data.
- Estimated impact: fewer false protective transitions and a lower chance of
  entering the unrecoverable core Risk Stop. Trade-count impact is not yet
  measurable.

### 3. Reduced allocation can fall below broker minimum volume

- Component: `ExecutionEngine` request sizing / `OrderExecutor` preparation.
- Evidence: 12 of 42 independent-quarter entry signals (28.57%) stopped with
  `Requested volume is outside the broker volume limits.` All 30 requests that
  reached the broker were accepted.
- Cause: the 0.01 fixed lot is multiplied by a Risk allocation multiplier below
  1.0, producing a volume below the broker's minimum.
- Proposed fix: implement broker-step-aware, risk-budget-aware lot sizing.
  When the risk budget cannot support the broker minimum, retain a classified
  no-trade result; do not silently round upward and exceed the risk budget.
- Estimated impact: up to 12 additional executable signals in these isolated
  tests if the configured risk budget can validly support the minimum lot.

### 4. Expected protective filters

Environment non-ranging state, Market Selection rejection, and excessive
spread also stopped entries. These are expected safety/strategy filters, not
proven defects. Pair Ranking, Capital Allocation, Trading Style, Strategy
Selection, and direct Standby gating caused no observed stop.

### 5. Negative validation performance

The independent runs produced a 50% win rate but negative net profit in every
quarter and profit factor below 0.45. The validation uses deliberately relaxed
entry thresholds and wide fixed exits, so this is not a production strategy
quality result. After execution-state recovery is fixed, exit calibration and
expectancy should be evaluated in a separate strategy task.

## Complete-cycle conclusion

The EA can execute complete trade cycles:

- entry order submitted and accepted;
- position open observed;
- open position evaluated on subsequent completed bars;
- explicit close submitted and accepted in Q2/Q3/Q4; and
- broker stop-loss close observed.

It cannot yet trade normally for a long continuous session because the first
core `RISK_STOP` transition is permanent until EA reinitialization.

## Temporary and validation-only artifacts

No temporary bypass or trading-behavior modification remains in product code.

- `Test/StrategyTester/Task003/GaRXY_FeNX_Task003.set` is a committed,
  validation-only input set.
- `Test/BacktestValidationReporter.mqh` and `OnTester()` are tester
  observability code and do not alter live order decisions.
- Local absolute-path `.ini` files, portable terminal copies, compiled `.ex5`
  output, Strategy Tester logs/reports, and build logs are not committed.

## Recommended next work

1. Implement and unit-test the confirmed `RISK_STOP -> STANDBY -> NORMAL`
   recovery path.
2. Add field-level Risk freshness diagnostics before changing any timeout.
3. Define broker-aware lot normalization that cannot exceed the Risk budget.
4. Repeat the continuous full-year test before tuning strategy profitability.
