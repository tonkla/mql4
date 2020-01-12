#property copyright "TRADEiS"
#property link      "https://tradeis.one"
#property version   "1.0"
#property strict

input string secret = "";// Secret spell to summon the EA
input int magic     = 0; // ID of the EA
input double lots   = 0; // Initial lots
input double inc    = 0; // Increased lots from the initial one (Martingale-like)
input int tf        = 0; // Timeframe (60=H1, 1440=D1)
input int period    = 0; // Period
input int max_ords  = 0; // Max orders per side
input int gap       = 0; // Gap between orders (%H-L)
input int sleep     = 0; // Seconds to sleep since loss
input bool force_sl = 0; // Force stop loss when trend changed
input int sl        = 0; // Auto stop loss (%H-L)
input int tp        = 0; // Auto take profit (%H-L)
input double sl_acc = 0; // Acceptable total loss (%AccountBalance)
input double tp_acc = 0; // Acceptable total profit (%AccountBalance)

int buy_tickets[], sell_tickets[];
double buy_nearest_price, sell_nearest_price, pl;
double ma_h0, ma_l0, ma_m0, ma_m1, ma_h_l;
datetime buy_closed_time, sell_closed_time, candle_time;


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
  pl = 0;

  for (int i = OrdersTotal() - 1; i >= 0; i--) {
    if (!OrderSelect(i, SELECT_BY_POS)) continue;
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != magic) continue;
    switch (OrderType()) {
      case OP_BUY:
        size = ArraySize(buy_tickets);
        ArrayResize(buy_tickets, size + 1);
        buy_tickets[size] = OrderTicket();
        if (buy_nearest_price == 0 || MathAbs(OrderOpenPrice() - Ask) < MathAbs(buy_nearest_price - Ask)) {
          buy_nearest_price = OrderOpenPrice();
        }
        break;
      case OP_SELL:
        size = ArraySize(sell_tickets);
        ArrayResize(sell_tickets, size + 1);
        sell_tickets[size] = OrderTicket();
        if (sell_nearest_price == 0 || MathAbs(OrderOpenPrice() - Bid) < MathAbs(sell_nearest_price - Bid)) {
          sell_nearest_price = OrderOpenPrice();
        }
        break;
    }
    pl += OrderProfit() + OrderCommission() + OrderSwap();
  }
}

void get_vars() {
  ma_h0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_HIGH, 0);
  ma_l0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_LOW, 0);
  ma_m0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 0);
  ma_m1 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 1);
  ma_h_l = ma_h0 - ma_l0;
}

void close() {
  if ((sl_acc > 0 && pl < 0 && MathAbs(pl) / AccountBalance() * 100 > sl_acc) ||
      (tp_acc > 0 && pl / AccountBalance() * 100 > tp_acc)) {
    close_buy_orders();
    close_sell_orders();
  }

  if (force_sl) {
    if (ma_m0 < ma_m1 && ArraySize(buy_tickets) > 0) close_buy_orders();
    if (ma_m0 > ma_m1 && ArraySize(sell_tickets) > 0) close_sell_orders();
  }

  if (sl > 0) {
    double _sl = sl * ma_h_l / 100;
    for (int i = 0; i < ArraySize(buy_tickets); i++) {
      if (!OrderSelect(buy_tickets[i], SELECT_BY_TICKET)) continue;
      if (OrderProfit() < 0 && OrderOpenPrice() - Bid > _sl
          && OrderClose(OrderTicket(), OrderLots(), Bid, 3))
        buy_closed_time = TimeCurrent();
    }
    for (int i = 0; i < ArraySize(sell_tickets); i++) {
      if (!OrderSelect(sell_tickets[i], SELECT_BY_TICKET)) continue;
      if (OrderProfit() < 0 && Ask - OrderOpenPrice() > _sl
          && OrderClose(OrderTicket(), OrderLots(), Ask, 3))
        sell_closed_time = TimeCurrent();
    }
  }

  if (tp > 0) {
    double _tp = tp * ma_h_l / 100;
    for (int i = 0; i < ArraySize(buy_tickets); i++) {
      if (!OrderSelect(buy_tickets[i], SELECT_BY_TICKET)) continue;
      if (Bid - OrderOpenPrice() > _tp
          && OrderClose(OrderTicket(), OrderLots(), Bid, 3)) continue;
    }
    for (int i = 0; i < ArraySize(sell_tickets); i++) {
      if (!OrderSelect(sell_tickets[i], SELECT_BY_TICKET)) continue;
      if (OrderOpenPrice() - Ask > _tp
          && OrderClose(OrderTicket(), OrderLots(), Ask, 3)) continue;
    }
  }
}

void close_buy_orders() {
  for (int i = 0; i < ArraySize(buy_tickets); i++) {
    if (!OrderSelect(buy_tickets[i], SELECT_BY_TICKET)) continue;
    if (OrderClose(OrderTicket(), OrderLots(), Bid, 3)) buy_closed_time = TimeCurrent();
  }
}

void close_sell_orders() {
  for (int i = 0; i < ArraySize(sell_tickets); i++) {
    if (!OrderSelect(sell_tickets[i], SELECT_BY_TICKET)) continue;
    if (OrderClose(OrderTicket(), OrderLots(), Ask, 3)) sell_closed_time = TimeCurrent();
  }
}

void open() {
  bool should_buy  = ma_m0 > ma_m1 // Uptrend, higher high-low
                  && ((ArraySize(buy_tickets) == 0
                        && iTime(Symbol(), tf, 0) != candle_time) ||
                      (ArraySize(buy_tickets) > 0
                        && buy_nearest_price - Ask > gap * ma_h_l / 100)) // Order gap, buy lower
                  && TimeCurrent() - buy_closed_time > sleep // Take a break after loss
                  && ArraySize(buy_tickets) < max_ords; // Not more than allowed max orders

  bool should_sell = ma_m0 < ma_m1 // Downtrend, lower high-low
                  && ((ArraySize(sell_tickets) == 0
                        && iTime(Symbol(), tf, 0) != candle_time) ||
                      (ArraySize(sell_tickets) > 0
                        && Bid - sell_nearest_price > gap * ma_h_l / 100)) // Order gap, sell higher
                  && TimeCurrent() - sell_closed_time > sleep // Take a break after loss
                  && ArraySize(sell_tickets) < max_ords; // Not more than allowed max orders

  if (should_buy) {
    double _lots = inc == 0
                    ? lots
                    : ArraySize(buy_tickets) == 0
                      ? lots
                      : Ask > buy_nearest_price
                        ? lots
                        : NormalizeDouble(ArraySize(buy_tickets) * inc + lots, 2);
    if (0 < OrderSend(Symbol(), OP_BUY, _lots, Ask, 3, 0, 0, NULL, magic, 0)) {
      if (ArraySize(buy_tickets) == 0) candle_time = iTime(Symbol(), tf, 0);
    }
  }

  if (should_sell) {
    double _lots = inc == 0
                    ? lots
                    : ArraySize(sell_tickets) == 0
                      ? lots
                      : Bid < sell_nearest_price
                        ? lots
                        : NormalizeDouble(ArraySize(sell_tickets) * inc + lots, 2);
    if (0 < OrderSend(Symbol(), OP_SELL, _lots, Bid, 3, 0, 0, NULL, magic, 0)) {
      if (ArraySize(sell_tickets) == 0) candle_time = iTime(Symbol(), tf, 0);
    }
  }
}
