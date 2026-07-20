//+------------------------------------------------------------------+
//|                                            Engine/IEngine.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_ENGINE_IENGINE_MQH
#define FENX_ENGINE_IENGINE_MQH

#include "../Config/ParameterManager.mqh"
#include "../Core/DataBus.mqh"
#include "../Core/StateManager.mqh"

//--- Contract implemented by every independently managed EA engine.
interface IEngine
  {
   void SetStateManager(CStateManager &state_manager);
   bool Initialize(CDataBus &data_bus,CParameterManager &parameters);
   void Update(void);
   void Shutdown(void);
   string GetName(void);
  };

#endif // FENX_ENGINE_IENGINE_MQH
