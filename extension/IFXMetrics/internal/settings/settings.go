package settings

import (
	"os"

	"github.com/indig0fox/a3go/a3interface"
	"github.com/spf13/viper"
)

type CBAEventHandlerSetting struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Enabled     bool   `json:"enabled"`
	Bucket      string `json:"bucket"`
	Measurement string `json:"measurement"`
}

var Active *viper.Viper

func init() {
	Active = viper.New()
}

func Setup(
	addonFolder string,
) error {
	Active.SetConfigName("ifxmetrics.config")
	Active.SetConfigType("json")
	Active.AddConfigPath(addonFolder)

	armaDir, err := os.Getwd()
	if err != nil {
		return err
	}
	Active.AddConfigPath(armaDir)

	Active.SetDefault("influxdb", map[string]interface{}{
		"enabled": false,
		"host":    "http://localhost:8086",
		"token":   "",
		"org":     "",
	})

	Active.SetDefault("arma3", map[string]interface{}{
		"refreshRateMs": 2000,
		"debug":         "true",
	})

	Active.SetDefault("monitords", map[string]any{
		"enabled":        false,
		"interval":       5,
		"serverPassword": "",
	})

	Active.SetDefault("cbaEventHandlers", []map[string]any{})

	if err := Active.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); ok {
			// Config file not found; ignore error if desired
			a3interface.WriteArmaCallback(
				"ifxmetrics",
				":LOG:",
				"WARN",
				"Config file not found; using default values.",
			)
			return nil
		} else {
			// Config file was found but another error was produced
			a3interface.WriteArmaCallback(
				"ifxmetrics",
				":LOG:",
				"ERROR",
				err.Error(),
			)
			return err
		}
	} else {
		a3interface.WriteArmaCallback(
			"ifxmetrics",
			":LOG:",
			"INFO",
			"Config file found; using values from config file.",
		)
	}
	return nil
}
