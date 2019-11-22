#property copyright "TRADEiS"
#property link      "https://tradeis.one"
#property version   "1.1"
#property strict

input string secret = "";
input int magic     = 0;
input double lots   = 0;
input double inc    = 0;
input int tf        = 0;
input int period    = 0;
input int maxord    = 0;
input int gap       = 0;
input int sl        = 0;
input int tp        = 0;
input double slsum  = 0;
input double tpsum  = 0;

int buy_tickets[];
int sell_tickets[];
int _int;
int _size;

double buy_nearest_price;
double sell_nearest_price;
double pl;
double ma_h0, ma_l0, ma_m0, ma_m1;


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
  ArrayFree(buy_tickets);
  ArrayFree(sell_tickets);
  buy_nearest_price = 0;
  sell_nearest_price = 0;
  pl = 0;

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
    pl += OrderProfit();
  }
}

void get_vars() {
  ma_h0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_HIGH, 0);
  ma_l0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_LOW, 0);
  ma_m0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 0);
  ma_m1 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 1);
}

void close() {
  if (sl > 0) {
    if (ma_m0 < ma_m1) close_buy_orders();
    else if (ma_m0 > ma_m1) close_sell_orders();
  }

  if (tp > 0) {
    double _tp = (ma_h0 - ma_l0) / (100 / tp);
    if (Bid > ma_h0 + _tp) close_buy_orders();
    else if (Ask < ma_l0 - _tp) close_sell_orders();
  }

  if ((slsum > 0 && pl < 0 && MathAbs(pl) / AccountBalance() * 100 > slsum) ||
      (tpsum > 0 && pl / AccountBalance() * 100 > tpsum)) {
    close_buy_orders();
    close_sell_orders();
  }
}

void close_buy_orders() {
  for (_int = 0; _int < ArraySize(buy_tickets); _int++) {
    if (!OrderSelect(buy_tickets[_int], SELECT_BY_TICKET)) continue;
    if (OrderClose(OrderTicket(), OrderLots(), Bid, 3)) continue;
  }
}

void close_sell_orders() {
  for (_int = 0; _int < ArraySize(sell_tickets); _int++) {
    if (!OrderSelect(sell_tickets[_int], SELECT_BY_TICKET)) continue;
    if (OrderClose(OrderTicket(), OrderLots(), Ask, 3)) continue;
  }
}

void open() {
  double _g = (ma_h0 - ma_l0) / (100 / gap);
  bool should_buy  = ma_m0 > ma_m1 // Uptrend, higher high-low
                  && Ask < ma_l0 + (ma_m0 - ma_m1) // Lower then the middle
                  && (buy_nearest_price == 0 || buy_nearest_price - Ask > _g) // Order gap, buy lower
                  && ArraySize(buy_tickets) < maxord; // Not more than max orders

  bool should_sell = ma_m0 < ma_m1 // Downtrend, lower high-low
                  && Bid > ma_h0 - (ma_m1 - ma_m0) // Higher than the middle
                  && (sell_nearest_price == 0 || Bid - sell_nearest_price > _g) // Order gap, sell higher
                  && ArraySize(sell_tickets) < maxord; // Not more than max orders

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
