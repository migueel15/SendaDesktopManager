package weather

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

func newTestClient(t *testing.T, handler http.HandlerFunc) *Client {
	t.Helper()
	server := httptest.NewServer(handler)
	t.Cleanup(server.Close)
	return &Client{
		endpoints: Endpoints{Geocoding: server.URL + "/geo", Forecast: server.URL + "/forecast"},
		http:      server.Client(),
	}
}

func TestSearchReturnsPlacesFromGeocoding(t *testing.T) {
	client := newTestClient(t, func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/geo" || r.URL.Query().Get("name") != "Valencia" || r.URL.Query().Get("language") != "es" {
			http.Error(w, "unexpected request", http.StatusBadRequest)
			return
		}
		fmt.Fprint(w, `{"results":[{"name":"Valencia","admin1":"Comunidad Valenciana","country":"España","latitude":39.46975,"longitude":-0.37739}]}`)
	})

	places, err := client.Search(context.Background(), " Valencia ")
	if err != nil {
		t.Fatalf("Search() error = %v", err)
	}
	if len(places) != 1 || places[0].Admin != "Comunidad Valenciana" || places[0].Latitude != 39.46975 {
		t.Fatalf("Search() = %+v", places)
	}
}

func TestSearchWithoutResultsIsEmptyNotNil(t *testing.T) {
	client := newTestClient(t, func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"generationtime_ms":0.1}`)
	})

	places, err := client.Search(context.Background(), "Zzzzzz")
	if err != nil {
		t.Fatalf("Search() error = %v", err)
	}
	if places == nil || len(places) != 0 {
		t.Fatalf("Search() = %#v, want an empty list", places)
	}
}

func TestSearchRejectsShortQueryWithoutCalling(t *testing.T) {
	client := newTestClient(t, func(w http.ResponseWriter, r *http.Request) {
		t.Error("the service must not be called for a short query")
	})

	if _, err := client.Search(context.Background(), "a"); !errors.Is(err, ErrQueryTooShort) {
		t.Fatalf("Search() error = %v, want ErrQueryTooShort", err)
	}
}

func TestCurrentReturnsTemperatureRangeAndCondition(t *testing.T) {
	client := newTestClient(t, func(w http.ResponseWriter, r *http.Request) {
		query := r.URL.Query()
		if query.Get("latitude") != "39.47" || query.Get("longitude") != "-0.38" || query.Get("timezone") != "auto" {
			http.Error(w, "unexpected coordinates", http.StatusBadRequest)
			return
		}
		fmt.Fprint(w, `{"current":{"temperature_2m":21.4,"weather_code":61},"daily":{"temperature_2m_max":[24.1],"temperature_2m_min":[15.2],"sunrise":["2026-10-18T08:12"],"sunset":["2026-10-18T19:02"]}}`)
	})

	current, err := client.Current(context.Background(), 39.47, -0.38)
	if err != nil {
		t.Fatalf("Current() error = %v", err)
	}
	if current.Temperature != 21.4 || current.Min != 15.2 || current.Max != 24.1 {
		t.Fatalf("Current() = %+v", current)
	}
	if current.Sunrise != "2026-10-18T08:12" || current.Sunset != "2026-10-18T19:02" {
		t.Fatalf("sunrise/sunset = %q / %q", current.Sunrise, current.Sunset)
	}
	if current.Condition != "rain" || current.Label != "Lluvia" {
		t.Fatalf("condition = %q / %q", current.Condition, current.Label)
	}
}

func TestCurrentFailsWithoutSunTimes(t *testing.T) {
	client := newTestClient(t, func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"current":{"temperature_2m":21.4,"weather_code":0},"daily":{"temperature_2m_max":[24.1],"temperature_2m_min":[15.2]}}`)
	})

	if _, err := client.Current(context.Background(), 1, 1); err == nil {
		t.Fatal("Current() accepted a response without sunrise or sunset")
	}
}

func TestCurrentFailsWithoutDailyRange(t *testing.T) {
	client := newTestClient(t, func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"current":{"temperature_2m":21.4,"weather_code":0},"daily":{}}`)
	})

	if _, err := client.Current(context.Background(), 1, 1); err == nil {
		t.Fatal("Current() accepted a response without a daily range")
	}
}

func TestCurrentReportsServiceErrors(t *testing.T) {
	client := newTestClient(t, func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "boom", http.StatusInternalServerError)
	})

	if _, err := client.Current(context.Background(), 1, 1); err == nil {
		t.Fatal("Current() ignored a 500 response")
	}
}

func TestConditionMapsWMOCodes(t *testing.T) {
	cases := map[int]string{
		0: "clear", 2: "partly-cloudy", 3: "cloudy", 45: "fog", 53: "drizzle",
		63: "rain", 81: "rain", 73: "snow", 86: "snow", 95: "storm", 99: "storm",
	}
	for code, want := range cases {
		if key, _ := Condition(code); key != want {
			t.Fatalf("Condition(%d) = %q, want %q", code, key, want)
		}
	}
	if key, _ := Condition(1234); key != "unknown" {
		t.Fatalf("unknown code mapped to %q", key)
	}
}
