#property indicator_chart_window

#define OBJ_VLINE_S "obj_vline_start"
#define OBJ_VLINE_M "obj_vline_mid"
#define OBJ_VLINE_E "obj_vline_end"

input int server_gmt = 2;
input int start_gmt  = 8;
input int mid_gmt    = 13;
input int end_gmt    = 20;

int startIdx = 0, bars = 0;

int OnInit() {
  return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
  delete_objects();
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {
  return rates_total;
}

void OnChartEvent(const int id,           // Event identifier
                  const long &lparam,     // Event parameter of long type
                  const double &dparam,   // Event parameter of double type
                  const string &sparam) { // Event parameter of string type
  if (id == CHARTEVENT_CLICK && startIdx != WindowFirstVisibleBar()) draw();
}

void draw() {
  if (Period() != PERIOD_H1) {
    delete_objects();
    return;
  }

  datetime t_start = 0, t_mid = 0, t_end = 0, t = 0;

  bars = WindowBarsPerChart();
  startIdx = bars > WindowFirstVisibleBar() ? bars : WindowFirstVisibleBar();

  for (int i = startIdx - bars; i < startIdx; i++) {
    t = iTime(NULL, PERIOD_H1, i);
    if (t_start == 0 && TimeHour(t) - server_gmt == start_gmt) t_start = t;
    else if (t_mid == 0 && TimeHour(t) - server_gmt == mid_gmt) t_mid = t;
    else if (t_end == 0 && TimeHour(t) - server_gmt == end_gmt) t_end = t;

    if (t_start > 0 && t_end > 0) break;
  }

  if (t_start > 0) {
    ObjectDelete(OBJ_VLINE_S);
    ObjectCreate(OBJ_VLINE_S, OBJ_VLINE, 0, t_start, 0);
    ObjectSetInteger(0, OBJ_VLINE_S, OBJPROP_COLOR, clrYellowGreen);
    ObjectSetInteger(0, OBJ_VLINE_S, OBJPROP_STYLE, STYLE_DOT);
  }

  if (t_mid > 0) {
    ObjectDelete(OBJ_VLINE_M);
    ObjectCreate(OBJ_VLINE_M, OBJ_VLINE, 0, t_mid, 0);
    ObjectSetInteger(0, OBJ_VLINE_M, OBJPROP_COLOR, clrDarkGray);
    ObjectSetInteger(0, OBJ_VLINE_M, OBJPROP_STYLE, STYLE_DOT);
  }

  if (t_end > 0) {
    ObjectDelete(OBJ_VLINE_E);
    ObjectCreate(OBJ_VLINE_E, OBJ_VLINE, 0, t_end, 0);
    ObjectSetInteger(0, OBJ_VLINE_E, OBJPROP_COLOR, clrCrimson);
    ObjectSetInteger(0, OBJ_VLINE_E, OBJPROP_STYLE, STYLE_DOT);
  }
}

void delete_objects() {
  ObjectDelete(OBJ_VLINE_S);
  ObjectDelete(OBJ_VLINE_M);
  ObjectDelete(OBJ_VLINE_E);
}
