//+------------------------------------------------------------------+
//|                                   Environment/RangeDetector.mqh |
//+------------------------------------------------------------------+
#ifndef FENX_ENVIRONMENT_RANGE_DETECTOR_MQH
#define FENX_ENVIRONMENT_RANGE_DETECTOR_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Engine/BaseEngine.mqh"

//--- Internal range-analysis facts. Runtime consumers receive values through CDataBus only.
struct SRangeSnapshot
  {
   double   upper;
   double   lower;
   double   width_points;
   double   midpoint;
   double   position;
   double   score;
   bool     is_range;
   bool     is_data_valid;
   datetime updated_at;
  };

//--- Detects stable, non-directional price ranges from completed candles only.
class CRangeDetector : public CBaseEngine
  {
private:
   int    m_lookback_bars;
   double m_boundary_trim_fraction;
   int    m_min_boundary_touches;
   double m_min_width_points;
   double m_min_width_atr_multiple;
   double m_max_width_atr_multiple;
   double m_touch_tolerance_atr_fraction;
   double m_break_buffer_atr_fraction;
   int    m_max_break_events;
   double m_score_threshold;

   void ResetSnapshot(SRangeSnapshot &snapshot)
     {
      snapshot.upper=0.0;
      snapshot.lower=0.0;
      snapshot.width_points=0.0;
      snapshot.midpoint=0.0;
      snapshot.position=0.0;
      snapshot.score=0.0;
      snapshot.is_range=false;
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

   bool CalculateStableBoundaries(MqlRates &rates[],const int bar_count,
                                  double &upper,double &lower)
     {
      if(bar_count<=0)
         return(false);

      double highs[];
      double lows[];
      if(ArrayResize(highs,bar_count)!=bar_count || ArrayResize(lows,bar_count)!=bar_count)
         return(false);

      for(int index=0;index<bar_count;index++)
        {
         highs[index]=rates[index].high;
         lows[index]=rates[index].low;
        }

      ArraySort(highs);
      ArraySort(lows);

      const int last_index=bar_count-1;
      int lower_index=(int)MathFloor(last_index*m_boundary_trim_fraction);
      int upper_index=(int)MathFloor(last_index*(1.0-m_boundary_trim_fraction));
      lower_index=(int)MathMax(0,MathMin(last_index,lower_index));
      upper_index=(int)MathMax(0,MathMin(last_index,upper_index));

      lower=lows[lower_index];
      upper=highs[upper_index];
      return(upper>lower);
     }

   double CalculateContainmentScore(MqlRates &rates[],const int bar_count,
                                    const double upper,const double lower)
     {
      int contained_bars=0;
      for(int index=0;index<bar_count;index++)
        {
         if(rates[index].close>=lower && rates[index].close<=upper)
            contained_bars++;
        }

      return(100.0*contained_bars/bar_count);
     }

   double CalculateTouchScore(MqlRates &rates[],const int bar_count,
                              const double upper,const double lower,
                              const double touch_tolerance)
     {
      int upper_touches=0;
      int lower_touches=0;
      for(int index=0;index<bar_count;index++)
        {
         if(rates[index].high>=upper-touch_tolerance)
            upper_touches++;
         if(rates[index].low<=lower+touch_tolerance)
            lower_touches++;
        }

      const double upper_score=100.0*MathMin(1.0,(double)upper_touches/m_min_boundary_touches);
      const double lower_score=100.0*MathMin(1.0,(double)lower_touches/m_min_boundary_touches);
      return((upper_score+lower_score)/2.0);
     }

   double CalculateEfficiencyScore(MqlRates &rates[],const int bar_count)
     {
      double total_movement=0.0;
      for(int index=1;index<bar_count;index++)
         total_movement+=MathAbs(rates[index].close-rates[index-1].close);

      if(total_movement<=0.0)
         return(100.0);

      const double net_movement=MathAbs(rates[bar_count-1].close-rates[0].close);
      const double efficiency=MathMin(1.0,net_movement/total_movement);
      return(100.0*(1.0-efficiency));
     }

   double CalculateWidthScore(const double width,const double atr)
     {
      if(width<=0.0 || atr<=0.0)
         return(0.0);

      const double atr_multiple=width/atr;
      if(atr_multiple<m_min_width_atr_multiple)
         return(100.0*atr_multiple/m_min_width_atr_multiple);
      if(atr_multiple>m_max_width_atr_multiple)
         return(100.0*m_max_width_atr_multiple/atr_multiple);

      return(100.0);
     }

   double CalculateBreakScore(MqlRates &rates[],const int bar_count,
                              const double upper,const double lower,
                              const double break_buffer)
     {
      int false_breaks=0;
      int excessive_breaks=0;
      for(int index=0;index<bar_count;index++)
        {
         if(rates[index].high>upper+break_buffer)
           {
            if(rates[index].close<=upper)
               false_breaks++;
            else
               excessive_breaks++;
           }

         if(rates[index].low<lower-break_buffer)
           {
            if(rates[index].close>=lower)
               false_breaks++;
            else
               excessive_breaks++;
           }
        }

      const double weighted_breaks=false_breaks+(2.0*excessive_breaks);
      const double penalty=MathMin(100.0,100.0*weighted_breaks/m_max_break_events);
      return(100.0-penalty);
     }

   bool BuildSnapshot(MqlRates &rates[],const int bar_count,const double atr,
                      SRangeSnapshot &snapshot)
     {
      ResetSnapshot(snapshot);
      if(bar_count!=m_lookback_bars || atr<=0.0)
         return(false);

      double upper=0.0;
      double lower=0.0;
      if(!CalculateStableBoundaries(rates,bar_count,upper,lower))
         return(false);

      const double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
      const double width=upper-lower;
      if(point<=0.0 || width<=0.0)
         return(false);

      const double width_points=width/point;
      if(width_points<m_min_width_points)
         return(false);

      const double touch_tolerance=MathMax(point,atr*m_touch_tolerance_atr_fraction);
      const double break_buffer=MathMax(point,atr*m_break_buffer_atr_fraction);
      const double containment_score=CalculateContainmentScore(rates,bar_count,upper,lower);
      const double touch_score=CalculateTouchScore(rates,bar_count,upper,lower,touch_tolerance);
      const double efficiency_score=CalculateEfficiencyScore(rates,bar_count);
      const double width_score=CalculateWidthScore(width,atr);
      const double break_score=CalculateBreakScore(rates,bar_count,upper,lower,break_buffer);
      const double atr_multiple=width/atr;

      snapshot.upper=upper;
      snapshot.lower=lower;
      snapshot.width_points=width_points;
      snapshot.midpoint=(upper+lower)/2.0;
      snapshot.position=MathMax(0.0,MathMin(1.0,
                                (rates[bar_count-1].close-lower)/width));
      snapshot.score=(0.30*containment_score)+
                     (0.20*touch_score)+
                     (0.25*efficiency_score)+
                     (0.15*width_score)+
                     (0.10*break_score);
      snapshot.is_data_valid=true;
      snapshot.is_range=(snapshot.score>=m_score_threshold &&
                         atr_multiple>=m_min_width_atr_multiple &&
                         atr_multiple<=m_max_width_atr_multiple &&
                         touch_score>=100.0);
      snapshot.updated_at=TimeCurrent();
      return(true);
     }

   bool PublishSnapshot(SRangeSnapshot &snapshot)
     {
      if(m_data_bus==NULL)
         return(false);

      const int symbol_digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      bool success=true;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPPER,
                             DoubleToString(snapshot.upper,symbol_digits)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_LOWER,
                             DoubleToString(snapshot.lower,symbol_digits)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_WIDTH_POINTS,
                             DoubleToString(snapshot.width_points,2)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_MIDPOINT,
                             DoubleToString(snapshot.midpoint,symbol_digits)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_POSITION,
                             DoubleToString(snapshot.position,4)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE,
                             DoubleToString(snapshot.score,2)))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_IS_RANGE,
                             (snapshot.is_range ? "true" : "false")))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID,
                             (snapshot.is_data_valid ? "true" : "false")))
         success=false;
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPDATED_AT,
                             TimeToString(snapshot.updated_at,TIME_DATE|TIME_SECONDS)))
         success=false;

      return(success);
     }

public:
                     CRangeDetector(void)
     {
      SetName("RangeDetector");
      m_lookback_bars=0;
      m_boundary_trim_fraction=0.0;
      m_min_boundary_touches=0;
      m_min_width_points=0.0;
      m_min_width_atr_multiple=0.0;
      m_max_width_atr_multiple=0.0;
      m_touch_tolerance_atr_fraction=0.0;
      m_break_buffer_atr_fraction=0.0;
      m_max_break_events=0;
      m_score_threshold=0.0;
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);

      m_lookback_bars=parameters.RangeLookbackBars();
      m_boundary_trim_fraction=parameters.RangeBoundaryTrimFraction();
      m_min_boundary_touches=parameters.RangeMinBoundaryTouches();
      m_min_width_points=parameters.RangeMinWidthPoints();
      m_min_width_atr_multiple=parameters.RangeMinWidthAtrMultiple();
      m_max_width_atr_multiple=parameters.RangeMaxWidthAtrMultiple();
      m_touch_tolerance_atr_fraction=parameters.RangeTouchToleranceAtrFraction();
      m_break_buffer_atr_fraction=parameters.RangeBreakBufferAtrFraction();
      m_max_break_events=parameters.RangeMaxBreakEvents();
      m_score_threshold=parameters.RangeScoreThreshold();

      if(m_lookback_bars<10 || m_boundary_trim_fraction<0.0 ||
         m_boundary_trim_fraction>=0.5 || m_min_boundary_touches<1 ||
         m_min_width_points<0.0 || m_min_width_atr_multiple<=0.0 ||
         m_max_width_atr_multiple<=m_min_width_atr_multiple ||
         m_touch_tolerance_atr_fraction<=0.0 ||
         m_break_buffer_atr_fraction<=0.0 || m_max_break_events<1 ||
         m_score_threshold<0.0 || m_score_threshold>100.0)
        {
         CLogger::Error("RangeDetector received invalid configuration.");
         CBaseEngine::Shutdown();
         return(false);
        }

      CLogger::Info(StringFormat("RangeDetector configured with %d completed bars.",
                                 m_lookback_bars));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;

      SRangeSnapshot snapshot;
      ResetSnapshot(snapshot);

      double atr=0.0;
      MqlRates rates[];
      // start_pos=1 excludes the current forming candle; the copied array is oldest to newest.
      const int copied=CopyRates(_Symbol,PERIOD_CURRENT,1,m_lookback_bars,rates);
      if(!ReadAtrFromDataBus(atr) || copied!=m_lookback_bars ||
         !BuildSnapshot(rates,copied,atr,snapshot))
        {
         CLogger::Warning("RangeDetector is waiting for valid ATR or completed-bar history.");
        }

      if(!PublishSnapshot(snapshot))
         CLogger::Error("RangeDetector could not publish its snapshot to DataBus.");
     }

   virtual void       Shutdown(void)
     {
      // No indicator handles are owned by RangeDetector.
      CBaseEngine::Shutdown();
     }
  };

#endif // FENX_ENVIRONMENT_RANGE_DETECTOR_MQH

