//+------------------------------------------------------------------+
//|                                  Execution/OrderRequest.mqh    |
//+------------------------------------------------------------------+
#ifndef FENX_EXECUTION_ORDER_REQUEST_MQH
#define FENX_EXECUTION_ORDER_REQUEST_MQH

//--- Clearly controlled order description created before execution validation.
struct SOrderRequest
  {
   string          symbol;
   ENUM_ORDER_TYPE direction;
   double          volume;
   double          entry_price;
   double          stop_loss;
   double          take_profit;
   long            magic_number;
   string          comment;
   datetime        timestamp;
   datetime        signal_bar_time;
   string          request_identifier;
  };

//--- Complete result returned by the only order-sending component.
struct SOrderExecutionResult
  {
   bool     accepted;
   long     retcode;
   long     deal_ticket;
   string   description;
   datetime executed_at;
  };

#endif // FENX_EXECUTION_ORDER_REQUEST_MQH
