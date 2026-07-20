//+------------------------------------------------------------------+
//|                                  Config/ParameterManager.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_CONFIG_PARAMETER_MANAGER_MQH
#define FENX_CONFIG_PARAMETER_MANAGER_MQH

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
  };

#endif // FENX_CONFIG_PARAMETER_MANAGER_MQH

