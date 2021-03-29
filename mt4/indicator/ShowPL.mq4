#property indicator_chart_window

#define FONT_FACE    "Verdana"
#define OBJ_PL       "obj_pl"
#define OBJ_BPL      "obj_bpl"
#define OBJ_SPL      "obj_spl"
#define COLOR_PROFIT YellowGreen
#define COLOR_LOSS   Crimson

input int magic = 0;

int seconds, multiplier, buy_orders, sell_orders, _int;
double pl, buy_pl, sell_pl, buy_pl_cur, sell_pl_cur;

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

  _int = Seconds();
  if (seconds == _int || MathMod(_int, 2) != 0) return rates_total;
  seconds = _int;

  buy_pl = 0;
  sell_pl = 0;
  buy_pl_cur = 0;
  sell_pl_cur = 0;
  buy_orders = 0;
  sell_orders = 0;
  for (_int = 0; _int < OrdersTotal(); _int++) {
    if (!OrderSelect(_int, SELECT_BY_POS)) continue;
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != magic) continue;
    if (OrderType() == OP_BUY) {
      buy_pl += Bid - OrderOpenPrice();
      buy_pl_cur += OrderProfit() + OrderCommission() + OrderSwap();
      buy_orders++;
    }
    else if (OrderType() == OP_SELL) {
      sell_pl += OrderOpenPrice() - Ask;
      sell_pl_cur += OrderProfit() + OrderCommission() + OrderSwap();
      sell_orders++;
    }
  }
  multiplier = MathPow(10, Digits);
  buy_pl *= multiplier;
  sell_pl *= multiplier;
  pl = buy_pl_cur + sell_pl_cur;

  // Buy Profit / Loss
  if (buy_orders > 0) {
    ObjectCreate(OBJ_BPL, OBJ_LABEL, 0, 0, 0);
    if (buy_pl > 0) ObjectSetText(OBJ_BPL, "+"+buy_pl+":B", 10, FONT_FACE, COLOR_PROFIT);
    else ObjectSetText(OBJ_BPL, buy_pl+":B", 10, FONT_FACE, COLOR_LOSS);
    ObjectSet(OBJ_BPL, OBJPROP_CORNER, 1);
    ObjectSet(OBJ_BPL, OBJPROP_XDISTANCE, 5);
    if (sell_orders > 0) ObjectSet(OBJ_BPL, OBJPROP_YDISTANCE, 30);
    else ObjectSet(OBJ_BPL, OBJPROP_YDISTANCE, 50);
  } else ObjectDelete(OBJ_BPL);

  // Sell Profit / Loss
  if (sell_orders > 0) {
    ObjectCreate(OBJ_SPL, OBJ_LABEL, 0, 0, 0);
    if (sell_pl > 0) ObjectSetText(OBJ_SPL, "+"+sell_pl+":S", 10, FONT_FACE, COLOR_PROFIT);
    else ObjectSetText(OBJ_SPL, sell_pl+":S", 10, FONT_FACE, COLOR_LOSS);
    ObjectSet(OBJ_SPL, OBJPROP_CORNER, 1);
    ObjectSet(OBJ_SPL, OBJPROP_XDISTANCE, 5);
    ObjectSet(OBJ_SPL, OBJPROP_YDISTANCE, 50);
  } else ObjectDelete(OBJ_SPL);

  // Net Profit / Loss
  if (buy_orders > 0 || sell_orders > 0) {
    ObjectCreate(OBJ_PL, OBJ_LABEL, 0, 0, 0);
    if (pl > 0) ObjectSetText(OBJ_PL, "+"+pl, 12, FONT_FACE, COLOR_PROFIT);
    else ObjectSetText(OBJ_PL, pl, 12, FONT_FACE, COLOR_LOSS);
    ObjectSet(OBJ_PL, OBJPROP_CORNER, 1);
    ObjectSet(OBJ_PL, OBJPROP_XDISTANCE, 5);
    ObjectSet(OBJ_PL, OBJPROP_YDISTANCE, 70);
  } else ObjectDelete(OBJ_PL);

  return rates_total;
}

void delete_objects() {
  ObjectDelete(OBJ_PL);
  ObjectDelete(OBJ_BPL);
  ObjectDelete(OBJ_SPL);
}
