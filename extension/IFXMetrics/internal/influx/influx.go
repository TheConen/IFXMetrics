package influx

import (
	"context"
	"time"

	"github.com/indig0fox/IFXMetrics/internal/logger"
	influxdb2 "github.com/influxdata/influxdb-client-go/v2"
	"github.com/influxdata/influxdb-client-go/v2/api"
	"github.com/influxdata/influxdb-client-go/v2/domain"
	"github.com/kataras/iris/v12/x/errors"
	"github.com/spf13/viper"
)

var InfluxClient influxdb2.Client
var Connected bool = false
var activeSettings *viper.Viper

var writeAPIs = map[string]api.WriteAPI{}
var writeAPIErrorChannels = map[string]<-chan error{}

var errorHandlerCancel context.CancelFunc

// Close cleanly shuts down write APIs and the InfluxDB client.
// Must be called before creating a new client.
func Close() {
	Connected = false

	// stop the previous error handler goroutine
	if errorHandlerCancel != nil {
		errorHandlerCancel()
		errorHandlerCancel = nil
	}

	// flush and close existing write APIs before closing the client
	for bucket, w := range writeAPIs {
		w.Flush()
		delete(writeAPIs, bucket)
		delete(writeAPIErrorChannels, bucket)
	}

	if InfluxClient != nil {
		InfluxClient.Close()
		InfluxClient = nil
	}
}

func Setup(
	settings *viper.Viper,
) error {
	activeSettings = settings

	// ensure any previous client is fully cleaned up
	Close()

	// create influx client
	InfluxClient = influxdb2.NewClientWithOptions(
		activeSettings.GetString("influxdb.host"),
		activeSettings.GetString("influxdb.token"),
		influxdb2.DefaultOptions().SetFlushInterval(1000),
	)

	_, err := InfluxClient.Ping(context.Background())
	if err != nil {
		return err
	}

	Connected = true

	// start error handler with cancellation support
	var ctx context.Context
	ctx, errorHandlerCancel = context.WithCancel(context.Background())
	go func() {
		for {
			select {
			case <-ctx.Done():
				return
			default:
			}
			for bucket, err := range writeAPIErrorChannels {
				thisLog := logger.FileOnly.With().
					Str("component", "influx").
					Str("bucket", bucket).
					Logger()

				select {
				case e := <-err:
					thisLog.Error().Msg(e.Error())
				default:
					continue
				}
			}
			time.Sleep(1 * time.Second)
		}
	}()
	return nil
}

func WriteLine(
	bucket string,
	measurement string,
	tags map[string]string,
	fields map[string]interface{},
) error {

	if !Connected {
		return errors.New("influxdb not connected")
	}

	if InfluxClient == nil {
		return errors.New("influxdb client not initialized")
	}

	// check if bucket exists
	b := InfluxClient.BucketsAPI()
	_, err := b.FindBucketByName(context.Background(), bucket)
	if err != nil {
		// get organization
		org, err := InfluxClient.OrganizationsAPI().FindOrganizationByName(
			context.Background(),
			activeSettings.GetString("influxdb.org"),
		)
		if err != nil {

			return err
		}
		// create bucket
		bucket, err := b.CreateBucketWithName(
			context.Background(),
			org,
			bucket,
			domain.RetentionRule{EverySeconds: 0},
		)
		if err != nil {

			return err
		}
		logger.Log.Info().Msgf("created bucket %s", bucket.Name)
		return err
	}

	if writeAPIs[bucket] == nil {
		writeAPIs[bucket] = InfluxClient.WriteAPI(
			activeSettings.GetString("influxdb.org"),
			bucket,
		)
		writeAPIErrorChannels[bucket] = writeAPIs[bucket].Errors()
	}

	p := influxdb2.NewPoint(
		measurement,
		tags,
		fields,
		time.Now(),
	)

	writeAPIs[bucket].WritePoint(p)

	return nil
}
