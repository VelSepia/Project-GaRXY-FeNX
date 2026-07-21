//+------------------------------------------------------------------+
//|                              Execution/TradeResultLogger.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_EXECUTION_TRADE_RESULT_LOGGER_MQH
#define FENX_EXECUTION_TRADE_RESULT_LOGGER_MQH

#include "../Common/Logger.mqh"

//--- Suppresses repeated execution messages while preserving meaningful tester logs.
class CTradeResultLogger
  {
private:
   string m_last_message;

public:
                     CTradeResultLogger(void)
     {
      m_last_message="";
     }

   void              InfoOnce(const string message)
     {
      if(message==m_last_message)
         return;
      m_last_message=message;
      CLogger::Info(message);
     }

   void              WarningOnce(const string message)
     {
      if(message==m_last_message)
         return;
      m_last_message=message;
      CLogger::Warning(message);
     }

   void              ErrorOnce(const string message)
     {
      if(message==m_last_message)
         return;
      m_last_message=message;
      CLogger::Error(message);
     }

   void              Reset(void)
     {
      m_last_message="";
     }
  };

#endif // FENX_EXECUTION_TRADE_RESULT_LOGGER_MQH
