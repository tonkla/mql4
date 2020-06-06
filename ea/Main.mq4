#property copyright "TRADEiS"
#property link      "https://stradeji.com"
#property version   "1.7"
#property strict

input string secret     = "";// Secret spell to summon the EA
input int max_spread    = 0; // Maximum allowed spread
input int magic_f       = 0; // ID of trend following strategy (F)
input int magic_c       = 0; // ID of trend countering strategy (C)
input int magic_s       = 0; // ID of scalping strategy (S)
input double lots_f     = 0; // Lots (F)
input double lots_c     = 0; // Lots (C)
input double lots_s     = 0; // Lots (S)
input int tf            = 0; // Timeframe
input int period        = 0; // Period
input int min_slope     = 0; // Minimum slope to be trend
input int max_orders_f  = 0; // Maximum allowed orders (F)
input int max_orders_c  = 0; // Maximum allowed orders (C)
input double gap_f      = 0; // Gap between orders in ATR (F)
input double gap_c      = 0; // Gap between orders in ATR (C)
input double tp_f       = 0; // Single TP in ATR (F)
input double tp_s       = 0; // Single TP in ATR (S)
input double slx_f      = 0; // Total SL in ATR (F)
input double tpx_f      = 0; // Total TP in ATR (F)
input double tpx_c      = 0; // TP exceeds H/L in ATR (C)
input int start_gmt     = -1;// Starting hour in GMT
input int stop_gmt      = -1;// Stopping hour in GMT
input int friday_gmt    = -1;// Close all on Friday hour in GMT

string symbol;
bool start=false;
datetime buy_closed_time_f, sell_closed_time_f;
datetime buy_closed_time_c, sell_closed_time_c;

int OnInit() {
  symbol = Symbol();
  return secret == "https://stradeji.com" ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick() {
  // Prevent abnormal spread
  if (MarketInfo(symbol, MODE_SPREAD) > max_spread) return;

  // Get Orders ----------------------------------------------------------------

  int buy_tickets_f[], sell_tickets_f[], buy_count_f=0, sell_count_f=0;
  int buy_tickets_c[], sell_tickets_c[], buy_count_c=0, sell_count_c=0;
  int buy_tickets_s[], sell_tickets_s[], buy_count_s=0, sell_count_s=0;
  double buy_nearest_price_f=0, sell_nearest_price_f=0;
  double buy_nearest_price_c=0, sell_nearest_price_c=0;
  double buy_nearest_price_s=0, sell_nearest_price_s=0;
  double buy_pl_f=0, sell_pl_f=0;
  double buy_pl_c=0, sell_pl_c=0;

  int size;
  for (int i = OrdersTotal() - 1; i >= 0; i--) {
    if (!OrderSelect(i, SELECT_BY_POS)) continue;
    if (OrderSymbol() != symbol || OrderMagicNumber() == 0) continue;
    if (OrderMagicNumber() == magic_f) {
      switch (OrderType()) {
        case OP_BUY:
          size = ArraySize(buy_tickets_f);
          ArrayResize(buy_tickets_f, size + 1);
          buy_tickets_f[size] = OrderTicket();
          if (buy_nearest_price_f == 0 || MathAbs(OrderOpenPrice() - Ask) < MathAbs(buy_nearest_price_f - Ask)) {
            buy_nearest_price_f = OrderOpenPrice();
          }
          buy_pl_f += Bid - OrderOpenPrice();
          break;
        case OP_SELL:
          size = ArraySize(sell_tickets_f);
          ArrayResize(sell_tickets_f, size + 1);
          sell_tickets_f[size] = OrderTicket();
          if (sell_nearest_price_f == 0 || MathAbs(OrderOpenPrice() - Bid) < MathAbs(sell_nearest_price_f - Bid)) {
            sell_nearest_price_f = OrderOpenPrice();
          }
          sell_pl_f += OrderOpenPrice() - Ask;
          break;
      }
    } else if (OrderMagicNumber() == magic_c) {
      switch (OrderType()) {
        case OP_BUY:
          size = ArraySize(buy_tickets_c);
          ArrayResize(buy_tickets_c, size + 1);
          buy_tickets_c[size] = OrderTicket();
          if (buy_nearest_price_c == 0 || MathAbs(OrderOpenPrice() - Ask) < MathAbs(buy_nearest_price_c - Ask)) {
            buy_nearest_price_c = OrderOpenPrice();
          }
          buy_pl_c += Bid - OrderOpenPrice();
          break;
        case OP_SELL:
          size = ArraySize(sell_tickets_c);
          ArrayResize(sell_tickets_c, size + 1);
          sell_tickets_c[size] = OrderTicket();
          if (sell_nearest_price_c == 0 || MathAbs(OrderOpenPrice() - Bid) < MathAbs(sell_nearest_price_c - Bid)) {
            sell_nearest_price_c = OrderOpenPrice();
          }
          sell_pl_c += OrderOpenPrice() - Ask;
          break;
      }
    } else if (OrderMagicNumber() == magic_s) {
      switch (OrderType()) {
        case OP_BUY:
          size = ArraySize(buy_tickets_s);
          ArrayResize(buy_tickets_s, size + 1);
          buy_tickets_s[size] = OrderTicket();
          if (buy_nearest_price_s == 0 || MathAbs(OrderOpenPrice() - Ask) < MathAbs(buy_nearest_price_s - Ask)) {
            buy_nearest_price_s = OrderOpenPrice();
          }
          break;
        case OP_SELL:
          size = ArraySize(sell_tickets_s);
          ArrayResize(sell_tickets_s, size + 1);
          sell_tickets_s[size] = OrderTicket();
          if (sell_nearest_price_s == 0 || MathAbs(OrderOpenPrice() - Bid) < MathAbs(sell_nearest_price_s - Bid)) {
            sell_nearest_price_s = OrderOpenPrice();
          }
          break;
      }
    }
  }

  buy_count_f = ArraySize(buy_tickets_f);
  sell_count_f = ArraySize(sell_tickets_f);
  buy_count_c = ArraySize(buy_tickets_c);
  sell_count_c = ArraySize(sell_tickets_c);
  buy_count_s = ArraySize(buy_tickets_s);
  sell_count_s = ArraySize(sell_tickets_s);

  // Get Variables -------------------------------------------------------------

  double ma_h0 = iMA(symbol, tf, period, 0, MODE_LWMA, PRICE_HIGH, 0);
  double ma_l0 = iMA(symbol, tf, period, 0, MODE_LWMA, PRICE_LOW, 0);
  double ma_m0 = iMA(symbol, tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 0);
  double ma_m1 = iMA(symbol, tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 1);
  double ma_hl = ma_h0 - ma_l0;
  double slope = MathAbs(ma_m0 - ma_m1) / ma_hl * 100;

  // Close ---------------------------------------------------------------------

  if ((stop_gmt >= 0 && TimeHour(TimeGMT()) >= stop_gmt) ||
      (friday_gmt > 0 && TimeHour(TimeGMT()) >= friday_gmt && DayOfWeek() == 5)) {
    if (buy_count_f > 0) close_buy_orders(buy_tickets_f);
    if (sell_count_f > 0) close_sell_orders(sell_tickets_f);
    if (buy_count_c > 0) close_buy_orders(buy_tickets_c);
    if (sell_count_c > 0) close_sell_orders(sell_tickets_c);
    if (buy_count_s > 0) close_buy_orders(buy_tickets_s);
    if (sell_count_s > 0) close_sell_orders(sell_tickets_s);
    start = false;
    return;
  }

  // Stop Loss ------------------------

  if (magic_f > 0 && slx_f > 0) {
    if (buy_pl_f < 0 && MathAbs(buy_pl_f) > slx_f * ma_hl) {
      for (int i = 0; i < buy_count_f; i++) {
        if (!OrderSelect(buy_tickets_f[i], SELECT_BY_TICKET)) continue;
        if (OrderClose(OrderTicket(), OrderLots(), Bid, 2)) buy_closed_time_f = TimeCurrent();
      }
    }
    if (sell_pl_f < 0 && MathAbs(sell_pl_f) > slx_f * ma_hl) {
      for (int i = 0; i < sell_count_f; i++) {
        if (!OrderSelect(sell_tickets_f[i], SELECT_BY_TICKET)) continue;
        if (OrderClose(OrderTicket(), OrderLots(), Ask, 2)) sell_closed_time_f = TimeCurrent();
      }
    }
  }

  // Take Profit ----------------------

  if (magic_f > 0 && tp_f > 0) {
    double _tp = tp_f * ma_hl;
    for (int i = 0; i < buy_count_f; i++) {
      if (!OrderSelect(buy_tickets_f[i], SELECT_BY_TICKET)) continue;
      if (Bid - OrderOpenPrice() > _tp && OrderClose(OrderTicket(), OrderLots(), Bid, 2)) continue;
    }
    for (int i = 0; i < sell_count_f; i++) {
      if (!OrderSelect(sell_tickets_f[i], SELECT_BY_TICKET)) continue;
      if (OrderOpenPrice() - Ask > _tp && OrderClose(OrderTicket(), OrderLots(), Ask, 2)) continue;
    }
  }

  if (magic_s > 0 && tp_s > 0) {
    double _tp = tp_s * ma_hl;
    for (int i = 0; i < buy_count_s; i++) {
      if (!OrderSelect(buy_tickets_s[i], SELECT_BY_TICKET)) continue;
      if (Bid - OrderOpenPrice() > _tp && OrderClose(OrderTicket(), OrderLots(), Bid, 2)) continue;
    }
    for (int i = 0; i < sell_count_s; i++) {
      if (!OrderSelect(sell_tickets_s[i], SELECT_BY_TICKET)) continue;
      if (OrderOpenPrice() - Ask > _tp && OrderClose(OrderTicket(), OrderLots(), Ask, 2)) continue;
    }
  }

  if (magic_f > 0 && tpx_f > 0) {
    if (buy_pl_f > tpx_f * ma_hl) {
      for (int i = 0; i < buy_count_f; i++) {
        if (!OrderSelect(buy_tickets_f[i], SELECT_BY_TICKET)) continue;
        if (OrderClose(OrderTicket(), OrderLots(), Bid, 2)) buy_closed_time_f = TimeCurrent();
      }
    }
    if (sell_pl_f > tpx_f * ma_hl) {
      for (int i = 0; i < sell_count_f; i++) {
        if (!OrderSelect(sell_tickets_f[i], SELECT_BY_TICKET)) continue;
        if (OrderClose(OrderTicket(), OrderLots(), Ask, 2)) sell_closed_time_f = TimeCurrent();
      }
    }
  }

  if (magic_c > 0 && tpx_c > 0) {
    if (buy_pl_c > 0 && Bid > ma_h0 + (tpx_c * ma_hl)) {
      for (int i = 0; i < buy_count_c; i++) {
        if (!OrderSelect(buy_tickets_c[i], SELECT_BY_TICKET)) continue;
        if (OrderClose(OrderTicket(), OrderLots(), Bid, 2)) buy_closed_time_c = TimeCurrent();
      }
    }
    if (sell_pl_c > 0 && Ask < ma_l0 - (tpx_c * ma_hl)) {
      for (int i = 0; i < sell_count_c; i++) {
        if (!OrderSelect(sell_tickets_c[i], SELECT_BY_TICKET)) continue;
        if (OrderClose(OrderTicket(), OrderLots(), Ask, 2)) sell_closed_time_c = TimeCurrent();
      }
    }
  }

  // Open ----------------------------------------------------------------------

  if (start_gmt >= 0 && !start) {
    if (TimeHour(TimeGMT()) < start_gmt || TimeHour(TimeGMT()) >= stop_gmt) return;
    start = true;
  }
  if (friday_gmt > 0 && TimeHour(TimeGMT()) >= friday_gmt && DayOfWeek() == 5) return;

  bool should_buy=false, should_sell=false;

  // Following -------------------------

  if (magic_f > 0) {
    should_buy   = ma_m1 < ma_m0
                && buy_count_f < max_orders_f
                && TimeCurrent() - buy_closed_time_f > 300
                && (buy_count_f == 0
                    ? slope > min_slope ? Ask < ma_h0 : Ask < ma_m0
                    : MathAbs(Ask - buy_nearest_price_f) > gap_f * ma_hl);

    if (should_buy && OrderSend(symbol, OP_BUY, lots_f, Ask, 2, 0, 0, "f", magic_f, 0) > 0) return;

    should_sell  = ma_m1 > ma_m0
                && sell_count_f < max_orders_f
                && TimeCurrent() - sell_closed_time_f > 300
                && (sell_count_f == 0
                    ? slope > min_slope ? Bid > ma_l0 : Bid > ma_m0
                    : MathAbs(sell_nearest_price_f - Bid) > gap_f * ma_hl);

    if (should_sell && OrderSend(symbol, OP_SELL, lots_f, Bid, 2, 0, 0, "f", magic_f, 0) > 0) return;
  }

  // Countering ------------------------

  if (magic_c > 0) {
    if (slope > min_slope) return;

    should_buy   = buy_count_c < max_orders_c
                && TimeCurrent() - buy_closed_time_c > 300
                && Ask < ma_m0 - (0.2 * ma_hl)
                && (buy_count_c == 0 || MathAbs(buy_nearest_price_c - Ask) > gap_c * ma_hl);

    if (should_buy && OrderSend(symbol, OP_BUY, lots_c, Ask, 2, 0, 0, "c", magic_c, 0) > 0) return;

    should_sell  = sell_count_c < max_orders_c
                && TimeCurrent() - sell_closed_time_c > 300
                && Bid > ma_m0 + (0.2 * ma_hl)
                && (sell_count_c == 0 || MathAbs(Bid - sell_nearest_price_c) > gap_c * ma_hl);

    if (should_sell && OrderSend(symbol, OP_SELL, lots_c, Bid, 2, 0, 0, "c", magic_c, 0) > 0) return;
  }

  // Scalping --------------------------

  if (magic_s > 0) {
    if (TimeHour(TimeGMT()) < 8 || TimeHour(TimeGMT()) >= 17) return;

    double open_d1 = iOpen(symbol, PERIOD_D1, 0);
    double ma_d_h0 = iMA(symbol, PERIOD_D1, 4, 0, MODE_LWMA, PRICE_HIGH, 0);
    double ma_d_l0 = iMA(symbol, PERIOD_D1, 4, 0, MODE_LWMA, PRICE_LOW, 0);
    double ma_d_hl = ma_d_h0 - ma_d_l0;
    double ma_h_h0 = iMA(symbol, PERIOD_H1, 4, 0, MODE_LWMA, PRICE_HIGH, 0);
    double ma_h_l0 = iMA(symbol, PERIOD_H1, 4, 0, MODE_LWMA, PRICE_LOW, 0);
    double ma_h_m0 = iMA(symbol, PERIOD_H1, 4, 0, MODE_LWMA, PRICE_MEDIAN, 0);
    double ma_h_m1 = iMA(symbol, PERIOD_H1, 4, 0, MODE_LWMA, PRICE_MEDIAN, 1);
    double ma_m_m0 = iMA(symbol, PERIOD_M5, 4, 0, MODE_LWMA, PRICE_MEDIAN, 0);
    double ma_m_m1 = iMA(symbol, PERIOD_M5, 4, 0, MODE_LWMA, PRICE_MEDIAN, 1);

    should_buy   = Ask > open_d1
                && ma_h_m1 < ma_h_m0 && ma_m_m1 > ma_m_m0
                && Ask < ma_h_h0 && Ask < ma_m_m0
                && (buy_count_s == 0 || MathAbs(Ask - buy_nearest_price_s) > 0.2 * ma_d_hl);

    if (should_buy && OrderSend(symbol, OP_BUY, lots_s, Ask, 2, 0, 0, "s", magic_s, 0) > 0) return;

    should_sell  = Bid < open_d1
                && ma_h_m1 > ma_h_m0 && ma_m_m1 < ma_m_m0
                && Bid > ma_h_l0 && Bid > ma_m_m0
                && (sell_count_s == 0 || MathAbs(sell_nearest_price_s - Bid) > 0.2 * ma_d_hl);

    if (should_sell && OrderSend(symbol, OP_SELL, lots_s, Bid, 2, 0, 0, "s", magic_s, 0) > 0) return;
  }
}

void close_buy_orders(int &buy_tickets[]) {
  for (int i = 0; i < ArraySize(buy_tickets); i++) {
    if (!OrderSelect(buy_tickets[i], SELECT_BY_TICKET)) continue;
    if (OrderClose(OrderTicket(), OrderLots(), Bid, 2)) continue;
  }
}

void close_sell_orders(int &sell_tickets[]) {
  for (int i = 0; i < ArraySize(sell_tickets); i++) {
    if (!OrderSelect(sell_tickets[i], SELECT_BY_TICKET)) continue;
    if (OrderClose(OrderTicket(), OrderLots(), Ask, 2)) continue;
  }
}
