#property copyright "TRADEiS"
#property link      "https://tradeis.one"
#property version   "1.3"
#property strict

input string secret = "";// Secret spell to summon the EA
input int magic     = 0; // ID of the EA
input double lots   = 0; // Initial lots
input double inc    = 0; // Increased lots from the initial one (Martingale-like)
input int tf        = 0; // Timeframe of indicators (60=H1, 1440=D1, 10080=W1)
input int period    = 0; // Number of bars to be calculated in indicators
input int maxord    = 0; // Max orders per side
input int gap       = 0; // Gap between orders (%H-L)
input double xhl    = 0; // Multiplier range from the first order to H/L
input int sl        = 0; // Auto stop loss (%H-L exceeded from H/L)
input int tp        = 0; // Auto take profit (%H-L exceeded from H/L)
input double slacc  = 0; // Accepted total loss (%AccountBalance)
input double tpacc  = 0; // Accepted total profit (%AccountBalance)

int buy_tickets[];
int sell_tickets[];
int _int;

double buy_nearest_price;
double sell_nearest_price;
double pl;
double ma_h0, ma_h1, ma_l0, ma_l1, ma_m0, ma_m1;


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
  ma_h1 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_HIGH, 1);
  ma_l0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_LOW, 0);
  ma_l1 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_LOW, 1);
  ma_m0 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 0);
  ma_m1 = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_MEDIAN, 1);
}

void close() {
  if (sl > 0) {
    double _sl = (ma_h0 - ma_l0) / (100 / sl);
    if ((ma_l0 < ma_l1 || ma_m0 < ma_m1 || Bid < ma_l0 - _sl)
      && ArraySize(buy_tickets) > 0) close_buy_orders();
    if ((ma_h0 > ma_h1 || ma_m0 > ma_m1 || Ask > ma_h0 + _sl)
      && ArraySize(sell_tickets) > 0) close_sell_orders();;
  }

  if (tp > 0) {
    double _tp = (ma_h0 - ma_l0) / (100 / tp);
    if (Bid > ma_h0 + _tp) close_buy_orders();
    if (Ask < ma_l0 - _tp) close_sell_orders();
  }

  if ((slacc > 0 && pl < 0 && MathAbs(pl) / AccountBalance() * 100 > slacc) ||
      (tpacc > 0 && pl / AccountBalance() * 100 > tpacc)) {
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
  double _xhl = MathAbs(ma_m0 - ma_m1) * xhl;
  double _gap = gap > 0 ? (ma_h0 - ma_l0) / (100 / gap) : 0;
  double _sl = sl > 0 ? (ma_h0 - ma_l0) / (100 / sl) : 0;

  bool should_buy  = ma_l0 > ma_l1 && ma_m0 > ma_m1 // Uptrend, higher high-low
                  && Ask < ma_m0 && Ask < ma_l0 + _xhl && Ask > ma_l0 - _sl // Lower then the middle
                  && (buy_nearest_price == 0 || buy_nearest_price - Ask > _gap) // Order gap, buy lower
                  && ArraySize(buy_tickets) < maxord; // Not more than max orders

  bool should_sell = ma_h0 < ma_h1 && ma_m0 < ma_m1 // Downtrend, lower high-low
                  && Bid > ma_m0 && Bid > ma_h0 - _xhl && Bid < ma_h0 + _sl // Higher than the middle
                  && (sell_nearest_price == 0 || Bid - sell_nearest_price > _gap) // Order gap, sell higher
                  && ArraySize(sell_tickets) < maxord; // Not more than max orders

  if (should_buy) {
    double _lots = ArraySize(buy_tickets) == 0
                    ? lots
                    : Ask < buy_nearest_price
                      ? NormalizeDouble(ArraySize(buy_tickets) * inc + lots, 2)
                      : lots;
    _int = OrderSend(Symbol(), OP_BUY, _lots, Ask, 3, 0, 0, NULL, magic, 0);
  }

  if (should_sell) {
    double _lots = ArraySize(sell_tickets) == 0
                    ? lots
                    : Bid > sell_nearest_price
                      ? NormalizeDouble(ArraySize(sell_tickets) * inc + lots, 2)
                      : lots;
    _int = OrderSend(Symbol(), OP_SELL, _lots, Bid, 3, 0, 0, NULL, magic, 0);
  }
}
