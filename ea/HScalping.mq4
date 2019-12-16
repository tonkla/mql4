#property copyright "TRADEiS"
#property link      "https://tradeis.one"
#property version   "1.0"
#property strict

input string secret = "";// Secret spell to summon the EA
input int magic     = 0; // ID of the EA
input double lots   = 0; // Lots
input int tf        = 0; // Timeframe consumed by indicators (60=H1)
input int period    = 0; // Number of bars consumed by indicators
input int sl        = 0; // Auto stop loss (%H-L)
input int tp        = 0; // Auto take profit (%H-L)
input int min_score = 0; // Minimum score to open an order
input int sleep     = 0; // Sleep in seconds before open next order

int buy_tickets[];
int sell_tickets[];
int _int;

double ma_h0, ma_h1, ma_l0, ma_l1, ma_m0, ma_m1;

datetime closed_time;


int OnInit() {
  return secret == "https://tradeis.one" ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick() {
  get_orders();
  get_vars();
  close();
  open();
}

void get_orders() {
  int _size = 0;
  ArrayFree(buy_tickets);
  ArrayFree(sell_tickets);

  for (_int = OrdersTotal() - 1; _int >= 0; _int--) {
    if (!OrderSelect(_int, SELECT_BY_POS)) continue;
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != magic) continue;
    switch (OrderType()) {
      case OP_BUY:
        _size = ArraySize(buy_tickets);
        ArrayResize(buy_tickets, _size + 1);
        buy_tickets[_size] = OrderTicket();
        break;
      case OP_SELL:
        _size = ArraySize(sell_tickets);
        ArrayResize(sell_tickets, _size + 1);
        sell_tickets[_size] = OrderTicket();
        break;
    }
  }
}

void get_vars() {
  ma_h0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_HIGH, 0);
  ma_h1 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_HIGH, 1);
  ma_l0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_LOW, 0);
  ma_l1 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_LOW, 1);
  ma_m0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 0);
  ma_m1 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 1);
}

void close() {
  double buy_pips = 0;
  double sell_pips = 0;

  if (ArraySize(buy_tickets) > 0 && OrderSelect(buy_tickets[0], SELECT_BY_TICKET))
    buy_pips = Bid - OrderOpenPrice();
  if (ArraySize(sell_tickets) > 0 && OrderSelect(sell_tickets[0], SELECT_BY_TICKET))
    sell_pips = OrderOpenPrice() - Ask;

  if (sl > 0 && (buy_pips < 0 || sell_pips < 0)) {
    double _sl = (ma_h0 - ma_l0) / (100 / sl);
    if (buy_pips < 0 && MathAbs(buy_pips) > _sl) close_buy_orders();
    if (sell_pips < 0 && MathAbs(sell_pips) > _sl) close_sell_orders();
  }

  if (tp > 0 && (buy_pips > 0 || sell_pips > 0)) {
    double _tp = (ma_h0 - ma_l0) / (100 / tp);
    if (buy_pips > _tp) close_buy_orders();
    if (sell_pips > _tp) close_sell_orders();
  }
}

void close_buy_orders() {
  for (_int = 0; _int < ArraySize(buy_tickets); _int++) {
    if (!OrderSelect(buy_tickets[_int], SELECT_BY_TICKET)) continue;
    if (OrderClose(OrderTicket(), OrderLots(), Bid, 3))
      closed_time = TimeCurrent();
  }
}

void close_sell_orders() {
  for (_int = 0; _int < ArraySize(sell_tickets); _int++) {
    if (!OrderSelect(sell_tickets[_int], SELECT_BY_TICKET)) continue;
    if (OrderClose(OrderTicket(), OrderLots(), Ask, 3))
      closed_time = TimeCurrent();
  }
}

void open() {
  if (ArraySize(buy_tickets) > 0 || ArraySize(sell_tickets) > 0) return;
  if (closed_time > 0 && TimeCurrent() - closed_time < sleep) return;

  double prev_bar_scores[] = {0, 0, 0};
  double trend_scores[] = {0, 0, 0};
  double zone_scores[] = {0, 0, 0};

  analyze_prev_bar(prev_bar_scores);
  analyze_trend(trend_scores);
  analyze_zone(zone_scores);

  double buy_score  = ((prev_bar_scores[1] / prev_bar_scores[0])
                    + (trend_scores[1] / trend_scores[0])
                    + (zone_scores[1] / zone_scores[0])) * 100 / 3;

  double sell_score = ((prev_bar_scores[2] / prev_bar_scores[0])
                    + (trend_scores[2] / trend_scores[0])
                    + (zone_scores[2] / zone_scores[0])) * 100 / 3;

  if (buy_score > min_score)
    _int = OrderSend(Symbol(), OP_BUY, lots, Ask, 3, 0, 0, NULL, magic, 0);

  if (sell_score > min_score)
    _int = OrderSend(Symbol(), OP_SELL, lots, Bid, 3, 0, 0, NULL, magic, 0);
}

void analyze_prev_bar(double &scores[]) {
  double u = 0, d = 0;

  double o = iOpen(Symbol(), tf, 1);
  double h = iHigh(Symbol(), tf, 1);
  double l = iLow(Symbol(), tf, 1);
  double c = iClose(Symbol(), tf, 1);

  double hoc = o < c ? h - c : h - o;
  double loc = o > c ? c - l : o - l;

  if (o < c) u += 1;
  if (hoc < loc) u += 1;
  if (hoc < loc / 2) u += 1;
  if (o < c && hoc < loc) u += 1;

  if (o > c) d += 1;
  if (hoc > loc) d += 1;
  if (hoc / 2 > loc) d += 1;
  if (o > c && hoc > loc) d += 1;

  scores[0] = 4; // Number of conditions
  scores[1] = u;
  scores[2] = d;
}

void analyze_trend(double &scores[]) {
  double u = 0, d = 0;

  if (ma_h0 > ma_h1) u += 1;
  if (ma_l0 > ma_l1) u += 1;
  if (ma_m0 > ma_m1) u += 1;

  if (ma_h0 < ma_h1) d += 1;
  if (ma_l0 < ma_l1) d += 1;
  if (ma_m0 < ma_m1) d += 1;

  scores[0] = 3; // Number of conditions
  scores[1] = u;
  scores[2] = d;
}

void analyze_zone(double &scores[]) {
  double u = 0, d = 0;

  double h = iHigh(Symbol(), tf, 0);
  double l = iLow(Symbol(), tf, 0);
  double m1_0 = iMA(Symbol(), 1, 5, 0, MODE_LWMA, PRICE_MEDIAN, 0);
  double m1_1 = iMA(Symbol(), 1, 5, 0, MODE_LWMA, PRICE_MEDIAN, 1);

  double mm = (ma_m0 - ma_l0) / 2;

  if (Ask < ma_m0) {
    u += 1;
    d -= 1;
  }
  if (Ask < ma_m0 - mm) {
    u += 1;
    d -= 1;
  }
  if (Ask < ma_l0) {
    u += 1;
    d -= 1;
  }
  if (Ask < ma_l0 - mm) {
    u += 1;
    d -= 1;
  }
  if (Ask > l + mm && m1_0 > m1_1) u += 1;

  if (Bid > ma_m0) {
    d += 1;
    u -= 1;
  }
  if (Bid > ma_m0 + mm) {
    d += 1;
    u -= 1;
  }
  if (Bid > ma_h0) {
    d += 1;
    u -= 1;
  }
  if (Bid > ma_h0 + mm) {
    d += 1;
    u -= 1;
  }
  if (Bid < h - mm && m1_0 < m1_1) d += 1;

  scores[0] = 5; // Number of conditions
  scores[1] = u;
  scores[2] = d;
}
