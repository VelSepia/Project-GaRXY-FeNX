//+------------------------------------------------------------------+
//|                                            Common/Logger.mqh    |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_LOGGER_MQH
#define FENX_COMMON_LOGGER_MQH

#include "Constants.mqh"
#include "Types.mqh"

//--- Centralized journal logging for framework components.
class CLogger
  {
public:
   static void Info(const string message)
     {
      Write(FENX_LOG_INFO,message);
     }

   static void Warning(const string message)
     {
      Write(FENX_LOG_WARNING,message);
     }

   static void Error(const string message)
     {
      Write(FENX_LOG_ERROR,message);
     }

   static void Write(const ENUM_FENX_LOG_LEVEL level,const string message)
     {
      PrintFormat("[%s][%s] %s",FENX_EA_NAME,LevelName(level),message);
     }

private:
   static string LevelName(const ENUM_FENX_LOG_LEVEL level)
     {
      switch(level)
        {
         case FENX_LOG_INFO:    return("INFO");
         case FENX_LOG_WARNING: return("WARNING");
         case FENX_LOG_ERROR:   return("ERROR");
        }

      return("UNKNOWN");
     }
  };

#endif // FENX_COMMON_LOGGER_MQH

