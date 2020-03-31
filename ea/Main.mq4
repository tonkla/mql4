#property copyright "TRADEiS"
#property link      "https://tradeis.one"
#property version   "1.5"
#property strict

input string secret   = "";// Secret spell to summon the EA
input int magic_1     = 0; // ID-1 (strategy: follow trend)
input double lots     = 0; // Initial lots
input double inc      = 0; // Increased lots from the initial one
input int max_orders  = 0; // Maximum orders in dangerous zone
input int tf          = 0; // Main timeframe
input int period      = 0; // Period for main timeframe
input int tf_2        = 0; // Fast timeframe
input int period_2    = 0; // Period for fast timeframe
input int min_hl      = 0; // Minimum range away from H/L in %ATR
input int min_prev    = 0; // Minimum back percent of previous H-L
input int min_slope   = 0; // Minimum slope percent to be trend
input int gap_bwd     = 0; // Backward gap between orders in %ATR
input int gap_fwd     = 0; // Forward gap between orders in %ATR
input int sleep       = 0; // Seconds to sleep since the order is closed
input int sl_time     = 0; // Seconds to close since the order is open
input int sl          = 0; // Single stop loss in %ATR
input int tp          = 0; // Single take profit in %ATR
input int sl_sum      = 0; // Total stop loss in %ATR
input int tp_sum      = 0; // Total take profit in %ATR
input int sl_near     = 0; // Stop loss in %ATR from the nearest order
input int tp_near     = 0; // Take profit in %ATR from the nearest order
input bool sl_trend   = 0; // Stop loss when the trend changed
input bool sl_oppo    = 0; // Stop loss when the opposite was opened
input bool sl_hl      = 0; // Stop loss when the order exceeds H/L
input int start_gmt   = -1;// Starting hour in GMT
input int stop_gmt    = -1;// Stopping hour in GMT
input int friday_gmt  = -1;// Close all on Friday hour in GMT

int buy_tickets[], sell_tickets[], buy_count, sell_count;
double buy_nearest_price, sell_nearest_price, buy_pl, sell_pl;
double ma_h0, ma_l0, ma_m0, ma_m1, m0, m1, ma_hl, slope, h0, l0, h1, l1, h2, l2;
datetime buy_closed_time, sell_closed_time;
bool start;


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
  int size = 0;
  ArrayFree(buy_tickets);
  ArrayFree(sell_tickets);
  buy_nearest_price = 0;
  sell_nearest_price = 0;
  buy_pl = 0;
  sell_pl = 0;

  for (int i = OrdersTotal() - 1; i >= 0; i--) {
    if (!OrderSelect(i, SELECT_BY_POS)) continue;
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != magic_1) continue;
    switch (OrderType()) {
      case OP_BUY:
        size = ArraySize(buy_tickets);
        ArrayResize(buy_tickets, size + 1);
        buy_tickets[size] = OrderTicket();
        if (buy_nearest_price == 0 || MathAbs(OrderOpenPrice() - Ask) < MathAbs(buy_nearest_price - Ask)) {
          buy_nearest_price = OrderOpenPrice();
        }
        buy_pl += Bid - OrderOpenPrice();
        break;
      case OP_SELL:
        size = ArraySize(sell_tickets);
        ArrayResize(sell_tickets, size + 1);
        sell_tickets[size] = OrderTicket();
        if (sell_nearest_price == 0 || MathAbs(OrderOpenPrice() - Bid) < MathAbs(sell_nearest_price - Bid)) {
          sell_nearest_price = OrderOpenPrice();
        }
        sell_pl += OrderOpenPrice() - Ask;
        break;
    }
  }

  buy_count = ArraySize(buy_tickets);
  sell_count = ArraySize(sell_tickets);
}

void get_vars() {
  ma_h0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_HIGH, 0);
  ma_l0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_LOW, 0);
  ma_m0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 0);
  ma_m1 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 1);
  ma_hl = ma_h0 - ma_l0;
  slope = MathAbs(ma_m0 - ma_m1) / ma_hl * 100;
  m0 = iMA(Symbol(), tf_2, period_2, 0, MODE_LWMA, PRICE_MEDIAN, 0);
  m1 = iMA(Symbol(), tf_2, period_2, 0, MODE_LWMA, PRICE_MEDIAN, 1);
  h0 = iHigh(Symbol(), tf, 0);
  l0 = iLow(Symbol(), tf, 0);
  h1 = iHigh(Symbol(), tf, 1);
  l1 = iLow(Symbol(), tf, 1);
  h2 = iHigh(Symbol(), tf, 2);
  l2 = iLow(Symbol(), tf, 2);
}

void close() {
  if (stop_gmt >= 0 && TimeHour(TimeGMT()) >= stop_gmt) {
    if (buy_count > 0) close_buy_orders();
    if (sell_count > 0) close_sell_orders();
    start = false;
    return;
  }

  if (friday_gmt > 0 && TimeHour(TimeGMT()) >= friday_gmt && DayOfWeek() == 5) {
    if (buy_count > 0) close_buy_orders();
    if (sell_count > 0) close_sell_orders();
    return;
  }

  if (sl_trend) {
    if (buy_count > 0 && (ma_m0 < ma_m1 || Bid < l2)) close_buy_orders();
    if (sell_count > 0 && (ma_m0 > ma_m1 || Ask > h2)) close_sell_orders();
  }

  if (sl_oppo && buy_count > 0 && sell_count > 0) {
    double _sl = 0.05 * ma_hl;
    if (buy_pl < 0 && sell_pl > _sl) close_buy_orders();
    if (sell_pl < 0 && buy_pl > _sl) close_sell_orders();
  }

  if (sl_hl) {
    for (int i = 0; i < buy_count; i++) {
      if (!OrderSelect(buy_tickets[i], SELECT_BY_TICKET)) continue;
      if (OrderOpenPrice() > ma_h0
          && OrderClose(OrderTicket(), OrderLots(), Bid, 3))
        buy_closed_time = TimeCurrent();
    }
    for (int i = 0; i < sell_count; i++) {
      if (!OrderSelect(sell_tickets[i], SELECT_BY_TICKET)) continue;
      if (OrderOpenPrice() < ma_l0
          && OrderClose(OrderTicket(), OrderLots(), Ask, 3))
        sell_closed_time = TimeCurrent();
    }
  }

  if (sl_time > 0) {
    for (int i = 0; i < buy_count; i++) {
      if (!OrderSelect(buy_tickets[i], SELECT_BY_TICKET)) continue;
      if (TimeCurrent() - OrderOpenTime() > sl_time
          && OrderClose(OrderTicket(), OrderLots(), Bid, 3)) continue;
    }
    for (int i = 0; i < sell_count; i++) {
      if (!OrderSelect(sell_tickets[i], SELECT_BY_TICKET)) continue;
      if (TimeCurrent() - OrderOpenTime() > sl_time
          && OrderClose(OrderTicket(), OrderLots(), Ask, 3)) continue;
    }
  }

  if (sl > 0) {
    double _sl = sl * ma_hl / 100;
    for (int i = 0; i < buy_count; i++) {
      if (!OrderSelect(buy_tickets[i], SELECT_BY_TICKET)) continue;
      if (OrderProfit() < 0 && OrderOpenPrice() - Bid > _sl
          && OrderClose(OrderTicket(), OrderLots(), Bid, 3))
        buy_closed_time = TimeCurrent();
    }
    for (int i = 0; i < sell_count; i++) {
      if (!OrderSelect(sell_tickets[i], SELECT_BY_TICKET)) continue;
      if (OrderProfit() < 0 && Ask - OrderOpenPrice() > _sl
          && OrderClose(OrderTicket(), OrderLots(), Ask, 3))
        sell_closed_time = TimeCurrent();
    }
  }

  if (tp > 0) {
    double _tp = tp * ma_hl / 100;
    for (int i = 0; i < buy_count; i++) {
      if (!OrderSelect(buy_tickets[i], SELECT_BY_TICKET)) continue;
      if (Bid - OrderOpenPrice() > _tp
          && OrderClose(OrderTicket(), OrderLots(), Bid, 3)) continue;
    }
    for (int i = 0; i < sell_count; i++) {
      if (!OrderSelect(sell_tickets[i], SELECT_BY_TICKET)) continue;
      if (OrderOpenPrice() - Ask > _tp
          && OrderClose(OrderTicket(), OrderLots(), Ask, 3)) continue;
    }
  }

  double pl = buy_pl + sell_pl;

  if (sl_sum > 0 && pl < 0 && MathAbs(pl) > sl_sum * ma_hl / 100) {
    if (buy_pl < 0) close_buy_orders();
    if (sell_pl < 0) close_sell_orders();
  }

  if (tp_sum > 0 && pl > tp_sum * ma_hl / 100) {
    if (buy_count > 0) close_buy_orders();
    if (sell_count > 0) close_sell_orders();
  }

  if (sl_near > 0 || tp_near > 0) {
    double buy_highest_price = 0;
    double buy_lowest_price = 0;
    double sell_highest_price = 0;
    double sell_lowest_price = 0;

    for (int i = 0; i < buy_count; i++) {
      if (!OrderSelect(buy_tickets[i], SELECT_BY_TICKET)) continue;
      if (buy_highest_price == 0 || OrderOpenPrice() > buy_highest_price) {
        buy_highest_price = OrderOpenPrice();
      }
      if (buy_lowest_price == 0 || OrderOpenPrice() < buy_lowest_price) {
        buy_lowest_price = OrderOpenPrice();
      }
    }

    for (int i = 0; i < sell_count; i++) {
      if (!OrderSelect(sell_tickets[i], SELECT_BY_TICKET)) continue;
      if (sell_highest_price == 0 || OrderOpenPrice() > sell_highest_price) {
        sell_highest_price = OrderOpenPrice();
      }
      if (sell_lowest_price == 0 || OrderOpenPrice() < sell_lowest_price) {
        sell_lowest_price = OrderOpenPrice();
      }
    }

    double _min_hl0 = min_hl * ma_hl / 100;

    if (sl_near > 0 && pl < 0) {
      double _sl = sl_near * ma_hl / 100;
      if (buy_pl < 0 && Bid < ma_l0 + _min_hl0 && buy_lowest_price - Bid > _sl)
        close_buy_orders();
      if (sell_pl < 0 && Ask > ma_h0 - _min_hl0 && Ask - sell_highest_price > _sl)
        close_sell_orders();
    }

    if (tp_near > 0 && pl > 0) {
      double _tp = tp_near * ma_hl / 100;
      if (buy_pl > 0 && Bid > ma_h0 - _min_hl0 && Bid - buy_highest_price > _tp)
        close_buy_orders();
      if (sell_pl > 0 && Ask < ma_l0 + _min_hl0 && sell_lowest_price - Ask > _tp)
        close_sell_orders();
    }
  }
}

void close_buy_orders() {
  for (int i = 0; i < buy_count; i++) {
    if (!OrderSelect(buy_tickets[i], SELECT_BY_TICKET)) continue;
    if (OrderClose(OrderTicket(), OrderLots(), Bid, 3)) buy_closed_time = TimeCurrent();
  }
}

void close_sell_orders() {
  for (int i = 0; i < sell_count; i++) {
    if (!OrderSelect(sell_tickets[i], SELECT_BY_TICKET)) continue;
    if (OrderClose(OrderTicket(), OrderLots(), Ask, 3)) sell_closed_time = TimeCurrent();
  }
}

void open() {
  if (start_gmt >= 0 && !start) {
    if (TimeHour(TimeGMT()) == start_gmt) start = true;
    else return;
  }
  if (friday_gmt > 0 && TimeHour(TimeGMT()) >= friday_gmt && DayOfWeek() == 5) return;

  int _magic = 0;
  bool should_buy = false, should_sell = false;

  double _gap_bwd = gap_bwd * ma_hl / 100;
  double _gap_fwd = gap_fwd * ma_hl / 100;

  // Strategy: follow trend
  if (magic_1 > 0 && slope > min_slope) {
    _magic = magic_1;

    double _min_hl0 = min_hl * ma_hl / 100;
    double _min_hl1 = min_prev * (h1 - l1) / 100;

    should_buy  = ma_m0 > ma_m1 && m0 > m1 && l0 > l2
               && (buy_count == 0
                    ? (Ask < ma_h0 - _min_hl0 && Ask < h1 - _min_hl1)
                    : (gap_bwd > 0 && buy_nearest_price - Ask > _gap_bwd) ||
                      (gap_fwd > 0 && Ask - buy_nearest_price > _gap_fwd))
               && (Ask > ma_h0 - _min_hl0 ? buy_count < max_orders : true)
               && TimeCurrent() - buy_closed_time > sleep;

    should_sell = ma_m0 < ma_m1 && m0 < m1 && h0 < h2
               && (sell_count == 0
                    ? (Bid > ma_l0 + _min_hl0 && Bid > l1 + _min_hl1)
                    : (gap_bwd > 0 && Bid - sell_nearest_price > _gap_bwd) ||
                      (gap_fwd > 0 && sell_nearest_price - Bid > _gap_fwd))
               && (Bid < ma_l0 + _min_hl0 ? sell_count < max_orders : true)
               && TimeCurrent() - sell_closed_time > sleep;
  }

  if (should_buy) {
    double _lots = inc == 0 ? lots
                    : buy_count == 0 ? lots
                      : Ask > buy_nearest_price ? lots
                        : NormalizeDouble(buy_count * inc + lots, 2);
    if (0 < OrderSend(Symbol(), OP_BUY, _lots, Ask, 3, 0, 0, NULL, _magic, 0)) return;
  }

  if (should_sell) {
    double _lots = inc == 0 ? lots
                    : sell_count == 0 ? lots
                      : Bid < sell_nearest_price ? lots
                        : NormalizeDouble(sell_count * inc + lots, 2);
    if (0 < OrderSend(Symbol(), OP_SELL, _lots, Bid, 3, 0, 0, NULL, _magic, 0)) return;
  }
}
