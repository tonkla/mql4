#property indicator_chart_window

#define FONT_FACE "Verdana"
#define OBJ_ATR   "obj_atr"
#define OBJ_HL    "obj_hl"

input int period   = 3;
input int interval = 5;


int OnInit() {
  return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
  delete_objects();
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {

  if (MathMod(Seconds()), interval) != 0) return rates_total;

  double _atr = iATR(NULL, 0, period, 0);
  int atr = int(_atr * MathPow(10, Digits));

  double h = iMA(NULL, 0, period, 0, MODE_SMA, PRICE_HIGH, 0);
  double l = iMA(NULL, 0, period, 0, MODE_SMA, PRICE_LOW, 0);
  int hl = int((h - l) * MathPow(10, Digits));

  // ATR
  ObjectCreate(OBJ_ATR, OBJ_LABEL, 0, 0, 0);
  ObjectSetText(OBJ_ATR, "ATR: "+atr, 10, FONT_FACE, White);
  ObjectSet(OBJ_ATR, OBJPROP_CORNER, 1);
  ObjectSet(OBJ_ATR, OBJPROP_XDISTANCE, 10);
  ObjectSet(OBJ_ATR, OBJPROP_YDISTANCE, 20);

  // High - Low
  ObjectCreate(OBJ_HL, OBJ_LABEL, 0, 0, 0);
  ObjectSetText(OBJ_HL, "H-L: "+hl, 10, FONT_FACE, White);
  ObjectSet(OBJ_HL, OBJPROP_CORNER, 1);
  ObjectSet(OBJ_HL, OBJPROP_XDISTANCE, 10);
  ObjectSet(OBJ_HL, OBJPROP_YDISTANCE, 35);

  return rates_total;
}

void delete_objects() {
  ObjectDelete(OBJ_ATR);
  ObjectDelete(OBJ_HL);
}
