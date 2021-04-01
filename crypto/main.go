package main

import (
	"log"

	"github.com/spf13/viper"

	"github.com/tonkla/tradeis/exchange"
)

func main() {
	viper.SetConfigFile("config.yaml")
	err := viper.ReadInConfig()
	if err != nil {
		log.Fatal(err)
	}

	cfgExchange := viper.GetString("exchange")
	cfgSymbols := viper.GetStringSlice("symbols")
	for _, symbol := range cfgSymbols {
		ex := exchange.New(cfgExchange)
		if ex != nil {
			result := ex.Trade(symbol)
			if result != nil {
				log.Printf("%+v\n", result)
			}
		} else {
			log.Println("Exchange does not found")
		}
	}
}
