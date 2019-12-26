#property copyright "TRADEiS"
#property link      "https://tradeis.one"
#property version   "1.0"
#property strict

input string secret = "";// Secret spell to summon the EA
input int magic     = 0; // ID of the EA
input float lots    = 0; // Lots
input int period    = 0; // Number of bars consumed by indicators
input bool force_sl = 0; // Force stop loss when trend changed
input int sl        = 0; // Auto stop loss (%H-L)
input int tp        = 0; // Auto take profit (%H-L)
input int sleep     = 0; // Sleep in seconds before next order
input int start_gmt = 0; // GMT hour to start open order
input int stop_gmt  = 0; // GMT hour to stop open order

int buy_ticket, sell_ticket;
datetime closed_time;


int OnInit() {
  return secret == "https://tradeis.one" ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick() {
  get_order();
  close();
  open();
}

void get_order() {
  buy_ticket = 0;
  sell_ticket = 0;

  for (int i = OrdersTotal() - 1; i >= 0; i--) {
    if (!OrderSelect(i, SELECT_BY_POS)) continue;
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

void close() {
  double buy_pips = 0;
  double sell_pips = 0;

  double ma_h_h0 = iMA(Symbol(), PERIOD_H1, period, 0, MODE_SMA, PRICE_HIGH, 0);
  double ma_h_l0 = iMA(Symbol(), PERIOD_H1, period, 0, MODE_SMA, PRICE_LOW, 0);

  if (buy_ticket > 0 && OrderSelect(buy_ticket, SELECT_BY_TICKET))
    buy_pips = Bid - OrderOpenPrice();
  if (sell_ticket > 0 && OrderSelect(sell_ticket, SELECT_BY_TICKET))
    sell_pips = OrderOpenPrice() - Ask;

  if (sl > 0 && (buy_pips < 0 || sell_pips < 0)) {
    double _sl = (ma_h_h0 - ma_h_l0) * sl / 100;
    if (buy_pips < 0 && MathAbs(buy_pips) > _sl) close_buy_order();
    if (sell_pips < 0 && MathAbs(sell_pips) > _sl) close_sell_order();
  }

  if (tp > 0 && (buy_pips > 0 || sell_pips > 0)) {
    double _tp = (ma_h_h0 - ma_h_l0) * tp / 100;
    if (buy_pips > _tp) close_buy_order();
    if (sell_pips > _tp) close_sell_order();
  }

  if (force_sl) {
    double o = iOpen(Symbol(), PERIOD_D1, 0);
    double c = iClose(Symbol(), PERIOD_D1, 0);
    if (o > c) close_buy_order();
    if (o < c) close_sell_order();
  }
}

void close_buy_order() {
  if (!OrderSelect(buy_ticket, SELECT_BY_TICKET)) return;
  if (OrderClose(OrderTicket(), OrderLots(), Bid, 3)) closed_time = TimeCurrent();
}

void close_sell_order() {
  if (!OrderSelect(sell_ticket, SELECT_BY_TICKET)) return;
  if (OrderClose(OrderTicket(), OrderLots(), Ask, 3)) closed_time = TimeCurrent();
}

void open() {
  if (buy_ticket > 0 || sell_ticket > 0) return;
  if (closed_time > 0 && TimeCurrent() - closed_time < sleep) return;
  // Note: London opens 08:00-17:00 GMT, New York opens 13:00-22:00 GMT
  if (TimeHour(TimeGMT()) < start_gmt || TimeHour(TimeGMT()) >= stop_gmt) return;

  double ma_d_h0 = iMA(Symbol(), PERIOD_D1, period, 0, MODE_SMA, PRICE_HIGH, 0);
  double ma_d_l0 = iMA(Symbol(), PERIOD_D1, period, 0, MODE_SMA, PRICE_LOW, 0);

  double ma_h_h0 = iMA(Symbol(), PERIOD_H1, period, 0, MODE_SMA, PRICE_HIGH, 0);
  double ma_h_l0 = iMA(Symbol(), PERIOD_H1, period, 0, MODE_SMA, PRICE_LOW, 0);

  double ma_m_h0 = iMA(Symbol(), PERIOD_M5, period, 0, MODE_SMA, PRICE_HIGH, 0);
  double ma_m_l0 = iMA(Symbol(), PERIOD_M5, period, 0, MODE_SMA, PRICE_LOW, 0);

  double d_o = iOpen(Symbol(), PERIOD_D1, 0);
  double d_h = iHigh(Symbol(), PERIOD_D1, 0);
  double d_l = iLow(Symbol(), PERIOD_D1, 0);
  double d_c = iClose(Symbol(), PERIOD_D1, 0);

  double h_o = iOpen(Symbol(), PERIOD_H1, 0);
  double h_h = iHigh(Symbol(), PERIOD_H1, 0);
  double h_l = iLow(Symbol(), PERIOD_H1, 0);
  double h_c = iClose(Symbol(), PERIOD_H1, 0);

  double m_o = iOpen(Symbol(), PERIOD_M5, 0);
  double m_h = iHigh(Symbol(), PERIOD_M5, 0);
  double m_l = iLow(Symbol(), PERIOD_M5, 0);
  double m_c = iClose(Symbol(), PERIOD_M5, 0);

  double d_hlx = (ma_d_h0 - ma_d_l0) / 3.5;
  double h_hlx = (ma_h_h0 - ma_h_l0) / 3.0;
  double m_hlx = (ma_m_h0 - ma_m_l0) / 2.5;

  bool should_buy  = (d_c - d_o > d_hlx || (d_c > d_o && d_o - d_l > d_hlx))
                  && (h_c - h_o > h_hlx || (h_c > h_o && h_o - h_l > h_hlx))
                  && (m_c - m_o > m_hlx || (m_c > m_o && m_o - m_l > m_hlx));

  bool should_sell = (d_o - d_c > d_hlx || (d_o > d_c && d_h - d_o > d_hlx))
                  && (h_o - h_c > h_hlx || (h_o > h_c && h_h - h_o > h_hlx))
                  && (m_o - m_c > m_hlx || (m_o > m_c && m_h - m_o > m_hlx));

  if (should_buy)
    int i = OrderSend(Symbol(), OP_BUY, lots, Ask, 3, 0, 0, NULL, magic, 0);

  if (should_sell)
    int i = OrderSend(Symbol(), OP_SELL, lots, Bid, 3, 0, 0, NULL, magic, 0);
}
