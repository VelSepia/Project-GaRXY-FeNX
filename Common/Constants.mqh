//+------------------------------------------------------------------+
//|                                         Common/Constants.mqh    |
//+------------------------------------------------------------------+
#ifndef FENX_COMMON_CONSTANTS_MQH
#define FENX_COMMON_CONSTANTS_MQH

//--- Framework identifiers and conservative Phase3-1 limits
#define FENX_EA_NAME           "GaRXY FeNX"
#define FENX_MAX_ENGINES       32
#define FENX_DATABUS_CAPACITY  64

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

#endif // FENX_COMMON_CONSTANTS_MQH

