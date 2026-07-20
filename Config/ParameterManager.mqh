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
  };

#endif // FENX_CONFIG_PARAMETER_MANAGER_MQH

