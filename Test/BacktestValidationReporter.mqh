//+------------------------------------------------------------------+
//|                         Test/BacktestValidationReporter.mqh      |
//+------------------------------------------------------------------+
#ifndef FENX_TEST_BACKTEST_VALIDATION_REPORTER_MQH
#define FENX_TEST_BACKTEST_VALIDATION_REPORTER_MQH

#include "../Common/Logger.mqh"

//--- Finds a tracked tester position identifier in a small validation array.
int FenxFindBacktestPosition(long &position_ids[],const long position_id)
  {
   for(int index=0;index<ArraySize(position_ids);index++)
     {
      if(position_ids[index]==position_id)
         return(index);
     }
   return(-1);
  }

//--- Calculates closed-position holding time and exit-reason counts from tester deals.
double FenxAverageHoldingSeconds(const string symbol,const long magic_number,
                                 int &closed_positions,int &stop_loss_closes,
                                 int &take_profit_closes,int &expert_closes,
                                 int &other_closes)
  {
   closed_positions=0;
   stop_loss_closes=0;
   take_profit_closes=0;
   expert_closes=0;
   other_closes=0;
   if(!HistorySelect(0,TimeCurrent()))
     {
      CLogger::Warning("[BACKTEST_METRICS] Trade history could not be selected.");
      return(0.0);
     }

   long position_ids[];
   long opened_at_msc[];
   bool position_closed[];
   long holding_milliseconds=0;
   const int deal_count=HistoryDealsTotal();
   for(int deal_index=0;deal_index<deal_count;deal_index++)
     {
      const ulong deal_ticket=HistoryDealGetTicket(deal_index);
      if(deal_ticket==0 ||
         HistoryDealGetString(deal_ticket,DEAL_SYMBOL)!=symbol ||
         HistoryDealGetInteger(deal_ticket,DEAL_MAGIC)!=magic_number)
         continue;

      const long position_id=HistoryDealGetInteger(deal_ticket,DEAL_POSITION_ID);
      const long deal_time_msc=HistoryDealGetInteger(deal_ticket,DEAL_TIME_MSC);
      const ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket,DEAL_ENTRY);
      int position_index=FenxFindBacktestPosition(position_ids,position_id);
      if(entry==DEAL_ENTRY_IN)
        {
         if(position_index>=0)
            continue;
         const int next_index=ArraySize(position_ids);
         if(ArrayResize(position_ids,next_index+1)!=(next_index+1) ||
            ArrayResize(opened_at_msc,next_index+1)!=(next_index+1) ||
            ArrayResize(position_closed,next_index+1)!=(next_index+1))
           {
            CLogger::Warning("[BACKTEST_METRICS] Holding-time arrays could not be expanded.");
            break;
           }
         position_ids[next_index]=position_id;
         opened_at_msc[next_index]=deal_time_msc;
         position_closed[next_index]=false;
         continue;
        }

      if(entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_OUT_BY)
         continue;
      if(position_index<0 || position_closed[position_index])
         continue;

      holding_milliseconds+=MathMax(0,deal_time_msc-opened_at_msc[position_index]);
      position_closed[position_index]=true;
      closed_positions++;
      const ENUM_DEAL_REASON reason=
         (ENUM_DEAL_REASON)HistoryDealGetInteger(deal_ticket,DEAL_REASON);
      if(reason==DEAL_REASON_SL)
         stop_loss_closes++;
      else if(reason==DEAL_REASON_TP)
         take_profit_closes++;
      else if(reason==DEAL_REASON_EXPERT)
         expert_closes++;
      else
         other_closes++;
     }

   if(closed_positions<=0)
      return(0.0);
   return((double)holding_milliseconds/(1000.0*closed_positions));
  }

//--- Emits one parse-friendly line containing the standard tester statistics.
double FenxReportBacktestValidation(const string symbol,const long magic_number)
  {
   const long total_trades=(long)TesterStatistics(STAT_TRADES);
   const long winning_trades=(long)TesterStatistics(STAT_PROFIT_TRADES);
   const long losing_trades=(long)TesterStatistics(STAT_LOSS_TRADES);
   const double win_rate=(total_trades>0 ?
                          100.0*(double)winning_trades/(double)total_trades : 0.0);
   const double profit_factor=TesterStatistics(STAT_PROFIT_FACTOR);
   const double net_profit=TesterStatistics(STAT_PROFIT);
   const double balance_drawdown=TesterStatistics(STAT_BALANCE_DD);
   const double balance_drawdown_percent=TesterStatistics(STAT_BALANCE_DDREL_PERCENT);
   const double equity_drawdown=TesterStatistics(STAT_EQUITY_DD);
   const double equity_drawdown_percent=TesterStatistics(STAT_EQUITY_DDREL_PERCENT);

   int closed_positions=0;
   int stop_loss_closes=0;
   int take_profit_closes=0;
   int expert_closes=0;
   int other_closes=0;
   const double average_holding_seconds=
      FenxAverageHoldingSeconds(symbol,magic_number,closed_positions,stop_loss_closes,
                                take_profit_closes,expert_closes,other_closes);

   CLogger::Info(StringFormat("[BACKTEST_METRICS] trades=%I64d;wins=%I64d;losses=%I64d;win_rate=%.2f;profit_factor=%.6f;net_profit=%.2f;balance_drawdown=%.2f;balance_drawdown_percent=%.2f;equity_drawdown=%.2f;equity_drawdown_percent=%.2f;average_holding_seconds=%.2f;closed_positions=%d;sl_closes=%d;tp_closes=%d;expert_closes=%d;other_closes=%d",
                              total_trades,winning_trades,losing_trades,win_rate,
                              profit_factor,net_profit,balance_drawdown,
                              balance_drawdown_percent,equity_drawdown,
                              equity_drawdown_percent,average_holding_seconds,
                              closed_positions,stop_loss_closes,take_profit_closes,
                              expert_closes,other_closes));
   return(net_profit);
  }

#endif // FENX_TEST_BACKTEST_VALIDATION_REPORTER_MQH
