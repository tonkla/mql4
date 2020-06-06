#property copyright "TRADEiS"
#property link      "https://stradeji.com"
#property version   "1.0"
#property strict

input string secret     = "";// Secret spell to summon the EA
input int max_spread    = 0; // Maximum allowed spread
input int magic_f       = 0; // ID of trend following strategy (F)
input int magic_c       = 0; // ID of trend countering strategy (S)
input int magic_s       = 0; // ID of trend scalping strategy (C)
input double lots_f     = 0; // Lots (F)
input double lots_c     = 0; // Lots (C)
input double lots_s     = 0; // Lots (S)
input int tf            = 0; // Timeframe
input int period        = 0; // Period
input int max_orders_f  = 0; // Maximum allowed orders (F)
input int max_orders_c  = 0; // Maximum allowed orders (C)
input int max_orders_s  = 0; // Maximum allowed orders (S)
input double gap_bwd_f  = 0; // Backward gap between orders in %ATR (F)
input double gap_fwd_f  = 0; // Forward gap between orders in %ATR (F)
input double gap_bwd_c  = 0; // Backward gap between orders in %ATR (C)
input double gap_fwd_c  = 0; // Forward gap between orders in %ATR (C)
input double slx_f      = 0; // Stop loss by total in %ATR (F)
input double tpx_f      = 0; // Take profit by total in %ATR (F)
input double slx_c      = 0; // Stop loss by total in %ATR (C)
input double tpx_c      = 0; // Take profit by total in %ATR (C)
input int start_gmt     = -1;// Starting hour in GMT
input int stop_gmt      = -1;// Stopping hour in GMT
input int friday_gmt    = -1;// Close all on Friday hour in GMT

bool start=false;
datetime buy_closed_time_f, sell_closed_time_f;
datetime buy_closed_time_c, sell_closed_time_c;

int OnInit() {
  return secret == "https://stradeji.com" ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick() {
  // Prevent abnormal spread
  if (MarketInfo(Symbol(), MODE_SPREAD) > max_spread) return;

  if (magic_f > 0) run_following();
  if (magic_c > 0) run_countering();
  if (magic_s > 0) run_scalping();
}

void run_following() {
  int buy_tickets_f[], sell_tickets_f[], buy_count_f=0, sell_count_f=0;
  double buy_nearest_price_f=0, sell_nearest_price_f=0;
  double buy_pl_f=0, sell_pl_f=0;

  int size;
  for (int i = OrdersTotal() - 1; i >= 0; i--) {
    if (!OrderSelect(i, SELECT_BY_POS)) continue;
    if (OrderSymbol() != Symbol() || OrderMagicNumber() == 0 || OrderMagicNumber() != magic_f) continue;
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
  }
  buy_count_f = ArraySize(buy_tickets_f);
  sell_count_f = ArraySize(sell_tickets_f);

  double ma_h0, ma_l0, ma_m0, ma_m1, ma_hl;

  ma_h0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_HIGH, 0);
  ma_l0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_LOW, 0);
  ma_m0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 0);
  ma_m1 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 1);
  ma_hl = ma_h0 - ma_l0;

  // Close --------------------------------------------------------------------

  if (stop_gmt >= 0 && TimeHour(TimeGMT()) >= stop_gmt) {
    close_buy_orders(buy_tickets_f);
    close_sell_orders(sell_tickets_f);
    start = false;
    return;
  }
  if (friday_gmt > 0 && TimeHour(TimeGMT()) >= friday_gmt && DayOfWeek() == 5) {
    close_buy_orders(buy_tickets_f);
    close_sell_orders(sell_tickets_f);
    return;
  }

  // Stop Loss ------------------------

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

  // Take Profit ----------------------

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

  // Open ---------------------------------------------------------------------

  if (start_gmt >= 0 && !start) {
    if (TimeHour(TimeGMT()) < start_gmt || TimeHour(TimeGMT()) >= stop_gmt) return;
    start = true;
  }
  if (friday_gmt > 0 && TimeHour(TimeGMT()) >= friday_gmt && DayOfWeek() == 5) return;

  bool should_buy=false, should_sell=false;

  double _gap_bwd = gap_bwd_f * ma_hl;
  double _gap_fwd = gap_fwd_f * ma_hl;

  should_buy   = ma_m1 < ma_m0
              && buy_count_f < max_orders_f
              && TimeCurrent() - buy_closed_time_f > 300
              && (buy_count_f == 0
                  ? Ask < ma_m0
                  : Ask - buy_nearest_price_f > _gap_fwd || buy_nearest_price_f - Ask > _gap_bwd);

  if (should_buy && OrderSend(Symbol(), OP_BUY, lots_f, Ask, 2, 0, 0, "f", magic_f, 0) > 0) return;

  should_sell  = ma_m1 > ma_m0
              && sell_count_f < max_orders_f
              && TimeCurrent() - sell_closed_time_f > 300
              && (sell_count_f == 0
                  ? Bid > ma_m0
                  : sell_nearest_price_f - Bid > _gap_fwd || Bid - sell_nearest_price_f > _gap_bwd);

  if (should_sell && OrderSend(Symbol(), OP_SELL, lots_f, Bid, 2, 0, 0, "f", magic_f, 0) > 0) return;
}

void run_countering() {
  int buy_tickets_c[], sell_tickets_c[], buy_count_c=0, sell_count_c=0;
  double buy_nearest_price_c=0, sell_nearest_price_c=0;
  double buy_pl_c=0, sell_pl_c=0;

  int size;
  for (int i = OrdersTotal() - 1; i >= 0; i--) {
    if (!OrderSelect(i, SELECT_BY_POS)) continue;
    if (OrderSymbol() != Symbol() || OrderMagicNumber() == 0 || OrderMagicNumber() != magic_c) continue;
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
  }
  buy_count_c = ArraySize(buy_tickets_c);
  sell_count_c = ArraySize(sell_tickets_c);

  // Close --------------------------------------------------------------------

  if (stop_gmt >= 0 && TimeHour(TimeGMT()) >= stop_gmt) {
    close_buy_orders(buy_tickets_c);
    close_sell_orders(sell_tickets_c);
    start = false;
    return;
  }
  if (friday_gmt > 0 && TimeHour(TimeGMT()) >= friday_gmt && DayOfWeek() == 5) {
    close_buy_orders(buy_tickets_c);
    close_sell_orders(sell_tickets_c);
    return;
  }

  // Stop Loss ------------------------

  if (buy_pl_c < 0 && MathAbs(buy_pl_c) > slx_c * ma_hl) {
    for (int i = 0; i < buy_count_c; i++) {
      if (!OrderSelect(buy_tickets_c[i], SELECT_BY_TICKET)) continue;
      if (OrderClose(OrderTicket(), OrderLots(), Bid, 2)) buy_closed_time_c = TimeCurrent();
    }
  }
  if (sell_pl_c < 0 && MathAbs(sell_pl_c) > slx_c * ma_hl) {
    for (int i = 0; i < sell_count_c; i++) {
      if (!OrderSelect(sell_tickets_c[i], SELECT_BY_TICKET)) continue;
      if (OrderClose(OrderTicket(), OrderLots(), Ask, 2)) sell_closed_time_c = TimeCurrent();
    }
  }

  // Take Profit ----------------------

  if (buy_pl_c > 0 && Bid > ma_h0) {
    for (int i = 0; i < buy_count_c; i++) {
      if (!OrderSelect(buy_tickets_c[i], SELECT_BY_TICKET)) continue;
      if (OrderClose(OrderTicket(), OrderLots(), Bid, 2)) buy_closed_time_c = TimeCurrent();
    }
  }
  if (sell_pl_c > 0 && Ask < ma_l0) {
    for (int i = 0; i < sell_count_c; i++) {
      if (!OrderSelect(sell_tickets_c[i], SELECT_BY_TICKET)) continue;
      if (OrderClose(OrderTicket(), OrderLots(), Ask, 2)) sell_closed_time_c = TimeCurrent();
    }
  }

  // Open ---------------------------------------------------------------------

  if (start_gmt >= 0 && !start) {
    if (TimeHour(TimeGMT()) < start_gmt || TimeHour(TimeGMT()) >= stop_gmt) return;
    start = true;
  }
  if (friday_gmt > 0 && TimeHour(TimeGMT()) >= friday_gmt && DayOfWeek() == 5) return;

  bool should_buy=false, should_sell=false;

  double _gap_bwd = gap_bwd_c * ma_hl;
  double _gap_fwd = gap_fwd_c * ma_hl;

  should_buy   = Ask < ma_m0 - (0.25 * ma_hl)
              && buy_count_c < max_orders_c
              && TimeCurrent() - buy_closed_time_c > 300
              && (buy_count_c == 0 ||
                  buy_nearest_price_c - Ask > _gap_bwd || Ask - buy_nearest_price_c > _gap_fwd);

  if (should_buy && OrderSend(Symbol(), OP_BUY, lots_c, Ask, 2, 0, 0, "c", magic_c, 0) > 0) return;

  should_sell  = Bid > ma_m0 + (0.25 * ma_hl)
              && sell_count_c < max_orders_c
              && TimeCurrent() - sell_closed_time_c > 300
              && (sell_count_c == 0 ||
                  Bid - sell_nearest_price_c > _gap_bwd || sell_nearest_price_c - Bid > _gap_fwd);

  if (should_sell && OrderSend(Symbol(), OP_SELL, lots_c, Bid, 2, 0, 0, "c", magic_c, 0) > 0) return;
}

void run_scalping() {
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
