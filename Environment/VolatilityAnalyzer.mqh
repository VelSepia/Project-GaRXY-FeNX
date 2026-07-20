//+------------------------------------------------------------------+
//|                              Environment/VolatilityAnalyzer.mqh |
//+------------------------------------------------------------------+
#ifndef FENX_ENVIRONMENT_VOLATILITY_ANALYZER_MQH
#define FENX_ENVIRONMENT_VOLATILITY_ANALYZER_MQH

#include "../Common/Constants.mqh"
#include "../Common/Logger.mqh"
#include "../Engine/BaseEngine.mqh"

//--- Publishes ATR-based market-volatility facts without trading decisions.
class CVolatilityAnalyzer : public CBaseEngine
  {
private:
   int    m_atr_handle;
   int    m_atr_period;
   int    m_baseline_samples;
   double m_low_score;
   double m_high_score;

   bool ReadSnapshot(double &atr,double &score)
     {
      if(m_atr_handle==INVALID_HANDLE)
         return(false);

      const int required_values=m_baseline_samples+1;
      double atr_values[];
      ResetLastError();
      const int copied=CopyBuffer(m_atr_handle,0,0,required_values,atr_values);
      if(copied!=required_values)
         return(false);

      // CopyBuffer stores the oldest copied value at index zero.
      atr=atr_values[copied-1];
      if(atr<=0.0)
         return(false);

      double baseline_atr=0.0;
      for(int index=0;index<copied-1;index++)
         baseline_atr+=atr_values[index];

      baseline_atr/=m_baseline_samples;
      score=CalculateScore(atr,baseline_atr);
      return(true);
     }

   bool PublishSnapshot(const double atr,const double score,const string level)
     {
      if(m_data_bus==NULL)
         return(false);

      const int symbol_digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_ATR,
                             DoubleToString(atr,symbol_digits)))
         return(false);

      if(!m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_SCORE,
                             DoubleToString(score,2)))
         return(false);

      return(m_data_bus.SetText(FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_LEVEL,level));
     }

public:
                     CVolatilityAnalyzer(void)
     {
      SetName("VolatilityAnalyzer");
      m_atr_handle=INVALID_HANDLE;
      m_atr_period=0;
      m_baseline_samples=0;
      m_low_score=0.0;
      m_high_score=0.0;
     }

   virtual bool       Initialize(CDataBus &data_bus,CParameterManager &parameters)
     {
      if(!CBaseEngine::Initialize(data_bus,parameters))
         return(false);

      m_atr_period=parameters.VolatilityAtrPeriod();
      m_baseline_samples=parameters.VolatilityBaselineSamples();
      m_low_score=parameters.VolatilityLowScore();
      m_high_score=parameters.VolatilityHighScore();

      if(m_atr_period<=0 || m_baseline_samples<=0 ||
         m_low_score<0.0 || m_high_score<=m_low_score)
        {
         CLogger::Error("VolatilityAnalyzer received invalid configuration.");
         CBaseEngine::Shutdown();
         return(false);
        }

      ResetLastError();
      m_atr_handle=iATR(_Symbol,PERIOD_CURRENT,m_atr_period);
      if(m_atr_handle==INVALID_HANDLE)
        {
         CLogger::Error(StringFormat("VolatilityAnalyzer could not create an ATR handle. Error: %d",
                                     GetLastError()));
         CBaseEngine::Shutdown();
         return(false);
        }

      CLogger::Info(StringFormat("VolatilityAnalyzer configured with ATR(%d) and %d baseline samples.",
                                 m_atr_period,m_baseline_samples));
      return(true);
     }

   virtual void       Update(void)
     {
      if(!m_initialized)
         return;

      double atr=0.0;
      double score=0.0;
      if(!ReadSnapshot(atr,score))
        {
         CLogger::Warning("VolatilityAnalyzer is waiting for ATR data.");
         return;
        }

      const string level=Classify(score);
      if(!PublishSnapshot(atr,score,level))
         CLogger::Error("VolatilityAnalyzer could not publish its snapshot to DataBus.");
     }

   virtual void       Shutdown(void)
     {
      if(m_atr_handle!=INVALID_HANDLE)
        {
         IndicatorRelease(m_atr_handle);
         m_atr_handle=INVALID_HANDLE;
        }

      CBaseEngine::Shutdown();
     }

   double            CalculateScore(const double current_atr,const double baseline_atr)
     {
      if(current_atr<=0.0 || baseline_atr<=0.0)
         return(0.0);

      // A current ATR equal to the recent baseline produces a neutral score of 50.
      return(MathMax(0.0,MathMin(100.0,50.0*current_atr/baseline_atr)));
     }

   string            Classify(const double score)
     {
      if(score>=m_high_score)
         return("HIGH");

      if(score<=m_low_score)
         return("LOW");

      return("NORMAL");
     }
  };

// TODO(Phase3-2.4): Add MarketStateIntegrator to combine published facts through CDataBus.

#endif // FENX_ENVIRONMENT_VOLATILITY_ANALYZER_MQH

