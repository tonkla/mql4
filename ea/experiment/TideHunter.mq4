#property copyright "TRADEiS"
#property link      "https://tradeis.one"
#property version   "1.0"
#property strict

input string secret   = "";// Secret spell to summon the EA
input int magic_c     = 0; // ID of trend countering strategy
input int magic_f     = 0; // ID of trend following strategy
input double lots     = 0; // Initial lots
input int start_gmt   = -1;// Starting hour in GMT
input int stop_gmt    = -1;// Stopping hour in GMT
input int friday_gmt  = -1;// Close all on Friday hour in GMT

int tf = 0, period = 0, max_spread = 0;
double gap_sta = 0, gap_bwd = 0, gap_fwd = 0, tp = 0;
bool start = false, sl = false;

int OnInit() {
  return secret == "https://tradeis.one" ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick() {
  // Prevent abnormal spread
  if (MarketInfo(Symbol(), MODE_SPREAD) > max_spread) return;

  int buy_tickets_c[], sell_tickets_c[], buy_count_c, sell_count_c,
      buy_tickets_f[], sell_tickets_f[], buy_count_f, sell_count_f,
      size;
  double buy_nearest_price_c = 0, sell_nearest_price_c = 0,
         buy_nearest_price_f = 0, sell_nearest_price_f = 0;

  // Counter
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
        break;
      case OP_SELL:
        size = ArraySize(sell_tickets_c);
        ArrayResize(sell_tickets_c, size + 1);
        sell_tickets_c[size] = OrderTicket();
        if (sell_nearest_price_c == 0 || MathAbs(OrderOpenPrice() - Bid) < MathAbs(sell_nearest_price_c - Bid)) {
          sell_nearest_price_c = OrderOpenPrice();
        }
        break;
    }
  }
  buy_count_c = ArraySize(buy_tickets_c);
  sell_count_c = ArraySize(sell_tickets_c);

  // Follow
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
        break;
      case OP_SELL:
        size = ArraySize(sell_tickets_f);
        ArrayResize(sell_tickets_f, size + 1);
        sell_tickets_f[size] = OrderTicket();
        if (sell_nearest_price_f == 0 || MathAbs(OrderOpenPrice() - Bid) < MathAbs(sell_nearest_price_f - Bid)) {
          sell_nearest_price_f = OrderOpenPrice();
        }
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
    close_buy_orders(buy_tickets_c);
    close_buy_orders(buy_tickets_f);
    close_sell_orders(sell_tickets_c);
    close_sell_orders(sell_tickets_f);
    start = false;
    return;
  }
  if (friday_gmt > 0 && TimeHour(TimeGMT()) >= friday_gmt && DayOfWeek() == 5) {
    close_buy_orders(buy_tickets_c);
    close_buy_orders(buy_tickets_f);
    close_sell_orders(sell_tickets_c);
    close_sell_orders(sell_tickets_f);
    return;
  }

  // Stop Loss ------------------------
  if (sl) {
    double _ma_h0 = iMA(Symbol(), PERIOD_D1, period, 0, MODE_LWMA, PRICE_HIGH, 0);
    double _ma_l0 = iMA(Symbol(), PERIOD_D1, period, 0, MODE_LWMA, PRICE_LOW, 0);
    for (int i = 0; i < buy_count_c; i++) {
      if (!OrderSelect(buy_tickets_c[i], SELECT_BY_TICKET)) continue;
      if (OrderOpenPrice() > _ma_h0 && OrderClose(OrderTicket(), OrderLots(), Bid, 3)) continue;
    }
    for (int j = 0; j < sell_count_f; j++) {
      if (!OrderSelect(sell_tickets_f[j], SELECT_BY_TICKET)) continue;
      if (OrderOpenPrice() > _ma_h0 && OrderClose(OrderTicket(), OrderLots(), Ask, 3)) continue;
    }
    for (int i = 0; i < sell_count_c; i++) {
      if (!OrderSelect(sell_tickets_c[i], SELECT_BY_TICKET)) continue;
      if (OrderOpenPrice() < _ma_l0 && OrderClose(OrderTicket(), OrderLots(), Ask, 3)) continue;
    }
    for (int j = 0; j < buy_count_f; j++) {
      if (!OrderSelect(buy_tickets_f[j], SELECT_BY_TICKET)) continue;
      if (OrderOpenPrice() < _ma_l0 && OrderClose(OrderTicket(), OrderLots(), Bid, 3)) continue;
    }
  }

  // Take Profit ----------------------
  double _tp = tp * ma_hl;
  for (int i = 0; i < buy_count_c; i++) {
    if (!OrderSelect(buy_tickets_c[i], SELECT_BY_TICKET)) continue;
    if (Bid - OrderOpenPrice() > _tp && OrderClose(OrderTicket(), OrderLots(), Bid, 3)) continue;
  }
  for (int i = 0; i < sell_count_c; i++) {
    if (!OrderSelect(sell_tickets_c[i], SELECT_BY_TICKET)) continue;
    if (OrderOpenPrice() - Ask > _tp && OrderClose(OrderTicket(), OrderLots(), Ask, 3)) continue;
  }

  // Open ---------------------------------------------------------------------
  if (start_gmt >= 0 && !start) {
    if (TimeHour(TimeGMT()) >= start_gmt && TimeHour(TimeGMT()) < stop_gmt) start = true;
    else return;
  }
  if (friday_gmt > 0 && TimeHour(TimeGMT()) >= friday_gmt && DayOfWeek() == 5) return;

  double _gap_sta = gap_sta * ma_hl;
  double _gap_bwd = gap_bwd * ma_hl;
  double _gap_fwd = gap_fwd * ma_hl;

  bool should_buy = false, should_sell = false;

  should_buy  = Ask < ma_m0 - _gap_sta
             && (buy_count_c == 0 ||
                 buy_nearest_price_c - Ask > _gap_bwd || Ask - buy_nearest_price_c > _gap_fwd);

  should_sell = Bid > ma_m0 + _gap_sta
             && (sell_count_c == 0 ||
                 Bid - sell_nearest_price_c > _gap_bwd || sell_nearest_price_c - Bid > _gap_fwd);

  if (should_buy && 0 < OrderSend(Symbol(), OP_BUY, lots, Ask, 3, 0, 0, "c", magic_c, 0)) {}
  if (should_sell && 0 < OrderSend(Symbol(), OP_SELL, lots, Bid, 3, 0, 0, "c", magic_c, 0)) {}

  should_buy  = ma_m0 > ma_m1 && Ask < ma_m0 + (0.5 * ma_hl)
             && (buy_count_f == 0 ||
                 buy_nearest_price_f - Ask > _gap_bwd || Ask - buy_nearest_price_f > _gap_fwd)
             && (buy_count_c == 0 ||
                 buy_nearest_price_c - Ask > _gap_bwd || Ask - buy_nearest_price_c > _gap_fwd);

  should_sell = ma_m0 < ma_m1 && Bid > ma_m0 - (0.5 * ma_hl)
             && (sell_count_f == 0 ||
                 Bid - sell_nearest_price_f > _gap_bwd || sell_nearest_price_f - Bid > _gap_fwd)
             && (sell_count_c == 0 ||
                 Bid - sell_nearest_price_c > _gap_bwd || sell_nearest_price_c - Bid > _gap_fwd);

  if (should_buy && 0 < OrderSend(Symbol(), OP_BUY, lots, Ask, 3, 0, 0, "f", magic_f, 0)) {}
  if (should_sell && 0 < OrderSend(Symbol(), OP_SELL, lots, Bid, 3, 0, 0, "f", magic_f, 0)) {}
}

void close_buy_orders(int &buy_tickets[]) {
  for (int i = 0; i < ArraySize(buy_tickets); i++) {
    if (!OrderSelect(buy_tickets[i], SELECT_BY_TICKET)) continue;
    if (OrderClose(OrderTicket(), OrderLots(), Bid, 3)) continue;
  }
}

void close_sell_orders(int &sell_tickets[]) {
  for (int i = 0; i < ArraySize(sell_tickets); i++) {
    if (!OrderSelect(sell_tickets[i], SELECT_BY_TICKET)) continue;
    if (OrderClose(OrderTicket(), OrderLots(), Ask, 3)) continue;
  }
}
