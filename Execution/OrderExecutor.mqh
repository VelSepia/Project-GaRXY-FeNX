//+------------------------------------------------------------------+
//|                                Execution/OrderExecutor.mqh     |
//+------------------------------------------------------------------+
#ifndef FENX_EXECUTION_ORDER_EXECUTOR_MQH
#define FENX_EXECUTION_ORDER_EXECUTOR_MQH

#include <Trade/Trade.mqh>
#include "OrderRequest.mqh"

//--- The only Phase3-9.5 component permitted to send an order.
class COrderExecutor
  {
private:
   CTrade m_trade;
   long   m_magic_number;
   int    m_maximum_slippage_points;
   int    m_transient_retry_limit;

   bool IsTransientRetcode(const long retcode)
     {
      return(retcode==TRADE_RETCODE_REQUOTE ||
             retcode==TRADE_RETCODE_PRICE_CHANGED ||
             retcode==TRADE_RETCODE_PRICE_OFF);
     }

   bool NormalizeVolume(const string symbol,const double requested_volume,
                        double &normalized_volume,string &reason)
     {
      const double minimum=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
      const double maximum=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
      const double step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
      if(minimum<=0.0 || maximum<minimum || step<=0.0)
        {
         reason="Symbol volume properties are invalid.";
         return(false);
        }
      if(requested_volume<minimum || requested_volume>maximum)
        {
         reason="Requested volume is outside the broker volume limits.";
         return(false);
        }
      normalized_volume=minimum+MathFloor(((requested_volume-minimum)/step)+0.5)*step;
      normalized_volume=MathMax(minimum,MathMin(maximum,normalized_volume));
      normalized_volume=NormalizeDouble(normalized_volume,8);
      if(normalized_volume<minimum || normalized_volume>maximum)
        {
         reason="Normalized volume is outside the broker volume limits.";
         return(false);
        }
      reason="";
      return(true);
     }

   bool NormalizeAndValidatePrices(const SOrderRequest &request,SOrderRequest &normalized,
                                   string &reason)
     {
      MqlTick tick;
      if(!SymbolInfoTick(request.symbol,tick))
        {
         reason="Current tick data is unavailable.";
         return(false);
        }
      const double point=SymbolInfoDouble(request.symbol,SYMBOL_POINT);
      const int digits=(int)SymbolInfoInteger(request.symbol,SYMBOL_DIGITS);
      const int stop_level=(int)SymbolInfoInteger(request.symbol,SYMBOL_TRADE_STOPS_LEVEL);
      if(point<=0.0 || digits<0 || tick.bid<=0.0 || tick.ask<=0.0)
        {
         reason="Symbol price properties are invalid.";
         return(false);
        }
      normalized=request;
      normalized.entry_price=NormalizeDouble((request.direction==ORDER_TYPE_BUY ? tick.ask : tick.bid),digits);
      normalized.stop_loss=NormalizeDouble(request.stop_loss,digits);
      normalized.take_profit=NormalizeDouble(request.take_profit,digits);
      const double minimum_distance=stop_level*point;
      if(request.direction==ORDER_TYPE_BUY)
        {
         if(normalized.stop_loss>=normalized.entry_price-minimum_distance ||
            normalized.take_profit<=normalized.entry_price+minimum_distance)
           {
            reason="BUY stop loss or take profit violates broker stop-level requirements.";
            return(false);
           }
        }
      else if(request.direction==ORDER_TYPE_SELL)
        {
         if(normalized.stop_loss<=normalized.entry_price+minimum_distance ||
            normalized.take_profit>=normalized.entry_price-minimum_distance)
           {
            reason="SELL stop loss or take profit violates broker stop-level requirements.";
            return(false);
           }
        }
      else
        {
         reason="Only market BUY and SELL requests are supported.";
         return(false);
        }
      reason="";
      return(true);
     }

public:
                     COrderExecutor(void)
     {
      m_magic_number=0;
      m_maximum_slippage_points=0;
      m_transient_retry_limit=0;
     }

   void              Configure(const long magic_number,const int maximum_slippage_points,
                               const int transient_retry_limit)
     {
      m_magic_number=magic_number;
      m_maximum_slippage_points=MathMax(0,maximum_slippage_points);
      m_transient_retry_limit=MathMax(0,transient_retry_limit);
      m_trade.SetExpertMagicNumber((ulong)m_magic_number);
      m_trade.SetDeviationInPoints(m_maximum_slippage_points);
     }

   bool              Prepare(const SOrderRequest &request,SOrderRequest &normalized,
                             string &reason)
     {
      if(StringLen(request.symbol)==0 || !SymbolSelect(request.symbol,true))
        {
         reason="Execution symbol is unavailable or cannot be selected.";
         return(false);
        }
      const long trade_mode=SymbolInfoInteger(request.symbol,SYMBOL_TRADE_MODE);
      if(trade_mode==SYMBOL_TRADE_MODE_DISABLED || trade_mode==SYMBOL_TRADE_MODE_CLOSEONLY)
        {
         reason="The execution symbol does not permit new market positions.";
         return(false);
        }
      if((request.direction==ORDER_TYPE_BUY && trade_mode==SYMBOL_TRADE_MODE_SHORTONLY) ||
         (request.direction==ORDER_TYPE_SELL && trade_mode==SYMBOL_TRADE_MODE_LONGONLY))
        {
         reason="The symbol trade mode does not allow the requested direction.";
         return(false);
        }
      normalized=request;
      if(!NormalizeVolume(request.symbol,request.volume,normalized.volume,reason))
         return(false);
      SOrderRequest price_normalized;
      if(!NormalizeAndValidatePrices(normalized,price_normalized,reason))
         return(false);
      normalized=price_normalized;
      if(!m_trade.SetTypeFillingBySymbol(request.symbol))
        {
         reason="The symbol does not expose a supported order filling mode.";
         return(false);
        }
      reason="";
      return(true);
     }

   bool              Send(const SOrderRequest &request,SOrderExecutionResult &result)
     {
      result.accepted=false;
      result.retcode=0;
      result.deal_ticket=0;
      result.description="";
      result.executed_at=TimeCurrent();
      SOrderRequest attempt=request;
      int retry_count=0;
      while(true)
        {
         const bool sent=(attempt.direction==ORDER_TYPE_BUY ?
                          m_trade.Buy(attempt.volume,attempt.symbol,attempt.entry_price,
                                      attempt.stop_loss,attempt.take_profit,attempt.comment) :
                          m_trade.Sell(attempt.volume,attempt.symbol,attempt.entry_price,
                                       attempt.stop_loss,attempt.take_profit,attempt.comment));
         result.retcode=(long)m_trade.ResultRetcode();
         result.deal_ticket=(long)m_trade.ResultDeal();
         result.description=m_trade.ResultRetcodeDescription();
         result.accepted=(sent && (result.retcode==TRADE_RETCODE_DONE ||
                                   result.retcode==TRADE_RETCODE_PLACED ||
                                   result.retcode==TRADE_RETCODE_DONE_PARTIAL));
         if(result.accepted || !IsTransientRetcode(result.retcode) ||
            retry_count>=m_transient_retry_limit)
            break;
         string retry_reason="";
         SOrderRequest refreshed_attempt;
         if(!NormalizeAndValidatePrices(request,refreshed_attempt,retry_reason))
           {
            result.description="Transient retry cancelled: "+retry_reason;
            break;
           }
         attempt=refreshed_attempt;
         retry_count++;
        }
      if(StringLen(result.description)==0)
         result.description=(result.accepted ? "Order accepted." : "Order rejected without a trade result description.");
      if(retry_count>0)
         result.description+=StringFormat(" (transient retries: %d)",retry_count);
      return(result.accepted);
     }
  };

#endif // FENX_EXECUTION_ORDER_EXECUTOR_MQH
