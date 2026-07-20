//+------------------------------------------------------------------+
//|                 CapitalAllocation/CapitalAllocationEngine.mqh  |
//+------------------------------------------------------------------+
#ifndef FENX_CAPITAL_ALLOCATION_ENGINE_MQH
#define FENX_CAPITAL_ALLOCATION_ENGINE_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Engine/BaseEngine.mqh"

//--- Shared, factual Environment snapshot read through CDataBus.
struct SAllocationEnvironment
  {
   double   volatility_score;
   string   market_state;
   bool     range_data_valid;
   bool     trend_data_valid;
   datetime updated_at;
  };

//--- Global Pair Ranking validity and freshness facts read through CDataBus.
struct SAllocationRankingGlobal
  {
   bool     data_valid;
   datetime updated_at;
  };

//--- Per-symbol inputs supplied by Market Selection and Pair Ranking through CDataBus.
struct SCapitalAllocationInput
  {
   string   symbol;
   bool     is_market_eligible;
   bool     is_pair_ranked;
   int      pair_rank;
   double   pair_ranking_score;
   double   pair_ranking_confidence;
   datetime selection_updated_at;
   datetime ranking_updated_at;
  };

//--- Per-symbol allocation recommendation. Percentages are normalized units only.
struct SCapitalAllocationSnapshot
  {
   string   symbol;
   bool     is_allocated;
   double   allocation_percent;
   double   allocation_score;
   double   allocation_confidence;
   string   reason;
   datetime updated_at;
  };

//--- Candidate reference used while deterministically distributing the normalized budget.
struct SCapitalAllocationCandidate
  {
   int    snapshot_index;
   int    pair_rank;
  };

//--- Global allocation recommendation published after each allocation cycle.
struct SGlobalCapitalAllocationSnapshot
  {
   int      allocated_symbol_count;
   double   total_allocated_percent;
   double   unallocated_percent;
   string   top_allocated_symbol;
   bool     data_valid;
   datetime updated_at;
  };

//--- Distributes a normalized budget; it has no account, margin, lot-size, position, or order logic.
class CCapitalAllocationEngine : public CBaseEngine
  {
private:
   string m_symbols[];
   double m_total_budget;
   double m_max_per_symbol;
   double m_min_threshold;
   int    m_max_funded_symbols;
   double m_concentration_limit;
   double m_confidence_threshold;
   int    m_stale_data_limit_seconds;
   double m_volatility_penalty;
   double m_transition_penalty;
   double m_high_volatility_score;

   void ResetSnapshot(SCapitalAllocationSnapshot &snapshot,const string symbol)
     {
      snapshot.symbol=symbol;
      snapshot.is_allocated=false;
      snapshot.allocation_percent=0.0;
      snapshot.allocation_score=0.0;
      snapshot.allocation_confidence=0.0;
      snapshot.reason="";
      snapshot.updated_at=TimeCurrent();
     }

   void ResetGlobalSnapshot(SGlobalCapitalAllocationSnapshot &snapshot)
     {
      snapshot.allocated_symbol_count=0;
      snapshot.total_allocated_percent=0.0;
      snapshot.unallocated_percent=100.0;
      snapshot.top_allocated_symbol="";
      snapshot.data_valid=false;
      snapshot.updated_at=TimeCurrent();
     }

   double ClampPercent(const double value)
     {
      return(MathMax(0.0,MathMin(100.0,value)));
     }

   bool ReadBooleanText(const string text,bool &value)
     {
      if(text=="true" || text=="TRUE")
        {
         value=true;
         return(true);
        }
      if(text=="false" || text=="FALSE")
        {
         value=false;
         return(true);
        }

      return(false);
     }

   bool ReadBoolean(const string key,bool &value)
     {
      if(m_data_bus==NULL)
         return(false);

      string text="";
      return(m_data_bus.TryGetText(key,text) && ReadBooleanText(text,value));
     }

   bool ReadDouble(const string key,double &value)
     {
      if(m_data_bus==NULL)
         return(false);

      string text="";
      if(!m_data_bus.TryGetText(key,text) || StringLen(text)==0)
         return(false);

      value=StringToDouble(text);
      return(true);
     }

   bool ReadTimestampText(const string text,datetime &value)
     {
      if(StringLen(text)==0)
         return(false);

      value=StringToTime(text);
      return(value>0);
     }

   bool ReadEnvironment(SAllocationEnvironment &environment)
     {
      if(m_data_bus==NULL)
         return(false);

      string updated_at_text="";
      if(!ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_SCORE,
                     environment.volatility_score) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_STATE,
                                environment.market_state) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID,
                      environment.range_data_valid) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_TREND_DATA_VALID,
                      environment.trend_data_valid) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_UPDATED_AT,
                                updated_at_text) ||
         !ReadTimestampText(updated_at_text,environment.updated_at))
         return(false);

      if(environment.volatility_score<0.0 || environment.volatility_score>100.0 ||
         !environment.range_data_valid || !environment.trend_data_valid)
         return(false);

      return(environment.market_state=="RANGING" || environment.market_state=="TRENDING" ||
             environment.market_state=="VOLATILE" || environment.market_state=="TRANSITION");
     }

   bool ReadRankingGlobal(SAllocationRankingGlobal &ranking)
     {
      if(m_data_bus==NULL)
         return(false);

      string updated_at_text="";
      return(ReadBoolean(FENX_DATABUS_KEY_PAIR_RANKING_DATA_VALID,ranking.data_valid) &&
             m_data_bus.TryGetText(FENX_DATABUS_KEY_PAIR_RANKING_UPDATED_AT,updated_at_text) &&
             ReadTimestampText(updated_at_text,ranking.updated_at));
     }

   bool ReadSymbolInput(const string symbol,SCapitalAllocationInput &input)
     {
      if(m_data_bus==NULL)
         return(false);

      string text="";
      string selection_updated_at_text="";
      string ranking_updated_at_text="";
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
                                      FENX_DATABUS_FIELD_MARKET_SELECTION_SYMBOL,input.symbol) ||
         input.symbol!=symbol ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
                                      FENX_DATABUS_FIELD_MARKET_SELECTION_IS_ELIGIBLE,text) ||
         !ReadBooleanText(text,input.is_market_eligible) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
                                      FENX_DATABUS_FIELD_MARKET_SELECTION_UPDATED_AT,
                                      selection_updated_at_text) ||
         !ReadTimestampText(selection_updated_at_text,input.selection_updated_at) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_SYMBOL,text) ||
         text!=symbol ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_IS_RANKED,text) ||
         !ReadBooleanText(text,input.is_pair_ranked) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_RANK,text))
         return(false);

      input.pair_rank=(int)StringToInteger(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_SCORE,text))
         return(false);
      input.pair_ranking_score=StringToDouble(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_CONFIDENCE,text))
         return(false);
      input.pair_ranking_confidence=StringToDouble(text);
      if(!m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                                      FENX_DATABUS_FIELD_PAIR_RANKING_UPDATED_AT,
                                      ranking_updated_at_text) ||
         !ReadTimestampText(ranking_updated_at_text,input.ranking_updated_at))
         return(false);

      return(input.pair_rank>=0 && input.pair_ranking_score>=0.0 &&
             input.pair_ranking_score<=100.0 && input.pair_ranking_confidence>=0.0 &&
             input.pair_ranking_confidence<=100.0);
     }

   bool CalculateFreshness(const datetime updated_at,double &freshness)
     {
      if(updated_at<=0 || m_stale_data_limit_seconds<=0)
         return(false);

      const long age_seconds=(long)(TimeCurrent()-updated_at);
      if(age_seconds<0 || age_seconds>m_stale_data_limit_seconds)
         return(false);

      freshness=ClampPercent(100.0*(1.0-((double)age_seconds/m_stale_data_limit_seconds)));
      return(true);
     }

   double CalculateVolatilityFactor(const double volatility_score)
     {
      if(m_high_volatility_score>=100.0 || volatility_score<=m_high_volatility_score)
         return(1.0);

      const double severity=(volatility_score-m_high_volatility_score)/
                            (100.0-m_high_volatility_score);
      return(MathMax(0.0,1.0-((m_volatility_penalty/100.0)*severity)));
     }

   double CalculateTransitionFactor(const string market_state)
     {
      if(market_state=="TRANSITION")
         return(MathMax(0.0,1.0-(m_transition_penalty/100.0)));

      return(1.0);
     }

   void BuildAllocationScore(const SCapitalAllocationInput &input,
                             const SAllocationEnvironment &environment,
                             const double freshness,SCapitalAllocationSnapshot &snapshot)
     {
      const double confidence_factor=input.pair_ranking_confidence/100.0;
      const double volatility_factor=CalculateVolatilityFactor(environment.volatility_score);
      const double transition_factor=CalculateTransitionFactor(environment.market_state);
      snapshot.allocation_score=ClampPercent(input.pair_ranking_score*confidence_factor*
                                              volatility_factor*transition_factor*(freshness/100.0));
      snapshot.allocation_confidence=ClampPercent(input.pair_ranking_confidence*(freshness/100.0));
      snapshot.reason="Allocation candidate accepted.";
     }

   bool HasHigherAllocationPriority(const SCapitalAllocationCandidate &left,
                                    const SCapitalAllocationCandidate &right,
                                    SCapitalAllocationSnapshot &snapshots[])
     {
      if(snapshots[left.snapshot_index].allocation_score>
         snapshots[right.snapshot_index].allocation_score+FENX_PAIR_RANKING_COMPARE_EPSILON)
         return(true);
      if(snapshots[right.snapshot_index].allocation_score>
         snapshots[left.snapshot_index].allocation_score+FENX_PAIR_RANKING_COMPARE_EPSILON)
         return(false);

      if(snapshots[left.snapshot_index].allocation_confidence>
         snapshots[right.snapshot_index].allocation_confidence+FENX_PAIR_RANKING_COMPARE_EPSILON)
         return(true);
      if(snapshots[right.snapshot_index].allocation_confidence>
         snapshots[left.snapshot_index].allocation_confidence+FENX_PAIR_RANKING_COMPARE_EPSILON)
         return(false);

      if(left.pair_rank<right.pair_rank)
         return(true);
      if(right.pair_rank<left.pair_rank)
         return(false);

      return(StringCompare(snapshots[left.snapshot_index].symbol,
                           snapshots[right.snapshot_index].symbol)<0);
     }

   void SortCandidates(SCapitalAllocationCandidate &candidates[],
                       SCapitalAllocationSnapshot &snapshots[])
     {
      for(int first=0;first<ArraySize(candidates)-1;first++)
        {
         int best=first;
         for(int next=first+1;next<ArraySize(candidates);next++)
           {
            if(HasHigherAllocationPriority(candidates[next],candidates[best],snapshots))
               best=next;
           }

         if(best!=first)
           {
            const int first_snapshot_index=candidates[first].snapshot_index;
            const int first_pair_rank=candidates[first].pair_rank;
            candidates[first].snapshot_index=candidates[best].snapshot_index;
            candidates[first].pair_rank=candidates[best].pair_rank;
            candidates[best].snapshot_index=first_snapshot_index;
            candidates[best].pair_rank=first_pair_rank;
           }
        }
     }

   void DistributeBudget(SCapitalAllocationCandidate &candidates[],const int candidate_count,
                         bool &funded[],SCapitalAllocationSnapshot &snapshots[],
                         const double effective_cap)
     {
      for(int index=0;index<candidate_count;index++)
        {
         const int snapshot_index=candidates[index].snapshot_index;
         snapshots[snapshot_index].allocation_percent=0.0;
        }

      for(int pass=0;pass<candidate_count;pass++)
        {
         double total_allocated=0.0;
         double available_weight=0.0;
         for(int index=0;index<candidate_count;index++)
           {
            const int snapshot_index=candidates[index].snapshot_index;
            total_allocated+=snapshots[snapshot_index].allocation_percent;
            if(funded[index] && snapshots[snapshot_index].allocation_percent<effective_cap-
               FENX_PAIR_RANKING_COMPARE_EPSILON)
               available_weight+=snapshots[snapshot_index].allocation_score;
           }

         const double remaining_budget=m_total_budget-total_allocated;
         if(remaining_budget<=FENX_PAIR_RANKING_COMPARE_EPSILON || available_weight<=0.0)
            return;

         bool capped_candidate=false;
         for(int index=0;index<candidate_count;index++)
           {
            const int snapshot_index=candidates[index].snapshot_index;
            if(!funded[index] || snapshots[snapshot_index].allocation_percent>=effective_cap-
               FENX_PAIR_RANKING_COMPARE_EPSILON)
               continue;

            const double suggested=remaining_budget*
                                   snapshots[snapshot_index].allocation_score/available_weight;
            const double capacity=effective_cap-snapshots[snapshot_index].allocation_percent;
            if(suggested>=capacity-FENX_PAIR_RANKING_COMPARE_EPSILON)
              {
               snapshots[snapshot_index].allocation_percent+=capacity;
               capped_candidate=true;
              }
           }

         if(!capped_candidate)
           {
            for(int index=0;index<candidate_count;index++)
              {
               const int snapshot_index=candidates[index].snapshot_index;
               if(funded[index] && snapshots[snapshot_index].allocation_percent<effective_cap-
                  FENX_PAIR_RANKING_COMPARE_EPSILON)
                  snapshots[snapshot_index].allocation_percent+=remaining_budget*
                    snapshots[snapshot_index].allocation_score/available_weight;
              }
            return;
           }
        }
     }

   void ApplyMinimumThreshold(SCapitalAllocationCandidate &candidates[],const int candidate_count,
                              bool &funded[],SCapitalAllocationSnapshot &snapshots[],
                              const double effective_cap)
     {
      for(int pass=0;pass<candidate_count;pass++)
        {
         DistributeBudget(candidates,candidate_count,funded,snapshots,effective_cap);
         bool removed_candidate=false;
         for(int index=0;index<candidate_count;index++)
           {
            const int snapshot_index=candidates[index].snapshot_index;
            if(funded[index] && snapshots[snapshot_index].allocation_percent<
               m_min_threshold-FENX_PAIR_RANKING_COMPARE_EPSILON)
              {
               funded[index]=false;
               snapshots[snapshot_index].allocation_percent=0.0;
               snapshots[snapshot_index].reason="Allocation is below the minimum threshold.";
               removed_candidate=true;
              }
           }

         if(!removed_candidate)
            return;
        }
     }

   bool PublishSnapshot(SCapitalAllocationSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);

      bool success=true;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_SYMBOL,snapshot.symbol))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_IS_ALLOCATED,
                                   (snapshot.is_allocated ? "true" : "false")))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_PERCENT,
                                   DoubleToString(snapshot.allocation_percent,2)))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_SCORE,
                                   DoubleToString(snapshot.allocation_score,2)))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_CONFIDENCE,
                                   DoubleToString(snapshot.allocation_confidence,2)))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_REASON,snapshot.reason))
         success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,snapshot.symbol,
                                   FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_UPDATED_AT,
                                   TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS)))
         success=false;

      return(success);
     }

   bool PublishGlobalSnapshot(SGlobalCapitalAllocationSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);

      bool success=true;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_SYMBOL_COUNT,
                             IntegerToString(snapshot.allocated_symbol_count)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_TOTAL_PERCENT,
                             DoubleToString(snapshot.total_allocated_percent,2)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_UNALLOCATED_PE…4712 tokens truncated…range_boundary_trim_fraction);
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

   double            CapitalAllocationTotalBudget(void)
     {
      return(m_capital_allocation_total_budget);
     }

   double            CapitalAllocationMaxPerSymbol(void)
     {
      return(m_capital_allocation_max_per_symbol);
     }

   double            CapitalAllocationMinThreshold(void)
     {
      return(m_capital_allocation_min_threshold);
     }

   int               CapitalAllocationMaxFundedSymbols(void)
     {
      return(m_capital_allocation_max_funded_symbols);
     }

   double            CapitalAllocationConcentrationLimit(void)
     {
      return(m_capital_allocation_concentration_limit);
     }

   double            CapitalAllocationConfidenceThreshold(void)
     {
      return(m_capital_allocation_confidence_threshold);
     }

   int               CapitalAllocationStaleDataLimitSeconds(void)
     {
      return(m_capital_allocation_stale_data_limit_seconds);
     }

   double            CapitalAllocationVolatilityPenalty(void)
     {
      return(m_capital_allocation_volatility_penalty);
     }

   double            CapitalAllocationTransitionPenalty(void)
     {
      return(m_capital_allocation_transition_penalty);
     }
  };

#endif // FENX_CONFIG_PARAMETER_MANAGER_MQH
