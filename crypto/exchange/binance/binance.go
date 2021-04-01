package binance

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/tidwall/gjson"

	"github.com/tonkla/tradeis/common"
	"github.com/tonkla/tradeis/strategy"
)

const (
	urlMainnet   = "https://api.binance.com/api/v3"
	urlTestnet   = "https://testnet.binance.vision/api/v3"
	pathCurPrice = "/ticker/price?symbol=%s"
	pathHisPrice = "/klines?symbol=%s&interval=%s&limit=%d"
)

type Binance struct {
}

func New() *Binance {
	return &Binance{}
}

// GetName returns "BINANCE"
func (b *Binance) GetName() string {
	return "BINANCE"
}

// GetCurrentPrice gets a current ticker
func (b *Binance) GetCurrentPrice(symbol string) *common.CurPrice {
	path := fmt.Sprintf(pathCurPrice, symbol)
	url := fmt.Sprintf("%s%s", urlMainnet, path)
	resp, err := http.Get(url)
	if err != nil {
		log.Fatal(err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Fatal(err)
	}

	return &common.CurPrice{
		Symbol: gjson.GetBytes(body, "symbol").String(),
		Price:  gjson.GetBytes(body, "price").Float()}
}

// GetHistoricalPrices gets k-lines/candlesticks
func (b *Binance) GetHistoricalPrices(symbol string, interval string, limit int) []*common.HisPrice {
	path := fmt.Sprintf(pathHisPrice, symbol, interval, limit)
	url := fmt.Sprintf("%s%s", urlMainnet, path)
	resp, err := http.Get(url)
	if err != nil {
		log.Fatal(err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Fatal(err)
	}

	var hPrices []*common.HisPrice
	for _, data := range gjson.Parse(string(body)).Array() {
		d := data.Array()
		p := &common.HisPrice{
			Symbol: symbol,
			Time:   d[0].Int() / 1000,
			Open:   d[1].Float(),
			High:   d[2].Float(),
			Low:    d[3].Float(),
			Close:  d[4].Float(),
		}
		hPrices = append(hPrices, p)
	}
	return hPrices
}

// Trade watches a current ticker, finds a possibility, and takes an action
func (b *Binance) Trade(symbol string) *common.TradeResult {
	p := b.GetCurrentPrice(symbol)
	wp := b.GetHistoricalPrices(symbol, "1w", 50)
	dp := b.GetHistoricalPrices(symbol, "1d", 50)
	hp := b.GetHistoricalPrices(symbol, "1h", 50)

	shouldBuy, shouldSell := strategy.MAMACD(p.Price, wp, dp, hp)

	result := &common.TradeResult{Time: time.Now().Unix(), Symbol: symbol}
	if shouldBuy {
		result.Side = "BUY"
		return result
	} else if shouldSell {
		result.Side = "SELL"
		return result
	}
	return nil
}
