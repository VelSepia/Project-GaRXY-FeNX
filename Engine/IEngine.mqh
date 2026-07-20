//+------------------------------------------------------------------+
//|                                            Engine/IEngine.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_ENGINE_IENGINE_MQH
#define FENX_ENGINE_IENGINE_MQH

#include "../Config/ParameterManager.mqh"
#include "../Core/DataBus.mqh"

//--- Contract implemented by every independently managed EA engine.
interface IEngine
  {
   bool Initialize(CDataBus &data_bus,CParameterManager &parameters);
   void Update(void);
   void Shutdown(void);
   string GetName(void);
  };

#endif // FENX_ENGINE_IENGINE_MQH

