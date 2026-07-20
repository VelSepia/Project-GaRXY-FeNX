//+------------------------------------------------------------------+
//|                         Environment/MarketStateIntegrator.mqh  |
//+------------------------------------------------------------------+
#ifndef FENX_ENVIRONMENT_MARKET_STATE_INTEGRATOR_MQH
#define FENX_ENVIRONMENT_MARKET_STATE_INTEGRATOR_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Engine/BaseEngine.mqh"

//--- Internal unified market facts. Runtime consumers receive values through CDataBus only.
struct SMarketStateSnapshot
  {
   string   market_state;
   double   confidence;
   string   recommended_trading_style;
   string   recommended_risk_level;
   datetime updated_at;
  };

//--- Combines published environment facts into one non-trading market-state description.
class CMarketStateIntegrator : public CBaseEngine
  {
private:
   double m_range_score_threshold;
   double m_range_max_trend_score;
   double m_trend_score_threshold;
   double m_volatility_score_threshold;
   double m_trend_min_adx;

   void ResetSnapshot(SMarketStateSnapshot &snapshot)
     {
      snapshot.market_state="TRANSITION";
      snapshot.confidence=0.0;
      snapshot.recommended_trading_style="Standby";
      snapshot.recommended_risk_level="Low";
      snapshot.updated_at=TimeCurrent();
     }

   double ClampScore(const double value)
     {
      return(MathMax(0.0,MathMin(100.0,value)));
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

   bool ReadBoolean(const string key,bool &value)
     {
      if(m_data_bus==NULL)
         return(false);

      string text="";
      if(!m_data_bus.TryGetText(key,text))
         return(false);
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

   bool ReadInputs(double &range_score,bool &is_range,double &trend_score,
                   double &trend_strength,double &volatility_score,double &atr,
                   double &adx)
     {
      return(ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE,range_score) &&
             ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_IS_RANGE,is_range) &&
             ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_SCORE,trend_score) &&
             ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_STRENGTH,trend_strength) &&
             ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_SCORE,volatility_score) &&
             ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_ATR,atr) &&
             ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_TREND_ADX,adx));
     }

   bool BuildSnapshot(const double range_score,const bool is_range,
                      const double trend_score,const double trend_strength,
                      const double volatility_score,const double atr,const double adx,
                      SMarketStateSnapshot &snapshot)
     {
      ResetSnapshot(snapshot);
      if(atr<=0.0)
         return(false);

      const double normalized_range_score=ClampScore(range_score);
      // TrendScore is signed; use its magnitude so UP and DOWN trends are treated symmetrically.
      const double trend_magnitude=ClampScore(MathAbs(trend_score));
      const double normalized_trend_strength=ClampScore(trend_strength);
      const double normalized_volatility_score=ClampScore(volatility_score);
      const double normalized_adx=ClampScore(adx);
      const double adx_strength=ClampScore(2.0*normalized_adx);

      if(is_range && normalized_range_score>m_range_score_threshold &&
         trend_magnitude<m_range_max_trend_score)
        {
         snapshot.market_state="RANGING";
         snapshot.confidence=ClampScore((0.50*normalized_range_score)+
                                        (0.30*(100.0-trend_magnitude))+20.0);
         snapshot.recommended_trading_style="Range";
         snapshot.recommended_risk_level=(normalized_volatility_score>
                                          m_volatility_score_threshold ? "High" : "Medium");
        }
      else if(trend_magnitude>m_trend_score_threshold && normalized_adx>=m_trend_min_adx)
        {
         snapshot.market_state="TRENDING";
         snapshot.confidence=ClampScore((0.45*trend_magnitude)+
                                        (0.30*normalized_trend_strength)+
                                        (0.25*adx_strength));
         snapshot.recommended_trading_style="Trend";
         snapshot.recommended_risk_level=(normalized_volatility_score>
                                          m_volatility_score_threshold ? "High" : "Medium");
        }
      else if(normalized_volatility_score>m_volatility_score_threshold)
        {
         snapshot.market_state="VOLATILE";
         snapshot.confidence=normalized_volatility_score;
         snapshot.recommended_trading_style="Standby";
         snapshot.recommended_risk_level="High";
        }
      else
        {
         const double strongest_evidence=MathMax(normalized_range_score,
                                         MathMax(trend_magnitude,normalized_volatility_score));
         snapshot.market_state="TRANSITION";
         snapshot.confidence=ClampScore(100.0-strongest_evidence);
         snapshot.recommended_trading_style="Standby";
         snapshot.recommended_risk_level="Low";
        }

      snapshot.updated_at=TimeCurrent();
      return(true);
     }

   bool PublishSnapshot(SMarketStateSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);

      bool success=true;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_STATE,
                             snapshot.market_state))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_CONFIDENCE,
                             DoubleToString(snapshot.confidence,2)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RECOMMENDED_STYLE,
                             snapshot.recommended_trading_style))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RECOMMENDED_RISK,
                             snapshot.recommended_risk_level))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_MARKET_UPDATED_AT,
                             TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS)))
         success=false;

      return(success);
     }

public:
                     CMarketStateIntegrator(void)
     {
      SetName("MarketStateIntegrator");
      m_range_score_threshold=0.0;
      m_range_max_trend_score=0.0;
      m_trend_score_threshold=0.0;
      m_volatility_score_threshold=0.0;
      m_trend_min_adx=0.0;
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);

      m_range_score_threshold=parameters.MarketRangeScoreThreshold();
      m_range_max_trend_score=parameters.MarketRangeMaxTrendScore();
      m_trend_score_threshold=parameters.MarketTrendScoreThreshold();
      m_volatility_score_threshold=parameters.MarketVolatilityScoreThreshold();
      m_trend_min_adx=parameters.MarketTrendMinAdx();

      if(m_range_score_threshold<0.0 || m_range_score_threshold>100.0 ||
         m_range_max_trend_score<0.0 || m_range_max_trend_score>100.0 ||
         m_trend_score_threshold<0.0 || m_trend_score_threshold>100.0 ||
         m_volatility_score_threshold<0.0 || m_volatility_score_threshold>100.0 ||
         m_trend_min_adx<0.0 || m_trend_min_adx>100.0)
        {
         CLogger::Error("MarketStateIntegrator received invalid configuration.");
         CBaseEngine::Shutdown();
         return(false);
        }

      CLogger::Info("MarketStateIntegrator initialized with DataBus-only inputs.");
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;

      SMarketStateSnapshot snapshot;
      ResetSnapshot(snapshot);
      double range_score=0.0;
      bool is_range=false;
      double trend_score=0.0;
      double trend_strength=0.0;
      double volatility_score=0.0;
      double atr=0.0;
      double adx=0.0;
      if(!ReadInputs(range_score,is_range,trend_score,trend_strength,
                     volatility_score,atr,adx) ||
         !BuildSnapshot(range_score,is_range,trend_score,trend_strength,
                        volatility_score,atr,adx,snapshot))
        {
         CLogger::Warning("MarketStateIntegrator is waiting for complete DataBus inputs.");
        }

      if(!PublishSnapshot(snapshot))
         CLogger::Error("MarketStateIntegrator could not publish its snapshot to DataBus.");
     }

   virtual void       Shutdown(void)
     {
      // MarketStateIntegrator owns no indicator or account resources.
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_ENVIRONMENT_MARKET_STATE_INTEGRATOR_MQH

