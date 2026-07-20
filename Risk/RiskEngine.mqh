//+------------------------------------------------------------------+
//|                                      Risk/RiskEngine.mqh       |
//+------------------------------------------------------------------+
#ifndef FENX_RISK_ENGINE_MQH
#define FENX_RISK_ENGINE_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Engine/BaseEngine.mqh"

//--- Environment facts consumed from CDataBus only.
struct SRiskEnvironment
  {
   string   market_state;
   double   market_confidence;
   double   volatility_score;
   double   range_score;
   double   trend_score;
   double   trend_strength;
   bool     range_data_valid;
   bool     trend_data_valid;
   datetime market_updated_at;
   datetime range_updated_at;
   datetime trend_updated_at;
  };

//--- Global upstream validity, timestamps, and aggregate facts.
struct SRiskPipeline
  {
   bool     pair_ranking_valid;
   datetime pair_ranking_updated_at;
   bool     allocation_valid;
   datetime allocation_updated_at;
   double   total_allocated_percent;
   bool     style_valid;
   datetime style_updated_at;
   bool     strategy_valid;
   datetime strategy_updated_at;
   bool     standby_valid;
   datetime standby_updated_at;
   int      standby_active_count;
   int      standby_escalation_count;
   int      standby_risk_stop_count;
  };

//--- Per-symbol records supplied by prior engines through CDataBus.
struct SRiskInput
  {
   string   symbol;
   bool     is_market_eligible;
   datetime market_selection_updated_at;
   bool     is_pair_ranked;
   int      pair_rank;
   double   pair_ranking_score;
   double   pair_ranking_confidence;
   datetime pair_ranking_updated_at;
   bool     is_capital_allocated;
   double   capital_allocation_percent;
   datetime capital_allocation_updated_at;
   string   trading_style;
   double   trading_style_confidence;
   bool     is_trading_style_valid;
   datetime trading_style_updated_at;
   string   selected_strategy;
   double   strategy_selection_confidence;
   bool     is_strategy_selection_valid;
   datetime strategy_selection_updated_at;
   string   standby_state;
   bool     is_standby_active;
   bool     are_new_entries_allowed;
   double   standby_escalation_score;
   string   standby_recommended_next_state;
   bool     standby_data_valid;
   datetime standby_updated_at;
  };

//--- Per-symbol persistent hysteresis state.
struct SRiskRuntime
  {
   string   state;
   datetime state_changed_at;
   int      unsafe_confirmation_count;
   int      recovery_confirmation_count;
  };

//--- Per-symbol final risk recommendation; it never represents an execution command.
struct SRiskSnapshot
  {
   string   symbol;
   string   state;
   string   action;
   bool     is_risk_approved;
   bool     are_new_entries_risk_approved;
   double   allocation_multiplier;
   double   score;
   double   confidence;
   string   reason;
   bool     preserve_existing_positions;
   bool     escalation_required;
   bool     data_valid;
   datetime updated_at;
  };

//--- System-level final risk recommendation.
struct SSystemRiskSnapshot
  {
   string   state;
   double   score;
   double   confidence;
   bool     trading_allowed;
   bool     new_entries_allowed;
   double   allocation_multiplier;
   int      suspended_symbol_count;
   int      risk_stop_required_count;
   int      invalid_symbol_count;
   string   reason;
   bool     data_valid;
   datetime updated_at;
  };

//--- Final safety authority for future execution. It publishes recommendations only.
class CRiskEngine : public CBaseEngine
  {
private:
   string        m_symbols[];
   SRiskRuntime  m_runtime[];
   SRiskRuntime  m_system_runtime;
   ENUM_FENX_STATE m_last_requested_state;
   bool          m_invalid_system_logged;
   double        m_caution_threshold;
   double        m_reduced_threshold;
   double        m_suspended_threshold;
   double        m_risk_stop_threshold;
   double        m_volatility_threshold;
   double        m_minimum_confidence;
   double        m_max_allocation_per_symbol;
   double        m_max_aggregate_allocation;
   double        m_max_concentration_ratio;
   int           m_stale_data_limit_seconds;
   double        m_invalid_symbol_ratio_threshold;
   double        m_standby_escalation_threshold;
   int           m_unsafe_confirmation_count;
   int           m_recovery_confirmation_count;
   int           m_transition_cooldown_seconds;
   double        m_caution_allocation_multiplier;
   double        m_reduced_allocation_multiplier;

   double ClampPercent(const double value)
     {
      return(MathMax(0.0,MathMin(100.0,value)));
     }

   void ResetRuntime(SRiskRuntime &runtime)
     {
      runtime.state="SAFE";
      runtime.state_changed_at=0;
      runtime.unsafe_confirmation_count=0;
      runtime.recovery_confirmation_count=0;
     }

   void ResetEnvironment(SRiskEnvironment &environment)
     {
      environment.market_state="TRANSITION";
      environment.market_confidence=0.0;
      environment.volatility_score=0.0;
      environment.range_score=0.0;
      environment.trend_score=0.0;
      environment.trend_strength=0.0;
      environment.range_data_valid=false;
      environment.trend_data_valid=false;
      environment.market_updated_at=0;
      environment.range_updated_at=0;
      environment.trend_updated_at=0;
     }

   void ResetPipeline(SRiskPipeline &pipeline)
     {
      pipeline.pair_ranking_valid=false;
      pipeline.pair_ranking_updated_at=0;
      pipeline.allocation_valid=false;
      pipeline.allocation_updated_at=0;
      pipeline.total_allocated_percent=0.0;
      pipeline.style_valid=false;
      pipeline.style_updated_at=0;
      pipeline.strategy_valid=false;
      pipeline.strategy_updated_at=0;
      pipeline.standby_valid=false;
      pipeline.standby_updated_at=0;
      pipeline.standby_active_count=0;
      pipeline.standby_escalation_count=0;
      pipeline.standby_risk_stop_count=0;
     }

   void ResetSnapshot(SRiskSnapshot &snapshot,const string symbol)
     {
      snapshot.symbol=symbol;
      snapshot.state="RISK_STOP_REQUIRED";
      snapshot.action="REQUEST_RISK_STOP";
      snapshot.is_risk_approved=false;
      snapshot.are_new_entries_risk_approved=false;
      snapshot.allocation_multiplier=0.0;
      snapshot.score=100.0;
      snapshot.confidence=0.0;
      snapshot.reason="Risk data is unavailable.";
      snapshot.preserve_existing_positions=true;
      snapshot.escalation_required=true;
      snapshot.data_valid=false;
      snapshot.updated_at=TimeCurrent();
     }

   void ResetSystemSnapshot(SSystemRiskSnapshot &snapshot)
     {
      snapshot.state="SYSTEM_SAFE";
      snapshot.score=0.0;
      snapshot.confidence=100.0;
      snapshot.trading_allowed=true;
      snapshot.new_entries_allowed=true;
      snapshot.allocation_multiplier=1.0;
      snapshot.suspended_symbol_count=0;
      snapshot.risk_stop_required_count=0;
      snapshot.invalid_symbol_count=0;
      snapshot.reason="No configured symbols require risk evaluation.";
      snapshot.data_valid=true;
      snapshot.updated_at=TimeCurrent();
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

   bool ReadInteger(const string key,int &value)
     {
      double numeric_value=0.0;
      if(!ReadDouble(key,numeric_value))
         return(false);
      value=(int)numeric_value;
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

   bool ReadEnvironment(SRiskEnvironment &environment)
     {
      if(m_data_bus==NULL)
         return(false);
      if(!m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_STATE,
                                environment.market_state) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_CONFIDENCE,
                     environment.market_confidence) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_SCORE,
                     environment.volatility_score) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE,environment.range_score) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_SCORE,environment.trend_score) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_STRENGTH,
                     environment.trend_strength) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID,
                      environment.range_data_valid) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_TREND_DATA_VALID,
                      environment.trend_data_valid) ||
         !ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_UPDATED_AT,
                        environment.market_updated_at) ||
         !ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPDATED_AT,
                        environment.range_updated_at) ||
         !ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_TREND_UPDATED_AT,
                        environment.trend_updated_at))
         return(false);

      return((environment.market_state=="RANGING" || environment.market_state=="TRENDING" ||
              environment.market_state=="VOLATILE" || environment.market_state=="TRANSITION") &&
             environment.market_confidence>=0.0 && environment.market_confidence<=100.0 &&
             environment.volatility_score>=0.0 && environment.volatility_score<=100.0 &&
             environment.range_score>=0.0 && environment.range_score<=100.0 &&
             environment.trend_score>=0.0 && environment.trend_score<=100.0 &&
             environment.trend_strength>=0.0 && environment.trend_strength<=100.0);
     }

   bool ReadPipeline(SRiskPipeline &pipeline)
     {
      return(ReadBoolean(FENX_DATABUS_KEY_PAIR_RANKING_DATA_VALID,
                         pipeline.pair_ranking_valid) &&
             ReadTimestamp(FENX_DATABUS_KEY_PAIR_RANKING_UPDATED_AT,
                           pipeline.pair_ranking_updated_at) &&
             ReadBoolean(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_DATA_VALID,
                         pipeline.allocation_valid) &&
             ReadTimestamp(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_UPDATED_AT,
                           pipeline.allocation_updated_at) &&
             ReadDouble(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_TOTAL_PERCENT,
                        pipeline.total_allocated_percent) &&
             ReadBoolean(FENX_DATABUS_KEY_TRADING_STYLE_DATA_VALID,pipeline.style_valid) &&
             ReadTimestamp(FENX_DATABUS_KEY_TRADING_STYLE_UPDATED_AT,
                           pipeline.style_updated_at) &&
             ReadBoolean(FENX_DATABUS_KEY_STRATEGY_SELECTION_DATA_VALID,
                         pipeline.strategy_valid) &&
             ReadTimestamp(FENX_DATABUS_KEY_STRATEGY_SELECTION_UPDATED_AT,
                           pipeline.strategy_updated_at) &&
             ReadBoolean(FENX_DATABUS_KEY_STANDBY_SYSTEM_VALID,pipeline.standby_valid) &&
             ReadTimestamp(FENX_DATABUS_KEY_STANDBY_SYSTEM_UPDATED_AT,
                           pipeline.standby_updated_at) &&
             ReadInteger(FENX_DATABUS_KEY_STANDBY_ACTIVE_SYMBOL_COUNT,
                         pipeline.standby_active_count) &&
             ReadInteger(FENX_DATABUS_KEY_STANDBY_ESCALATION_PENDING_COUNT,
                         pipeline.standby_escalation_count) &&
             ReadInteger(FENX_DATABUS_KEY_STANDBY_RISK_STOP_PENDING_COUNT,
                         pipeline.standby_risk_stop_count));
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

   bool ReadSymbolInput(const string symbol,SRiskInput &input)
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
                           FENX_DATABUS_FIELD_PAIR_RANKING_SCORE,input.pair_ranking_score) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_PAIR_RANKING,symbol,
                           FENX_DATABUS_FIELD_PAIR_RANKING_CONFIDENCE,
                           input.pair_ranking_confidence) ||
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
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_TRADING_STYLE,symbol,
                           FENX_DATABUS_FIELD_TRADING_STYLE_CONFIDENCE,
                           input.trading_style_confidence) ||
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
                              input.strategy_selection_updated_at) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,symbol,
                                      FENX_DATABUS_FIELD_STANDBY_STATE,input.standby_state) ||
         !ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STANDBY,symbol,
                            FENX_DATABUS_FIELD_STANDBY_IS_ACTIVE,input.is_standby_active) ||
         !ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STANDBY,symbol,
                            FENX_DATABUS_FIELD_STANDBY_NEW_ENTRIES_ALLOWED,
                            input.are_new_entries_allowed) ||
         !ReadSymbolDouble(FENX_DATABUS_NAMESPACE_STANDBY,symbol,
                           FENX_DATABUS_FIELD_STANDBY_ESCALATION_SCORE,
                           input.standby_escalation_score) ||
         !m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STANDBY,symbol,
                                      FENX_DATABUS_FIELD_STANDBY_RECOMMENDED_NEXT_STATE,
                                      input.standby_recommended_next_state) ||
         !ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STANDBY,symbol,
                            FENX_DATABUS_FIELD_STANDBY_DATA_VALID,input.standby_data_valid) ||
         !ReadSymbolTimestamp(FENX_DATABUS_NAMESPACE_STANDBY,symbol,
                              FENX_DATABUS_FIELD_STANDBY_UPDATED_AT,input.standby_updated_at))
         return(false);

      return(input.pair_rank>=0 && input.pair_ranking_score>=0.0 &&
             input.pair_ranking_score<=100.0 && input.pair_ranking_confidence>=0.0 &&
             input.pair_ranking_confidence<=100.0 && input.capital_allocation_percent>=0.0 &&
             input.capital_allocation_percent<=100.0 && input.trading_style_confidence>=0.0 &&
             input.trading_style_confidence<=100.0 && input.strategy_selection_confidence>=0.0 &&
             input.strategy_selection_confidence<=100.0 && input.standby_escalation_score>=0.0 &&
             input.standby_escalation_score<=100.0 &&
             (input.trading_style=="RANGE" || input.trading_style=="TREND" ||
              input.trading_style=="HYBRID" || input.trading_style=="STANDBY") &&
             (input.selected_strategy=="RANGE_MEAN_REVERSION" ||
              input.selected_strategy=="TREND_FOLLOWING" || input.selected_strategy=="BREAKOUT" ||
              input.selected_strategy=="HYBRID_ADAPTIVE" || input.selected_strategy…3362 tokens truncated… : "false"))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_NEW_ENTRIES_RISK_APPROVED,
                                   (snapshot.are_new_entries_risk_approved ? "true" : "false"))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_RECOMMENDED_ALLOCATION_MULTIPLIER,
                                   DoubleToString(snapshot.allocation_multiplier,2))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_RISK_SCORE,
                                   DoubleToString(snapshot.score,2))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_RISK_CONFIDENCE,
                                   DoubleToString(snapshot.confidence,2))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_RISK_REASON,snapshot.reason)) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_RISK_PRESERVE_POSITIONS,"true")) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_RISK_ESCALATION_REQUIRED,
                                   (snapshot.escalation_required ? "true" : "false"))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_RISK_DATA_VALID,
                                   (snapshot.data_valid ? "true" : "false"))) success=false;
      if(!m_data_bus.SetSymbolText(FENX_DATABUS_NAMESPACE_RISK,snapshot.symbol,
                                   FENX_DATABUS_FIELD_RISK_UPDATED_AT,
                                   TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS))) success=false;
      return(success);
     }

   double SystemScore(const int symbol_count,const int suspended_count,const int risk_stop_count,
                      const int invalid_count,const int standby_or_escalation_count,
                      const double total_allocated,const double largest_allocation,
                      const bool global_data_valid,const bool contradictory)
     {
      if(symbol_count<=0)
         return(0.0);
      const double denominator=(double)symbol_count;
      const double suspended_ratio=suspended_count/denominator;
      const double risk_stop_ratio=risk_stop_count/denominator;
      const double invalid_ratio=invalid_count/denominator;
      const double standby_ratio=standby_or_escalation_count/denominator;
      const double aggregate_risk=(total_allocated>m_max_aggregate_allocation ?
         ClampPercent(100.0*(total_allocated-m_max_aggregate_allocation)/
                      MathMax(1.0,100.0-m_max_aggregate_allocation)) : 0.0);
      const double concentration_ratio=(total_allocated>0.0 ? largest_allocation/total_allocated : 0.0);
      const double concentration_risk=(concentration_ratio>m_max_concentration_ratio ?
         ClampPercent(100.0*(concentration_ratio-m_max_concentration_ratio)/
                      MathMax(0.01,1.0-m_max_concentration_ratio)) : 0.0);
      return(ClampPercent((0.20*100.0*suspended_ratio)+(0.25*100.0*risk_stop_ratio)+
                          (0.10*aggregate_risk)+(0.10*concentration_risk)+
                          (0.15*100.0*invalid_ratio)+(0.10*ClampPercent(100.0*standby_ratio))+
                          (!global_data_valid && invalid_count==0 ? 5.0 : 0.0)+
                          (contradictory ? 5.0 : 0.0)));
     }

   string SystemCandidateState(const int symbol_count,const int risk_stop_count,
                               const int invalid_count,const double system_score)
     {
      if(symbol_count<=0) return("SAFE");
      if(risk_stop_count>0) return("RISK_STOP_REQUIRED");
      if((double)invalid_count/symbol_count>=m_invalid_symbol_ratio_threshold)
         return("SUSPENDED");
      if(system_score>=m_risk_stop_threshold) return("RISK_STOP_REQUIRED");
      if(system_score>=m_suspended_threshold) return("SUSPENDED");
      if(system_score>=m_reduced_threshold) return("REDUCED");
      if(system_score>=m_caution_threshold) return("CAUTION");
      return("SAFE");
     }

   void BuildSystemSnapshot(const string final_state,const double score,const double confidence,
                            const int suspended_count,const int risk_stop_count,
                            const int invalid_count,const bool data_valid,
                            const bool all_symbol_entries_allowed,SSystemRiskSnapshot &snapshot)
     {
      snapshot.state="SYSTEM_"+final_state;
      snapshot.score=score;
      snapshot.confidence=confidence;
      snapshot.suspended_symbol_count=suspended_count;
      snapshot.risk_stop_required_count=risk_stop_count;
      snapshot.invalid_symbol_count=invalid_count;
      snapshot.data_valid=data_valid;
      snapshot.allocation_multiplier=AllocationMultiplier(final_state);
      snapshot.trading_allowed=(final_state=="SAFE" || final_state=="CAUTION" ||
                                final_state=="REDUCED");
      snapshot.new_entries_allowed=(snapshot.trading_allowed && all_symbol_entries_allowed);
      if(final_state=="RISK_STOP_REQUIRED")
         snapshot.reason="Critical system risk requires future Risk Engine handling and no forced closure is performed.";
      else if(final_state=="SUSPENDED")
         snapshot.reason="System risk is suspended pending valid, stable recovery conditions.";
      else if(final_state=="REDUCED")
         snapshot.reason="System risk permits reduced recommended exposure only.";
      else if(final_state=="CAUTION")
         snapshot.reason="System caution reduces recommended exposure.";
      else
         snapshot.reason="System risk inputs support normal future-entry permission.";
      snapshot.updated_at=TimeCurrent();
     }

   bool PublishSystemSnapshot(const SSystemRiskSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);
      bool success=true;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SYSTEM_STATE,snapshot.state)) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SYSTEM_SCORE,
                             DoubleToString(snapshot.score,2))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SYSTEM_CONFIDENCE,
                             DoubleToString(snapshot.confidence,2))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SYSTEM_TRADING_ALLOWED,
                             (snapshot.trading_allowed ? "true" : "false"))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SYSTEM_NEW_ENTRIES_ALLOWED,
                             (snapshot.new_entries_allowed ? "true" : "false"))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SYSTEM_ALLOCATION_MULTIPLIER,
                             DoubleToString(snapshot.allocation_multiplier,2))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SUSPENDED_SYMBOL_COUNT,
                             IntegerToString(snapshot.suspended_symbol_count))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_STOP_REQUIRED_COUNT,
                             IntegerToString(snapshot.risk_stop_required_count))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_INVALID_SYMBOL_COUNT,
                             IntegerToString(snapshot.invalid_symbol_count))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SYSTEM_REASON,snapshot.reason)) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SYSTEM_DATA_VALID,
                             (snapshot.data_valid ? "true" : "false"))) success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_RISK_SYSTEM_UPDATED_AT,
                             TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS))) success=false;
      return(success);
     }

   void RequestCoreState(const SSystemRiskSnapshot &system_snapshot,
                         const bool has_dynamic_escalation,const bool has_entry_block)
     {
      if(m_state_manager==NULL || m_state_manager.GetState()==FENX_STATE_SHUTDOWN ||
         m_state_manager.GetState()==FENX_STATE_RISK_STOP)
         return;

      ENUM_FENX_STATE requested_state=FENX_STATE_NORMAL;
      if(system_snapshot.state=="SYSTEM_RISK_STOP")
         requested_state=FENX_STATE_RISK_STOP;
      else if(has_dynamic_escalation)
         requested_state=FENX_STATE_DYNAMIC_ZONE;
      else if(system_snapshot.state!="SYSTEM_SAFE" || has_entry_block)
         requested_state=FENX_STATE_STANDBY;

      if(requested_state==m_last_requested_state ||
         requested_state==m_state_manager.GetState())
        {
         m_last_requested_state=requested_state;
         return;
        }
      if(m_state_manager.RequestTransition(requested_state,"RiskEngine"))
         m_last_requested_state=requested_state;
      else
         CLogger::Error("RiskEngine state transition request was rejected.");
     }

public:
                     CRiskEngine(void)
     {
      SetName("RiskEngine");
      ResetRuntime(m_system_runtime);
      m_last_requested_state=FENX_STATE_INIT;
      m_invalid_system_logged=false;
      m_caution_threshold=0.0;
      m_reduced_threshold=0.0;
      m_suspended_threshold=0.0;
      m_risk_stop_threshold=0.0;
      m_volatility_threshold=0.0;
      m_minimum_confidence=0.0;
      m_max_allocation_per_symbol=0.0;
      m_max_aggregate_allocation=0.0;
      m_max_concentration_ratio=0.0;
      m_stale_data_limit_seconds=0;
      m_invalid_symbol_ratio_threshold=0.0;
      m_standby_escalation_threshold=0.0;
      m_unsafe_confirmation_count=0;
      m_recovery_confirmation_count=0;
      m_transition_cooldown_seconds=0;
      m_caution_allocation_multiplier=0.0;
      m_reduced_allocation_multiplier=0.0;
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);

      m_caution_threshold=parameters.RiskCautionThreshold();
      m_reduced_threshold=parameters.RiskReducedThreshold();
      m_suspended_threshold=parameters.RiskSuspendedThreshold();
      m_risk_stop_threshold=parameters.RiskStopThreshold();
      m_volatility_threshold=parameters.RiskVolatilityThreshold();
      m_minimum_confidence=parameters.RiskMinimumConfidence();
      m_max_allocation_per_symbol=parameters.RiskMaxAllocationPerSymbol();
      m_max_aggregate_allocation=parameters.RiskMaxAggregateAllocation();
      m_max_concentration_ratio=parameters.RiskMaxConcentrationRatio();
      m_stale_data_limit_seconds=parameters.RiskStaleDataLimitSeconds();
      m_invalid_symbol_ratio_threshold=parameters.RiskInvalidSymbolRatioThreshold();
      m_standby_escalation_threshold=parameters.RiskStandbyEscalationThreshold();
      m_unsafe_confirmation_count=parameters.RiskUnsafeConfirmationCount();
      m_recovery_confirmation_count=parameters.RiskRecoveryConfirmationCount();
      m_transition_cooldown_seconds=parameters.RiskTransitionCooldownSeconds();
      m_caution_allocation_multiplier=parameters.RiskCautionAllocationMultiplier();
      m_reduced_allocation_multiplier=parameters.RiskReducedAllocationMultiplier();

      if(!LoadSymbols(parameters) || m_caution_threshold<0.0 ||
         m_caution_threshold>=m_reduced_threshold ||
         m_reduced_threshold>=m_suspended_threshold ||
         m_suspended_threshold>=m_risk_stop_threshold || m_risk_stop_threshold>100.0 ||
         m_volatility_threshold<=0.0 || m_volatility_threshold>100.0 ||
         m_minimum_confidence<=0.0 || m_minimum_confidence>100.0 ||
         m_max_allocation_per_symbol<=0.0 || m_max_allocation_per_symbol>100.0 ||
         m_max_aggregate_allocation<=0.0 || m_max_aggregate_allocation>100.0 ||
         m_max_concentration_ratio<=0.0 || m_max_concentration_ratio>1.0 ||
         m_stale_data_limit_seconds<=0 || m_invalid_symbol_ratio_threshold<=0.0 ||
         m_invalid_symbol_ratio_threshold>1.0 || m_standby_escalation_threshold<0.0 ||
         m_standby_escalation_threshold>100.0 || m_unsafe_confirmation_count<1 ||
         m_recovery_confirmation_count<1 || m_transition_cooldown_seconds<0 ||
         m_caution_allocation_multiplier<=0.0 || m_caution_allocation_multiplier>=1.0 ||
         m_reduced_allocation_multiplier<=0.0 ||
         m_reduced_allocation_multiplier>=m_caution_allocation_multiplier)
        {
         CLogger::Error("RiskEngine received invalid configuration.");
         CBaseEngine::Shutdown();
         return(false);
        }

      CLogger::Info(StringFormat("RiskEngine configured for %d symbol(s).",ArraySize(m_symbols)));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;

      const int symbol_count=ArraySize(m_symbols);
      SSystemRiskSnapshot system_snapshot;
      ResetSystemSnapshot(system_snapshot);
      if(symbol_count==0)
        {
         PublishSystemSnapshot(system_snapshot);
         RequestCoreState(system_snapshot,false,false);
         return;
        }

      SRiskEnvironment environment;
      SRiskPipeline pipeline;
      ResetEnvironment(environment);
      ResetPipeline(pipeline);
      const bool environment_available=ReadEnvironment(environment);
      const bool pipeline_available=ReadPipeline(pipeline);
      const bool environment_fresh=(environment_available && IsEnvironmentFresh(environment));
      const bool pipeline_fresh=(pipeline_available && IsPipelineFresh(pipeline));
      const bool upstream_valid=(environment_available && pipeline_available && environment_fresh &&
                                 pipeline_fresh && environment.range_data_valid &&
                                 environment.trend_data_valid && pipeline.pair_ranking_valid &&
                                 pipeline.allocation_valid && pipeline.style_valid &&
                                 pipeline.strategy_valid && pipeline.standby_valid);
      if(!upstream_valid && !m_invalid_system_logged)
        {
         CLogger::Error("RiskEngine detected invalid, missing, or stale upstream risk data.");
         m_invalid_system_logged=true;
        }
      if(upstream_valid)
         m_invalid_system_logged=false;

      SRiskSnapshot snapshots[];
      if(ArrayResize(snapshots,symbol_count)!=symbol_count)
        {
         CLogger::Error("RiskEngine could not allocate per-symbol snapshots.");
         return;
        }

      int suspended_count=0;
      int risk_stop_count=0;
      int invalid_count=0;
      int standby_count=0;
      int escalation_count=0;
      int standby_or_escalation_count=0;
      double largest_allocation=0.0;
      double confidence_total=0.0;
      bool all_entries_allowed=true;
      bool all_data_valid=upstream_valid;
      bool has_dynamic_escalation=false;
      bool has_entry_block=false;
      for(int index=0;index<symbol_count;index++)
        {
         ResetSnapshot(snapshots[index],m_symbols[index]);
         SRiskInput input;
         const bool input_available=ReadSymbolInput(m_symbols[index],input);
         const bool input_fresh=(input_available && IsInputFresh(input));
         const bool data_valid=(upstream_valid && input_available && input_fresh &&
                                input.is_trading_style_valid && input.is_strategy_selection_valid &&
                                input.standby_data_valid);
         if(!input_available)
           {
            SetRuntimeState(m_runtime[index],"RISK_STOP_REQUIRED",m_symbols[index],
                            "Required symbol-level risk records are unavailable.");
            snapshots[index].reason="Required symbol-level risk records are unavailable.";
            invalid_count++;
            risk_stop_count++;
            all_entries_allowed=false;
            all_data_valid=false;
            has_entry_block=true;
            continue;
           }

         const double score=CalculateRiskScore(environment,input,data_valid);
         const double confidence=CalculateRiskConfidence(environment,input,data_valid);
         const string candidate=CandidateState(environment,input,score,confidence,data_valid);
         const string final_state=ApplyHysteresis(m_runtime[index],candidate,m_symbols[index],
                                                  RiskReason(candidate,input,data_valid));
         BuildSnapshot(final_state,environment,input,score,confidence,data_valid,snapshots[index]);
         if(!data_valid)
            invalid_count++;
         if(!data_valid)
            all_data_valid=false;
         if(input.is_standby_active)
            standby_count++;
         if(input.standby_recommended_next_state=="DYNAMIC_ZONE" ||
            input.standby_escalation_score>=m_standby_escalation_threshold)
            escalation_count++;
         if(input.is_standby_active || input.standby_recommended_next_state=="DYNAMIC_ZONE" ||
            input.standby_escalation_score>=m_standby_escalation_threshold)
            standby_or_escalation_count++;
         if(snapshots[index].state=="SUSPENDED")
            suspended_count++;
         if(snapshots[index].state=="RISK_STOP_REQUIRED")
            risk_stop_count++;
         if(!snapshots[index].are_new_entries_risk_approved)
            {
             all_entries_allowed=false;
             has_entry_block=true;
            }
         if(snapshots[index].action=="ESCALATE_DYNAMIC_ZONE")
            has_dynamic_escalation=true;
         if(snapshots[index].action=="REQUEST_RISK_STOP")
            has_entry_block=true;
         largest_allocation=MathMax(largest_allocation,input.capital_allocation_percent);
         confidence_total+=snapshots[index].confidence;
        }

      const bool contradictory=(pipeline.standby_active_count!=standby_count ||
                                pipeline.standby_escalation_count!=escalation_count ||
                                (pipeline.standby_risk_stop_count>0 && risk_stop_count==0));
      const double system_score=SystemScore(symbol_count,suspended_count,risk_stop_count,
                                            invalid_count,standby_or_escalation_count,
                                            pipeline.total_allocated_percent,largest_allocation,
                                            all_data_valid,contradictory);
      const string system_candidate=SystemCandidateState(symbol_count,risk_stop_count,
                                                          invalid_count,system_score);
      const string final_system_state=ApplyHysteresis(m_system_runtime,system_candidate,"SYSTEM",
                                                       "System risk inputs changed.");
      const double system_confidence=(all_data_valid ?
         ClampPercent(confidence_total/symbol_count) : 0.0);
      BuildSystemSnapshot(final_system_state,system_score,system_confidence,suspended_count,
                          risk_stop_count,invalid_count,all_data_valid,all_entries_allowed,
                          system_snapshot);
      for(int index=0;index<symbol_count;index++)
        {
         if(!PublishSnapshot(snapshots[index]))
            CLogger::Error(StringFormat("RiskEngine could not publish %s.",m_symbols[index]));
        }
      if(!PublishSystemSnapshot(system_snapshot))
         CLogger::Error("RiskEngine could not publish global risk data.");
      RequestCoreState(system_snapshot,has_dynamic_escalation,has_entry_block);
     }

   virtual void       Shutdown(void)
     {
      ArrayFree(m_symbols);
      ArrayFree(m_runtime);
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_RISK_ENGINE_MQH
