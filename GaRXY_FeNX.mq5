//+------------------------------------------------------------------+
//|                                                   GaRXY_FeNX.mq5 |
//|                    Phase3-1 framework for the GaRXY FeNX Expert |
//+------------------------------------------------------------------+
#property copyright "VelSepia"
#property version   "0.1.0"
#property strict

#include "Core/CoreController.mqh"
#include "Environment/MarketStateIntegrator.mqh"
#include "Environment/RangeDetector.mqh"
#include "Environment/TrendDetector.mqh"
#include "Environment/VolatilityAnalyzer.mqh"
#include "MarketSelection/MarketSelectionEngine.mqh"
#include "PairRanking/PairRankingEngine.mqh"
#include "CapitalAllocation/CapitalAllocationEngine.mqh"
#include "TradingStyle/TradingStyleEngine.mqh"
#include "Strategy/StrategySelectionEngine.mqh"

//--- Framework-wide services
CParameterManager g_parameters;
CCoreController   g_controller;
CVolatilityAnalyzer g_volatility_analyzer;
CRangeDetector      g_range_detector;
CTrendDetector      g_trend_detector;
CMarketStateIntegrator g_market_state_integrator;
CMarketSelectionEngine g_market_selection_engine;
CPairRankingEngine     g_pair_ranking_engine;
CCapitalAllocationEngine g_capital_allocation_engine;
CTradingStyleEngine      g_trading_style_engine;
CStrategySelectionEngine g_strategy_selection_engine;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!g_parameters.Load())
     {
      CLogger::Error("Unable to load framework parameters.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_volatility_analyzer))
     {
      CLogger::Error("Unable to register VolatilityAnalyzer.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_range_detector))
     {
      CLogger::Error("Unable to register RangeDetector.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_trend_detector))
     {
      CLogger::Error("Unable to register TrendDetector.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_market_state_integrator))
     {
      CLogger::Error("Unable to register MarketStateIntegrator.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_market_selection_engine))
     {
      CLogger::Error("Unable to register MarketSelectionEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_pair_ranking_engine))
     {
      CLogger::Error("Unable to register PairRankingEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_capital_allocation_engine))
     {
      CLogger::Error("Unable to register CapitalAllocationEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_trading_style_engine))
     {
      CLogger::Error("Unable to register TradingStyleEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.RegisterEngine(g_strategy_selection_engine))
     {
      CLogger::Error("Unable to register StrategySelectionEngine.");
      return(INIT_FAILED);
     }

   if(!g_controller.Initialize(g_parameters))
      return(INIT_FAILED);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_controller.Shutdown();
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_controller.Update();
  }

