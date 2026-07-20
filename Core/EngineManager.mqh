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

//--- Coordinates the lifecycle of non-owning references to EA engines.
class CEngineManager
  {
private:
   IEngine *m_engines[];
   int      m_initialized_engine_count;
   bool     m_initialized;

public:
                     CEngineManager(void)
     {
      m_initialized_engine_count=0;
      m_initialized=false;
     }

   bool              Register(IEngine &engine)
     {
      if(m_initialized)
        {
         CLogger::Warning("Engine registration is only allowed before initialization.");
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

      if(ArrayResize(m_engines,engine_count+1)!=(engine_count+1))
        {
         CLogger::Error("EngineManager could not register a new engine.");
         return(false);
        }

      m_engines[engine_count]=engine_pointer;
      CLogger::Info(StringFormat("Registered engine: %s",engine_pointer.GetName()));
      return(true);
     }

   bool              Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(m_initialized)
         return(true);

      const int engine_count=ArraySize(m_engines);
      for(int index=0;index<engine_count;index++)
        {
         if(m_engines[index]==NULL)
           {
            CLogger::Error("EngineManager found an invalid engine pointer.");
            Shutdown();
            return(false);
           }

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

   void              Update(void)
     {
      if(!m_initialized)
         return;

      for(int index=0;index<m_initialized_engine_count;index++)
        {
         if(m_engines[index]!=NULL)
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

      m_initialized_engine_count=0;
      m_initialized=false;
     }

   int               Count(void)
     {
      return(ArraySize(m_engines));
     }
  };

#endif // FENX_CORE_ENGINE_MANAGER_MQH

