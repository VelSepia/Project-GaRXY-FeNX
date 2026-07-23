//+------------------------------------------------------------------+
//|                                Execution/PositionManager.mqh   |
//+------------------------------------------------------------------+
#ifndef FENX_EXECUTION_POSITION_MANAGER_MQH
#define FENX_EXECUTION_POSITION_MANAGER_MQH

//--- Identifies and reports FeNX positions without sending trade requests.
class CPositionManager
  {
private:
   string m_symbol;
   long   m_magic_number;

public:
                     CPositionManager(void)
     {
      m_symbol="";
      m_magic_number=0;
     }

   void              Configure(const string symbol,const long magic_number)
     {
      m_symbol=symbol;
      m_magic_number=magic_number;
     }

   //--- Returns the single managed position expected by the execution contract.
   bool              TryGetFeNXPosition(ulong &ticket,ENUM_POSITION_TYPE &position_type,
                                        datetime &opened_at)
     {
      ticket=0;
      position_type=POSITION_TYPE_BUY;
      opened_at=0;
      for(int index=PositionsTotal()-1;index>=0;index--)
        {
         const ulong candidate=PositionGetTicket(index);
         if(candidate==0 || !PositionSelectByTicket(candidate))
            continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_symbol ||
            PositionGetInteger(POSITION_MAGIC)!=m_magic_number)
            continue;

         ticket=candidate;
         position_type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         opened_at=(datetime)PositionGetInteger(POSITION_TIME);
         return(true);
        }
      return(false);
     }

   int               CountFeNXPositions(void)
     {
      int count=0;
      for(int index=PositionsTotal()-1;index>=0;index--)
        {
         const ulong ticket=PositionGetTicket(index);
         if(ticket==0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL)==m_symbol &&
            PositionGetInteger(POSITION_MAGIC)==m_magic_number)
            count++;
        }
      return(count);
     }

   bool              HasAnyPositionOnSymbol(void)
     {
      for(int index=PositionsTotal()-1;index>=0;index--)
        {
         const ulong ticket=PositionGetTicket(index);
         if(ticket==0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL)==m_symbol)
            return(true);
        }
      return(false);
     }

   bool              CanOpenNewPosition(const int maximum_fenx_positions,string &reason)
     {
      if(CountFeNXPositions()>=maximum_fenx_positions)
        {
         reason="An existing FeNX position already uses the execution symbol.";
         return(false);
        }
      // Conservative behavior is required for both hedging and netting accounts: do not merge
      // a FeNX order into a manual or another-EA USDJPY position.
      if(HasAnyPositionOnSymbol())
        {
         reason="An existing position on USDJPY blocks a new FeNX order to avoid interference.";
         return(false);
        }
      reason="";
      return(true);
     }
  };

#endif // FENX_EXECUTION_POSITION_MANAGER_MQH
