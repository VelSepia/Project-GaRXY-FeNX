//+------------------------------------------------------------------+
//|                                         Common/Constants.mqh    |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_CONSTANTS_MQH
#define FENX_COMMON_CONSTANTS_MQH

//--- Framework identifiers and conservative Phase3-1 limits
#define FENX_EA_NAME           "GaRXY FeNX"
#define FENX_MAX_ENGINES       32
#define FENX_DATABUS_CAPACITY  64
#define FENX_MARKET_SELECTION_MAX_SYMBOLS 4

//--- Environment Engine DataBus keys
#define FENX_DATABUS_KEY_ENVIRONMENT_ATR               "Environment.Volatility.ATR"
#define FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_SCORE  "Environment.Volatility.Score"
#define FENX_DATABUS_KEY_ENVIRONMENT_VOLATILITY_LEVEL  "Environment.Volatility.Level"

//--- Environment range-analysis DataBus keys
#define FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPPER          "Environment.Range.Upper"
#define FENX_DATABUS_KEY_ENVIRONMENT_RANGE_LOWER          "Environment.Range.Lower"
#define FENX_DATABUS_KEY_ENVIRONMENT_RANGE_WIDTH_POINTS   "Environment.Range.WidthPoints"
#define FENX_DATABUS_KEY_ENVIRONMENT_RANGE_MIDPOINT       "Environment.Range.Midpoint"
#define FENX_DATABUS_KEY_ENVIRONMENT_RANGE_POSITION       "Environment.Range.Position"
#define FENX_DATABUS_KEY_ENVIRONMENT_RANGE_SCORE          "Environment.Range.Score"
#define FENX_DATABUS_KEY_ENVIRONMENT_IS_RANGE             "Environment.Range.IsRange"
#define FENX_DATABUS_KEY_ENVIRONMENT_RANGE_DATA_VALID     "Environment.Range.IsDataValid"
#define FENX_DATABUS_KEY_ENVIRONMENT_RANGE_UPDATED_AT     "Environment.Range.UpdatedAt"

//--- Environment trend-analysis DataBus keys
#define FENX_DATABUS_KEY_ENVIRONMENT_TREND_DIRECTION      "Environment.Trend.Direction"
#define FENX_DATABUS_KEY_ENVIRONMENT_TREND_STRENGTH       "Environment.Trend.Strength"
#define FENX_DATABUS_KEY_ENVIRONMENT_TREND_SCORE          "Environment.Trend.Score"
#define FENX_DATABUS_KEY_ENVIRONMENT_TREND_SLOPE          "Environment.Trend.Slope"
#define FENX_DATABUS_KEY_ENVIRONMENT_TREND_CONFIDENCE     "Environment.Trend.Confidence"
#define FENX_DATABUS_KEY_ENVIRONMENT_TREND_ADX            "Environment.Trend.ADX"
#define FENX_DATABUS_KEY_ENVIRONMENT_IS_TREND             "Environment.Trend.IsTrend"
#define FENX_DATABUS_KEY_ENVIRONMENT_TREND_DATA_VALID     "Environment.Trend.IsDataValid"
#define FENX_DATABUS_KEY_ENVIRONMENT_TREND_UPDATED_AT     "Environment.Trend.UpdatedAt"

//--- Unified market-state DataBus keys
#define FENX_DATABUS_KEY_ENVIRONMENT_MARKET_STATE         "Environment.Market.State"
#define FENX_DATABUS_KEY_ENVIRONMENT_MARKET_CONFIDENCE    "Environment.Market.Confidence"
#define FENX_DATABUS_KEY_ENVIRONMENT_RECOMMENDED_STYLE    "Environment.Market.RecommendedTradingStyle"
#define FENX_DATABUS_KEY_ENVIRONMENT_RECOMMENDED_RISK     "Environment.Market.RecommendedRiskLevel"
#define FENX_DATABUS_KEY_ENVIRONMENT_MARKET_UPDATED_AT    "Environment.Market.UpdatedAt"

//--- Per-symbol Market Selection DataBus namespace and field names
#define FENX_DATABUS_NAMESPACE_MARKET_SELECTION           "MarketSelection"
#define FENX_DATABUS_FIELD_MARKET_SELECTION_SYMBOL        "Symbol"
#define FENX_DATABUS_FIELD_MARKET_SELECTION_IS_ELIGIBLE   "IsMarketEligible"
#define FENX_DATABUS_FIELD_MARKET_SELECTION_SCORE         "MarketSelectionScore"
#define FENX_DATABUS_FIELD_MARKET_SELECTION_CONFIDENCE    "MarketSelectionConfidence"
#define FENX_DATABUS_FIELD_MARKET_SELECTION_SPREAD_POINTS "SpreadPoints"
#define FENX_DATABUS_FIELD_MARKET_SELECTION_SPREAD_ATR    "SpreadToATRRatio"
#define FENX_DATABUS_FIELD_MARKET_SELECTION_REJECTION     "RejectionReason"
#define FENX_DATABUS_FIELD_MARKET_SELECTION_UPDATED_AT    "MarketSelectionUpdatedAt"

#endif // FENX_COMMON_CONSTANTS_MQH

