#property copyright "TRADEiS"
#property link      "https://tradeis.one"
#property version   "1.0"
#property strict

input string secret = "";
input int magic     = 0;
input double lots   = 0;
input double inc    = 0;
input int tf        = 0;
input int period    = 0;
input int maxord    = 0;
input int mid       = 0;
input int gap       = 0;
input int sl        = 0;
input int tp        = 0;
input int slsum     = 0;
input int tpsum     = 0;

int buy_tickets[];
int sell_tickets[];
int _int;
int _size;

double buy_nearest_price;
double sell_nearest_price;
double pl;
double ma_h0, ma_l0, ma_m0, ma_m1;
double hl_m, hl_g;


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

  hl_m = (ma_h0 - ma_l0) / (100 / mid);
  hl_g = (ma_h0 - ma_l0) / (100 / gap);
}

void close() {
  if (sl > 0) {
    if (ma_m0 < ma_m1) {
      for (_int = 0; _int < ArraySize(buy_tickets); _int++) {
        if (!OrderSelect(buy_tickets[_int], SELECT_BY_TICKET)) continue;
        if (OrderClose(OrderTicket(), OrderLots(), Bid, 3)) continue;
      }
    }
    else if (ma_m0 > ma_m1) {
      for (_int = 0; _int < ArraySize(sell_tickets); _int++) {
        if (!OrderSelect(sell_tickets[_int], SELECT_BY_TICKET)) continue;
        if (OrderClose(OrderTicket(), OrderLots(), Ask, 3)) continue;
      }
    }
  }

  if (tp > 0) {
    double _tp = (ma_h0 - ma_l0) / (100 / tp);
    if (Bid > ma_h0 + _tp) {
      for (_int = 0; _int < ArraySize(buy_tickets); _int++) {
        if (!OrderSelect(buy_tickets[_int], SELECT_BY_TICKET)) continue;
        if (OrderClose(OrderTicket(), OrderLots(), Bid, 3)) continue;
      }
    }
    else if (Ask < ma_l0 - _tp) {
      for (_int = 0; _int < ArraySize(sell_tickets); _int++) {
        if (!OrderSelect(sell_tickets[_int], SELECT_BY_TICKET)) continue;
        if (OrderClose(OrderTicket(), OrderLots(), Ask, 3)) continue;
      }
    }
  }

  if ((slsum > 0 && pl < 0 && MathAbs(pl) / AccountBalance() * 100 > slsum) ||
      (tpsum > 0 && pl / AccountBalance() * 100 > tpsum)) {
    for (_int = 0; _int < ArraySize(buy_tickets); _int++) {
      if (!OrderSelect(buy_tickets[_int], SELECT_BY_TICKET)) continue;
      if (OrderClose(OrderTicket(), OrderLots(), Bid, 3)) continue;
    }
    for (_int = 0; _int < ArraySize(sell_tickets); _int++) {
      if (!OrderSelect(sell_tickets[_int], SELECT_BY_TICKET)) continue;
      if (OrderClose(OrderTicket(), OrderLots(), Ask, 3)) continue;
    }
  }
}

void open() {
  bool should_buy  = ma_m0 > ma_m1 // Uptrend, higher high-low
                  && Ask < ma_l0 + hl_m // Lower then the middle
                  && (buy_nearest_price == 0 || buy_nearest_price - Ask > hl_g) // Order gap, buy lower
                  && ArraySize(buy_tickets) < maxord; // Not more than max orders

  bool should_sell = ma_m0 < ma_m1 // Downtrend, lower high-low
                  && Bid > ma_h0 - hl_m // Higher than the middle
                  && (sell_nearest_price == 0 || Bid - sell_nearest_price > hl_g) // Order gap, sell higher
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
