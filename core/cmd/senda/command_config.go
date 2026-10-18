package main

import (
	"encoding/json"
	"fmt"
	"io"
	"strconv"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
	"github.com/migueel15/SendaDesktopManager/core/internal/googlecalendar"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/spf13/cobra"
)

const (
	keyGoogleClientID     = "SENDA_GOOGLE_CLIENT_ID"
	keyGoogleClientSecret = "SENDA_GOOGLE_CLIENT_SECRET"
	keyGoogleCalendars    = "SENDA_GOOGLE_CALENDARS"
	keyWeatherLocation    = "SENDA_WEATHER_LOCATION"
	keyWeatherLat         = "SENDA_WEATHER_LAT"
	keyWeatherLon         = "SENDA_WEATHER_LON"
)

// editableSettings is the only set of keys the settings panel may write. Any
// other key is refused, so a bad caller cannot change unrelated settings such
// as DORLAB_API_KEY.
var editableSettings = map[string]bool{
	keyGoogleClientID:     true,
	keyGoogleClientSecret: true,
	keyGoogleCalendars:    true,
	keyWeatherLocation:    true,
	keyWeatherLat:         true,
	keyWeatherLon:         true,
}

func configCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "config",
		Short: "Read and write the Senda settings used by the settings panel",
	}
	cmd.AddCommand(configGetCmd(), configSetCmd())
	return cmd
}

// configGetCmd prints the editable settings from the config file as JSON. The
// client secret is never printed; only whether it is set.
func configGetCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "get",
		Short: "Print the editable settings as JSON",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			values, err := config.Load(paths.ConfigFile())
			if err != nil {
				return err
			}
			result := map[string]any{
				"values": map[string]string{
					keyGoogleClientID:  values[keyGoogleClientID],
					keyGoogleCalendars: values[keyGoogleCalendars],
					keyWeatherLocation: values[keyWeatherLocation],
					keyWeatherLat:      values[keyWeatherLat],
					keyWeatherLon:      values[keyWeatherLon],
				},
				"googleClientSecretConfigured": values[keyGoogleClientSecret] != "",
				"embeddedGoogleClient":         googlecalendar.HasEmbeddedCredentials(),
			}
			return writeJSON(cmd, result)
		},
	}
}

// configSetCmd reads a JSON object from stdin, such as {"SENDA_WEATHER_LAT":"39.4"}.
// Values go through stdin rather than arguments so that secrets never appear
// in the process list. An empty value removes the setting.
func configSetCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "set",
		Short: "Update settings from a JSON object on stdin",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			changes, err := readChanges(cmd.InOrStdin())
			if err != nil {
				return err
			}
			if err := config.Set(paths.ConfigFile(), changes); err != nil {
				return err
			}
			fmt.Fprintln(cmd.OutOrStdout(), "settings saved")
			return nil
		},
	}
}

// readChanges decodes one JSON object and stops reading after it. The caller
// may keep stdin open, so reading to EOF would block.
func readChanges(input io.Reader) (map[string]string, error) {
	var changes map[string]string
	if err := json.NewDecoder(io.LimitReader(input, 1<<16)).Decode(&changes); err != nil {
		return nil, fmt.Errorf("stdin must be a JSON object of string values: %w", err)
	}
	for key, value := range changes {
		if !editableSettings[key] {
			return nil, fmt.Errorf("%s cannot be changed from the settings panel", key)
		}
		if err := validateSetting(key, value); err != nil {
			return nil, err
		}
	}
	return changes, nil
}

func validateSetting(key, value string) error {
	switch key {
	case keyWeatherLat:
		return validateCoordinate(key, strings.TrimSpace(value), 90)
	case keyWeatherLon:
		return validateCoordinate(key, strings.TrimSpace(value), 180)
	}
	return nil
}

func validateCoordinate(key, value string, limit float64) error {
	if value == "" {
		return nil
	}
	number, err := strconv.ParseFloat(value, 64)
	if err != nil || number < -limit || number > limit {
		return fmt.Errorf("%s must be a number between -%g and %g", key, limit, limit)
	}
	return nil
}
