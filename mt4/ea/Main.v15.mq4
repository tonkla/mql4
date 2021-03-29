#property copyright "TRADEiS"
#property link      "https://stradeji.com"
#property version   "1.14"
#property strict

input string secret     = "";// Secret spell to summon the EA
input int max_spread    = 0; // Maximum allowed spread
input int magic_a       = 0; // ID of trend following strategy (A)
input int magic_b       = 0; // ID of the guard of A (B)
input double lots_a     = 0; // Lots (A)
input double lots_b     = 0; // Lots (B)
input int tf            = 0; // Timeframe
input int period_1      = 0; // Period 1
input int period_2      = 0; // Period 2
input int period_3      = 0; // Period 3
input int period_4      = 0; // Period 4
input int period_5      = 0; // Period 5
input double gap_a      = 0; // Minimum gap between orders in ATR (A)
input double gap_b      = 0; // Minimum gap between orders in ATR (B)
input int max_orders_a  = 0; // Maximum allowed orders (A)
input int max_orders_b  = 0; // Maximum allowed orders (B)
input double sl_a       = 0; // Single SL in ATR (A)
input double tp_a       = 0; // Single TP in ATR (A)
input double sl_b       = 0; // Single SL in ATR (B)
input double tp_b       = 0; // Single TP in ATR (B)
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
  double buy_nearest_price_a=0, sell_nearest_price_a=0;
  double buy_nearest_price_b=0, sell_nearest_price_b=0;
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
          break;
        case OP_SELL:
          size = ArraySize(sell_tickets_a);
          ArrayResize(sell_tickets_a, size + 1);
          sell_tickets_a[size] = OrderTicket();
          if (sell_nearest_price_a == 0 || MathAbs(OrderOpenPrice() - Bid) < MathAbs(sell_nearest_price_a - Bid)) {
            sell_nearest_price_a = OrderOpenPrice();
          }
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
    }
  }

  buy_count_a = ArraySize(buy_tickets_a);
  sell_count_a = ArraySize(sell_tickets_a);
  buy_count_b = ArraySize(buy_tickets_b);
  sell_count_b = ArraySize(sell_tickets_b);

  // Get Variables -------------------------------------------------------------

  double ma_h1_f = iMA(symbol, tf, period_f, 0, MODE_LWMA, PRICE_HIGH, 1);
  double ma_l1_f = iMA(symbol, tf, period_f, 0, MODE_LWMA, PRICE_LOW, 1);
  double ma_m0_f = iMA(symbol, tf, period_f, 0, MODE_LWMA, PRICE_MEDIAN, 0);
  double ma_m1_f = iMA(symbol, tf, period_f, 0, MODE_LWMA, PRICE_MEDIAN, 1);
  double ma_m0_s = iMA(symbol, tf, period_s, 0, MODE_LWMA, PRICE_MEDIAN, 0);
  double ma_m1_s = iMA(symbol, tf, period_s, 0, MODE_LWMA, PRICE_MEDIAN, 1);
  double ma_hl = ma_h1_f - ma_l1_f; // Use `h1 - l1` because I need a fixed range
  double close1 = iClose(symbol, tf, 1);
  double high1 = iHigh(symbol, tf, 1);
  double low1 = iLow(symbol, tf, 1);

  // Close ---------------------------------------------------------------------

  if ((stop_gmt >= 0 && TimeHour(TimeGMT()) >= stop_gmt) ||
      (friday_gmt > 0 && TimeHour(TimeGMT()) >= friday_gmt && DayOfWeek() == 5)) {
    if (buy_count_a > 0) close_buy(buy_tickets_a);
    if (sell_count_a > 0) close_sell(sell_tickets_a);
    if (buy_count_b > 0) close_buy(buy_tickets_b);
    if (sell_count_b > 0) close_sell(sell_tickets_b);
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

  // Take Profit -----------------------

  if (magic_a > 0 && tp_a > 0) {
    double tp = tp_a * ma_hl;
    if (tp_buy(buy_tickets_a, tp) || tp_sell(sell_tickets_a, tp)) return;
  }

  if (magic_b > 0 && tp_b > 0) {
    double tp = tp_b * ma_hl;
    if (tp_buy(buy_tickets_b, tp) || tp_sell(sell_tickets_b, tp)) return;
  }

  // Open ----------------------------------------------------------------------

  if (start_gmt >= 0 && !start) {
    if (TimeHour(TimeGMT()) < start_gmt || TimeHour(TimeGMT()) >= stop_gmt) return;
    start = true;
  }
  if (friday_gmt > 0 && TimeHour(TimeGMT()) >= friday_gmt && DayOfWeek() == 5) return;

  bool should_buy=false, should_sell=false;
  double d_50 = 0.50 * ma_hl;

  // Following -------------------------

  if (magic_a > 0) {
    should_buy   = buy_count_a < max_orders_a
                && ma_m1_f < ma_m0_f && ma_m1_s < ma_m0_s
                && Ask < close1
                && (buy_count_a == 0 || MathAbs(Ask - buy_nearest_price_a) > gap_a * ma_hl);

    if (should_buy && OrderSend(symbol, OP_BUY, lots_a, Ask, 2, 0, 0, "A", magic_a, 0) > 0) return;

    should_sell  = sell_count_a < max_orders_a
                && ma_m1_f > ma_m0_f && ma_m1_s > ma_m0_s
                && Bid > close1
                && (sell_count_a == 0 || MathAbs(sell_nearest_price_a - Bid) > gap_a * ma_hl);

    if (should_sell && OrderSend(symbol, OP_SELL, lots_a, Bid, 2, 0, 0, "A", magic_a, 0) > 0) return;
  }

  if (magic_b > 0) {
    should_buy   = buy_count_b < max_orders_b
                && buy_count_a > 0
                && Ask < buy_nearest_price_a && Ask < close1 && Ask < high1 - d_50
                && (buy_count_b == 0 || MathAbs(Ask - buy_nearest_price_b) > gap_b * ma_hl);

    if (should_buy && OrderSend(symbol, OP_BUY, lots_b, Ask, 2, 0, 0, "B", magic_b, 0) > 0) return;

    should_sell  = sell_count_b < max_orders_b
                && sell_count_a > 0
                && Bid > sell_nearest_price_a && Bid > close1 && Bid > low1 + d_50
                && (sell_count_b == 0 || MathAbs(sell_nearest_price_b - Bid) > gap_b * ma_hl);

    if (should_sell && OrderSend(symbol, OP_SELL, lots_b, Bid, 2, 0, 0, "B", magic_b, 0) > 0) return;
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
