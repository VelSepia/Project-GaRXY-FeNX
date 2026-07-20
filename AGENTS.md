# Project GaRXY FeNX — Development Guide

This file is the permanent development guide for Project GaRXY FeNX. Follow it for every implementation, review, test, and commit.

## 1. Project Vision

GaRXY FeNX is a long-term, modular MQL5 trading framework.

- Prioritize maintainability, reliability, and replaceability over short-term implementation speed.
- Keep responsibilities explicit and isolated.
- Design every component so it can be replaced without requiring changes to unrelated components.
- Build the framework before introducing trading decisions or execution logic.

## 2. Architecture

| Folder | Responsibility |
| --- | --- |
| `Core/` | Framework lifecycle, state transitions, engine registration, and shared coordination. |
| `Engine/` | Engine contracts and reusable base behavior for all engines. |
| `Common/` | Shared types, constants, logging, and other cross-cutting utilities. |
| `Config/` | Centralized parameter loading, validation, and configuration access. |
| `Risk/` | Future risk controls, position limits, and capital-protection modules. |
| `Strategy/` | Future strategy definitions and strategy-selection integrations. |
| `Data/` | Future market-data providers, data models, and normalization services. |
| `Test/` | Test harnesses, fixtures, repeatable scenarios, and validation assets. |

## 3. Engine Rules

Every engine must:

- Inherit from `CBaseEngine`.
- Satisfy the `IEngine` contract.
- Have one clearly defined responsibility.
- Never communicate directly with another engine.
- Communicate with other engines only through `CDataBus`.
- Be independently testable.
- Be registered through `CEngineManager` before framework initialization.
- Avoid trading decisions unless that engine's phase explicitly authorizes them.

## 4. Coding Rules

- Use modern object-oriented MQL5.
- Apply the Single Responsibility Principle.
- Keep classes small, cohesive, and easy to replace.
- Write clear English comments where intent is not obvious.
- Use English identifiers for classes, methods, variables, and files.
- Prefer explicit interfaces and well-defined data contracts.
- Keep dependencies directed through the framework architecture; do not introduce hidden cross-module coupling.
- Add TODO comments only for planned work with a clear future owner or phase.

## 5. Git Rules

- Make small, focused commits.
- Use clear, concise commit messages.
- Do not mix framework changes and trading logic in the same commit.
- Do not combine unrelated refactors, behavior changes, and documentation changes.
- Verify affected interfaces and include paths before committing.
- Keep the default branch buildable at every commit.

## 6. Phase Rules

Implement phases in order unless a documented architecture decision explicitly changes the plan.

1. Phase3-1 — Framework
2. Phase3-2 — Environment Engine
3. Phase3-3 — Market Selection Engine
4. Phase3-4 — Pair Ranking Engine
5. Phase3-5 — Capital Allocation Engine
6. Phase3-6 — Trading Style Engine
7. Phase3-7 — Strategy Selection Engine
8. Phase3-8 — Standby Engine
9. Phase3-9 — Priority Decision Engine
10. Phase3-10 — Risk Engine
11. Phase3-11 — Backtest
12. Phase3-12 — Forward Test

Each phase must preserve the previous framework contracts, introduce only its assigned responsibility, and remain independently testable.

## 7. Future Engine Placeholders

- TODO(EnvironmentEngine): Publish factual market-condition snapshots to `CDataBus`; do not generate trading decisions.
- TODO(MarketSelectionEngine): Select eligible markets from shared environment and data snapshots.
- TODO(PairRankingEngine): Rank candidate symbols using published criteria.
- TODO(CapitalAllocationEngine): Allocate capital subject to future risk constraints.
- TODO(TradingStyleEngine): Select an approved trading style from shared context.
- TODO(StrategySelectionEngine): Select a strategy without directly executing trades.
- TODO(StandbyEngine): Define safe standby behavior and recovery conditions.
- TODO(PriorityDecisionEngine): Coordinate priority decisions from DataBus outputs.
- TODO(RiskEngine): Enforce risk-stop and capital-protection rules in Phase3-10.

No future engine may be implemented outside its assigned phase without updating this guide and documenting the architectural reason.
