//+------------------------------------------------------------------+
//|                         Strategy/RangeMeanReversionStrategy.mqh |
//+------------------------------------------------------------------+
#ifndef FENX_RANGE_MEAN_REVERSION_STRATEGY_MQH
#define FENX_RANGE_MEAN_REVERSION_STRATEGY_MQH

#include "../Common/Constants.mqh"
#include "../Core/DataBus.mqh"

//--- Completed-bar entry intent. It contains no execution behavior.
struct SRangeEntryIntent
  {
   bool            has_signal;
   ENUM_ORDER_TYPE direction;
   double          signal_price;
   double          score;
   double          confidence;
   double          range_lower;
   double          range_upper;
   double          range_midpoint;
   datetime        bar_time;
   string          reason;
  };

//--- Produces a BUY near RangeLower or SELL near RangeUpper from completed candles only.
class CRangeMeanReversionStrategy
  {
private:
   CDataBus *m_data_bus;
   string    m_symbol;
   double    m_boundary_distance_points;
   double    m_boundary_distance_atr_ratio;
   double    m_minimum_range_score;
   bool      m_allow_buy;
   bool      m_allow_sell;

   bool ReadBooleanText(const string text,bool &value)
     {
      if(text=="true" || text=="TRUE")
        {
         value=true;
         return(true);
        }
      if(text=="false" || text=="FALSE")
        {
         value=false;
         return(true);
        }
      return(false);
     }

   bool ReadDouble(const string key,double &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      if(!m_data_bus.TryGetText(key,text) || StringLen(text)==0)
         return(false);
      value=StringToDouble(text);
      return(true);
     }

   bool ReadBoolean(const string key,bool &value)
     {
      if(m_data_bus==NULL)
         return(false);
      string text="";
      return(m_data_bus.TryGetText(key,text) && ReadBooleanText(text,value));
     }

   void ResetIntent(SRangeEntryIntent &intent)
     {
      intent.has_signal=false;
      intent.direction=ORDER_TYPE_BUY;
      intent.signal_price=0.0;
      intent.score=0.0;
      intent.confidence=0.0;
      intent.range_lower=0.0;
      intent.range_upper=0.0;
      intent.range_midpoint=0.0;
      intent.bar_time=0;
      intent.reason="No completed-bar range entry is available.";
     }

public:
                     CRangeMeanReversionStrategy(void)
     {
      m_data_bus=NULL;
      m_symbol="";
      m_boundary_distance_points=0.0;
      m_boundary_distance_atr_ratio=0.0;
      m_minimum_range_score=0.0;
      m_allow_buy=true;
      m_allow_sell=true;
     }

   void              Configure(CDataBus &data_bus,const string symbol,
                               const double boundary_distance_points,
                               const double boundary_distance_atr_ratio,
                               const double minimum_range_score,
                               const bool allow_buy,const bool allow_sell)
     {
      m_data_bus=GetPointer(data_bus);
      m_symbol=symbol;
      m_boundary_distance_points=boundary_distance_points;
      m_boundary_distance_atr_ratio=boundary_distance_atr_ratio;
      m_minimum_range_score=minimum_range_score;
      m_allow_buy=allow_buy;
      m_allow_sell=allow_sell;
     }

   bool              Evaluate(SRangeEntryIntent &intent)
     {
      ResetIntent(intent);
      if(m_data_bus==NULL || m_symbol!="USDJPY")
        {
         intent.reason="Range strategy supports USDJPY only.";
         return(false);
        }

      double lower=0.0,upper=0.0,midpoint=0.0,range_score=0.0,atr=0.0;
      bool is_range=false,range_data_valid=false;
      if(!ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_LOWER,lower) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPPER,upper) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_MIDPOINT,midpoint) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE,range_score) ||
         !ReadDouble(FENX_DATABUS_KEY_ENVIRONMENT_ATR,atr) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_IS_RANGE,is_range) ||
         !ReadBoolean(FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID,range_data_valid) ||
         lower>=upper || atr<=0.0 || !is_range || !range_data_valid ||
         range_score<m_minimum_range_score)
        {
         intent.reason="Range facts are not valid for a mean-reversion entry.";
         return(false);
        }

      MqlRates rates[];
      // start_pos=1 explicitly excludes the forming bar and prevents look-ahead bias.
      if(CopyRates(m_symbol,PERIOD_CURRENT,1,1,rates)!=1)
        {
         intent.reason="The latest completed candle is unavailable.";
         return(false);
        }
      const double point=SymbolInfoDouble(m_symbol,SYMBOL_POINT);
      if(point<=0.0)
        {
         intent.reason="The execution symbol has no valid point size.";
         return(false);
        }
      const double boundary=MathMax(m_boundary_distance_points*point,
                                    atr*m_boundary_distance_atr_ratio);
      const double close_price=rates[0].close;
      intent.signal_price=close_price;
      intent.range_lower=lower;
      intent.range_upper=upper;
      intent.range_midpoint=midpoint;
      intent.bar_time=rates[0].time;
      intent.score=range_score;
      intent.confidence=range_score;
      if(m_allow_buy && MathAbs(close_price-lower)<=boundary)
        {
         intent.has_signal=true;
         intent.direction=ORDER_TYPE_BUY;
         intent.reason="Completed-bar close is near RangeLower.";
         return(true);
        }
      if(m_allow_sell && MathAbs(close_price-upper)<=boundary)
        {
         intent.has_signal=true;
         intent.direction=ORDER_TYPE_SELL;
         intent.reason="Completed-bar close is near RangeUpper.";
         return(true);
        }
      intent.reason="Completed-bar close is away from both range boundaries.";
      return(false);
     }

   bool              BuildProtection(const SRangeEntryIntent &intent,const double entry_price,
                                     const string exit_mode,const double fixed_take_profit_points,
                                     const double fixed_stop_loss_points,
                                     const double range_stop_buffer_points,
                                     double &stop_loss,double &take_profit,string &reason)
     {
      stop_loss=0.0;
      take_profit=0.0;
      const double point=SymbolInfoDouble(m_symbol,SYMBOL_POINT);
      if(point<=0.0 || entry_price<=0.0)
        {
         reason="Entry price or point size is invalid for protection calculation.";
         return(false);
        }
      if(exit_mode=="FIXED_POINTS")
        {
         if(fixed_take_profit_points<=0.0 || fixed_stop_loss_points<=0.0)
           {
            reason="Fixed protection points are invalid.";
            return(false);
           }
         if(intent.direction==ORDER_TYPE_BUY)
           {
            stop_loss=entry_price-(fixed_stop_loss_points*point);
            take_profit=entry_price+(fixed_take_profit_points*point);
           }
         else
           {
            stop_loss=entry_price+(fixed_stop_loss_points*point);
            take_profit=entry_price-(fixed_take_profit_points*point);
           }
        }
      else if(exit_mode=="RANGE_BASED")
        {
         if(range_stop_buffer_points<0.0)
           {
            reason="Range stop buffer is invalid.";
            return(false);
           }
         if(intent.direction==ORDER_TYPE_BUY)
           {
            stop_loss=intent.range_lower-(range_stop_buffer_points*point);
            take_profit=intent.range_midpoint;
           }
         else
           {
            stop_loss=intent.range_upper+(range_stop_buffer_points*point);
            take_profit=intent.range_midpoint;
           }
        }
      else
        {
         reason="Unsupported execution exit mode.";
         return(false);
        }

      if((intent.direction==ORDER_TYPE_BUY && (stop_loss>=entry_price || take_profit<=entry_price)) ||
         (intent.direction==ORDER_TYPE_SELL && (stop_loss<=entry_price || take_profit>=entry_price)))
        {
         reason="Range protection is not valid relative to the market entry price.";
         return(false);
        }
      reason="";
      return(true);
     }
  };

#endif // FENX_RANGE_MEAN_REVERSION_STRATEGY_MQH
