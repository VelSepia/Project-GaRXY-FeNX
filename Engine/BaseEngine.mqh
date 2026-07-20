//+------------------------------------------------------------------+
//|                                         Engine/BaseEngine.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_ENGINE_BASE_ENGINE_MQH
#define FENX_ENGINE_BASE_ENGINE_MQH

#include "IEngine.mqh"
#include "../Common/Logger.mqh"

//--- Default implementation for future concrete engines.
class CBaseEngine : public IEngine
  {
protected:
   string             m_name;
   bool               m_initialized;
   CDataBus           *m_data_bus;
   CParameterManager  *m_parameters;

public:
                     CBaseEngine(void)
     {
      m_name="BaseEngine";
      m_initialized=false;
      m_data_bus=NULL;
      m_parameters=NULL;
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      m_data_bus=GetPointer(data_bus);
      m_parameters=GetPointer(parameters);
      m_initialized=true;
      CLogger::Info(StringFormat("%s initialized.",m_name));
      return(true);
     }

   virtual void       Update(void)
     {
      // TODO: Future engines override this method with non-trading responsibilities.
     }

   virtual void       Shutdown(void)
     {
      m_initialized=false;
      m_data_bus=NULL;
      m_parameters=NULL;
      CLogger::Info(StringFormat("%s shut down.",m_name));
     }

   virtual string     GetName(void)
     {
      return(m_name);
     }

   bool               IsInitialized(void)
     {
      return(m_initialized);
     }

   void               SetName(const string name)
     {
      if(StringLen(name)>0)
         m_name=name;
     }
  };

#endif // FENX_ENGINE_BASE_ENGINE_MQH

