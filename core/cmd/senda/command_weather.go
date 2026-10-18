package main

import (
	"errors"
	"fmt"
	"strconv"

	"github.com/migueel15/SendaDesktopManager/core/internal/location"
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
			place, err := configuredLocation()
			if err != nil {
				return err
			}
			current, err := weather.NewClient().Current(cmd.Context(), place.Latitude, place.Longitude)
			if err != nil {
				return err
			}
			return writeJSON(cmd, map[string]any{
				"location": place.Name,
				"current":  current,
			})
		},
	}
}

// configuredLocation returns the place chosen in the settings panel. Without a
// choice, it falls back to the capital of the system time zone.
func configuredLocation() (location.Place, error) {
	latText := paths.Setting(keyWeatherLat)
	lonText := paths.Setting(keyWeatherLon)
	if latText == "" && lonText == "" {
		if place, ok := location.Default(); ok {
			return place, nil
		}
		return location.Place{}, errLocationNotSet
	}
	if latText == "" || lonText == "" {
		return location.Place{}, errLocationNotSet
	}
	latitude, err := strconv.ParseFloat(latText, 64)
	if err != nil {
		return location.Place{}, fmt.Errorf("%s is not a number: %w", keyWeatherLat, err)
	}
	longitude, err := strconv.ParseFloat(lonText, 64)
	if err != nil {
		return location.Place{}, fmt.Errorf("%s is not a number: %w", keyWeatherLon, err)
	}
	return location.Place{
		Name:      paths.Setting(keyWeatherLocation),
		Latitude:  latitude,
		Longitude: longitude,
	}, nil
}
