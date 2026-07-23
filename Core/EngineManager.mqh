//+------------------------------------------------------------------+
//|                                         Core/EngineManager.mqh  |
//+------------------------------------------------------------------+
#ifndef FENX_CORE_ENGINE_MANAGER_MQH
#define FENX_CORE_ENGINE_MANAGER_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Config/ParameterManager.mqh"
#include "../Core/DataBus.mqh"
#include "../Engine/IEngine.mqh"

//--- Selects the event that allows EngineManager to update an engine.
//--- RUNMODE_TICK preserves the scheduling behavior used before run modes existed.
enum ENUM_ENGINE_RUN_MODE
  {
   RUNMODE_TICK = 0,
   RUNMODE_NEWBAR,
   RUNMODE_ONCHANGE
  };

//--- Coordinates the lifecycle of non-owning references to EA engines.
class CEngineManager
  {
private:
   IEngine              *m_engines[];
   ENUM_ENGINE_RUN_MODE m_run_modes[];
   bool                 m_change_pending[];
   int                  m_initialized_engine_count;
   bool                 m_initialized;
   bool                 m_has_newbar_engine;
   datetime             m_last_bar_time;

   //--- Detects one forward transition of the current chart's bar.
   //--- A missing first bar is stored as a baseline and is not treated as new.
   bool              IsNewBar(void)
     {
      const datetime current_bar_time=iTime(_Symbol,_Period,0);
      if(current_bar_time<=0)
         return(false);

      if(m_last_bar_time<=0)
        {
         m_last_bar_time=current_bar_time;
         return(false);
        }

      if(current_bar_time<=m_last_bar_time)
         return(false);

      m_last_bar_time=current_bar_time;
      return(true);
     }

public:
                     CEngineManager(void)
     {
      m_initialized_engine_count=0;
      m_initialized=false;
      m_has_newbar_engine=false;
      m_last_bar_time=0;
     }

   //--- Registers a non-owning engine reference and its scheduling mode.
   //--- The default keeps every existing one-argument Register() call tick-driven.
   bool              Register(IEngine &engine,
                              const ENUM_ENGINE_RUN_MODE run_mode=RUNMODE_TICK)
     {
      if(m_initialized)
        {
         CLogger::Warning("Engine registration is only allowed before initialization.");
         return(false);
        }

      if(run_mode!=RUNMODE_TICK &&
         run_mode!=RUNMODE_NEWBAR &&
         run_mode!=RUNMODE_ONCHANGE)
        {
         CLogger::Error("Engine registration received an invalid run mode.");
         return(false);
        }

      IEngine *engine_pointer=GetPointer(engine);
      if(engine_pointer==NULL)
        {
         CLogger::Error("Engine registration received an invalid engine reference.");
         return(false);
        }

      const int engine_count=ArraySize(m_engines);
      if(engine_count>=FENX_MAX_ENGINES)
        {
         CLogger::Error("EngineManager capacity has been reached.");
         return(false);
        }

      for(int index=0;index<engine_count;index++)
        {
         if(m_engines[index]==engine_pointer)
           {
            CLogger::Warning("Engine registration ignored a duplicate engine.");
            return(false);
           }
        }

      if(ArrayResize(m_engines,engine_count+1)!=(engine_count+1) ||
         ArrayResize(m_run_modes,engine_count+1)!=(engine_count+1) ||
         ArrayResize(m_change_pending,engine_count+1)!=(engine_count+1))
        {
         // Keep the parallel registration arrays aligned after any allocation failure.
         ArrayResize(m_engines,engine_count);
         ArrayResize(m_run_modes,engine_count);
         ArrayResize(m_change_pending,engine_count);
         CLogger::Error("EngineManager could not register a new engine.");
         return(false);
        }

      m_engines[engine_count]=engine_pointer;
      m_run_modes[engine_count]=run_mode;
      m_change_pending[engine_count]=false;
      if(run_mode==RUNMODE_NEWBAR)
         m_has_newbar_engine=true;

      CLogger::Info(StringFormat("Registered engine: %s",engine_pointer.GetName()));
      return(true);
     }

   bool              Initialize(CDataBus &data_bus,CParameterManager &parameters,
                                CStateManager &state_manager)
     {
      if(m_initialized)
         return(true);

      const int engine_count=ArraySize(m_engines);
      if(m_has_newbar_engine)
         m_last_bar_time=iTime(_Symbol,_Period,0);

      for(int index=0;index<engine_count;index++)
        {
         if(m_engines[index]==NULL)
           {
            CLogger::Error("EngineManager found an invalid engine pointer.");
            Shutdown();
           return(false);
           }

         m_engines[index].SetStateManager(state_manager);

         if(!m_engines[index].Initialize(data_bus,parameters))
           {
            CLogger::Error(StringFormat("Failed to initialize engine: %s",m_engines[index].GetName()));
            Shutdown();
            return(false);
           }

         m_initialized_engine_count++;
        }

      m_initialized=true;
      CLogger::Info(StringFormat("EngineManager initialized %d engine(s).",engine_count));
      return(true);
     }

   //--- Queues one update for a registered RUNMODE_ONCHANGE engine.
   //--- Repeated notifications before Update() are intentionally coalesced.
   bool              NotifyChange(IEngine &engine)
     {
      IEngine *engine_pointer=GetPointer(engine);
      if(engine_pointer==NULL)
         return(false);

      const int engine_count=ArraySize(m_engines);
      for(int index=0;index<engine_count;index++)
        {
         if(m_engines[index]!=engine_pointer)
            continue;

         if(m_run_modes[index]!=RUNMODE_ONCHANGE)
           {
            CLogger::Warning("Change notification ignored for a non-OnChange engine.");
            return(false);
           }

         m_change_pending[index]=true;
         return(true);
        }

      CLogger::Warning("Change notification ignored for an unregistered engine.");
      return(false);
     }

   //--- Dispatches updates only to engines whose configured event has occurred.
   void              Update(void)
     {
      if(!m_initialized)
         return;

      const bool is_new_bar=(m_has_newbar_engine && IsNewBar());
      for(int index=0;index<m_initialized_engine_count;index++)
        {
         if(m_engines[index]==NULL)
            continue;

         bool should_update=false;
         switch(m_run_modes[index])
           {
            case RUNMODE_TICK:
               should_update=true;
               break;

            case RUNMODE_NEWBAR:
               should_update=is_new_bar;
               break;

            case RUNMODE_ONCHANGE:
               should_update=m_change_pending[index];
               if(should_update)
                  m_change_pending[index]=false;
               break;
           }

         if(should_update)
            m_engines[index].Update();
        }
     }

   void              Shutdown(void)
     {
      for(int index=m_initialized_engine_count-1;index>=0;index--)
        {
         if(m_engines[index]!=NULL)
            m_engines[index].Shutdown();
        }

      // Discard queued events, including those for engines not yet initialized.
      for(int index=0;index<ArraySize(m_change_pending);index++)
         m_change_pending[index]=false;

      m_initialized_engine_count=0;
      m_initialized=false;
      m_last_bar_time=0;
     }

   int               Count(void)
     {
      return(ArraySize(m_engines));
     }
  };

#endif // FENX_CORE_ENGINE_MANAGER_MQH
