//+------------------------------------------------------------------+
//|                                  Config/ParameterManager.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_CONFIG_PARAMETER_MANAGER_MQH
#define FENX_CONFIG_PARAMETER_MANAGER_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"

//--- Owns framework configuration independently from trading logic.
class CParameterManager
  {
private:
   int    m_update_interval_seconds;
   bool   m_framework_logging_enabled;
   int    m_volatility_atr_period;
   int    m_volatility_baseline_samples;
   double m_volatility_low_score;
   double m_volatility_high_score;
   int    m_range_lookback_bars;
   double m_range_boundary_trim_fraction;
   int    m_range_min_boundary_touches;
   double m_range_min_width_points;
   double m_range_min_width_atr_multiple;
   double m_range_max_width_atr_multiple;
   double m_range_touch_tolerance_atr_fraction;
   double m_range_break_buffer_atr_fraction;
   int    m_range_max_break_events;
   double m_range_score_threshold;
   int    m_trend_lookback_bars;
   int    m_trend_ma_period;
   int    m_trend_slope_bars;
   int    m_trend_adx_period;
   double m_trend_min_adx;
   double m_trend_min_slope_atr_fraction;
   double m_trend_min_atr_movement;
   double m_trend_noise_atr_fraction;
   double m_trend_direction_score_threshold;
   double m_trend_strength_threshold;
   double m_trend_confidence_threshold;
   double m_market_range_score_threshold;
   double m_market_range_max_trend_score;
   double m_market_trend_score_threshold;
   double m_market_volatility_score_threshold;
   double m_market_trend_min_adx;
   string m_market_selection_symbols[];
   int    m_market_selection_min_history_bars;
   double m_market_selection_max_spread_points;
   double m_market_selection_max_spread_to_atr_ratio;
   double m_market_selection_min_volatility_score;
   double m_market_selection_max_volatility_score;
   double m_market_selection_min_score;
   double m_market_selection_transition_penalty;
   int    m_pair_ranking_max_data_age_seconds;
   double m_pair_ranking_weight_selection_score;
   double m_pair_ranking_weight_selection_confidence;
   double m_pair_ranking_weight_spread_efficiency;
   double m_pair_ranking_weight_environment_confidence;
   double m_pair_ranking_weight_volatility_suitability;
   double m_pair_ranking_weight_regime_suitability;
   double m_pair_ranking_weight_freshness;

public:
                     CParameterManager(void)
     {
      Reset();
     }

   bool              Load(void)
     {
      // TODO: Read EA input parameters and external configuration in a later phase.
      Reset();
      CLogger::Info("ParameterManager loaded framework defaults.");
      return(true);
     }

   void              Reset(void)
     {
      m_update_interval_seconds=1;
      m_framework_logging_enabled=true;
      m_volatility_atr_period=14;
      m_volatility_baseline_samples=20;
      m_volatility_low_score=35.0;
      m_volatility_high_score=65.0;
      m_range_lookback_bars=40;
      m_range_boundary_trim_fraction=0.10;
      m_range_min_boundary_touches=2;
      m_range_min_width_points=20.0;
      m_range_min_width_atr_multiple=0.75;
      m_range_max_width_atr_multiple=6.00;
      m_range_touch_tolerance_atr_fraction=0.20;
      m_range_break_buffer_atr_fraction=0.15;
      m_range_max_break_events=4;
      m_range_score_threshold=65.0;
      m_trend_lookback_bars=30;
      m_trend_ma_period=20;
      m_trend_slope_bars=10;
      m_trend_adx_period=14;
      m_trend_min_adx=20.0;
      m_trend_min_slope_atr_fraction=0.05;
      m_trend_min_atr_movement=0.75;
      m_trend_noise_atr_fraction=0.10;
      m_trend_direction_score_threshold=20.0;
      m_trend_strength_threshold=60.0;
      m_trend_confidence_threshold=60.0;
      m_market_range_score_threshold=70.0;
      m_market_range_max_trend_score=40.0;
      m_market_trend_score_threshold=70.0;
      m_market_volatility_score_threshold=80.0;
      m_market_trend_min_adx=20.0;
      ArrayResize(m_market_selection_symbols,1);
      m_market_selection_symbols[0]=_Symbol;
      m_market_selection_min_history_bars=100;
      m_market_selection_max_spread_points=30.0;
      m_market_selection_max_spread_to_atr_ratio=0.30;
      m_market_selection_min_volatility_score=20.0;
      m_market_selection_max_volatility_score=80.0;
      m_market_selection_min_score=60.0;
      m_market_selection_transition_penalty=30.0;
      m_pair_ranking_max_data_age_seconds=5;
      m_pair_ranking_weight_selection_score=0.25;
      m_pair_ranking_weight_selection_confidence=0.15;
      m_pair_ranking_weight_spread_efficiency=0.15;
      m_pair_ranking_weight_environment_confidence=0.15;
      m_pair_ranking_weight_volatility_suitability=0.10;
      m_pair_ranking_weight_regime_suitability=0.10;
      m_pair_ranking_weight_freshness=0.10;
     }

   int               UpdateIntervalSeconds(void)
     {
      return(m_update_interval_seconds);
     }

   bool              IsFrameworkLoggingEnabled(void)
     {
      return(m_framework_logging_enabled);
     }

   int               VolatilityAtrPeriod(void)
     {
      return(m_volatility_atr_period);
     }

   int               VolatilityBaselineSamples(void)
     {
      return(m_volatility_baseline_samples);
     }

   double            VolatilityLowScore(void)
     {
      return(m_volatility_low_score);
     }

   double            VolatilityHighScore(void)
     {
      return(m_volatility_high_score);
     }

   int               RangeLookbackBars(void)
     {
      return(m_range_lookback_bars);
     }

   double            RangeBoundaryTrimFraction(void)
     {
      return(m_range_boundary_trim_fraction);
     }

   int               RangeMinBoundaryTouches(void)
     {
      return(m_range_min_boundary_touches);
     }

   double            RangeMinWidthPoints(void)
     {
      return(m_range_min_width_points);
     }

   double            RangeMinWidthAtrMultiple(void)
     {
      return(m_range_min_width_atr_multiple);
     }

   double            RangeMaxWidthAtrMultiple(void)
     {
      return(m_range_max_width_atr_multiple);
     }

   double            RangeTouchToleranceAtrFraction(void)
     {
      return(m_range_touch_tolerance_atr_fraction);
     }

   double            RangeBreakBufferAtrFraction(void)
     {
      return(m_range_break_buffer_atr_fraction);
     }

   int               RangeMaxBreakEvents(void)
     {
      return(m_range_max_break_events);
     }

   double            RangeScoreThreshold(void)
     {
      return(m_range_score_threshold);
     }

   int               TrendLookbackBars(void)
     {
      return(m_trend_lookback_bars);
     }

   int               TrendMaPeriod(void)
     {
      return(m_trend_ma_period);
     }

   int               TrendSlopeBars(void)
     {
      return(m_trend_slope_bars);
     }

   int               TrendAdxPeriod(void)
     {
      return(m_trend_adx_period);
     }

   double            TrendMinAdx(void)
     {
      return(m_trend_min_adx);
     }

   double            TrendMinSlopeAtrFraction(void)
     {
      return(m_trend_min_slope_atr_fraction);
     }

   double            TrendMinAtrMovement(void)
     {
      return(m_trend_min_atr_movement);
     }

   double            TrendNoiseAtrFraction(void)
     {
      return(m_trend_noise_atr_fraction);
     }

   double            TrendDirectionScoreThreshold(void)
     {
      return(m_trend_direction_score_threshold);
     }

   double            TrendStrengthThreshold(void)
     {
      return(m_trend_strength_threshold);
     }

   double            TrendConfidenceThreshold(void)
     {
      return(m_trend_confidence_threshold);
     }

   double            MarketRangeScoreThreshold(void)
     {
      return(m_market_range_score_threshold);
     }

   double            MarketRangeMaxTrendScore(void)
     {
      return(m_market_range_max_trend_score);
     }

   double            MarketTrendScoreThreshold(void)
     {
      return(m_market_trend_score_threshold);
     }

   double            MarketVolatilityScoreThreshold(void)
     {
      return(m_market_volatility_score_threshold);
     }

   double            MarketTrendMinAdx(void)
     {
      return(m_market_trend_min_adx);
     }

   bool              SetMarketSelectionSymbols(string &symbols[])
     {
      const int symbol_count=ArraySize(symbols);
      if(symbol_count<1 || symbol_count>FENX_MARKET_SELECTION_MAX_SYMBOLS)
         return(false);

      for(int index=0;index<symbol_count;index++)
        {
         if(StringLen(symbols[index])==0)
            return(false);
        }

      if(ArrayResize(m_market_selection_symbols,symbol_count)!=symbol_count)
         return(false);

      for(int index=0;index<symbol_count;index++)
         m_market_selection_symbols[index]=symbols[index];

      return(true);
     }

   int               MarketSelectionSymbolCount(void)
     {
      return(ArraySize(m_market_selection_symbols));
     }

   bool              TryGetMarketSelectionSymbol(const int index,string &symbol)
     {
      if(index<0 || index>=ArraySize(m_market_selection_symbols))
         return(false);

      symbol=m_market_selection_symbols[index];
      return(StringLen(symbol)>0);
     }

   int               MarketSelectionMinHistoryBars(void)
     {
      return(m_market_selection_min_history_bars);
     }

   double            MarketSelectionMaxSpreadPoints(void)
     {
      return(m_market_selection_max_spread_points);
     }

   double            MarketSelectionMaxSpreadToAtrRatio(void)
     {
      return(m_market_selection_max_spread_to_atr_ratio);
     }

   double            MarketSelectionMinVolatilityScore(void)
     {
      return(m_market_selection_min_volatility_score);
     }

   double            MarketSelectionMaxVolatilityScore(void)
     {
      return(m_market_selection_max_volatility_score);
     }

   double            MarketSelectionMinScore(void)
     {
      return(m_market_selection_min_score);
     }

   double            MarketSelectionTransitionPenalty(void)
     {
      return(m_market_selection_transition_penalty);
     }

   int               PairRankingMaxDataAgeSeconds(void)
     {
      return(m_pair_ranking_max_data_age_seconds);
     }

   double            PairRankingWeightSelectionScore(void)
     {
      return(m_pair_ranking_weight_selection_score);
     }

   double            PairRankingWeightSelectionConfidence(void)
     {
      return(m_pair_ranking_weight_selection_confidence);
     }

   double            PairRankingWeightSpreadEfficiency(void)
     {
      return(m_pair_ranking_weight_spread_efficiency);
     }

   double            PairRankingWeightEnvironmentConfidence(void)
     {
      return(m_pair_ranking_weight_environment_confidence);
     }

   double            PairRankingWeightVolatilitySuitability(void)
     {
      return(m_pair_ranking_weight_volatility_suitability);
     }

   double            PairRankingWeightRegimeSuitability(void)
     {
      return(m_pair_ranking_weight_regime_suitability);
     }

   double            PairRankingWeightFreshness(void)
     {
      return(m_pair_ranking_weight_freshness);
     }
  };

#endif // FENX_CONFIG_PARAMETER_MANAGER_MQH

