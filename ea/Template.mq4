#property copyright "TRADEiS"
#property link      "https://tradeis.one"
#property version   "1.0"
#property strict

input string secret = "";
input int magic     = 0;
input double lots   = 0;
input double inc    = 0;

int buy_tickets[];
int sell_tickets[];
int _int;

double buy_nearest_price;
double sell_nearest_price;


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
  int _size = 0;
  ArrayFree(buy_tickets);
  ArrayFree(sell_tickets);
  buy_nearest_price = 0;
  sell_nearest_price = 0;

  for (_int = OrdersTotal() - 1; _int >= 0; _int--) {
    if (!OrderSelect(_int, SELECT_BY_POS)) continue;
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != magic) continue;
    switch (OrderType()) {
      case OP_BUY:
        _size = ArraySize(buy_tickets);
        ArrayResize(buy_tickets, _size + 1);
        buy_tickets[_size] = OrderTicket();
        if (buy_nearest_price == 0 || MathAbs(OrderOpenPrice() - Ask) < MathAbs(buy_nearest_price - Ask)) {
          buy_nearest_price = OrderOpenPrice();
        }
        break;
      case OP_SELL:
        _size = ArraySize(sell_tickets);
        ArrayResize(sell_tickets, _size + 1);
        sell_tickets[_size] = OrderTicket();
        if (sell_nearest_price == 0 || MathAbs(OrderOpenPrice() - Bid) < MathAbs(sell_nearest_price - Bid)) {
          sell_nearest_price = OrderOpenPrice();
        }
        break;
    }
  }
}

void get_vars() {
}

void close() {
}

void open() {
  bool should_buy  = false;

  bool should_sell = false;

  if (should_buy) {
    double _lots = ArraySize(buy_tickets) == 0
                    ? lots
                    : Ask < buy_nearest_price
                      ? NormalizeDouble(ArraySize(buy_tickets) * inc + lots, 2)
                      : lots;
    _int = OrderSend(Symbol(), OP_BUY, _lots, Ask, 3, 0, 0, NULL, magic, 0);
  }
  else if (should_sell) {
    double _lots = ArraySize(sell_tickets) == 0
                    ? lots
                    : Bid > sell_nearest_price
                      ? NormalizeDouble(ArraySize(sell_tickets) * inc + lots, 2)
                      : lots;
    _int = OrderSend(Symbol(), OP_SELL, _lots, Bid, 3, 0, 0, NULL, magic, 0);
  }
}
