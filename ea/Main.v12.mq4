#property copyright "TRADEiS"
#property link      "https://stradeji.com"
#property version   "1.12"
#property strict

input string secret     = "";// Secret spell to summon the EA
input int max_spread    = 0; // Maximum allowed spread
input int magic_f       = 0; // ID of trend following strategy (F)
input int magic_c       = 0; // ID of trend countering strategy (C)
input int magic_s       = 0; // ID of scalping strategy (S)
input double lots       = 0; // Lots
input int tf            = 0; // Timeframe
input int period        = 0; // Period
input double gap_f      = 0; // Gap between orders in ATR (F)
input double gap_c      = 0; // Gap between orders in ATR (C)
input double gap_s      = 0; // Gap between orders in ATR (S)
input double tp         = 0; // Total TP in ATR
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

  int buy_tickets_f[], sell_tickets_f[], buy_count_f=0, sell_count_f=0;
  int buy_tickets_c[], sell_tickets_c[], buy_count_c=0, sell_count_c=0;
  int buy_tickets_s[], sell_tickets_s[], buy_count_s=0, sell_count_s=0;
  double buy_nearest_price_f=0, sell_nearest_price_f=0;
  double buy_nearest_price_c=0, sell_nearest_price_c=0;
  double buy_nearest_price_s=0, sell_nearest_price_s=0;
  double buy_pl_f=0, sell_pl_f=0;
  double buy_pl_c=0, sell_pl_c=0;
  double buy_pl_s=0, sell_pl_s=0;

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
          buy_pl_s += Bid - OrderOpenPrice();
          break;
        case OP_SELL:
          size = ArraySize(sell_tickets_s);
          ArrayResize(sell_tickets_s, size + 1);
          sell_tickets_s[size] = OrderTicket();
          if (sell_nearest_price_s == 0 || MathAbs(OrderOpenPrice() - Bid) < MathAbs(sell_nearest_price_s - Bid)) {
            sell_nearest_price_s = OrderOpenPrice();
          }
          sell_pl_s += OrderOpenPrice() - Ask;
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

  // Take Profit -----------------------

  if (buy_pl_f + buy_pl_c + buy_pl_s + sell_pl_f + sell_pl_c + sell_pl_s > tp * ma_hl) {
    if (buy_count_f > 0) close_buy_orders(buy_tickets_f);
    if (sell_count_f > 0) close_sell_orders(sell_tickets_f);
    if (buy_count_c > 0) close_buy_orders(buy_tickets_c);
    if (sell_count_c > 0) close_sell_orders(sell_tickets_c);
    if (buy_count_s > 0) close_buy_orders(buy_tickets_s);
    if (sell_count_s > 0) close_sell_orders(sell_tickets_s);
    return;
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
                && Ask < ma_h0
                && (buy_count_f == 0 || MathAbs(Ask - buy_nearest_price_f) > gap_f * ma_hl);

    if (should_buy && OrderSend(symbol, OP_BUY, lots, Ask, 2, 0, 0, "f", magic_f, 0) > 0) return;

    should_sell  = ma_m1 > ma_m0
                && Bid > ma_l0
                && (sell_count_f == 0 || MathAbs(sell_nearest_price_f - Bid) > gap_f * ma_hl);

    if (should_sell && OrderSend(symbol, OP_SELL, lots, Bid, 2, 0, 0, "f", magic_f, 0) > 0) return;
  }

  // Countering ------------------------

  if (magic_c > 0) {
    should_buy   = Ask < ma_m0 - (0.25 * ma_hl)
                && (buy_count_c == 0 ||
                    Ask - buy_nearest_price_c > gap_c * ma_hl ||
                    buy_nearest_price_c - Ask > gap_c * ma_hl * 4);

    if (should_buy && OrderSend(symbol, OP_BUY, lots, Ask, 2, 0, 0, "c", magic_c, 0) > 0) return;

    should_sell  = Bid > ma_m0 + (0.25 * ma_hl)
                && (sell_count_c == 0 ||
                    sell_nearest_price_c - Bid > gap_c * ma_hl ||
                    Bid - sell_nearest_price_c > gap_c * ma_hl * 4);

    if (should_sell && OrderSend(symbol, OP_SELL, lots, Bid, 2, 0, 0, "c", magic_c, 0) > 0) return;
  }

  // Scalping --------------------------

  if (magic_s > 0) {
    double _d = 0.25 * ma_hl;
    should_buy   = Ask < ma_m0
                && ((buy_pl_f > _d && sell_pl_f < 0) || (buy_pl_c > _d && sell_pl_c < 0))
                && (buy_count_s == 0 || MathAbs(Ask - buy_nearest_price_s) > gap_s * ma_hl);

    if (should_buy && OrderSend(symbol, OP_BUY, lots, Ask, 2, 0, 0, "s", magic_s, 0) > 0) return;

    should_sell  = Bid > ma_m0
                && ((sell_pl_f > _d && buy_pl_f < 0) || (sell_pl_c > _d || buy_pl_c < 0))
                && (sell_count_s == 0 || MathAbs(sell_nearest_price_s - Bid) > gap_s * ma_hl);

    if (should_sell && OrderSend(symbol, OP_SELL, lots, Bid, 2, 0, 0, "s", magic_s, 0) > 0) return;
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
