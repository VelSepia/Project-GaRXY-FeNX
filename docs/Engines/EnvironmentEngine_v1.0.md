# Environment Engine v1.0

Status: Adopted

## Mission
Evaluate current market conditions and provide an EnvironmentSnapshot.
The engine never generates buy/sell decisions.

## Inputs
- OHLC
- Bid/Ask
- ATR
- ADX
- Moving Average
- Volatility
- Spread
- Session

## Internal Scores
- TrendScore (-100 to 100)
- VolatilityScore (0 to 100)
- StrengthScore (0 to 100)
- ActivityScore (0 to 100)
- MarketRiskScore (0 to 100)
- Confidence (0 to 100)

## Outputs
EnvironmentSnapshot containing all scores and raw spread/session information.

## Rules
- Facts only.
- No trading decisions.
- Store snapshot to DataBus.
- One responsibility only.
