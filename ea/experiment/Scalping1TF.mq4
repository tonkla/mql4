#property copyright "TRADEiS"
#property link      "https://tradeis.one"
#property version   "1.2"
#property strict

input string secret = "";// Secret spell to summon the EA
input int magic     = 0; // ID of the EA
input float lots    = 0; // Lots
input int tf        = 0; // Timeframe (60=H1)
input int period    = 0; // Period
input int sl        = 0; // Auto stop loss (%H-L)
input int tp        = 0; // Auto take profit (%H-L)

int buy_ticket, sell_ticket;
double o, h, l, c;
double ma_h, ma_l, ma_h_l;
datetime buy_closed_time, sell_closed_time;


int OnInit() {
  return secret == "https://tradeis.one" ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick() {
  get_order();
  get_vars();
  close();
  open();
}

void get_order() {
  buy_ticket = 0;
  sell_ticket = 0;

  for (int i = OrdersTotal() - 1; i >= 0; i--) {
    if (!OrderSelect(i, SELECT_BY_POS)) continue;
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != magic) continue;
    switch (OrderType()) {
      case OP_BUY:
        buy_ticket = OrderTicket();
        break;
      case OP_SELL:
        sell_ticket = OrderTicket();
        break;
    }
  }
}

void get_vars() {
  o = iOpen(Symbol(), tf, 0);
  h = iHigh(Symbol(), tf, 0);
  l = iLow(Symbol(), tf, 0);
  c = iClose(Symbol(), tf, 0);
  ma_h = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_HIGH, 0);
  ma_l = iMA(Symbol(), tf, period, 0, MODE_LWMA, PRICE_LOW, 0);
  ma_h_l = ma_h - ma_l;
}

void close() {
  double buy_pips = 0;
  double sell_pips = 0;

  if (buy_ticket > 0 && OrderSelect(buy_ticket, SELECT_BY_TICKET))
    buy_pips = Bid - OrderOpenPrice();
  if (sell_ticket > 0 && OrderSelect(sell_ticket, SELECT_BY_TICKET))
    sell_pips = OrderOpenPrice() - Ask;

  if (sl > 0 && (buy_pips < 0 || sell_pips < 0)) {
    double _sl = sl * ma_h_l / 100;
    if (buy_pips < 0 && MathAbs(buy_pips) > _sl) close_buy_order();
    if (sell_pips < 0 && MathAbs(sell_pips) > _sl) close_sell_order();
  }

  if (tp > 0 && (buy_pips > 0 || sell_pips > 0)) {
    double _tp = tp * ma_h_l / 100;
    if (buy_pips > _tp) close_buy_order();
    if (sell_pips > _tp) close_sell_order();
  }
}

void close_buy_order() {
  if (!OrderSelect(buy_ticket, SELECT_BY_TICKET)) return;
  if (OrderClose(OrderTicket(), OrderLots(), Bid, 3)) buy_closed_time = TimeCurrent();
}

void close_sell_order() {
  if (!OrderSelect(sell_ticket, SELECT_BY_TICKET)) return;
  if (OrderClose(OrderTicket(), OrderLots(), Ask, 3)) sell_closed_time = TimeCurrent();
}

void open() {
  int hidx = iHighest(Symbol(), 1, MODE_HIGH, 5, 0);
  int lidx = iLowest(Symbol(), 1, MODE_LOW, 5, 0);
  double _h = iHigh(Symbol(), 1, hidx);
  double _l = iLow(Symbol(), 1, lidx);
  double _t = 0.5 * (h - l);
  double min = 0.2 * ma_h_l;

  bool should_buy  = lidx > hidx && _h - Ask < Bid - _l && Bid - _l > _t // Moving up
                  && Ask < ma_h - min // Limited buy zone
                  && buy_closed_time < iTime(Symbol(), tf, 0) // Buy once per TF
                  && buy_ticket == 0; // Only one buy order

  bool should_sell = lidx < hidx && _h - Ask > Bid - _l && _h - Ask > _t // Moving down
                  && Bid > ma_l + min // Limited sell zone
                  && sell_closed_time < iTime(Symbol(), tf, 0) // Sell once per TF
                  && sell_ticket == 0; // Only one sell order

  if (should_buy && 0 < OrderSend(Symbol(), OP_BUY, lots, Ask, 3, 0, 0, NULL, magic, 0))
    return;

  if (should_sell && 0 < OrderSend(Symbol(), OP_SELL, lots, Bid, 3, 0, 0, NULL, magic, 0))
    return;
}
