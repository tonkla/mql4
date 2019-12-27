#property copyright "TRADEiS"
#property link      "https://tradeis.one"
#property version   "1.1"
#property strict

input string secret = "";// Secret spell to summon the EA
input int magic     = 0; // ID of the EA
input float lots    = 0; // Lots
input int period    = 0; // Number of bars consumed by indicators
input bool force_sl = 0; // Force stop loss when trend changed
input int sl        = 0; // Auto stop loss (%H-L)
input int tp        = 0; // Auto take profit (%H-L)
input double xhl    = 0; // Threshold (%H-L)

int buy_ticket, sell_ticket;
double o, h, l, c;
double ma_h, ma_l, hlx;
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
  o = iOpen(Symbol(), PERIOD_H1, 0);
  h = iHigh(Symbol(), PERIOD_H1, 0);
  l = iLow(Symbol(), PERIOD_H1, 0);
  c = iClose(Symbol(), PERIOD_H1, 0);
  ma_h = iMA(Symbol(), PERIOD_H1, period, 0, MODE_SMA, PRICE_HIGH, 0);
  ma_l = iMA(Symbol(), PERIOD_H1, period, 0, MODE_SMA, PRICE_LOW, 0);
  hlx = (ma_h - ma_l) * xhl / 100;
}

void close() {
  double buy_pips = 0;
  double sell_pips = 0;

  if (buy_ticket > 0 && OrderSelect(buy_ticket, SELECT_BY_TICKET))
    buy_pips = Bid - OrderOpenPrice();
  if (sell_ticket > 0 && OrderSelect(sell_ticket, SELECT_BY_TICKET))
    sell_pips = OrderOpenPrice() - Ask;

  if (sl > 0 && (buy_pips < 0 || sell_pips < 0)) {
    double _sl = (ma_h - ma_l) * sl / 100;
    if (buy_pips < 0 && MathAbs(buy_pips) > _sl) close_buy_order();
    if (sell_pips < 0 && MathAbs(sell_pips) > _sl) close_sell_order();
  }

  if (tp > 0 && (buy_pips > 0 || sell_pips > 0)) {
    double _tp = (ma_h - ma_l) * tp / 100;
    if (buy_pips > _tp) close_buy_order();
    if (sell_pips > _tp) close_sell_order();
  }

  if (force_sl) {
    if (o - c > hlx) close_buy_order();
    if (c - o > hlx) close_sell_order();
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
  bool should_buy  = (c - o > hlx || (c > o && o - l > hlx)) // Moving up
                  && Ask < ma_h - hlx // Buy zone
                  && buy_closed_time < iTime(Symbol(), PERIOD_H1, 0) // Buy once per TF
                  && buy_ticket == 0; // Only one buy order

  bool should_sell = (o - c > hlx || (o > c && h - o > hlx)) // Moving down
                  && Bid > ma_l + hlx // Sell zone
                  && sell_closed_time < iTime(Symbol(), PERIOD_H1, 0) // Sell once per TF
                  && sell_ticket == 0; // Only one sell order

  if (should_buy && 0 < OrderSend(Symbol(), OP_BUY, lots, Ask, 3, 0, 0, NULL, magic, 0))
    return;

  if (should_sell && 0 < OrderSend(Symbol(), OP_SELL, lots, Bid, 3, 0, 0, NULL, magic, 0))
    return;
}
