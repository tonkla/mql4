#property copyright "TRADEiS"
#property link      "https://tradeis.one"
#property version   "1.1"
#property strict

input string secret = "";// Secret spell to summon the EA
input int magic     = 0; // ID of the EA
input float lots    = 0; // Lots
input int tf        = 0; // Timeframe consumed by indicators (60=H1)
input int period    = 0; // Number of bars consumed by indicators
input int sl        = 0; // Auto stop loss (%H-L)
input int tp        = 0; // Auto take profit (%H-L)
input int sleep     = 0; // Sleep in seconds before open next order
input int start_gmt = 0; // GMT hour to start open order
input int stop_gmt  = 0; // GMT hour to stop open order

int buy_ticket;
int sell_ticket;
int _int;
double ma_h_h0, ma_h_h1, ma_h_l0, ma_h_l1, ma_h_m0, ma_h_m1;
datetime closed_time;


int OnInit() {
  return secret == "https://tradeis.one" ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick() {
  get_order();
  get_vars();
  close();
  open();
}

void get_order() {
  buy_ticket = 0;
  sell_ticket = 0;

  for (_int = OrdersTotal() - 1; _int >= 0; _int--) {
    if (!OrderSelect(_int, SELECT_BY_POS)) continue;
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != magic) continue;
    switch (OrderType()) {
      case OP_BUY:
        buy_ticket = OrderTicket();
        break;
      case OP_SELL:
        sell_ticket = OrderTicket();
        break;
    }
  }
}

void get_vars() {
  ma_h_h0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_HIGH, 0);
  ma_h_h1 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_HIGH, 1);
  ma_h_l0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_LOW, 0);
  ma_h_l1 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_LOW, 1);
  ma_h_m0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 0);
  ma_h_m1 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 1);
}

void close() {
  double buy_pips = 0;
  double sell_pips = 0;

  if (buy_ticket > 0 && OrderSelect(buy_ticket, SELECT_BY_TICKET))
    buy_pips = Bid - OrderOpenPrice();
  if (sell_ticket > 0 && OrderSelect(sell_ticket, SELECT_BY_TICKET))
    sell_pips = OrderOpenPrice() - Ask;

  if (sl > 0 && (buy_pips < 0 || sell_pips < 0)) {
    double _sl = (ma_h_h0 - ma_h_l0) / (100 / sl);
    if (buy_pips < 0 && MathAbs(buy_pips) > _sl) close_buy_orders();
    if (sell_pips < 0 && MathAbs(sell_pips) > _sl) close_sell_orders();
  }

  if (tp > 0 && (buy_pips > 0 || sell_pips > 0)) {
    double _tp = (ma_h_h0 - ma_h_l0) / (100 / tp);
    if (buy_pips > _tp) close_buy_orders();
    if (sell_pips > _tp) close_sell_orders();
  }
}

void close_buy_orders() {
  if (!OrderSelect(buy_ticket, SELECT_BY_TICKET)) return;
  if (OrderClose(OrderTicket(), OrderLots(), Bid, 3)) closed_time = TimeCurrent();
}

void close_sell_orders() {
  if (!OrderSelect(sell_ticket, SELECT_BY_TICKET)) return;
  if (OrderClose(OrderTicket(), OrderLots(), Ask, 3)) closed_time = TimeCurrent();
}

void open() {
  if (buy_ticket > 0 || sell_ticket > 0) return;
  if (closed_time > 0 && TimeCurrent() - closed_time < sleep) return;
  // Note: London is open on 08:00 GMT, New York is closed on 22:00 GMT
  if (TimeHour(TimeGMT()) < start_gmt || TimeHour(TimeGMT()) >= stop_gmt) return;

  int stf = PERIOD_M5;
  double ma_m_h0 = iMA(Symbol(), stf, period, 0, MODE_LWMA, PRICE_HIGH, 0);
  double ma_m_h1 = iMA(Symbol(), stf, period, 0, MODE_LWMA, PRICE_HIGH, 1);
  double ma_m_l0 = iMA(Symbol(), stf, period, 0, MODE_LWMA, PRICE_LOW, 0);
  double ma_m_l1 = iMA(Symbol(), stf, period, 0, MODE_LWMA, PRICE_LOW, 1);
  double ma_m_m0 = iMA(Symbol(), stf, period, 0, MODE_LWMA, PRICE_MEDIAN, 0);
  double ma_m_m1 = iMA(Symbol(), stf, period, 0, MODE_LWMA, PRICE_MEDIAN, 1);
  double hl3 = (ma_m_h0 - ma_m_l0) / 3;
  double o = iOpen(Symbol(), stf, 0);
  double h = iHigh(Symbol(), stf, 0);
  double l = iLow(Symbol(), stf, 0);
  double c = iClose(Symbol(), stf, 0);

  bool should_buy  = ma_h_m0 > ma_h_m1 && ma_h_l0 > ma_h_l1 // Uptrend, higher high/low
                  && ma_m_m0 > ma_m_m1 && ma_m_l0 > ma_m_l1
                  && (c - o > hl3 || (c > o && o - l > hl3)) // Moving up in smaller timeframe
                  && Ask < ma_h_m0; // Margin of safety, buy low

  bool should_sell = ma_h_m0 < ma_h_m1 && ma_h_h0 < ma_h_h1 // Downtrend, lower high/low
                  && ma_m_m0 < ma_m_m1 && ma_m_h0 < ma_m_h1
                  && (o - c > hl3 || (o > c && h - o > hl3)) // Moving down in smaller timeframe
                  && Bid > ma_h_m0; // Margin of safety, sell high

  if (should_buy)
    _int = OrderSend(Symbol(), OP_BUY, lots, Ask, 3, 0, 0, NULL, magic, 0);

  if (should_sell)
    _int = OrderSend(Symbol(), OP_SELL, lots, Bid, 3, 0, 0, NULL, magic, 0);
}
