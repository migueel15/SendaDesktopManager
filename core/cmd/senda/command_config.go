package main

import (
	"encoding/json"
	"fmt"
	"io"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
	"github.com/migueel15/SendaDesktopManager/core/internal/googlecalendar"
	"github.com/migueel15/SendaDesktopManager/core/internal/location"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
	"github.com/spf13/cobra"
)

const (
	keyGoogleClientID     = "SENDA_GOOGLE_CLIENT_ID"
	keyGoogleClientSecret = "SENDA_GOOGLE_CLIENT_SECRET"
	keyGoogleCalendars    = "SENDA_GOOGLE_CALENDARS"
	keyWeatherLocation    = "SENDA_WEATHER_LOCATION"
	keyWeatherLat         = "SENDA_WEATHER_LAT"
	keyWeatherLon         = "SENDA_WEATHER_LON"
	keyUIFontScale        = "SENDA_UI_FONT_SCALE"
	keyWidgetSpotify      = "SENDA_WIDGET_SPOTIFY"
	keyScreenshotDir      = "SENDA_SCREENSHOT_DIR"
	keyWidgetDiscord      = "SENDA_WIDGET_DISCORD"
)

// Bounds of the interface font scale, in percent. 100 is the default size.
const (
	minUIFontScale = 80
	maxUIFontScale = 150
)

// editableSettings is the only set of keys the settings panel may write. Any
// other key is refused, so a bad caller cannot change unrelated settings such
// as DORLAB_API_KEY.
var editableSettings = map[string]bool{
	keyScreenshotDir:      true,
	keyGoogleClientID:     true,
	keyGoogleClientSecret: true,
	keyGoogleCalendars:    true,
	keyWeatherLocation:    true,
	keyWeatherLat:         true,
	keyWeatherLon:         true,
	keyUIFontScale:        true,
	keyWidgetSpotify:      true,
	keyWidgetDiscord:      true,
	stt.KeyLanguage:       true,
	stt.KeyPreload:        true,
	stt.KeyAudioDucking:   true,
	stt.KeyAudioVolume:    true,
	stt.KeyPasteMode:      true,
	stt.KeyTerminals:      true,
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
			sttSettings := stt.LoadSettings(values)
			result := map[string]any{
				"values": map[string]string{
					keyScreenshotDir:    values[keyScreenshotDir],
					keyGoogleClientID:   values[keyGoogleClientID],
					keyGoogleCalendars:  values[keyGoogleCalendars],
					keyWeatherLocation:  values[keyWeatherLocation],
					keyWeatherLat:       values[keyWeatherLat],
					keyWeatherLon:       values[keyWeatherLon],
					keyUIFontScale:      values[keyUIFontScale],
					keyWidgetSpotify:    values[keyWidgetSpotify],
					keyWidgetDiscord:    values[keyWidgetDiscord],
					stt.KeyPreload:      strconv.FormatBool(sttSettings.Preload),
					stt.KeyAudioDucking: strconv.FormatBool(sttSettings.AudioDucking),
					stt.KeyAudioVolume:  strconv.Itoa(sttSettings.AudioVolume),
					stt.KeyModel:        sttSettings.ModelID,
					stt.KeyLanguage:     sttSettings.Language,
					stt.KeyPasteMode:    string(sttSettings.PasteMode),
					stt.KeyShortcut:     sttSettings.Shortcut,
					stt.KeyTerminals:    strings.Join(sttSettings.Terminals, ","),
				},
				"googleClientSecretConfigured": values[keyGoogleClientSecret] != "",
				"embeddedGoogleClient":         googlecalendar.HasEmbeddedCredentials(),
				"defaultWeatherLocation":       defaultLocationName(),
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
	case keyScreenshotDir:
		if value != "" && !filepath.IsAbs(value) && !strings.HasPrefix(value, "~/") {
			return fmt.Errorf("la ruta de capturas debe ser absoluta o empezar por ~/")
		}
		if strings.ContainsAny(value, "\x00\n\r") {
			return fmt.Errorf("ruta de capturas inválida")
		}
	case keyWeatherLat:
		return validateCoordinate(key, strings.TrimSpace(value), 90)
	case keyWeatherLon:
		return validateCoordinate(key, strings.TrimSpace(value), 180)
	case keyUIFontScale:
		return validateFontScale(strings.TrimSpace(value))
	case stt.KeyPreload, stt.KeyAudioDucking, keyWidgetSpotify, keyWidgetDiscord:
		if value != "" && value != "true" && value != "false" {
			return fmt.Errorf("%s must be true or false", key)
		}
	case stt.KeyAudioVolume:
		if value != "" {
			percent, err := strconv.Atoi(value)
			if err != nil || percent < 0 || percent > 100 {
				return fmt.Errorf("%s must be a whole number between 0 and 100", key)
			}
		}
	case stt.KeyPasteMode:
		if value != "" && value != string(stt.PasteDirect) && value != string(stt.PasteClipboard) {
			return fmt.Errorf("%s must be paste or clipboard", stt.KeyPasteMode)
		}
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

// defaultLocationName names the capital used when no weather location is
// chosen, or "" when the system time zone has no known capital.
func defaultLocationName() string {
	if place, ok := location.Default(); ok {
		return place.Name
	}
	return ""
}

// validateFontScale accepts an empty value, which restores the default, or a
// whole percentage within the allowed range.
func validateFontScale(value string) error {
	if value == "" {
		return nil
	}
	percent, err := strconv.Atoi(value)
	if err != nil || percent < minUIFontScale || percent > maxUIFontScale {
		return fmt.Errorf("%s must be a whole number between %d and %d", keyUIFontScale, minUIFontScale, maxUIFontScale)
	}
	return nil
}
