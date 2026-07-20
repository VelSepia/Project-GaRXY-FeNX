//+------------------------------------------------------------------+
//|                                             Common/Types.mqh    |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_TYPES_MQH
#define FENX_COMMON_TYPES_MQH

//--- High-level lifecycle states for the Expert Advisor.
enum ENUM_FENX_STATE
  {
   FENX_STATE_INIT = 0,
   FENX_STATE_NORMAL,
   FENX_STATE_STANDBY,
   FENX_STATE_DYNAMIC_ZONE,
   FENX_STATE_RISK_STOP,
   FENX_STATE_SHUTDOWN
  };

//--- Log severity used by the shared logger.
enum ENUM_FENX_LOG_LEVEL
  {
   FENX_LOG_INFO = 0,
   FENX_LOG_WARNING,
   FENX_LOG_ERROR
  };

//--- A lightweight shared-data entry. Typed payloads can be added later.
struct SDataBusItem
  {
   string   key;
   string   value;
   datetime updated_at;
  };

#endif // FENX_COMMON_TYPES_MQH

