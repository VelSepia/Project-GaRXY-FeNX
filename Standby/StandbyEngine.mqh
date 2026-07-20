//+------------------------------------------------------------------+
//|                                  Standby/StandbyEngine.mqh     |
//+------------------------------------------------------------------+
#ifndef FENX_STANDBY_ENGINE_MQH
#define FENX_STANDBY_ENGINE_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Engine/BaseEngine.mqh"

//--- Factual Environment data supplied by the earlier Environment Engine.
struct SStandbyEnvironment
  {
   string   market_state;
   double   market_confidence;
   double   atr;
   double   range_upper;
   double   range_lower;
   double   range_width_points;
   double   range_position;
   double   range_score;
   bool     is_range;
   bool     range_data_valid;
   double   trend_score;
   double   trend_strength;
   string   trend_direction;
   bool     trend_data_valid;
   double   volatility_score;
   datetime market_updated_at;
   datetime range_updated_at;
   datetime range_closed_bar_time;
   datetime trend_updated_at;
  };

//--- Global validity and freshness facts supplied by upstream engines.
struct SStandbyPipeline
  {
   bool     pair_ranking_valid;
   datetime pair_ranking_updated_at;
   bool     allocation_valid;
   datetime allocation_updated_at;
   bool     style_valid;
   datetime style_updated_at;
   bool     strategy_valid;
   datetime strategy_updated_at;
  };

//--- Per-symbol facts consumed only through CDataBus.
struct SStandbyInput
  {
   string   symbol;
   bool     is_market_eligible;
   datetime market_selection_updated_at;
   bool     is_pair_ranked;
   int      pair_rank;
   double   pair_ranking_score;
   datetime pair_ranking_updated_at;
   bool     is_capital_allocated;
   double   capital_allocation_percent;
   datetime capital_allocation_updated_at;
   string   trading_style;
   bool     is_trading_style_valid;
   datetime trading_style_updated_at;
   string   selected_strategy;
   double   strategy_selection_confidence;
   bool     is_strategy_selection_valid;
   datetime strategy_selection_updated_at;
  };

//--- Persistent state retained per configured symbol to prevent state flapping.
struct SStandbyRuntime
  {
   string   state;
   datetime entered_at;
   datetime state_changed_at;
   datetime last_confirmation_bar_time;
   int      entry_confirmation_count;
   int      recovery_confirmation_count;
   bool     duration_warning_logged;
   bool     critical_warning_logged;
  };

//--- Per-symbol non-executable standby recommendation.
struct SStandbySnapshot
  {
   string   symbol;
   string   state;
   bool     is_active;
   bool     are_new_entries_allowed;
   bool     preserve_existing_positions;
   string   reason;
   double   confidence;
   datetime entered_at;
   long     duration_seconds;
   double   recovery_progress;
   double   escalation_score;
   string   recommended_next_state;
   bool     is_data_valid;
   datetime updated_at;
  };

//--- Global Standby Engine snapshot.
struct SGlobalStandbySnapshot
  {
   int      active_symbol_count;
   int      recovery_pending_count;
   int      escalation_pending_count;
   int      risk_stop_pending_count;
   bool     system_valid;
   datetime updated_at;
  };

//--- Coordinates temporary protective standby recommendations without executing trades.
class CStandbyEngine : public CBaseEngine
  {
private:
   string          m_symbols[];
   SStandbyRuntime m_runtime[];
   int             m_entry_confirmation_bars;
   int             m_recovery_confirmation_bars;
   int             m_max_duration_seconds;
   double          m_breakout_distance_points;
   double          m_breakout_distance_atr_multiple;
   double          m_min_range_recovery_score;
   double          m_trend_escalation_threshold;
   double          m_volatility_escalation_threshold;
   double          m_confidence_recovery_threshold;
   double          m_confidence_failure_threshold;
   int             m_transition_cooldown_seconds;
   int             m_stale_data_grace_seconds;
   int             m_base_stale_data_limit_seconds;

   double ClampPercent(const double value)
     {
      return(MathMax(0.0,MathMin(100.0,value)));
     }

   void ResetRuntime(SStandbyRuntime &runtime)
     {
      runtime.state="NORMAL";
      runtime.entered_at=0;
      runtime.state_changed_at=0;
      runtime.last_confirmation_bar_time=0;
      runtime.entry_confirmation_count=0;
      runtime.recovery_confirmation_count=0;
      runtime.duration_warning_logged=false;
      runtime.critical_warning_logged=false;
     }

   void ResetSnapshot(SStandbySnapshot &snapshot,const string symbol)
     {
      snapshot.symbol=symbol;
      snapshot.state="NORMAL";
      snapshot.is_active=false;
      snapshot.are_new_entries_allowed=false;
      snapshot.preserve_existing_positions=true;
      snapshot.reason="";
      snapshot.confidence=0.0;
      snapshot.entered_at=0;
      snapshot.duration_seconds=0;
      snapshot.recovery_progress=0.0;
      snapshot.escalation_score=0.0;
      snapshot.recommended_next_state="NORMAL";
      snapshot.is_data_valid=false;
      snapshot.updated_at=TimeCurrent();
     }

   void ResetGlobalSnapshot(SGlobalStandbySnapshot &snapshot)
     {
      snapshot.active_symbol_count=0;
      snapshot.recovery_pending_count=0;
      snapshot.escalation_pending_count=0;
      snapshot.risk_stop_pending_count=0;
      snapshot.system_valid=false;
      snapshot.updated_at=TimeCurrent();
     }

   void ResetEnvironment(SStandbyEnvironment &environment)
     {
      environment.market_state="TRANSITION";
      environment.market_confidence=0.0;
      environment.atr=0.0;
      environment.range_upper=0.0;
      environment.range_lower=0.0;
      environment.range_width_points=0.0;
      environment.range_position=0.0;
      environment.range_score=0.0;
      environment.is_range=false;
      environment.range_data_valid=false;
      environment.trend_score=0.0;
      environment.trend_strength=0.0;
      environment.trend_direction="NEUTRAL";
      environment.trend_data_valid=false;
      environment.volatility_score=0.0;
      environment.market_updated_at=0;
      environment.range_updated_at=0;
      environment.range_closed_bar_time=0;
      environment.trend_updated_at=0;
     }

   void ResetPipeline(SStandbyPipeline &pipeline)
     {
      pipeline.pair_ranking_valid=false;
      pipeline.pair_ranking_updated_at=0;
      pipeline.allocation_valid=false;
      pipeline.allocation_updated_at=0;
      pipeline.style_valid=false;
      pipeline.style_updated_at=0;
      pipeline.strategy_valid=false;
      pipeline.strategy_updated_at=0;
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

   bool ReadTimestamp(const string key,datetime &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      return(m_data_bus.TryGetText(key,text) && ReadTimestampText(text,value));
     }

   bool ReadEnvironment(SStandbyEnvironment &environment)
     {
      if(m_data_bus==NULL)
         return(false);

      if(!m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_STATE,
                                environment.market_state) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_CONFIDENCE,
                     environment.market_confidence) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_ATR,environment.atr) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPPER,environment.range_upper) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_LOWER,environment.range_lower) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_WIDTH_POINTS,
                     environment.range_width_points) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_POSITION,
                     environment.range_position) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE,environment.range_score) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_IS_RANGE,environment.is_range) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID,
                      environment.range_data_valid) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_SCORE,environment.trend_score) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_STRENGTH,
                     environment.trend_strength) ||
         !m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_TREND_DIRECTION,
                                environment.trend_direction) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_TREND_DATA_VALID,
                      environment.trend_data_valid) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_SCORE,
                     environment.volatility_score) ||
         !ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_UPDATED_AT,
                        environment.market_updated_at) ||
         !ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPDATED_AT,
                        environment.range_updated_at) ||
         !ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_CLOSED_BAR_TIME,
                        environment.range_closed_bar_time) ||
         !ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_TREND_UPDATED_AT,
                        environment.trend_updated_at))
         return(false);

      return((environment.market_state=="RANGING" || environment.market_state=="TRENDING" ||
              environment.market_state=="VOLATILE" || environment.market_state=="TRANSITION") &&
             environment.market_confidence>=0.0 && environment.market_confidence<=100.0 &&
             environment.atr>0.0 && environment.range_upper>environment.range_lower &&
             environment.range_width_points>0.0 && environment.range_position>=0.0 &&
             environment.range_position<=1.0 && environment.range_score>=0.0 &&
             environment.range_score<=100.0 && environment.trend_score>=0.0 &&
             environment.trend_score<=100.0 && environment.trend_strength>=0.0 &&
             environment.trend_strength<=100.0 && environment.volatility_score>=0.0 &&
             environment.volatility_score<=100.0);
     }

   bool ReadPipeline(SStandbyPipeline &pipeline)
     {
      return(ReadBoolean(FENX_DATABUS_KEY_PAIR_RANKING_DATA_VALID,
                         pipeline.pair_ranking_valid) &&
             ReadTimestamp(FENX_DATABUS_KEY_PAIR_RANKING_UPDATED_AT,
                           pipeline.pair_ranking_updated_at) &&
             ReadBoolean(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_DATA_VALID,
                         pipeline.allocation_valid) &&
             ReadTimestamp(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_UPDATED_AT,
                           pipeline.allocation_updated_at) &&
             ReadBoolean(FENX_DATABUS_KEY_TRADING_STYLE_DATA_VALID,pipeline.style_valid) &&
             ReadTimestamp(FENX_DATABUS_KEY_TRADING_STYLE_UPDATED_AT,
                           pipeline.style_updated_at) &&
             ReadBoolean(FENX_DATABUS_KEY_STRATEGY_SELECTION_DATA_VALID,
                         pipeline.strategy_valid) &&
             ReadTimestamp(FENX_DATABUS_KEY_STRATEGY_SELECTION_UPDATED_AT,
                           pipeline.strategy_updated_at));
     }

   bool ReadSymbolBoolean(const string name_space,const string symbol,const string field,
                          bool &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      return(m_data_bus.TryGetSymbolText(name_space,symbol,field,text) &&
             ReadBooleanText(text,value));
     }

   bool ReadSymbolDouble(const string name_space,const string symbol,const string field,
                         double &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      if(!m_data_bus.TryGetSymbolText(name_space,symbol,field,text) || StringLen(text)==0)
         return(false);
      value=StringToDouble(text);
      return(true);
     }

   bool ReadSymbolInteger(const string name_space,const string symbol,const string field,
                          int &value)
     {
      double numeric_value=0.0;
      if(!ReadSymbolDouble(name_space,symbol,field,numeric_value))
         return(false);
      value=(int)numeric_value;
      return(true);
     }

   bool ReadSymbolTimestamp(const string name_space,const string symbol,const string field,
                            datetime &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      return(m_data_bus.TryGetSymbolText(name_space,symbol,field,text) &&
             ReadTimestampText(text,value));
     }

   bool ReadSymbolInput(const string symbol,SStandbyInput &input)
     {
      if(m_data_bus==NULL)
         return(false);

      input.symbol=symbol;
      if(!ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
                            FENX_DATABUS_FIELD_MARKET_SELECTION_IS_ELIGIBLE,
                            input.is_market_eligible) ||
         !ReadSymbolTimestamp(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,symbol,
                              FENX_DATABUS_FIELD_MARKET_SELECTION_UPDATED_AT,
                              input.market_selection_updated_at) ||
         !ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                            FENX_DATABUS_FIELD_PAIR_RANKING_IS_RANKED,
                            input.is_pair_ranked) ||
         !ReadSymbolInteger(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                            FENX_DATABUS_FIELD_PAIR_RANKING_RANK,input.pair_rank) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                           FENX_DATABUS_FIELD_PAIR_RANKING_SCORE,
                           input.pair_ranking_score) ||
         !ReadSymbolTimestamp(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                              FENX_DATABUS_FIELD_PAIR_RANKING_UPDATED_AT,
                              input.pair_ranking_updated_at) ||
         !ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,symbol,
                            FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_IS_ALLOCATED,
                            input.is_capital_allocated) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,symbol,
                           FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_PERCENT,
                           input.capital_allocation_percent) ||
         !ReadSymbolTimestamp(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,symbol,
                              FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_UPDATED_AT,
                              input.capital_allocation_updated_at) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_TRADING_STYLE,symbol,
                                      FENX_DATABUS_FIELD_TRADING_STYLE,input.trading_style) ||
         !ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_TRADING_STYLE,symbol,
                            FENX_DATABUS_FIELD_TRADING_STYLE_IS_VALID,
                            input.is_trading_style_valid) ||
         !ReadSymbolTimestamp(FENX_DATABUS_NAMESPACE_TRADING_STYLE,symbol,
                              FENX_DATABUS_FIELD_TRADING_STYLE_UPDATED_AT,
                              input.trading_style_updated_at) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,symbol,
                                      FENX_DATABUS_FIELD_SELECTED_STRATEGY,
                                      input.selected_strategy) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,symbol,
                           FENX_DATABUS_FIELD_STRATEGY_SELECTION_CONFIDENCE,
                           input.strategy_selection_confidence) ||
         !ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,symbol,
                            FENX_DATABUS_FIELD_STRATEGY_SELECTION_IS_VALID,
                            input.is_strategy_selection_valid) ||
         !ReadSymbolTimestamp(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,symbol,
                              FENX_DATABUS_FIELD_STRATEGY_SELECTION_UPDATED_AT,
                              input.strategy_selection_updated_at))
         return(false);

      return(input.pair_rank>=0 && input.pair_ranking_score>=0.0 &&
             input.pair_ranking_score<=100.0 && input.capital_allocation_percent>=0.0 &&
             input.capital_allocation_percent<=100.0 &&
             input.strategy_selection_confidence>=0.0 &&
             input.strategy_selection_confidence<=100.0 &&
             (input.trading_style=="RANGE" || input.trading_style=="TREND" ||
              input.trading_style=="HYBRID" || input.trading_style=="STANDBY") &&
             (input.selected_strategy=="RANGE_MEAN_REVERSION" ||
              input.selected_strategy=="TREND_FOLLOWING" || input.selected_strategy=="BREAKOUT" ||
              input.selected_strategy=="HYBRID_ADAPTIVE" || input.selected_strategy=="NO_TRADE"));
     }

   bool IsTimestampFresh(const datetime updated_at,const int limit_seconds)
     {
      if(updated_at<=0 || limit_seconds<=0)
         return(false);
      const long age_seconds=(long)(TimeCurrent()-updated_at);
      return(age_seconds>=0 && age_seconds<=limit_seconds);
     }

   bool IsEnvironmentFresh(const SStandbyEnvironment &environment,const int limit_seconds)
     {
      return(IsTimestampFresh(environment.market_updated_at,limit_seconds) &&
             IsTimestampFresh(environment.range_updated_at,limit_seconds) &&
             IsTimestampFresh(environment.trend_updated_at,limit_seconds));
     }

   bool IsPipelineFresh(const SStandbyPipeline &pipeline,const int limit_seconds)
     {
      return(IsTimestampFresh(pipeline.pair_ranking_updated_at,limit_seconds) &&
             IsTimestampFresh(pipeline.allocation_updated_at,limit_seconds) &&
             IsTimestampFresh(pipeline.style_updated_at,limit_seconds) &&
             IsTimestampFresh(pipeline.strategy_updated_at,limit_seconds));
     }

   bool IsInputFresh(const SStandbyInput &input,const int limit_seconds)
     {
      return(IsTimestampFresh(input.market_selection_updated_at,limit_seconds) &&
             IsTimestampFresh(input.pair_ranking_updated_at,limit_seconds) &&
             IsTimestampFresh(input.capital_allocation_updated_at,limit_seconds) &&
             IsTimestampFresh(input.trading_style_updated_at,limit_seconds) &&
             IsTimestampFresh(input.strategy_selection_updated_at,limit_seconds));
     }

   bool LoadSymbols(CParameterManager &parameters)
     {
      const int symbol_count=parameters.MarketSelectionSymbolCount();
      if(symbol_count<0 || symbol_count>FENX_MARKET_SELECTION_MAX_SYMBOLS ||
         ArrayResize(m_symbols,symbol_count)!=symbol_count ||
         ArrayResize(m_runtime,symbol_count)!=symbol_count)
         return(false);

      for(int index=0;index<symbol_count;index++)
        {
         if(!parameters.TryGetMarketSelectionSymbol(index,m_symbols[index]) ||
            StringLen(m_symbols[index])==0)
            return(false);
         ResetRuntime(m_runtime[index]);
        }
      return(true);
     }

   bool IsNewConfirmationBar(SStandbyRuntime &runtime,const datetime closed_bar_time)
     {
      if(closed_bar_time<=0 || closed_bar_time<=…2628 tokens truncated…G",symbol,
                            "Duration, trend, volatility, or confidence indicates structural change.");
         else if(recovery_condition && IsCooldownComplete(runtime))
           {
            SetRuntimeState(runtime,"RECOVERY_PENDING",symbol,
                            "Recovery conditions were observed; awaiting completed-bar confirmation.");
            if(is_new_bar)
               runtime.recovery_confirmation_count++;
            if(runtime.recovery_confirmation_count>=m_recovery_confirmation_bars)
               SetRuntimeState(runtime,"NORMAL",symbol,
                               "Recovery conditions persisted across completed-bar confirmations.");
           }
         return;
        }

      if(runtime.state=="RECOVERY_PENDING")
        {
         if(severe_condition)
            SetRuntimeState(runtime,"RISK_STOP_PENDING",symbol,
                            "Recovery data became unsafe and requires risk review.");
         else if(entry_condition)
            SetRuntimeState(runtime,"STANDBY",symbol,
                            "A temporary entry condition returned during recovery confirmation.");
         else if(escalation_condition)
            SetRuntimeState(runtime,"ESCALATION_PENDING",symbol,
                            "Recovery did not prevent a structural condition.");
         else
           {
            if(is_new_bar)
               runtime.recovery_confirmation_count++;
            if(runtime.recovery_confirmation_count>=m_recovery_confirmation_bars)
               SetRuntimeState(runtime,"NORMAL",symbol,
                               "Recovery conditions persisted across completed-bar confirmations.");
           }
         return;
        }

      if(runtime.state=="ESCALATION_PENDING")
        {
         if(severe_condition)
            SetRuntimeState(runtime,"RISK_STOP_PENDING",symbol,
                            "Escalated condition requires immediate risk review.");
         else if(recovery_condition && IsCooldownComplete(runtime))
           {
            SetRuntimeState(runtime,"RECOVERY_PENDING",symbol,
                            "Escalated condition improved; awaiting recovery confirmation.");
            if(is_new_bar)
               runtime.recovery_confirmation_count++;
           }
         return;
        }
      // RISK_STOP_PENDING remains stable until the future Risk Engine owns the outcome.
     }

   string RecommendedNextState(const string standby_state)
     {
      if(standby_state=="ESCALATION_PENDING")
         return("DYNAMIC_ZONE");
      if(standby_state=="RISK_STOP_PENDING")
         return("RISK_STOP");
      if(standby_state=="ENTERING_STANDBY" || standby_state=="STANDBY" ||
         standby_state=="RECOVERY_PENDING")
         return("STANDBY");
      return("NORMAL");
     }

   void BuildSnapshot(const SStandbyRuntime &runtime,const SStandbyEnvironment &environment,
                      const SStandbyInput &input,const bool is_participant,const bool data_valid,
                      const bool data_fresh,SStandbySnapshot &snapshot)
     {
      snapshot.state=runtime.state;
      snapshot.is_active=(runtime.state!="NORMAL" && is_participant);
      snapshot.preserve_existing_positions=true;
      snapshot.entered_at=(snapshot.is_active ? runtime.entered_at : 0);
      if(snapshot.entered_at>0)
         snapshot.duration_seconds=MathMax(0,(long)(TimeCurrent()-snapshot.entered_at));
      snapshot.confidence=CalculateStandbyConfidence(environment,input,data_fresh);
      snapshot.escalation_score=CalculateEscalationScore(runtime,environment,
                                                          IsBoundaryBreach(environment),data_valid);
      snapshot.recommended_next_state=RecommendedNextState(runtime.state);
      snapshot.is_data_valid=data_valid;
      snapshot.are_new_entries_allowed=(runtime.state=="NORMAL" && is_participant && data_valid &&
                                        input.is_market_eligible && input.is_pair_ranked &&
                                        input.is_trading_style_valid &&
                                        input.is_strategy_selection_valid &&
                                        input.trading_style!="STANDBY" &&
                                        input.selected_strategy!="NO_TRADE");
      if(runtime.state=="RECOVERY_PENDING")
         snapshot.recovery_progress=ClampPercent(100.0*runtime.recovery_confirmation_count/
                                                  MathMax(1,m_recovery_confirmation_bars));
      else if(runtime.state=="NORMAL")
         snapshot.recovery_progress=100.0;

      if(!is_participant)
         snapshot.reason="Symbol is not currently capital allocated; standby monitoring is inactive.";
      else if(runtime.state=="ENTERING_STANDBY")
         snapshot.reason="Temporary condition is awaiting completed-bar entry confirmation.";
      else if(runtime.state=="STANDBY")
         snapshot.reason="New-entry permission is paused while existing positions are preserved.";
      else if(runtime.state=="RECOVERY_PENDING")
         snapshot.reason="Recovery is awaiting completed-bar confirmation before NORMAL is requested.";
      else if(runtime.state=="ESCALATION_PENDING")
         snapshot.reason="Structural change is pending DYNAMIC_ZONE review.";
      else if(runtime.state=="RISK_STOP_PENDING")
         snapshot.reason="Critical condition is pending future Risk Engine review.";
      else if(!data_valid)
         snapshot.reason="Required DataBus facts are invalid, unavailable, or stale.";
      else
         snapshot.reason="Normal participation conditions are currently available.";
     }

   bool PublishSnapshot(const SStandbySnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);
      bool success=true;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_STATE,snapshot.state)) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_IS_ACTIVE,
                                   (snapshot.is_active ? "true" : "false"))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_NEW_ENTRIES_ALLOWED,
                                   (snapshot.are_new_entries_allowed ? "true" : "false"))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_PRESERVE_POSITIONS,"true")) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_REASON,snapshot.reason)) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_CONFIDENCE,
                                   DoubleToString(snapshot.confidence,2))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_ENTERED_AT,
                                   TimeToString(snapshot.entered_at,TIME_DATE|TIME_SECONDS))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_DURATION_SECONDS,
                                   IntegerToString((int)snapshot.duration_seconds))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_RECOVERY_PROGRESS,
                                   DoubleToString(snapshot.recovery_progress,2))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_ESCALATION_SCORE,
                                   DoubleToString(snapshot.escalation_score,2))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_RECOMMENDED_NEXT_STATE,
                                   snapshot.recommended_next_state)) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_DATA_VALID,
                                   (snapshot.is_data_valid ? "true" : "false"))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,snapshot.symbol,
                                   FENX_DATABUS_FIELD_STANDBY_UPDATED_AT,
                                   TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS))) success=false;
      return(success);
     }

   bool PublishGlobalSnapshot(const SGlobalStandbySnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);
      bool success=true;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_STANDBY_ACTIVE_SYMBOL_COUNT,
                             IntegerToString(snapshot.active_symbol_count))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_STANDBY_RECOVERY_PENDING_COUNT,
                             IntegerToString(snapshot.recovery_pending_count))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_STANDBY_ESCALATION_PENDING_COUNT,
                             IntegerToString(snapshot.escalation_pending_count))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_STANDBY_RISK_STOP_PENDING_COUNT,
                             IntegerToString(snapshot.risk_stop_pending_count))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_STANDBY_SYSTEM_VALID,
                             (snapshot.system_valid ? "true" : "false"))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_STANDBY_SYSTEM_UPDATED_AT,
                             TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS))) success=false;
      return(success);
     }

   void RequestCoreState(const SGlobalStandbySnapshot &snapshot)
     {
      if(m_state_manager==NULL || m_state_manager.GetState()==FENX_STATE_SHUTDOWN ||
         m_state_manager.GetState()==FENX_STATE_RISK_STOP)
         return;

      if(snapshot.risk_stop_pending_count>0)
        {
         m_state_manager.RequestTransition(FENX_STATE_RISK_STOP,"StandbyEngine");
         return;
        }
      if(snapshot.escalation_pending_count>0)
        {
         if(m_state_manager.GetState()==FENX_STATE_STANDBY)
            m_state_manager.RequestTransition(FENX_STATE_DYNAMIC_ZONE,"StandbyEngine");
         else if(m_state_manager.GetState()==FENX_STATE_NORMAL)
            m_state_manager.RequestTransition(FENX_STATE_STANDBY,"StandbyEngine");
         return;
        }
      if(snapshot.active_symbol_count>0)
        {
         if(m_state_manager.GetState()==FENX_STATE_NORMAL ||
            m_state_manager.GetState()==FENX_STATE_DYNAMIC_ZONE)
            m_state_manager.RequestTransition(FENX_STATE_STANDBY,"StandbyEngine");
         return;
        }
      if(m_state_manager.GetState()==FENX_STATE_STANDBY ||
         m_state_manager.GetState()==FENX_STATE_DYNAMIC_ZONE)
         m_state_manager.RequestTransition(FENX_STATE_NORMAL,"StandbyEngine");
     }

public:
                     CStandbyEngine(void)
     {
      SetName("StandbyEngine");
      m_entry_confirmation_bars=0;
      m_recovery_confirmation_bars=0;
      m_max_duration_seconds=0;
      m_breakout_distance_points=0.0;
      m_breakout_distance_atr_multiple=0.0;
      m_min_range_recovery_score=0.0;
      m_trend_escalation_threshold=0.0;
      m_volatility_escalation_threshold=0.0;
      m_confidence_recovery_threshold=0.0;
      m_confidence_failure_threshold=0.0;
      m_transition_cooldown_seconds=0;
      m_stale_data_grace_seconds=0;
      m_base_stale_data_limit_seconds=0;
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);

      m_entry_confirmation_bars=parameters.StandbyEntryConfirmationBars();
      m_recovery_confirmation_bars=parameters.StandbyRecoveryConfirmationBars();
      m_max_duration_seconds=parameters.StandbyMaxDurationSeconds();
      m_breakout_distance_points=parameters.StandbyBreakoutDistancePoints();
      m_breakout_distance_atr_multiple=parameters.StandbyBreakoutDistanceAtrMultiple();
      m_min_range_recovery_score=parameters.StandbyMinRangeRecoveryScore();
      m_trend_escalation_threshold=parameters.StandbyTrendEscalationThreshold();
      m_volatility_escalation_threshold=parameters.StandbyVolatilityEscalationThreshold();
      m_confidence_recovery_threshold=parameters.StandbyConfidenceRecoveryThreshold();
      m_confidence_failure_threshold=parameters.StandbyConfidenceFailureThreshold();
      m_transition_cooldown_seconds=parameters.StandbyTransitionCooldownSeconds();
      m_stale_data_grace_seconds=parameters.StandbyStaleDataGraceSeconds();
      m_base_stale_data_limit_seconds=parameters.StrategySelectionStaleDataLimitSeconds();

      if(!LoadSymbols(parameters) || m_entry_confirmation_bars<1 ||
         m_recovery_confirmation_bars<1 || m_max_duration_seconds<1 ||
         m_breakout_distance_points<0.0 || m_breakout_distance_atr_multiple<0.0 ||
         m_min_range_recovery_score<0.0 || m_min_range_recovery_score>100.0 ||
         m_trend_escalation_threshold<=0.0 || m_trend_escalation_threshold>100.0 ||
         m_volatility_escalation_threshold<=0.0 || m_volatility_escalation_threshold>100.0 ||
         m_confidence_recovery_threshold<=0.0 || m_confidence_recovery_threshold>100.0 ||
         m_confidence_failure_threshold<0.0 ||
         m_confidence_failure_threshold>=m_confidence_recovery_threshold ||
         m_transition_cooldown_seconds<0 || m_stale_data_grace_seconds<0 ||
         m_base_stale_data_limit_seconds<1)
        {
         CLogger::Error("StandbyEngine received invalid configuration.");
         CBaseEngine::Shutdown();
         return(false);
        }

      CLogger::Info(StringFormat("StandbyEngine configured for %d symbol(s) with %d/%d bar confirmation.",
                                 ArraySize(m_symbols),m_entry_confirmation_bars,
                                 m_recovery_confirmation_bars));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;

      SStandbyEnvironment environment;
      SStandbyPipeline pipeline;
      ResetEnvironment(environment);
      ResetPipeline(pipeline);
      const bool environment_available=ReadEnvironment(environment);
      const bool pipeline_available=ReadPipeline(pipeline);
      const bool environment_fresh=(environment_available &&
                                    IsEnvironmentFresh(environment,m_base_stale_data_limit_seconds));
      const bool pipeline_fresh=(pipeline_available &&
                                 IsPipelineFresh(pipeline,m_base_stale_data_limit_seconds));
      const bool environment_within_grace=(environment_available &&
                                           IsEnvironmentFresh(environment,
                                           m_base_stale_data_limit_seconds+m_stale_data_grace_seconds));
      const bool pipeline_within_grace=(pipeline_available &&
                                        IsPipelineFresh(pipeline,
                                        m_base_stale_data_limit_seconds+m_stale_data_grace_seconds));
      if(!environment_available || !pipeline_available)
         CLogger::Warning("StandbyEngine is waiting for complete Environment and upstream DataBus facts.");

      const int symbol_count=ArraySize(m_symbols);
      SStandbySnapshot snapshots[];
      if(ArrayResize(snapshots,symbol_count)!=symbol_count)
        {
         CLogger::Error("StandbyEngine could not allocate per-symbol snapshots.");
         return;
        }

      SGlobalStandbySnapshot global_snapshot;
      ResetGlobalSnapshot(global_snapshot);
      bool all_data_valid=(environment_available && pipeline_available && environment_fresh &&
                           pipeline_fresh && environment.range_data_valid &&
                           environment.trend_data_valid && pipeline.pair_ranking_valid &&
                           pipeline.allocation_valid && pipeline.style_valid &&
                           pipeline.strategy_valid);
      for(int index=0;index<symbol_count;index++)
        {
         ResetSnapshot(snapshots[index],m_symbols[index]);
         SStandbyInput input;
         const bool input_available=ReadSymbolInput(m_symbols[index],input);
         const bool input_fresh=(input_available &&
                                 IsInputFresh(input,m_base_stale_data_limit_seconds));
         const bool input_within_grace=(input_available &&
                                        IsInputFresh(input,m_base_stale_data_limit_seconds+
                                        m_stale_data_grace_seconds));
         const bool raw_data_available=(environment_available && pipeline_available && input_available);
         const bool data_fresh=(environment_fresh && pipeline_fresh && input_fresh);
         const bool within_grace=(environment_within_grace && pipeline_within_grace &&
                                  input_within_grace);
         const bool data_valid=(data_fresh && environment.range_data_valid &&
                                environment.trend_data_valid && pipeline.pair_ranking_valid &&
                                pipeline.allocation_valid && pipeline.style_valid &&
                                pipeline.strategy_valid && input.is_market_eligible &&
                                input.is_pair_ranked && input.is_trading_style_valid &&
                                input.is_strategy_selection_valid);
         const bool is_participant=(input_available && input.is_capital_allocated &&
                                    input.capital_allocation_percent>0.0);

         if(!input_available)
           {
            snapshots[index].reason="Per-symbol eligibility, ranking, allocation, style, or strategy data is unavailable.";
            snapshots[index].is_data_valid=false;
            all_data_valid=false;
            continue;
           }

         if(is_participant)
            UpdateRuntime(m_runtime[index],m_symbols[index],environment,pipeline,input,
                          raw_data_available,data_fresh,within_grace,data_valid);
         else
            ResetRuntime(m_runtime[index]);

         BuildSnapshot(m_runtime[index],environment,input,is_participant,data_valid,
                       data_fresh,snapshots[index]);
         if(!snapshots[index].is_data_valid)
            all_data_valid=false;
         if(snapshots[index].is_active)
            global_snapshot.active_symbol_count++;
         if(snapshots[index].state=="RECOVERY_PENDING")
            global_snapshot.recovery_pending_count++;
         if(snapshots[index].state=="ESCALATION_PENDING")
            global_snapshot.escalation_pending_count++;
         if(snapshots[index].state=="RISK_STOP_PENDING")
            global_snapshot.risk_stop_pending_count++;
        }

      global_snapshot.system_valid=all_data_valid;
      for(int index=0;index<symbol_count;index++)
        {
         if(!PublishSnapshot(snapshots[index]))
            CLogger::Error(StringFormat("StandbyEngine could not publish %s.",m_symbols[index]));
        }
      if(!PublishGlobalSnapshot(global_snapshot))
         CLogger::Error("StandbyEngine could not publish global standby data.");
      RequestCoreState(global_snapshot);
     }

   virtual void       Shutdown(void)
     {
      ArrayFree(m_symbols);
      ArrayFree(m_runtime);
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_STANDBY_ENGINE_MQH
