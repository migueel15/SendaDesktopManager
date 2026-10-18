// Package weather reads the current conditions for a place from Open-Meteo,
// which needs no API key. The place is chosen by hand in the settings panel.
package weather

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

const (
	maxResponse      = 1 << 20
	minSearchLength  = 2
	maxSearchResults = 8
)

// ErrQueryTooShort means the place name is too short to search for.
var ErrQueryTooShort = errors.New("type at least two characters to search for a place")

// Endpoints are Open-Meteo's URLs. Tests replace them with a local server.
type Endpoints struct {
	Geocoding string
	Forecast  string
}

// DefaultEndpoints are the public Open-Meteo URLs.
var DefaultEndpoints = Endpoints{
	Geocoding: "https://geocoding-api.open-meteo.com/v1/search",
	Forecast:  "https://api.open-meteo.com/v1/forecast",
}

// Client calls Open-Meteo.
type Client struct {
	endpoints Endpoints
	http      *http.Client
}

// NewClient returns a client that calls the public Open-Meteo API.
func NewClient() *Client {
	return &Client{endpoints: DefaultEndpoints, http: &http.Client{Timeout: 15 * time.Second}}
}

// Place is one search result. Its coordinates are what the forecast uses.
type Place struct {
	Name      string  `json:"name"`
	Admin     string  `json:"admin"`
	Country   string  `json:"country"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

// Current is the forecast the dashboard shows. Condition is a stable key the
// UI maps to an icon; Label is the same condition in Spanish.
type Current struct {
	Temperature float64 `json:"temperature"`
	Min         float64 `json:"min"`
	Max         float64 `json:"max"`
	Condition   string  `json:"condition"`
	Label       string  `json:"label"`
}

type geocodingResponse struct {
	Results []struct {
		Name      string  `json:"name"`
		Admin1    string  `json:"admin1"`
		Country   string  `json:"country"`
		Latitude  float64 `json:"latitude"`
		Longitude float64 `json:"longitude"`
	} `json:"results"`
}

type forecastResponse struct {
	Current struct {
		Temperature float64 `json:"temperature_2m"`
		WeatherCode int     `json:"weather_code"`
	} `json:"current"`
	Daily struct {
		TemperatureMax []float64 `json:"temperature_2m_max"`
		TemperatureMin []float64 `json:"temperature_2m_min"`
	} `json:"daily"`
}

// Search returns up to maxSearchResults places whose names match query, in
// Spanish.
func (c *Client) Search(ctx context.Context, query string) ([]Place, error) {
	query = strings.TrimSpace(query)
	if len([]rune(query)) < minSearchLength {
		return nil, ErrQueryTooShort
	}

	var response geocodingResponse
	if err := c.getJSON(ctx, c.endpoints.Geocoding, url.Values{
		"name":     {query},
		"count":    {fmt.Sprint(maxSearchResults)},
		"language": {"es"},
		"format":   {"json"},
	}, &response); err != nil {
		return nil, err
	}

	places := []Place{}
	for _, result := range response.Results {
		places = append(places, Place{
			Name:      result.Name,
			Admin:     result.Admin1,
			Country:   result.Country,
			Latitude:  result.Latitude,
			Longitude: result.Longitude,
		})
	}
	return places, nil
}

// Current returns the temperature now and the range for today at the given
// coordinates.
func (c *Client) Current(ctx context.Context, latitude, longitude float64) (Current, error) {
	var response forecastResponse
	if err := c.getJSON(ctx, c.endpoints.Forecast, url.Values{
		"latitude":      {strconv.FormatFloat(latitude, 'f', -1, 64)},
		"longitude":     {strconv.FormatFloat(longitude, 'f', -1, 64)},
		"current":       {"temperature_2m,weather_code"},
		"daily":         {"temperature_2m_max,temperature_2m_min"},
		"forecast_days": {"1"},
		"timezone":      {"auto"},
	}, &response); err != nil {
		return Current{}, err
	}

	if len(response.Daily.TemperatureMax) == 0 || len(response.Daily.TemperatureMin) == 0 {
		return Current{}, errors.New("forecast response has no daily range")
	}
	key, label := Condition(response.Current.WeatherCode)
	return Current{
		Temperature: response.Current.Temperature,
		Min:         response.Daily.TemperatureMin[0],
		Max:         response.Daily.TemperatureMax[0],
		Condition:   key,
		Label:       label,
	}, nil
}

// Condition maps a WMO weather code, as Open-Meteo returns it, to a stable key
// and a Spanish label.
func Condition(code int) (string, string) {
	switch {
	case code == 0:
		return "clear", "Despejado"
	case code == 1:
		return "mostly-clear", "Mayormente despejado"
	case code == 2:
		return "partly-cloudy", "Parcialmente nublado"
	case code == 3:
		return "cloudy", "Nublado"
	case code == 45 || code == 48:
		return "fog", "Niebla"
	case code >= 51 && code <= 57:
		return "drizzle", "Llovizna"
	case code >= 61 && code <= 67, code >= 80 && code <= 82:
		return "rain", "Lluvia"
	case code >= 71 && code <= 77, code == 85 || code == 86:
		return "snow", "Nieve"
	case code >= 95 && code <= 99:
		return "storm", "Tormenta"
	default:
		return "unknown", "Tiempo variable"
	}
}

func (c *Client) getJSON(ctx context.Context, endpoint string, query url.Values, target any) error {
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint+"?"+query.Encode(), nil)
	if err != nil {
		return err
	}
	response, err := c.http.Do(request)
	if err != nil {
		return fmt.Errorf("reach the weather service: %w", err)
	}
	defer response.Body.Close()

	body, err := io.ReadAll(io.LimitReader(response.Body, maxResponse))
	if err != nil {
		return err
	}
	if response.StatusCode != http.StatusOK {
		return fmt.Errorf("weather service returned status %d", response.StatusCode)
	}
	if err := json.Unmarshal(body, target); err != nil {
		return fmt.Errorf("decode weather response: %w", err)
	}
	return nil
}
