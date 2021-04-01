package exchange

import (
	"github.com/tonkla/tradeis/common"
	"github.com/tonkla/tradeis/exchange/binance"
)

type Exchange interface {
	GetName() string
	GetCurrentPrice(symbol string) *common.CurPrice
	GetHistoricalPrices(symbol string, interval string, limit int) []*common.HisPrice
	Trade(symbol string) *common.TradeResult
}

func New(name string) Exchange {
	var ex Exchange
	if name == "BINANCE" {
		ex = binance.New()
	}
	return ex
}
