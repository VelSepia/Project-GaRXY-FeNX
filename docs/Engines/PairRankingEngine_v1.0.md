# Pair Ranking Engine v1.0

Status: Phase3-4

## Mission

Compare only eligible configured FX symbols and publish a deterministic ordering through `CDataBus`. The engine does not change eligibility, allocate capital, choose a trading style or strategy, inspect account state, or execute trades.

## Inputs and validation

The engine reads each `MarketSelection.<symbol>.*` record and the shared Phase3-2 Environment snapshot only through `CDataBus`. A symbol can be ranked only when its selection record is complete, fresh, and marked `IsMarketEligible=true`; the Environment range/trend data must also be valid and fresh. Missing, malformed, stale, or ineligible records are published as `IsPairRanked=false` with a reason.

`RankingDataValid` is true when the Environment snapshot and every configured Market Selection record are complete and fresh. It can remain true with zero ranked symbols when every selection record is valid but ineligible; this distinguishes “no candidates” from incomplete data.

## Score composition

`PairRankingScore` is normalized to 0–100 using parameterized default weights:

- Market Selection Score: 25%
- Market Selection Confidence: 15%
- spread efficiency: 15%
- Environment confidence: 15%
- volatility suitability: 10%
- range or trend suitability: 10%
- freshness: 10%

The two spread measurements are collapsed into one spread-efficiency factor. Only the suitability matching the current `MarketState` is used—range and trend are never added together. The upstream Market Selection Score remains one published assessment; Pair Ranking does not re-run selection or contact that engine directly.

## Deterministic ordering

Candidates are ordered by:

1. higher `PairRankingScore`;
2. higher `PairRankingConfidence`;
3. lower `SpreadToATRRatio` as spread cost; then
4. alphabetical symbol order.

This produces stable ranks for equal scores and safely handles zero or one eligible candidate.

## DataBus contract

Per-symbol results are written under `PairRanking.<symbol>.<field>`: `Symbol`, `PairRank`, `PairRankingScore`, `PairRankingConfidence`, `IsPairRanked`, `PairRankingReason`, and `PairRankingUpdatedAt`.

Global results are `RankedSymbolCount`, `TopRankedSymbol`, `TopRankingScore`, `RankingDataValid`, and `RankingUpdatedAt`.

Phase3-5 may consume these facts to decide future capital allocation. This engine makes no allocation decision itself.

