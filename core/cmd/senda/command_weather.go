package main

import (
	"errors"
	"fmt"
	"strconv"

	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/migueel15/SendaDesktopManager/core/internal/weather"
	"github.com/spf13/cobra"
)

// errLocationNotSet tells the user how to choose a place. The dashboard shows
// it as a hint instead of an error.
var errLocationNotSet = errors.New("no weather location is set; choose one in the Senda settings")

func weatherCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "weather",
		Short: "Find places and read the weather for the configured location",
	}
	cmd.AddCommand(weatherSearchCmd(), weatherCurrentCmd())
	return cmd
}

func weatherSearchCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "search <place>",
		Short: "Print matching places as JSON",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			places, err := weather.NewClient().Search(cmd.Context(), args[0])
			if err != nil {
				return err
			}
			return writeJSON(cmd, map[string]any{"places": places})
		},
	}
}

func weatherCurrentCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "current",
		Short: "Print the weather for the configured location as JSON",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			latitude, longitude, err := configuredLocation()
			if err != nil {
				return err
			}
			current, err := weather.NewClient().Current(cmd.Context(), latitude, longitude)
			if err != nil {
				return err
			}
			return writeJSON(cmd, map[string]any{
				"location": paths.Setting(keyWeatherLocation),
				"current":  current,
			})
		},
	}
}

// configuredLocation reads the coordinates chosen in the settings panel.
func configuredLocation() (float64, float64, error) {
	latText := paths.Setting(keyWeatherLat)
	lonText := paths.Setting(keyWeatherLon)
	if latText == "" || lonText == "" {
		return 0, 0, errLocationNotSet
	}
	latitude, err := strconv.ParseFloat(latText, 64)
	if err != nil {
		return 0, 0, fmt.Errorf("%s is not a number: %w", keyWeatherLat, err)
	}
	longitude, err := strconv.ParseFloat(lonText, 64)
	if err != nil {
		return 0, 0, fmt.Errorf("%s is not a number: %w", keyWeatherLon, err)
	}
	return latitude, longitude, nil
}
