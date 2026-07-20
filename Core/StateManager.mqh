//+------------------------------------------------------------------+
//|                                           Core/StateManager.mqh |
//+------------------------------------------------------------------+
#ifndef FENX_CORE_STATE_MANAGER_MQH
#define FENX_CORE_STATE_MANAGER_MQH

#include "../Common/Logger.mqh"
#include "../Common/Types.mqh"

//--- Owns and validates high-level Expert Advisor state transitions.
class CStateManager
  {
private:
   ENUM_FENX_STATE m_current_state;

   bool IsTransitionAllowed(const ENUM_FENX_STATE from_state,const ENUM_FENX_STATE to_state)
     {
      if(from_state==to_state)
         return(true);

      switch(from_state)
        {
         case FENX_STATE_INIT:
            return(to_state==FENX_STATE_NORMAL ||
                   to_state==FENX_STATE_STANDBY ||
                   to_state==FENX_STATE_RISK_STOP ||
                   to_state==FENX_STATE_SHUTDOWN);

         case FENX_STATE_NORMAL:
            return(to_state==FENX_STATE_STANDBY ||
                   to_state==FENX_STATE_DYNAMIC_ZONE ||
                   to_state==FENX_STATE_RISK_STOP ||
                   to_state==FENX_STATE_SHUTDOWN);

         case FENX_STATE_STANDBY:
            return(to_state==FENX_STATE_NORMAL ||
                   to_state==FENX_STATE_DYNAMIC_ZONE ||
                   to_state==FENX_STATE_RISK_STOP ||
                   to_state==FENX_STATE_SHUTDOWN);

         case FENX_STATE_DYNAMIC_ZONE:
            return(to_state==FENX_STATE_NORMAL ||
                   to_state==FENX_STATE_STANDBY ||
                   to_state==FENX_STATE_RISK_STOP ||
                   to_state==FENX_STATE_SHUTDOWN);

         case FENX_STATE_RISK_STOP:
            return(to_state==FENX_STATE_STANDBY ||
                   to_state==FENX_STATE_SHUTDOWN);

         case FENX_STATE_SHUTDOWN:
            return(false);
        }

      return(false);
     }

public:
                     CStateManager(void)
     {
      m_current_state=FENX_STATE_INIT;
     }

   void              Reset(void)
     {
      m_current_state=FENX_STATE_INIT;
     }

   ENUM_FENX_STATE   GetState(void)
     {
      return(m_current_state);
     }

   bool              TransitionTo(const ENUM_FENX_STATE next_state)
     {
      const ENUM_FENX_STATE previous_state=m_current_state;
      if(!IsTransitionAllowed(previous_state,next_state))
        {
         CLogger::Warning(StringFormat("Rejected state transition: %s -> %s.",
                                       StateName(previous_state),StateName(next_state)));
         return(false);
        }

      m_current_state=next_state;
      CLogger::Info(StringFormat("State transition: %s -> %s.",
                                 StateName(previous_state),StateName(next_state)));
      return(true);
     }

   string            StateName(const ENUM_FENX_STATE state)
     {
      switch(state)
        {
         case FENX_STATE_INIT:         return("INIT");
         case FENX_STATE_NORMAL:       return("NORMAL");
         case FENX_STATE_STANDBY:      return("STANDBY");
         case FENX_STATE_DYNAMIC_ZONE: return("DYNAMIC_ZONE");
         case FENX_STATE_RISK_STOP:    return("RISK_STOP");
         case FENX_STATE_SHUTDOWN:     return("SHUTDOWN");
        }

      return("UNKNOWN");
     }
  };

#endif // FENX_CORE_STATE_MANAGER_MQH

