package common

type CurPrice struct {
	Symbol string
	Price  float64
}

type HisPrice struct {
	Symbol string
	Time   int64
	Open   float64
	High   float64
	Low    float64
	Close  float64
}

type TradeResult struct {
	Time   int64
	Symbol string
	Side   string
	Size   float64
}
