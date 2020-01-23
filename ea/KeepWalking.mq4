#property copyright "TRADEiS"
#property link      "https://tradeis.one"
#property version   "1.0"
#property strict

input string secret = "";// Secret spell to summon the EA
input int magic     = 0; // ID of the EA
input double lots   = 0; // Initial lots
input double inc    = 0; // Increased lots from the initial one (Martingale-like)
input int start_gmt = 0; // GMT hour to start
input int orders    = 0; // Limited orders per side
input int gap       = 0; // Gap between orders (%ATR)
input double tp     = 0; // Take profit in $Currency
input bool sl       = 0; // Stop the old opposite one
input bool friday   = 0; // Close all on late Friday

int buy_tickets[], sell_tickets[], buy_count, sell_count;
double buy_nearest_price, sell_nearest_price, buy_pl, sell_pl;
datetime buy_closed_time, sell_closed_time;
bool start;


int OnInit() {
  return secret == "https://tradeis.one" ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick() {
  get_orders();
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
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != magic) continue;
    switch (OrderType()) {
      case OP_BUY:
        size = ArraySize(buy_tickets);
        ArrayResize(buy_tickets, size + 1);
        buy_tickets[size] = OrderTicket();
        if (buy_nearest_price == 0 || MathAbs(OrderOpenPrice() - Ask) < MathAbs(buy_nearest_price - Ask)) {
          buy_nearest_price = OrderOpenPrice();
        }
        buy_pl += OrderProfit() + OrderCommission() + OrderSwap();
        break;
      case OP_SELL:
        size = ArraySize(sell_tickets);
        ArrayResize(sell_tickets, size + 1);
        sell_tickets[size] = OrderTicket();
        if (sell_nearest_price == 0 || MathAbs(OrderOpenPrice() - Bid) < MathAbs(sell_nearest_price - Bid)) {
          sell_nearest_price = OrderOpenPrice();
        }
        sell_pl += OrderProfit() + OrderCommission() + OrderSwap();
        break;
    }
  }

  buy_count = ArraySize(buy_tickets);
  sell_count = ArraySize(sell_tickets);
}

void close() {
  if (friday && TimeHour(TimeGMT()) >= 21 && DayOfWeek() == 5) {
    if (buy_count > 0) {
      close_buy_orders();
      start = false;
    }
    if (sell_count > 0) {
      close_sell_orders();
      start = false;
    }
    return;
  }

  if (sl && buy_count > 0 && sell_count > 0) {
    if (buy_pl < 0 && sell_pl > 0) close_buy_orders();
    if (buy_pl > 0 && sell_pl < 0) close_sell_orders();
  }

  if (tp > 0 && buy_pl + sell_pl > tp) {
    if (buy_count > 0) {
      close_buy_orders();
      start = false;
    }
    if (sell_count > 0) {
      close_sell_orders();
      start = false;
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
  if (!start) { // Start on 0:00 GMT
    if (TimeHour(TimeGMT()) == start_gmt) start = true;
    else return;
  }

  double atr = iATR(Symbol(), PERIOD_D1, 3, 0);

  bool should_buy  = Ask > iOpen(Symbol(), PERIOD_D1, 0) + (0.05 * atr)
                  && TimeCurrent() - buy_closed_time > 1800
                  && (buy_count == 0 || Ask - buy_nearest_price > gap * atr / 100)
                  && buy_count < orders;

  bool should_sell = Bid < iOpen(Symbol(), PERIOD_D1, 0) - (0.05 * atr)
                  && TimeCurrent() - sell_closed_time > 1800
                  && (sell_count == 0 || sell_nearest_price - Bid > gap * atr / 100)
                  && sell_count < orders;

  if (should_buy) {
    double _lots = buy_count == 0 ? lots : NormalizeDouble(buy_count * inc + lots, 2);
    if (0 < OrderSend(Symbol(), OP_BUY, _lots, Ask, 3, 0, 0, NULL, magic, 0)) return;
  }

  if (should_sell) {
    double _lots = sell_count == 0 ? lots : NormalizeDouble(sell_count * inc + lots, 2);
    if (0 < OrderSend(Symbol(), OP_SELL, _lots, Bid, 3, 0, 0, NULL, magic, 0)) return;
  }
}
