package strategy

import (
	"github.com/tonkla/tradeis/common"
)

func MAMACD(price float64, wPrices []*common.HisPrice, dPrices []*common.HisPrice, hPrices []*common.HisPrice) (bool, bool) {
	return false, false
}
