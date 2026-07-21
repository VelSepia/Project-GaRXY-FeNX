//+------------------------------------------------------------------+
//|                                  Execution/ExecutionGate.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_EXECUTION_GATE_MQH
#define FENX_EXECUTION_GATE_MQH

#include "../Common/Constants.mqh"
#include "../Core/DataBus.mqh"
#include "../Core/StateManager.mqh"

//--- Final non-executable permission returned to the execution lifecycle.
struct SExecutionGateResult
  {
   bool   allowed;
   bool   data_valid;
   double allocation_multiplier;
   string reason;
  };

//--- Reads final DataBus permissions and state before a strategy may create an order request.
class CExecutionGate
  {
private:
   CDataBus      *m_data_bus;
   CStateManager *m_state_manager;
   string         m_symbol;
   bool           m_execution_enabled;
   double         m_maximum_spread_points;
   double         m_minimum_range_score;
   double         m_minimum_strategy_confidence;
   double         m_minimum_risk_confidence;
   int            m_stale_data_limit_seconds;

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

   bool ReadSymbolBoolean(const string name_space,const string field,bool &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      return(m_data_bus.TryGetSymbolText(name_space,m_symbol,field,text) &&
             ReadBooleanText(text,value));
     }

   bool ReadSymbolDouble(const string name_space,const string field,double &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      if(!m_data_bus.TryGetSymbolText(name_space,m_symbol,field,text) || StringLen(text)==0)
         return(false);
      value=StringToDouble(text);
      return(true);
     }

   bool ReadSymbolTimestamp(const string name_space,const string field,datetime &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      return(m_data_bus.TryGetSymbolText(name_space,m_symbol,field,text) &&
             ReadTimestampText(text,value));
     }

   bool IsFresh(const datetime timestamp)
     {
      if(timestamp<=0 || m_stale_data_limit_seconds<=0)
         return(false);
      const long age=(long)(TimeCurrent()-timestamp);
      return(age>=0 && age<=m_stale_data_limit_seconds);
     }

   void ResetResult(SExecutionGateResult &result)
     {
      result.allowed=false;
      result.data_valid=false;
      result.allocation_multiplier=0.0;
      result.reason="Execution Gate has not received valid data.";
     }

public:
                     CExecutionGate(void)
     {
      m_data_bus=NULL;
      m_state_manager=NULL;
      m_symbol="";
      m_execution_enabled=false;
      m_maximum_spread_points=0.0;
      m_minimum_range_score=0.0;
      m_minimum_strategy_confidence=0.0;
      m_minimum_risk_confidence=0.0;
      m_stale_data_limit_seconds=0;
     }

   void              Configure(CDataBus &data_bus,CStateManager *state_manager,
                               const string symbol,const bool execution_enabled,
                               const double maximum_spread_points,
                               const double minimum_range_score,
                               const double minimum_strategy_confidence,
                               const double minimum_risk_confidence,
                               const int stale_data_limit_seconds)
     {
      m_data_bus=GetPointer(data_bus);
      m_state_manager=state_manager;
      m_symbol=symbol;
      m_execution_enabled=execution_enabled;
      m_maximum_spread_points=maximum_spread_points;
      m_minimum_range_score=minimum_range_score;
      m_minimum_strategy_confidence=minimum_strategy_confidence;
      m_minimum_risk_confidence=minimum_risk_confidence;
      m_stale_data_limit_seconds=stale_data_limit_seconds;
     }

   bool              Evaluate(const double spread_points,SExecutionGateResult &result)
     {
      ResetResult(result);
      if(m_data_bus==NULL || m_state_manager==NULL)
        {
         result.reason="Execution Gate is not initialized.";
         return(false);
        }
      if(!m_execution_enabled)
        {
         result.reason="Execution is disabled by configuration.";
         return(false);
        }
      if(m_symbol!="USDJPY")
        {
         result.reason="Minimal execution supports USDJPY only.";
         return(false);
        }
      if(m_state_manager.GetState()!=FENX_STATE_NORMAL)
        {
         result.reason="Framework state is not NORMAL.";
         return(false);
        }
      if(spread_points<0.0 || spread_points>m_maximum_spread_points)
        {
         result.reason="Current spread exceeds the execution limit.";
         return(false);
        }

      bool eligible=false,ranked=false,allocated=false,style_valid=false,strategy_valid=false;
      bool range_data_valid=false;
      bool standby_active=false,standby_entries_allowed=false,standby_data_valid=false;
      bool risk_approved=false,risk_entries_approved=false,risk_data_valid=false;
      bool ranking_data_valid=false,allocation_data_valid=false,style_data_valid=false;
      bool strategy_data_valid=false,standby_system_valid=false,risk_system_valid=false;
      bool system_trading_allowed=false,system_entries_allowed=false;
      double range_score=0.0,strategy_confidence=0.0,risk_confidence=0.0;
      double symbol_multiplier=0.0,system_multiplier=0.0;
      string market_state="",trading_style="",selected_strategy="",risk_action="";
      datetime market_updated=0,range_updated=0,selection_updated=0,ranking_updated=0;
      datetime allocation_updated=0,style_updated=0,strategy_updated=0,standby_updated=0;
      datetime risk_updated=0,risk_system_updated=0;

      const bool complete=(m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_STATE,
                                                  market_state) &&
                           ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE,range_score) &&
                           ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID,
                                       range_data_valid) &&
                           ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_UPDATED_AT,market_updated) &&
                           ReadTimestamp(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPDATED_AT,range_updated) &&
                           ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,
                                             FENX_DATABUS_FIELD_MARKET_SELECTION_IS_ELIGIBLE,eligible) &&
                           ReadSymbolTimestamp(FENX_DATABUS_NAMESPACE_MARKET_SELECTION,
                                                FENX_DATABUS_FIELD_MARKET_SELECTION_UPDATED_AT,selection_updated) &&
                           ReadBoolean(FENX_DATABUS_KEY_PAIR_RANKING_DATA_VALID,ranking_data_valid) &&
                           ReadTimestamp(FENX_DATABUS_KEY_PAIR_RANKING_UPDATED_AT,ranking_updated) &&
                           ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_PAIR_RANKING,
                                             FENX_DATABUS_FIELD_PAIR_RANKING_IS_RANKED,ranked) &&
                           ReadBoolean(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_DATA_VALID,
                                       allocation_data_valid) &&
                           ReadTimestamp(FENX_DATABUS_KEY_CAPITAL_ALLOCATION_UPDATED_AT,
                                         allocation_updated) &&
                           ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_CAPITAL_ALLOCATION,
                                             FENX_DATABUS_FIELD_CAPITAL_ALLOCATION_IS_ALLOCATED,allocated) &&
                           ReadBoolean(FENX_DATABUS_KEY_TRADING_STYLE_DATA_VALID,style_data_valid) &&
                           ReadTimestamp(FENX_DATABUS_KEY_TRADING_STYLE_UPDATED_AT,style_updated) &&
                           m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_TRADING_STYLE,m_symbol,
                                                       FENX_DATABUS_FIELD_TRADING_STYLE,trading_style) &&
                           ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_TRADING_STYLE,
                                             FENX_DATABUS_FIELD_TRADING_STYLE_IS_VALID,style_valid) &&
                           ReadBoolean(FENX_DATABUS_KEY_STRATEGY_SELECTION_DATA_VALID,
                                       strategy_data_valid) &&
                           ReadTimestamp(FENX_DATABUS_KEY_STRATEGY_SELECTION_UPDATED_AT,
                                         strategy_updated) &&
                           m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,m_symbol,
                                                       FENX_DATABUS_FIELD_SELECTED_STRATEGY,selected_strategy) &&
                           ReadSymbolDouble(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,
                                            FENX_DATABUS_FIELD_STRATEGY_SELECTION_CONFIDENCE,
                                            strategy_confidence) &&
                           ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STRATEGY_SELECTION,
                                             FENX_DATABUS_FIELD_STRATEGY_SELECTION_IS_VALID,strategy_valid) &&
                           ReadBoolean(FENX_DATABUS_KEY_STANDBY_SYSTEM_VALID,standby_system_valid) &&
                           ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STANDBY,
                                             FENX_DATABUS_FIELD_STANDBY_IS_ACTIVE,standby_active) &&
                           ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STANDBY,
                                             FENX_DATABUS_FIELD_STANDBY_NEW_ENTRIES_ALLOWED,
                                             standby_entries_allowed) &&
                           ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_STANDBY,
                                             FENX_DATABUS_FIELD_STANDBY_DATA_VALID,standby_data_valid) &&
                           ReadSymbolTimestamp(FENX_DATABUS_NAMESPACE_STANDBY,
                                                FENX_DATABUS_FIELD_STANDBY_UPDATED_AT,standby_updated) &&
                           ReadBoolean(FENX_DATABUS_KEY_RISK_SYSTEM_DATA_VALID,risk_system_valid) &&
                           ReadBoolean(FENX_DATABUS_KEY_RISK_SYSTEM_TRADING_ALLOWED,
                                       system_trading_allowed) &&
                           ReadBoolean(FENX_DATABUS_KEY_RISK_SYSTEM_NEW_ENTRIES_ALLOWED,
                                       system_entries_allowed) &&
                           ReadDouble(FENX_DATABUS_KEY_RISK_SYSTEM_ALLOCATION_MULTIPLIER,
                                      system_multiplier) &&
                           ReadTimestamp(FENX_DATABUS_KEY_RISK_SYSTEM_UPDATED_AT,risk_system_updated) &&
                           ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_RISK,
                                             FENX_DATABUS_FIELD_IS_RISK_APPROVED,risk_approved) &&
                           ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_RISK,
                                             FENX_DATABUS_FIELD_NEW_ENTRIES_RISK_APPROVED,
                                             risk_entries_approved) &&
                           ReadSymbolDouble(FENX_DATABUS_NAMESPACE_RISK,
                                            FENX_DATABUS_FIELD_RECOMMENDED_ALLOCATION_MULTIPLIER,
                                            symbol_multiplier) &&
                           ReadSymbolDouble(FENX_DATABUS_NAMESPACE_RISK,
                                            FENX_DATABUS_FIELD_RISK_CONFIDENCE,risk_confidence) &&
                           m_data_bus.TryGetSymbolText(FENX_DATABUS_NAMESPACE_RISK,m_symbol,
                                                       FENX_DATABUS_FIELD_RISK_ACTION,risk_action) &&
                           ReadSymbolBoolean(FENX_DATABUS_NAMESPACE_RISK,
                                             FENX_DATABUS_FIELD_RISK_DATA_VALID,risk_data_valid) &&
                           ReadSymbolTimestamp(FENX_DATABUS_NAMESPACE_RISK,
                                                FENX_DATABUS_FIELD_RISK_UPDATED_AT,risk_updated));
      const bool fresh=(IsFresh(market_updated) && IsFresh(range_updated) && IsFresh(selection_updated) &&
                        IsFresh(ranking_updated) && IsFresh(allocation_updated) && IsFresh(style_updated) &&
                        IsFresh(strategy_updated) && IsFresh(standby_updated) && IsFresh(risk_updated) &&
                        IsFresh(risk_system_updated));
      result.data_valid=(complete && fresh && ranking_data_valid && allocation_data_valid &&
                         style_data_valid && strategy_data_valid && standby_system_valid &&
                         risk_system_valid && standby_data_valid && risk_data_valid && range_data_valid &&
                         range_score>=m_minimum_range_score &&
                         strategy_confidence>=m_minimum_strategy_confidence &&
                         risk_confidence>=m_minimum_risk_confidence);
      if(!result.data_valid)
        {
         result.reason="Required final market, strategy, Standby, or Risk data is invalid or stale.";
         return(false);
        }
      if(market_state!="RANGING" || !eligible || !ranked || !allocated ||
         trading_style!="RANGE" || !style_valid || selected_strategy!="RANGE_MEAN_REVERSION" ||
         !strategy_valid || standby_active || !standby_entries_allowed || !risk_approved ||
         !risk_entries_approved || !system_trading_allowed || !system_entries_allowed ||
         (risk_action!="ALLOW" && risk_action!="ALLOW_REDUCED"))
        {
         result.reason="A final selection, Standby, or Risk permission blocks a new entry.";
         return(false);
        }
      result.allocation_multiplier=MathMin(1.0,MathMin(symbol_multiplier,system_multiplier));
      if(result.allocation_multiplier<=0.0 || result.allocation_multiplier>1.0)
        {
         result.reason="Risk allocation multiplier is invalid for a new order.";
         return(false);
        }
      result.allowed=true;
      result.reason="Execution Gate approved a new USDJPY RANGE mean-reversion entry.";
      return(true);
     }
  };

#endif // FENX_EXECUTION_GATE_MQH
