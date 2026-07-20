//+------------------------------------------------------------------+
//|                                        Core/CoreController.mqh  |
//+------------------------------------------------------------------+
#ifndef FENX_CORE_CONTROLLER_MQH
#define FENX_CORE_CONTROLLER_MQH

#include "../Common/Logger.mqh"
#include "../Config/ParameterManager.mqh"
#include "DataBus.mqh"
#include "EngineManager.mqh"
#include "StateManager.mqh"

//--- Top-level coordinator for framework initialization, updates, and shutdown.
class CCoreController
  {
private:
   CDataBus       m_data_bus;
   CEngineManager m_engine_manager;
   CStateManager  m_state_manager;
   bool           m_initialized;

public:
                     CCoreController(void)
     {
      m_initialized=false;
     }

   bool              Initialize(CParameterManager &parameters)
     {
      if(m_initialized)
        {
         CLogger::Warning("CoreController was already initialized.");
         return(true);
        }

      m_state_manager.Reset();

      // TODO: Register Environment, Risk, Strategy, and Data engines in future phases.
      if(!m_engine_manager.Initialize(m_data_bus,parameters))
        {
         m_state_manager.TransitionTo(FENX_STATE_SHUTDOWN);
         CLogger::Error("CoreController failed to initialize EngineManager.");
         return(false);
        }

      if(!m_state_manager.TransitionTo(FENX_STATE_NORMAL))
        {
         m_engine_manager.Shutdown();
         return(false);
        }

      m_initialized=true;
      CLogger::Info("CoreController initialized.");
      return(true);
     }

   void              Update(void)
     {
      if(!m_initialized || m_state_manager.GetState()==FENX_STATE_SHUTDOWN)
         return;

      m_engine_manager.Update();
     }

   void              Shutdown(void)
     {
      if(m_state_manager.GetState()!=FENX_STATE_SHUTDOWN)
         m_state_manager.TransitionTo(FENX_STATE_SHUTDOWN);

      m_engine_manager.Shutdown();
      m_data_bus.Clear();
      m_initialized=false;
      CLogger::Info("CoreController shut down.");
     }

   CEngineManager   *Engines(void)
     {
      return(GetPointer(m_engine_manager));
     }

   CDataBus         *DataBus(void)
     {
      return(GetPointer(m_data_bus));
     }

   CStateManager    *State(void)
     {
      return(GetPointer(m_state_manager));
     }
  };

#endif // FENX_CORE_CONTROLLER_MQH

