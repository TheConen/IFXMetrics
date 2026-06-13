package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/indig0fox/IFXMetrics/internal/influx"
	"github.com/indig0fox/IFXMetrics/internal/logger"
	"github.com/indig0fox/IFXMetrics/internal/settings"
	"github.com/indig0fox/a3go/a3interface"
	"github.com/indig0fox/a3go/assemblyfinder"
)

var EXTENSION_VERSION string = "DEVELOPMENT"

// file paths
var EXTENSION_PATH string = assemblyfinder.GetModulePath()
var ADDON_FOLDER string = filepath.Dir(EXTENSION_PATH)
var LOG_FILE string = ADDON_FOLDER + "\\ifxmetrics.log"
var SETTINGS_FILE string = ADDON_FOLDER + "\\ifxmetrics.config.json"

var extensionReady bool = false

// configure log output
func init() {

	var err error

	// load settings
	err = settings.Setup(ADDON_FOLDER)
	if err != nil {
		log.Fatal(err)
	}

	if settings.Active == nil {
		log.Fatal("settings.Active is nil")
	}

	// init logger
	logger.InitLoggers(&logger.LoggerOptionsType{
		Path:             LOG_FILE,
		AddonName:        "IFXMetrics",
		ExtensionName:    "IFXMetrics",
		ExtensionVersion: EXTENSION_VERSION,
		Debug:            settings.Active.GetBool("arma3.debug"),
		Trace:            settings.Active.GetBool("arma3.traceLogToFile"),
	})

	logger.Log.Info().Msgf(
		`IFXMetrics extension started. Version: %s`,
		EXTENSION_VERSION,
	)

	a3interface.NewRegistration(":START:").
		SetFunction(func(
			ctx a3interface.ArmaExtensionContext,
			data string,
		) (string, error) {
			if extensionReady {
				// reload config
				settings.Active.ReadInConfig()
				logger.Log.Info().Msg("Reloaded config")
			}
			extensionReady = true
			return fmt.Sprintf(
				`["IFXMetrics ready (v%s)"]`,
				EXTENSION_VERSION,
			), nil
		}).
		SetRunInBackground(false).
		Register()

	a3interface.NewRegistration(":SETTINGS:").
		SetFunction(onSettingsCommand).
		SetRunInBackground(false).
		Register()

	a3interface.NewRegistration(":CUSTOM:CBA:EVENTS:").
		SetFunction(onCustomCBAEventsCommand).
		SetRunInBackground(false).
		Register()

	a3interface.NewRegistration(":INFLUX:CONNECT:").
		SetFunction(onInfluxConnect).
		SetRunInBackground(false).
		Register()

	a3interface.NewRegistration(":INFLUX:WRITE:").
		SetArgsFunction(onInfluxWrite).
		SetRunInBackground(false).
		Register()
}

func onSettingsCommand(
	ctx a3interface.ArmaExtensionContext,
	data string,
) (string, error) {

	return fmt.Sprintf(
		`[%t, %t, %d]`,
		settings.Active.GetBool("influxdb.enabled"),
		settings.Active.GetBool("arma3.debug"),
		settings.Active.GetInt("arma3.refreshRateMs"),
	), nil
}

func onCustomCBAEventsCommand(
	ctx a3interface.ArmaExtensionContext,
	data string,
) (string, error) {
	s := settings.Active.Get("cbaEventHandlers")
	// return the custom cba event handlers as an arma hashmap
	se := a3interface.ToArmaHashMap(s)
	return fmt.Sprintf(
		`%s`,
		se,
	), nil
}

func onInfluxConnect(
	ctx a3interface.ArmaExtensionContext,
	data string,
) (string, error) {
	err := influx.Setup(
		settings.Active,
	)
	if err != nil {
		logger.Log.Error().Msg(err.Error())
		return "", err
	}

	logger.Log.Info().Msgf(
		"Connected to InfluxDB at %s",
		settings.Active.GetString("influxdb.host"),
	)

	return fmt.Sprintf(
		`["OK", "Connected to InfluxDB at %s"]`,
		settings.Active.GetString("influxdb.host"),
	), nil
}

func onInfluxWrite(
	ctx a3interface.ArmaExtensionContext,
	command string,
	args []string,
) (string, error) {

	var err error

	commandTrace := logger.FileOnly.With().
		Str("command", command).
		Str("file_source", ctx.FileSource).
		Logger()

	commandTrace.Trace().Msgf(
		"onInfluxWrite: %s",
		strings.Join(args, ", "),
	)

	argsProcessed := []map[string]interface{}{}
	for _, arg := range args {
		thisArgJSON, err := a3interface.ParseSQF(arg)
		if err != nil {
			logger.Log.Error().
				Str("command", command).
				Str("arg", arg).
				Msg(err.Error())
			continue
		}

		thisArgHash, err := a3interface.ParseSQFHashMap(thisArgJSON)
		if err != nil {
			logger.Log.Error().
				Str("command", command).
				Str("arg", arg).
				Msg(err.Error())
			continue
		}

		argsProcessed = append(argsProcessed, thisArgHash)
	}

	commandTrace.Trace().Msgf(
		"argsProcessed: %v",
		argsProcessed,
	)

	for _, hash := range argsProcessed {
		hashLog := commandTrace.With().
			Str("bucket", fmt.Sprintf("%v", hash["bucket"])).
			Str("measurement", fmt.Sprintf("%v", hash["measurement"])).
			Logger()

		// bucket
		if hash["bucket"] == nil {
			hashLog.Error().Msg("bucket not declared")
			continue
		}
		// determine type of bucket
		hashLog.Trace().Msgf(
			"hash[\"bucket\"] is type %T",
			hash["bucket"],
		)
		var bucket string = hash["bucket"].(string)
		if bucket == "" {
			hashLog.Error().Msg("bucket not declared")
			continue
		}

		// measurement
		if hash["measurement"] == nil {
			hashLog.Error().Msg("measurement not declared")
			continue
		}
		// determine type of measurement
		hashLog.Trace().Msgf(
			"hash[\"measurement\"] is type %T",
			hash["measurement"],
		)
		var measurement string = hash["measurement"].(string)
		if measurement == "" {
			hashLog.Error().Msg("measurement not declared")
			continue
		}

		// tags
		// write type
		hashLog.Trace().Msgf(
			"hash[\"tags\"] is type %T",
			hash["tags"],
		)
		var tags = map[string]string{}
		if hash["tags"] == nil {
			tags = map[string]string{}
		} else {
			// convert the tags to a map[string]string type by transferring values
			for k, v := range hash["tags"].(map[string]interface{}) {
				tags[k] = fmt.Sprintf("%v", v)
			}
		}

		// fields
		// write type
		hashLog.Trace().Msgf(
			"hash[\"fields\"] is type %T",
			hash["fields"],
		)
		var fields map[string]interface{}
		if hash["fields"] == nil {
			fields = map[string]interface{}{}
		} else {
			fields = hash["fields"].(map[string]interface{})
		}

		// write the line to influx
		hashLog.Trace().Msg("Writing line to influx")
		err = influx.WriteLine(
			bucket,
			measurement,
			tags,
			fields,
		)
		if err != nil {
			hashLog.Error().Msg(err.Error())
			continue
		}
	}

	return fmt.Sprintf(
		"Wrote %d lines to InfluxDB buffer",
		len(argsProcessed),
	), nil
}

func getDir() string {
	dir, err := os.Getwd()
	if err != nil {
		log.Fatal(err)
	}
	return dir
}

func getUnixTimeNano() int64 {
	// get the current unix timestamp in nanoseconds
	return time.Now().UnixNano()
}

func trimQuotes(s string) string {
	// trim the start and end quotes from a string
	return strings.Trim(s, `"`)
}

func fixEscapeQuotes(s string) string {
	// fix the escape quotes in a string
	return strings.Replace(s, `""`, `"`, -1)
}

func main() {
	// // Example usage
	// data := map[string]interface{}{
	// 	"name": "John \"Doe\"",
	// 	"info": map[string]interface{}{
	// 		"address": "123 \"Main\" St",
	// 	},
	// 	"numbers": []interface{}{1, 2, 3.14, "four", true},
	// }

	// result := a3interface.ToArmaHashMap(data)
	// fmt.Println(result)

	// s := settings.Active.Get("cbaEventHandlers")
	// // return the custom cba event handlers as an arma hashmap
	// fmt.Println(a3interface.ToArmaHashMap(s))

	fmt.Println("IFXMetrics extension started. Version: " + EXTENSION_VERSION)
	fmt.Scanln()
}
