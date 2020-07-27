#property copyright "TRADEiS"
#property link      "https://stradeji.com"
#property version   "1.13"
#property strict

input string secret     = "";// Secret spell to summon the EA
input int max_spread    = 0; // Maximum allowed spread
input int magic_a       = 0; // ID of trend following strategy (A)
input int magic_b       = 0; // ID of the guard of A (B)
input int magic_c       = 0; // ID of trend countering strategy (C)
input int magic_d       = 0; // ID of the guard of C (D)
input double lots_a     = 0; // Lots (A)
input double lots_b     = 0; // Lots (B)
input double lots_c     = 0; // Lots (C)
input double lots_d     = 0; // Lots (D)
input int tf            = 0; // Timeframe
input int period        = 0; // Period
input double gap        = 0; // Minimum gap between orders in ATR
input int max_orders_a  = 0; // Maximum allowed orders (A)
input int max_orders_b  = 0; // Maximum allowed orders (B)
input int max_orders_c  = 0; // Maximum allowed orders (C)
input int max_orders_d  = 0; // Maximum allowed orders (D)
input double sl_a       = 0; // Single SL in ATR (A)
input double tp_a       = 0; // Single TP in ATR (A)
input double sl_b       = 0; // Single SL in ATR (B)
input double tp_b       = 0; // Single TP in ATR (B)
input double sl_c       = 0; // Single SL in ATR (C)
input double tp_c       = 0; // Single TP in ATR (C)
input double sl_d       = 0; // Single SL in ATR (D)
input double tp_d       = 0; // Single TP in ATR (D)
input bool auto_sl_a    = 0; // Auto SL (A)
input bool auto_sl_b    = 0; // Auto SL (B)
input bool auto_sl_c    = 0; // Auto SL (C)
input bool auto_sl_d    = 0; // Auto SL (D)
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

  int buy_tickets_a[], sell_tickets_a[], buy_count_a=0, sell_count_a=0;
  int buy_tickets_b[], sell_tickets_b[], buy_count_b=0, sell_count_b=0;
  int buy_tickets_c[], sell_tickets_c[], buy_count_c=0, sell_count_c=0;
  int buy_tickets_d[], sell_tickets_d[], buy_count_d=0, sell_count_d=0;
  double buy_nearest_price_a=0, sell_nearest_price_a=0;
  double buy_nearest_price_b=0, sell_nearest_price_b=0;
  double buy_nearest_price_c=0, sell_nearest_price_c=0;
  double buy_nearest_price_d=0, sell_nearest_price_d=0;
  double buy_pl_a=0, sell_pl_a=0;
  double buy_pl_c=0, sell_pl_c=0;
  double closed=false;

  int size;
  for (int i = OrdersTotal() - 1; i >= 0; i--) {
    if (!OrderSelect(i, SELECT_BY_POS)) continue;
    if (OrderSymbol() != symbol || OrderMagicNumber() == 0) continue;
    if (OrderMagicNumber() == magic_a) {
      switch (OrderType()) {
        case OP_BUY:
          size = ArraySize(buy_tickets_a);
          ArrayResize(buy_tickets_a, size + 1);
          buy_tickets_a[size] = OrderTicket();
          if (buy_nearest_price_a == 0 || MathAbs(OrderOpenPrice() - Ask) < MathAbs(buy_nearest_price_a - Ask)) {
            buy_nearest_price_a = OrderOpenPrice();
          }
          buy_pl_a += Bid - OrderOpenPrice();
          break;
        case OP_SELL:
          size = ArraySize(sell_tickets_a);
          ArrayResize(sell_tickets_a, size + 1);
          sell_tickets_a[size] = OrderTicket();
          if (sell_nearest_price_a == 0 || MathAbs(OrderOpenPrice() - Bid) < MathAbs(sell_nearest_price_a - Bid)) {
            sell_nearest_price_a = OrderOpenPrice();
          }
          sell_pl_a += OrderOpenPrice() - Ask;
          break;
      }
    } else if (OrderMagicNumber() == magic_b) {
      switch (OrderType()) {
        case OP_BUY:
          size = ArraySize(buy_tickets_b);
          ArrayResize(buy_tickets_b, size + 1);
          buy_tickets_b[size] = OrderTicket();
          if (buy_nearest_price_b == 0 || MathAbs(OrderOpenPrice() - Ask) < MathAbs(buy_nearest_price_b - Ask)) {
            buy_nearest_price_b = OrderOpenPrice();
          }
          break;
        case OP_SELL:
          size = ArraySize(sell_tickets_b);
          ArrayResize(sell_tickets_b, size + 1);
          sell_tickets_b[size] = OrderTicket();
          if (sell_nearest_price_b == 0 || MathAbs(OrderOpenPrice() - Bid) < MathAbs(sell_nearest_price_b - Bid)) {
            sell_nearest_price_b = OrderOpenPrice();
          }
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
    } else if (OrderMagicNumber() == magic_d) {
      switch (OrderType()) {
        case OP_BUY:
          size = ArraySize(buy_tickets_d);
          ArrayResize(buy_tickets_d, size + 1);
          buy_tickets_d[size] = OrderTicket();
          if (buy_nearest_price_d == 0 || MathAbs(OrderOpenPrice() - Ask) < MathAbs(buy_nearest_price_d - Ask)) {
            buy_nearest_price_d = OrderOpenPrice();
          }
          break;
        case OP_SELL:
          size = ArraySize(sell_tickets_d);
          ArrayResize(sell_tickets_d, size + 1);
          sell_tickets_d[size] = OrderTicket();
          if (sell_nearest_price_d == 0 || MathAbs(OrderOpenPrice() - Bid) < MathAbs(sell_nearest_price_d - Bid)) {
            sell_nearest_price_d = OrderOpenPrice();
          }
          break;
      }
    }
  }

  buy_count_a = ArraySize(buy_tickets_a);
  sell_count_a = ArraySize(sell_tickets_a);
  buy_count_b = ArraySize(buy_tickets_b);
  sell_count_b = ArraySize(sell_tickets_b);
  buy_count_c = ArraySize(buy_tickets_c);
  sell_count_c = ArraySize(sell_tickets_c);
  buy_count_d = ArraySize(buy_tickets_d);
  sell_count_d = ArraySize(sell_tickets_d);

  // Get Variables -------------------------------------------------------------

  double ma_h0 = iMA(symbol, tf, period, 0, MODE_LWMA, PRICE_HIGH, 0);
  double ma_l0 = iMA(symbol, tf, period, 0, MODE_LWMA, PRICE_LOW, 0);
  double ma_h1 = iMA(symbol, tf, period, 0, MODE_LWMA, PRICE_HIGH, 1);
  double ma_l1 = iMA(symbol, tf, period, 0, MODE_LWMA, PRICE_LOW, 1);
  double ma_h2 = iMA(symbol, tf, period, 0, MODE_LWMA, PRICE_HIGH, 2);
  double ma_l2 = iMA(symbol, tf, period, 0, MODE_LWMA, PRICE_LOW, 2);
  double ma_m0 = iMA(symbol, tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 0);
  double ma_m1 = iMA(symbol, tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 1);
  double ma_hl = ma_h1 - ma_l1; // Use `h1 - l1` because I need a fixed range
  double close1 = iClose(symbol, tf, 1);
  double close2 = iClose(symbol, tf, 2);
  double high0 = iHigh(symbol, tf, 0);
  double high1 = iHigh(symbol, tf, 1);
  double low0 = iLow(symbol, tf, 0);
  double low1 = iLow(symbol, tf, 1);

  // Close ---------------------------------------------------------------------

  if ((stop_gmt >= 0 && TimeHour(TimeGMT()) >= stop_gmt) ||
      (friday_gmt > 0 && TimeHour(TimeGMT()) >= friday_gmt && DayOfWeek() == 5)) {
    if (buy_count_a > 0) close_buy(buy_tickets_a);
    if (sell_count_a > 0) close_sell(sell_tickets_a);
    if (buy_count_b > 0) close_buy(buy_tickets_b);
    if (sell_count_b > 0) close_sell(sell_tickets_b);
    if (buy_count_c > 0) close_buy(buy_tickets_c);
    if (sell_count_c > 0) close_sell(sell_tickets_c);
    if (buy_count_d > 0) close_buy(buy_tickets_d);
    if (sell_count_d > 0) close_sell(sell_tickets_d);
    start = false;
    return;
  }

  // Stop Loss -------------------------

  if (magic_a > 0 && sl_a > 0) {
    double sl = sl_a * ma_hl;
    if (sl_buy(buy_tickets_a, sl) || sl_sell(sell_tickets_a, sl)) return;
  }

  if (magic_b > 0 && sl_b > 0) {
    double sl = sl_b * ma_hl;
    if (sl_buy(buy_tickets_b, sl) || sl_sell(sell_tickets_b, sl)) return;
  }

  if (magic_c > 0 && sl_c > 0) {
    double sl = sl_c * ma_hl;
    if (sl_buy(buy_tickets_c, sl) || sl_sell(sell_tickets_c, sl)) return;
  }

  if (magic_d > 0 && sl_d > 0) {
    double sl = sl_d * ma_hl;
    if (sl_buy(buy_tickets_d, sl) || sl_sell(sell_tickets_d, sl)) return;
  }

  // Take Profit -----------------------

  if (magic_a > 0 && tp_a > 0) {
    double tp = tp_a * ma_hl;
    if (tp_buy(buy_tickets_a, tp) || tp_sell(sell_tickets_a, tp)) return;
  }

  if (magic_b > 0 && tp_b > 0) {
    double tp = tp_b * ma_hl;
    if (tp_buy(buy_tickets_b, tp) || tp_sell(sell_tickets_b, tp)) return;
  }

  if (magic_c > 0 && tp_c > 0) {
    double tp = tp_c * ma_hl;
    if (tp_buy(buy_tickets_c, tp) || tp_sell(sell_tickets_c, tp)) return;
  }

  if (magic_d > 0 && tp_d > 0) {
    double tp = tp_d * ma_hl;
    if (tp_buy(buy_tickets_d, tp) || tp_sell(sell_tickets_d, tp)) return;
  }

  // Auto SL / TP ----------------------

  if (magic_a > 0 && auto_sl_a) {
    if (ma_m1 > ma_m0 && low1 > Bid) {
      for (int i = 0; i < buy_count_a; i++) {
        if (!OrderSelect(buy_tickets_a[i], SELECT_BY_TICKET)) continue;
        if (OrderClose(OrderTicket(), OrderLots(), Bid, 2)) closed = true;
      }
    }
    if (ma_m1 < ma_m0 && high1 < Ask) {
      for (int i = 0; i < sell_count_a; i++) {
        if (!OrderSelect(sell_tickets_a[i], SELECT_BY_TICKET)) continue;
        if (OrderClose(OrderTicket(), OrderLots(), Ask, 2)) closed = true;
      }
    }
    if (closed) return;
  }

  if (magic_b > 0 && auto_sl_b) {
    if (buy_count_a == 0 && buy_count_b > 0) {
      for (int i = 0; i < buy_count_b; i++) {
        if (!OrderSelect(buy_tickets_b[i], SELECT_BY_TICKET)) continue;
        if (OrderClose(OrderTicket(), OrderLots(), Bid, 2)) closed = true;
      }
    }
    if (sell_count_a == 0 && sell_count_b > 0) {
      for (int i = 0; i < sell_count_b; i++) {
        if (!OrderSelect(sell_tickets_b[i], SELECT_BY_TICKET)) continue;
        if (OrderClose(OrderTicket(), OrderLots(), Ask, 2)) closed = true;
      }
    }
    if (closed) return;
  }

  if (magic_c > 0 && auto_sl_c) {
    for (int i = 0; i < buy_count_c; i++) {
      if (!OrderSelect(buy_tickets_c[i], SELECT_BY_TICKET)) continue;
      if (OrderOpenPrice() > ma_m0 && OrderClose(OrderTicket(), OrderLots(), Bid, 2)) closed = true;
    }
    for (int i = 0; i < sell_count_c; i++) {
      if (!OrderSelect(sell_tickets_c[i], SELECT_BY_TICKET)) continue;
      if (OrderOpenPrice() < ma_m0 && OrderClose(OrderTicket(), OrderLots(), Ask, 2)) closed = true;
    }
    if (closed) return;
  }

  if (magic_d > 0 && auto_sl_d) {
    if (buy_count_c == 0 && buy_count_d > 0) {
      for (int i = 0; i < buy_count_d; i++) {
        if (!OrderSelect(buy_tickets_d[i], SELECT_BY_TICKET)) continue;
        if (OrderClose(OrderTicket(), OrderLots(), Bid, 2)) closed = true;
      }
    }
    if (sell_count_c == 0 && sell_count_d > 0) {
      for (int i = 0; i < sell_count_d; i++) {
        if (!OrderSelect(sell_tickets_d[i], SELECT_BY_TICKET)) continue;
        if (OrderClose(OrderTicket(), OrderLots(), Ask, 2)) closed = true;
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
  double d_25 = 0.25 * ma_hl;
  double d_50 = 0.50 * ma_hl;

  // Following -------------------------

  if (magic_a > 0) {
    should_buy   = buy_count_a < max_orders_a
                && ma_m1 < ma_m0
                && low1 < low0
                && Ask < high1 - d_50
                && (buy_count_a == 0 ||
                    Ask - buy_nearest_price_a > gap * ma_hl ||
                    buy_nearest_price_a - Ask > gap * ma_hl * 4);

    if (should_buy && OrderSend(symbol, OP_BUY, lots_a, Ask, 2, 0, 0, "A", magic_a, 0) > 0) return;

    should_sell  = sell_count_a < max_orders_a
                && ma_m1 > ma_m0
                && high1 > high0
                && Bid > low1 + d_50
                && (sell_count_a == 0 ||
                    sell_nearest_price_a - Bid > gap * ma_hl ||
                    Bid - sell_nearest_price_a > gap * ma_hl * 4);

    if (should_sell && OrderSend(symbol, OP_SELL, lots_a, Bid, 2, 0, 0, "A", magic_a, 0) > 0) return;
  }

  if (magic_b > 0) {
    should_buy   = buy_count_b < max_orders_b
                && buy_count_a > 0
                && Ask < buy_nearest_price_a
                && Ask < ma_m0
                && (buy_count_b == 0 ||
                    Ask - buy_nearest_price_b > gap * ma_hl ||
                    buy_nearest_price_b - Ask > gap * ma_hl * 4);

    if (should_buy && OrderSend(symbol, OP_BUY, lots_b, Ask, 2, 0, 0, "B", magic_b, 0) > 0) return;

    should_sell  = sell_count_b < max_orders_b
                && sell_count_a > 0
                && Bid > sell_nearest_price_a
                && Bid > ma_m0
                && (sell_count_b == 0 ||
                    sell_nearest_price_b - Bid > gap * ma_hl ||
                    Bid - sell_nearest_price_b > gap * ma_hl * 4);

    if (should_sell && OrderSend(symbol, OP_SELL, lots_b, Bid, 2, 0, 0, "B", magic_b, 0) > 0) return;
  }

  // Countering ------------------------

  if (magic_c > 0) {
    should_buy   = buy_count_c < max_orders_c
                && close2 > ma_l2 - d_25 && close1 > ma_l1 - d_25
                && Ask < ma_m0 - d_25 && Ask > ma_l0 - d_50
                && (buy_count_c == 0 ||
                    Ask - buy_nearest_price_c > gap * ma_hl ||
                    buy_nearest_price_c - Ask > gap * ma_hl * 4);

    if (should_buy && OrderSend(symbol, OP_BUY, lots_c, Ask, 2, 0, 0, "C", magic_c, 0) > 0) return;

    should_sell  = sell_count_c < max_orders_c
                && close2 < ma_h2 + d_25 && close1 < ma_h1 + d_25
                && Bid > ma_m0 + d_25 && Bid < ma_h0 + d_50
                && (sell_count_c == 0 ||
                    sell_nearest_price_c - Bid > gap * ma_hl ||
                    Bid - sell_nearest_price_c > gap * ma_hl * 4);

    if (should_sell && OrderSend(symbol, OP_SELL, lots_c, Bid, 2, 0, 0, "C", magic_c, 0) > 0) return;
  }

  if (magic_d > 0) {
    should_buy   = buy_count_d < max_orders_d
                && buy_count_c > 0
                && Ask < buy_nearest_price_c
                && (buy_count_d == 0 ||
                    Ask - buy_nearest_price_d > gap * ma_hl ||
                    buy_nearest_price_d - Ask > gap * ma_hl * 4);

    if (should_buy && OrderSend(symbol, OP_BUY, lots_d, Ask, 2, 0, 0, "D", magic_d, 0) > 0) return;

    should_sell  = sell_count_d < max_orders_d
                && sell_count_c > 0
                && Bid > sell_nearest_price_c
                && (sell_count_d == 0 ||
                    sell_nearest_price_d - Bid > gap * ma_hl ||
                    Bid - sell_nearest_price_d > gap * ma_hl * 4);

    if (should_sell && OrderSend(symbol, OP_SELL, lots_d, Bid, 2, 0, 0, "D", magic_d, 0) > 0) return;
  }
}

void close_buy(int &buy_tickets[]) {
  for (int i = 0; i < ArraySize(buy_tickets); i++) {
    if (!OrderSelect(buy_tickets[i], SELECT_BY_TICKET)) continue;
    if (OrderClose(OrderTicket(), OrderLots(), Bid, 2)) continue;
  }
}

void close_sell(int &sell_tickets[]) {
  for (int i = 0; i < ArraySize(sell_tickets); i++) {
    if (!OrderSelect(sell_tickets[i], SELECT_BY_TICKET)) continue;
    if (OrderClose(OrderTicket(), OrderLots(), Ask, 2)) continue;
  }
}

bool tp_buy(int &buy_tickets[], double tp) {
  bool closed = false;
  for (int i = 0; i < ArraySize(buy_tickets); i++) {
    if (!OrderSelect(buy_tickets[i], SELECT_BY_TICKET)) continue;
    if (Bid - OrderOpenPrice() > tp && OrderClose(OrderTicket(), OrderLots(), Bid, 2)) closed = true;
  }
  return closed;
}

bool tp_sell(int &sell_tickets[], double tp) {
  bool closed = false;
  for (int i = 0; i < ArraySize(sell_tickets); i++) {
    if (!OrderSelect(sell_tickets[i], SELECT_BY_TICKET)) continue;
    if (OrderOpenPrice() - Ask > tp && OrderClose(OrderTicket(), OrderLots(), Ask, 2)) closed = true;
  }
  return closed;
}

bool sl_buy(int &buy_tickets[], double sl) {
  bool closed = false;
  for (int i = 0; i < ArraySize(buy_tickets); i++) {
    if (!OrderSelect(buy_tickets[i], SELECT_BY_TICKET)) continue;
    if (OrderOpenPrice() - Bid > sl && OrderClose(OrderTicket(), OrderLots(), Bid, 2)) closed = true;
  }
  return closed;
}

bool sl_sell(int &sell_tickets[], double sl) {
  bool closed = false;
  for (int i = 0; i < ArraySize(sell_tickets); i++) {
    if (!OrderSelect(sell_tickets[i], SELECT_BY_TICKET)) continue;
    if (Ask - OrderOpenPrice() > sl && OrderClose(OrderTicket(), OrderLots(), Ask, 2)) closed = true;
  }
  return closed;
}
