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
   int  m_update_interval_seconds;
   bool m_framework_logging_enabled;

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
     }

   int               UpdateIntervalSeconds(void)
     {
      return(m_update_interval_seconds);
     }

   bool              IsFrameworkLoggingEnabled(void)
     {
      return(m_framework_logging_enabled);
     }
  };

#endif // FENX_CONFIG_PARAMETER_MANAGER_MQH

