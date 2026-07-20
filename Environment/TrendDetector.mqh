//+------------------------------------------------------------------+
//|                                   Environment/TrendDetector.mqh |
//+------------------------------------------------------------------+
#ifndef FENX_ENVIRONMENT_TREND_DETECTOR_MQH
#define FENX_ENVIRONMENT_TREND_DETECTOR_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Engine/BaseEngine.mqh"

//--- Internal trend facts. Runtime consumers receive values through CDataBus only.
struct STrendSnapshot
  {
   string   direction;
   double   strength;
   double   score;
   double   slope_points;
   double   confidence;
   double   adx;
   bool     is_trend;
   bool     is_data_valid;
   datetime updated_at;
  };

//--- Detects directional market facts from completed bars without making decisions.
class CTrendDetector : public CBaseEngine
  {
private:
   int    m_ma_handle;
   int    m_adx_handle;
   int    m_lookback_bars;
   int    m_ma_period;
   int    m_slope_bars;
   int    m_adx_period;
   double m_min_adx;
   double m_min_slope_atr_fraction;
   double m_min_atr_movement;
   double m_noise_atr_fraction;
   double m_direction_score_threshold;
   double m_strength_threshold;
   double m_confidence_threshold;

   void ResetSnapshot(STrendSnapshot &snapshot)
     {
      snapshot.direction="NEUTRAL";
      snapshot.strength=0.0;
      snapshot.score=0.0;
      snapshot.slope_points=0.0;
      snapshot.confidence=0.0;
      snapshot.adx=0.0;
      snapshot.is_trend=false;
      snapshot.is_data_valid=false;
      snapshot.updated_at=TimeCurrent();
     }

   bool ReadAtrFromDataBus(double &atr)
     {
      if(m_data_bus==NULL)
         return(false);

      string atr_text="";
      if(!m_data_bus.TryGetText(FENX_DATABUS_KEY_ENVIRONMENT_ATR,atr_text))
         return(false);

      atr=StringToDouble(atr_text);
      return(atr>0.0);
     }

   bool CopyClosedValue(const int handle,const int buffer_index,double &value)
     {
      if(handle==INVALID_HANDLE)
         return(false);

      double values[];
      ResetLastError();
      if(CopyBuffer(handle,buffer_index,1,1,values)!=1)
         return(false);

      value=values[0];
      return(true);
     }

   bool ReadClosedIndicators(double &ma_first,double &ma_last,double &adx,
                             double &plus_di,double &minus_di)
     {
      if(m_ma_handle==INVALID_HANDLE || m_adx_handle==INVALID_HANDLE)
         return(false);

      const int required_values=m_slope_bars+1;
      double ma_values[];
      ResetLastError();
      if(CopyBuffer(m_ma_handle,0,1,required_values,ma_values)!=required_values)
         return(false);

      // CopyBuffer writes the oldest requested closed-bar value at index zero.
      ma_first=ma_values[0];
      ma_last=ma_values[required_values-1];
      return(CopyClosedValue(m_adx_handle,0,adx) &&
             CopyClosedValue(m_adx_handle,1,plus_di) &&
             CopyClosedValue(m_adx_handle,2,minus_di));
     }

   void CalculateStructureScores(MqlRates &rates[],const int bar_count,
                                 const double noise_band,double &up_score,
                                 double &down_score)
     {
      int higher_highs=0;
      int higher_lows=0;
      int lower_highs=0;
      int lower_lows=0;
      const int comparisons=bar_count-1;

      for(int index=1;index<bar_count;index++)
        {
         if(rates[index].high>rates[index-1].high+noise_band)
            higher_highs++;
         if(rates[index].low>rates[index-1].low+noise_band)
            higher_lows++;
         if(rates[index].high<rates[index-1].high-noise_band)
            lower_highs++;
         if(rates[index].low<rates[index-1].low-noise_band)
            lower_lows++;
        }

      up_score=50.0*((double)higher_highs/comparisons+
                     (double)higher_lows/comparisons);
      down_score=50.0*((double)lower_highs/comparisons+
                       (double)lower_lows/comparisons);
     }

   double CalculateNoiseScore(MqlRates &rates[],const int bar_count,
                              const double noise_band)
     {
      double total_movement=0.0;
      double meaningful_movement=0.0;
      for(int index=1;index<bar_count;index++)
        {
         const double movement=MathAbs(rates[index].close-rates[index-1].close);
         total_movement+=movement;
         if(movement>noise_band)
            meaningful_movement+=movement;
        }

      if(total_movement<=0.0)
         return(0.0);

      return(100.0*meaningful_movement/total_movement);
     }

   double CalculateAdxStrength(const double adx)
     {
      if(adx<=0.0)
         return(0.0);

      return(MathMin(100.0,100.0*adx/50.0));
     }

   double CalculateConfidence(const string direction,const double slope_atr,
                              const double up_structure,const double down_structure,
                              const double plus_di,const double minus_di,
                              const double net_movement,const double noise_score)
     {
      if(direction=="NEUTRAL")
         return(0.0);

      const bool is_up=(direction=="UP");
      double agreement=0.0;
      if((is_up && slope_atr>0.0) || (!is_up && slope_atr<0.0))
         agreement+=30.0;
      if((is_up && up_structure>down_structure) ||
         (!is_up && down_structure>up_structure))
         agreement+=25.0;
      if((is_up && plus_di>minus_di) || (!is_up && minus_di>plus_di))
         agreement+=20.0;
      if((is_up && net_movement>0.0) || (!is_up && net_movement<0.0))
         agreement+=15.0;

      return(MathMin(100.0,agreement+(0.10*noise_score)));
     }

   bool BuildSnapshot(MqlRates &rates[],const int bar_count,const double atr,
                      const double ma_first,const double ma_last,const double adx,
                      const double plus_di,const double minus_di,STrendSnapshot &snapshot)
     {
      ResetSnapshot(snapshot);
      if(bar_count!=m_lookback_bars || atr<=0.0)
         return(false);

      const double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
      if(point<=0.0)
         return(false);

      const double noise_band=MathMax(point,atr*m_noise_atr_fraction);
      const double slope_price=(ma_last-ma_first)/m_slope_bars;
      const double slope_atr=slope_price/atr;
      const double slope_strength=MathMin(100.0,
                                          100.0*MathAbs(slope_atr)/m_min_slope_atr_fraction);
      const double net_movement=rates[bar_count-1].close-rates[0].close;
      const double movement_strength=MathMin(100.0,
                                             100.0*MathAbs(net_movement)/(atr*m_min_atr_movement));
      const double noise_score=CalculateNoiseScore(rates,bar_count,noise_band);
      double up_structure=0.0;
      double down_structure=0.0;
      CalculateStructureScores(rates,bar_count,noise_band,up_structure,down_structure);
      const double adx_strength=CalculateAdxStrength(adx);

      double up_evidence=0.10*noise_score;
      double down_evidence=0.10*noise_score;
      if(slope_atr>m_min_slope_atr_fraction)
         up_evidence+=0.30*slope_strength;
      if(slope_atr<-m_min_slope_atr_fraction)
         down_evidence+=0.30*slope_strength;
      up_evidence+=0.25*up_structure;
      down_evidence+=0.25*down_structure;
      if(plus_di>minus_di)
         up_evidence+=0.20*adx_strength;
      if(minus_di>plus_di)
         down_evidence+=0.20*adx_strength;
      if(net_movement>noise_band)
         up_evidence+=0.15*movement_strength;
      if(net_movement<-noise_band)
         down_evidence+=0.15*movement_strength;

      snapshot.score=up_evidence-down_evidence;
      snapshot.strength=MathMax(up_evidence,down_evidence);
      if(snapshot.score>=m_direction_score_threshold)
         snapshot.direction="UP";
      else if(snapshot.score<=-m_direction_score_threshold)
         snapshot.direction="DOWN";
      else
         snapshot.direction="NEUTRAL";

      snapshot.slope_points=slope_price/point;
      snapshot.confidence=CalculateConfidence(snapshot.direction,slope_atr,
                                              up_structure,down_structure,plus_di,
                                              minus_di,net_movement,noise_score);
      snapshot.adx=adx;
      snapshot.is_data_valid=true;
      snapshot.is_trend=(snapshot.direction!="NEUTRAL" &&
                         snapshot.strength>=m_strength_threshold &&
                         snapshot.confidence>=m_confidence_threshold &&
                         adx>=m_min_adx);
      snapshot.updated_at=TimeCurrent();
      return(true);
     }

   bool PublishSnapshot(STrendSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);

      bool success=true;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_TREND_DIRECTION,
                             snapshot.direction))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_TREND_STRENGTH,
                             DoubleToString(snapshot.strength,2)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_TREND_SCORE,
                             DoubleToString(snapshot.score,2)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_TREND_SLOPE,
                             DoubleToString(snapshot.slope_points,4)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_TREND_CONFIDENCE,
                             DoubleToString(snapshot.confidence,2)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_TREND_ADX,
                             DoubleToString(snapshot.adx,2)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_IS_TREND,
                             (snapshot.is_trend ? "true" : "false")))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_TREND_DATA_VALID,
                             (snapshot.is_data_valid ? "true" : "false")))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_TREND_UPDATED_AT,
                             TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS)))
         success=false;

      return(success);
     }

public:
                     CTrendDetector(void)
     {
      SetName("TrendDetector");
      m_ma_handle=INVALID_HANDLE;
      m_adx_handle=INVALID_HANDLE;
      m_lookback_bars=0;
      m_ma_period=0;
      m_slope_bars=0;
      m_adx_period=0;
      m_min_adx=0.0;
      m_min_slope_atr_fraction=0.0;
      m_min_atr_movement=0.0;
      m_noise_atr_fraction=0.0;
      m_direction_score_threshold=0.0;
      m_strength_threshold=0.0;
      m_confidence_threshold=0.0;
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);

      m_lookback_bars=parameters.TrendLookbackBars();
      m_ma_period=parameters.TrendMaPeriod();
      m_slope_bars=parameters.TrendSlopeBars();
      m_adx_period=parameters.TrendAdxPeriod();
      m_min_adx=parameters.TrendMinAdx();
      m_min_slope_atr_fraction=parameters.TrendMinSlopeAtrFraction();
      m_min_atr_movement=parameters.TrendMinAtrMovement();
      m_noise_atr_fraction=parameters.TrendNoiseAtrFraction();
      m_direction_score_threshold=parameters.TrendDirectionScoreThreshold();
      m_strength_threshold=parameters.TrendStrengthThreshold();
      m_confidence_threshold=parameters.TrendConfidenceThreshold();

      if(m_lookback_bars<10 || m_ma_period<2 || m_slope_bars<1 ||
         m_adx_period<2 || m_min_adx<0.0 || m_min_adx>100.0 ||
         m_min_slope_atr_fraction<=0.0 || m_min_atr_movement<=0.0 ||
         m_noise_atr_fraction<=0.0 || m_direction_score_threshold<0.0 ||
         m_direction_score_threshold>100.0 || m_strength_threshold<0.0 ||
         m_strength_threshold>100.0 || m_confidence_threshold<0.0 ||
         m_confidence_threshold>100.0)
        {
         CLogger::Error("TrendDetector received invalid configuration.");
         CBaseEngine::Shutdown();
         return(false);
        }

      ResetLastError();
      m_ma_handle=iMA(_Symbol,PERIOD_CURRENT,m_ma_period,0,MODE_EMA,PRICE_CLOSE);
      m_adx_handle=iADX(_Symbol,PERIOD_CURRENT,m_adx_period);
      if(m_ma_handle==INVALID_HANDLE || m_adx_handle==INVALID_HANDLE)
        {
         CLogger::Error(StringFormat("TrendDetector could not create indicator handles. Error: %d",
                                     GetLastError()));
         Shutdown();
         return(false);
        }

      CLogger::Info(StringFormat("TrendDetector configured with EMA(%d), ADX(%d), and %d completed bars.",
                                 m_ma_period,m_adx_period,m_lookback_bars));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;

      STrendSnapshot snapshot;
      ResetSnapshot(snapshot);
      double atr=0.0;
      double ma_first=0.0;
      double ma_last=0.0;
      double adx=0.0;
      double plus_di=0.0;
      double minus_di=0.0;
      MqlRates rates[];
      // start_pos=1 excludes the current forming candle; the copied array is oldest to newest.
      const int copied=CopyRates(_Symbol,PERIOD_CURRENT,1,m_lookback_bars,rates);
      if(!ReadAtrFromDataBus(atr) || copied!=m_lookback_bars ||
         !ReadClosedIndicators(ma_first,ma_last,adx,plus_di,minus_di) ||
         !BuildSnapshot(rates,copied,atr,ma_first,ma_last,adx,plus_di,minus_di,snapshot))
        {
         CLogger::Warning("TrendDetector is waiting for valid ATR, indicators, or completed-bar history.");
        }

      if(!PublishSnapshot(snapshot))
         CLogger::Error("TrendDetector could not publish its snapshot to DataBus.");
     }

   virtual void       Shutdown(void)
     {
      if(m_ma_handle!=INVALID_HANDLE)
        {
         IndicatorRelease(m_ma_handle);
         m_ma_handle=INVALID_HANDLE;
        }
      if(m_adx_handle!=INVALID_HANDLE)
        {
         IndicatorRelease(m_adx_handle);
         m_adx_handle=INVALID_HANDLE;
        }

      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_ENVIRONMENT_TREND_DETECTOR_MQH

