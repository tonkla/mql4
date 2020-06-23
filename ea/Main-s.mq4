#property copyright "TRADEiS"
#property link      "https://stradeji.com"
#property version   "1.9"
#property strict

input string secret     = "";// Secret spell to summon the EA
input int max_spread    = 0; // Maximum allowed spread
input int magic_s1      = 0; // ID of strategy S1
input int magic_s2      = 0; // ID of strategy S2
input double lots_s1    = 0; // Lots (S1)
input double lots_s2    = 0; // Lots (S2)
input int tf            = 0; // Timeframe
input int period        = 0; // Period
input double min_profit = 0; // Minimum profit for TP in ATR
input double sl_s1      = 0; // Single SL in ATR (S1)
input double sl_s2      = 0; // Single SL in ATR (S2)
input double tp_s1      = 0; // Single TP in ATR (S1)
input double tp_s2      = 0; // Single TP in ATR (S2)
input bool auto_sl_s1   = 0; // Auto SL (S1)
input bool auto_sl_s2   = 0; // Auto SL (S2)
input bool auto_tp_s1   = 0; // Auto TP (S1)
input bool auto_tp_s2   = 0; // Auto TP (S2)
input int start_gmt     = -1;// Starting hour in GMT
input int stop_gmt      = -1;// Stopping hour in GMT
input int friday_gmt    = -1;// Close all on Friday hour in GMT

string symbol;
bool start=false;

int OnInit() {
  symbol = Symbol();
  return secret == "https://stradeji.com" ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick() {
  // Prevent abnormal spread
  if (MarketInfo(symbol, MODE_SPREAD) > max_spread) return;

  // Get Orders ----------------------------------------------------------------

  int buy_tickets_s1[], sell_tickets_s1[], buy_count_s1=0, sell_count_s1=0;
  int buy_tickets_s2[], sell_tickets_s2[], buy_count_s2=0, sell_count_s2=0;
  double buy_nearest_price_s1=0, sell_nearest_price_s1=0;
  double buy_nearest_price_s2=0, sell_nearest_price_s2=0;
  bool closed=false;

  int size;
  for (int i = OrdersTotal() - 1; i >= 0; i--) {
    if (!OrderSelect(i, SELECT_BY_POS)) continue;
    if (OrderSymbol() != symbol || OrderMagicNumber() == 0) continue;
    if (OrderMagicNumber() == magic_s1) {
      switch (OrderType()) {
        case OP_BUY:
          size = ArraySize(buy_tickets_s1);
          ArrayResize(buy_tickets_s1, size + 1);
          buy_tickets_s1[size] = OrderTicket();
          if (buy_nearest_price_s1 == 0 || MathAbs(OrderOpenPrice() - Ask) < MathAbs(buy_nearest_price_s1 - Ask)) {
            buy_nearest_price_s1 = OrderOpenPrice();
          }
          break;
        case OP_SELL:
          size = ArraySize(sell_tickets_s1);
          ArrayResize(sell_tickets_s1, size + 1);
          sell_tickets_s1[size] = OrderTicket();
          if (sell_nearest_price_s1 == 0 || MathAbs(OrderOpenPrice() - Bid) < MathAbs(sell_nearest_price_s1 - Bid)) {
            sell_nearest_price_s1 = OrderOpenPrice();
          }
          break;
      }
    } else if (OrderMagicNumber() == magic_s2) {
      switch (OrderType()) {
        case OP_BUY:
          size = ArraySize(buy_tickets_s2);
          ArrayResize(buy_tickets_s2, size + 1);
          buy_tickets_s2[size] = OrderTicket();
          if (buy_nearest_price_s2 == 0 || MathAbs(OrderOpenPrice() - Ask) < MathAbs(buy_nearest_price_s2 - Ask)) {
            buy_nearest_price_s2 = OrderOpenPrice();
          }
          break;
        case OP_SELL:
          size = ArraySize(sell_tickets_s2);
          ArrayResize(sell_tickets_s2, size + 1);
          sell_tickets_s2[size] = OrderTicket();
          if (sell_nearest_price_s2 == 0 || MathAbs(OrderOpenPrice() - Bid) < MathAbs(sell_nearest_price_s2 - Bid)) {
            sell_nearest_price_s2 = OrderOpenPrice();
          }
          break;
      }
    }
  }

  buy_count_s1 = ArraySize(buy_tickets_s1);
  sell_count_s1 = ArraySize(sell_tickets_s1);
  buy_count_s2 = ArraySize(buy_tickets_s2);
  sell_count_s2 = ArraySize(sell_tickets_s2);

  // Get Variables -------------------------------------------------------------

  double h1 = iHigh(symbol, tf, 1);
  double l1 = iLow(symbol, tf, 1);
  double open = iOpen(symbol, tf, 0);
  double ma_h0 = iMA(symbol, tf, period, 0, MODE_LWMA, PRICE_HIGH, 0);
  double ma_l0 = iMA(symbol, tf, period, 0, MODE_LWMA, PRICE_LOW, 0);
  double ma_m0 = iMA(symbol, tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 0);
  double ma_m1 = iMA(symbol, tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 1);
  double ma_hl = ma_h0 - ma_l0;
  double ma_m_m0 = iMA(symbol, PERIOD_M1, 8, 0, MODE_LWMA, PRICE_MEDIAN, 0);
  double ma_m_m1 = iMA(symbol, PERIOD_M1, 8, 0, MODE_LWMA, PRICE_MEDIAN, 1);
  double ma_m_m2 = iMA(symbol, PERIOD_M1, 8, 0, MODE_LWMA, PRICE_MEDIAN, 2);

  // Close ---------------------------------------------------------------------

  if ((stop_gmt >= 0 && TimeHour(TimeGMT()) >= stop_gmt) ||
      (friday_gmt > 0 && TimeHour(TimeGMT()) >= friday_gmt && DayOfWeek() == 5)) {
    if (buy_count_s1 > 0) close_buy_orders(buy_tickets_s1);
    if (sell_count_s1 > 0) close_sell_orders(sell_tickets_s1);
    if (buy_count_s2 > 0) close_buy_orders(buy_tickets_s2);
    if (sell_count_s2 > 0) close_sell_orders(sell_tickets_s2);
    start = false;
    return;
  }

  // Stop Loss ------------------------

  if (magic_s1 > 0 && sl_s1 > 0) {
    double _sl = sl_s1 * ma_hl;
    for (int i = 0; i < buy_count_s1; i++) {
      if (!OrderSelect(buy_tickets_s1[i], SELECT_BY_TICKET)) continue;
      if (OrderOpenPrice() - Bid > _sl && OrderClose(OrderTicket(), OrderLots(), Bid, 2)) {
        closed = true;
        continue;
      }
    }
    for (int i = 0; i < sell_count_s1; i++) {
      if (!OrderSelect(sell_tickets_s1[i], SELECT_BY_TICKET)) continue;
      if (Ask - OrderOpenPrice() > _sl && OrderClose(OrderTicket(), OrderLots(), Ask, 2)) {
        closed = true;
        continue;
      }
    }
    if (closed) return;
  }

  if (magic_s2 > 0 && sl_s2 > 0) {
    double _sl = sl_s2 * ma_hl;
    for (int i = 0; i < buy_count_s2; i++) {
      if (!OrderSelect(buy_tickets_s2[i], SELECT_BY_TICKET)) continue;
      if (OrderOpenPrice() - Bid > _sl && OrderClose(OrderTicket(), OrderLots(), Bid, 2)) {
        closed = true;
        continue;
      }
    }
    for (int i = 0; i < sell_count_s2; i++) {
      if (!OrderSelect(sell_tickets_s2[i], SELECT_BY_TICKET)) continue;
      if (Ask - OrderOpenPrice() > _sl && OrderClose(OrderTicket(), OrderLots(), Ask, 2)) {
        closed = true;
        continue;
      }
    }
    if (closed) return;
  }

  if (magic_s1 > 0 && auto_sl_s1) {
    if (Bid < l1 - (0.05 * ma_hl)) {
      for (int i = 0; i < buy_count_s1; i++) {
        if (!OrderSelect(buy_tickets_s1[i], SELECT_BY_TICKET)) continue;
        if (OrderClose(OrderTicket(), OrderLots(), Bid, 2)) {
          closed = true;
          continue;
        }
      }
    }
    if (Ask > h1 + (0.05 * ma_hl)) {
      for (int i = 0; i < sell_count_s1; i++) {
        if (!OrderSelect(sell_tickets_s1[i], SELECT_BY_TICKET)) continue;
        if (OrderClose(OrderTicket(), OrderLots(), Ask, 2)) {
          closed = true;
          continue;
        }
      }
    }
    if (closed) return;
  }

  if (magic_s2 > 0 && auto_sl_s2) {
    if (Bid < open) {
      for (int i = 0; i < buy_count_s2; i++) {
        if (!OrderSelect(buy_tickets_s2[i], SELECT_BY_TICKET)) continue;
        if (TimeCurrent() - OrderOpenTime() > 3600 && OrderClose(OrderTicket(), OrderLots(), Bid, 2)) {
          closed = true;
          continue;
        }
      }
    }
    if (Ask > open) {
      for (int i = 0; i < sell_count_s2; i++) {
        if (!OrderSelect(sell_tickets_s2[i], SELECT_BY_TICKET)) continue;
        if (TimeCurrent() - OrderOpenTime() > 3600 && OrderClose(OrderTicket(), OrderLots(), Ask, 2)) {
          closed = true;
          continue;
        }
      }
    }
    if (closed) return;
  }

  // Take Profit ----------------------

  if (magic_s1 > 0 && tp_s1 > 0) {
    double _tp = tp_s1 * ma_hl;
    for (int i = 0; i < buy_count_s1; i++) {
      if (!OrderSelect(buy_tickets_s1[i], SELECT_BY_TICKET)) continue;
      if (Bid - OrderOpenPrice() > _tp && OrderClose(OrderTicket(), OrderLots(), Bid, 2)) {
        closed = true;
        continue;
      }
    }
    for (int i = 0; i < sell_count_s1; i++) {
      if (!OrderSelect(sell_tickets_s1[i], SELECT_BY_TICKET)) continue;
      if (OrderOpenPrice() - Ask > _tp && OrderClose(OrderTicket(), OrderLots(), Ask, 2)) {
        closed = true;
        continue;
      }
    }
    if (closed) return;
  }

  if (magic_s2 > 0 && tp_s2 > 0) {
    double _tp = tp_s2 * ma_hl;
    for (int i = 0; i < buy_count_s2; i++) {
      if (!OrderSelect(buy_tickets_s2[i], SELECT_BY_TICKET)) continue;
      if (Bid - OrderOpenPrice() > _tp && OrderClose(OrderTicket(), OrderLots(), Bid, 2)) {
        closed = true;
        continue;
      }
    }
    for (int i = 0; i < sell_count_s2; i++) {
      if (!OrderSelect(sell_tickets_s2[i], SELECT_BY_TICKET)) continue;
      if (OrderOpenPrice() - Ask > _tp && OrderClose(OrderTicket(), OrderLots(), Ask, 2)) {
        closed = true;
        continue;
      }
    }
    if (closed) return;
  }

  if (magic_s1 > 0 && auto_tp_s1) {
    double _h = iHigh(symbol, PERIOD_M15, 1);
    double _l = iLow(symbol, PERIOD_M15, 1);
    double m0 = iMA(symbol, PERIOD_M5, 4, 0, MODE_LWMA, PRICE_MEDIAN, 0);
    double m1 = iMA(symbol, PERIOD_M5, 4, 0, MODE_LWMA, PRICE_MEDIAN, 1);
    double _profit = min_profit * ma_hl;
    if (m1 > m0 || Bid < _l) {
      for (int i = 0; i < buy_count_s1; i++) {
        if (!OrderSelect(buy_tickets_s1[i], SELECT_BY_TICKET)) continue;
        if (Bid - OrderOpenPrice() > _profit && OrderClose(OrderTicket(), OrderLots(), Bid, 2)) {
          closed = true;
          continue;
        }
      }
    }
    if (m1 < m0 || Ask > _h) {
      for (int i = 0; i < sell_count_s1; i++) {
        if (!OrderSelect(sell_tickets_s1[i], SELECT_BY_TICKET)) continue;
        if (OrderOpenPrice() - Ask > _profit && OrderClose(OrderTicket(), OrderLots(), Ask, 2)) {
          closed = true;
          continue;
        }
      }
    }
    if (closed) return;
  }

  if (magic_s2 > 0 && auto_tp_s2) {
    double _h = iHigh(symbol, PERIOD_M15, 1);
    double _l = iLow(symbol, PERIOD_M15, 1);
    double m0 = iMA(symbol, PERIOD_M5, 4, 0, MODE_LWMA, PRICE_MEDIAN, 0);
    double m1 = iMA(symbol, PERIOD_M5, 4, 0, MODE_LWMA, PRICE_MEDIAN, 1);
    double _profit = min_profit * ma_hl;
    if (m1 > m0 || Bid < _l) {
      for (int i = 0; i < buy_count_s2; i++) {
        if (!OrderSelect(buy_tickets_s2[i], SELECT_BY_TICKET)) continue;
        if (Bid - OrderOpenPrice() > _profit && OrderClose(OrderTicket(), OrderLots(), Bid, 2)) {
          closed = true;
          continue;
        }
      }
    }
    if (m1 < m0 || Ask > _h) {
      for (int i = 0; i < sell_count_s2; i++) {
        if (!OrderSelect(sell_tickets_s2[i], SELECT_BY_TICKET)) continue;
        if (OrderOpenPrice() - Ask > _profit && OrderClose(OrderTicket(), OrderLots(), Ask, 2)) {
          closed = true;
          continue;
        }
      }
    }
    if (closed) return;
  }

  // Open ----------------------------------------------------------------------

  if (start_gmt >= 0 && !start) {
    if (TimeHour(TimeGMT()) < start_gmt || TimeHour(TimeGMT()) >= stop_gmt) return;
    start = true;
  }
  if (friday_gmt > 0 && TimeHour(TimeGMT()) >= friday_gmt && DayOfWeek() == 5) return;

  bool should_buy=false, should_sell=false;

  // S1 --------------------------------

  if (magic_s1 > 0) {
    should_buy   = ma_m1 < ma_m0 && l1 < Ask && Ask < ma_h0
                && ma_m_m2 < ma_m_m1 && ma_m_m1 < ma_m_m0
                && (buy_count_s1 == 0 || MathAbs(Ask - buy_nearest_price_s1) > 0.2 * ma_hl);

    if (should_buy && OrderSend(symbol, OP_BUY, lots_s1, Ask, 2, 0, 0, "s1", magic_s1, 0) > 0) return;

    should_sell  = ma_m1 > ma_m0 && h1 > Bid && Bid > ma_l0
                && ma_m_m2 > ma_m_m1 && ma_m_m1 > ma_m_m0
                && (sell_count_s1 == 0 || MathAbs(sell_nearest_price_s1 - Bid) > 0.2 * ma_hl);

    if (should_sell && OrderSend(symbol, OP_SELL, lots_s1, Bid, 2, 0, 0, "s1", magic_s1, 0) > 0) return;
  }

  // S2 --------------------------------

  if (magic_s2 > 0) {
    should_buy   = Ask > open
                && ma_m_m2 < ma_m_m1 && ma_m_m1 < ma_m_m0
                && (buy_count_s2 == 0 || MathAbs(Ask - buy_nearest_price_s2) > 0.2 * ma_hl);

    if (should_buy && OrderSend(symbol, OP_BUY, lots_s2, Ask, 2, 0, 0, "s2", magic_s2, 0) > 0) return;

    should_sell  = Bid < open
                && ma_m_m2 > ma_m_m1 && ma_m_m1 > ma_m_m0
                && (sell_count_s2 == 0 || MathAbs(sell_nearest_price_s2 - Bid) > 0.2 * ma_hl);

    if (should_sell && OrderSend(symbol, OP_SELL, lots_s2, Bid, 2, 0, 0, "s2", magic_s2, 0) > 0) return;
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
