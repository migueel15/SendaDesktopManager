package googlecalendar

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"
)

// newCalendarClientWithToken returns a client whose access token is already
// cached, so tests only exercise the Calendar API calls.
func newCalendarClientWithToken(t *testing.T, fake *fakeGoogle) *Client {
	t.Helper()
	client, store := newTestClient(t, fake, testCreds)
	if err := store.Save("refresh-1"); err != nil {
		t.Fatal(err)
	}
	client.accessToken = "access-cached"
	client.expiresAt = time.Now().Add(time.Hour)
	return client
}

func TestListCalendarsSkipsHiddenCalendars(t *testing.T) {
	fake := newFakeGoogle(t)
	fake.calendarHandler = func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/users/me/calendarList" {
			http.NotFound(w, r)
			return
		}
		if r.Header.Get("Authorization") != "Bearer access-cached" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		fmt.Fprint(w, `{"items":[
			{"id":"main@example.test","summary":"Personal","selected":true},
			{"id":"work@example.test","summary":"Trabajo","selected":false},
			{"id":"old@example.test","summary":"Antiguo","selected":true,"hidden":true}
		]}`)
	}
	client := newCalendarClientWithToken(t, fake)

	calendars, err := client.ListCalendars(context.Background())
	if err != nil {
		t.Fatalf("ListCalendars() error = %v", err)
	}
	if len(calendars) != 2 {
		t.Fatalf("ListCalendars() = %v, want 2 visible calendars", calendars)
	}
	if calendars[0].ID != "main@example.test" || !calendars[0].Selected {
		t.Fatalf("first calendar = %+v", calendars[0])
	}
}

func TestResolveCalendarsUsesConfiguredIDsFirst(t *testing.T) {
	fake := newFakeGoogle(t)
	fake.calendarHandler = func(w http.ResponseWriter, r *http.Request) {
		t.Error("calendar list must not be requested when IDs are configured")
	}
	client := newCalendarClientWithToken(t, fake)

	ids, err := client.ResolveCalendars(context.Background(), []string{"chosen@example.test"})
	if err != nil {
		t.Fatalf("ResolveCalendars() error = %v", err)
	}
	if len(ids) != 1 || ids[0] != "chosen@example.test" {
		t.Fatalf("ResolveCalendars() = %v", ids)
	}
}

func TestResolveCalendarsFallsBackToSelectedCalendars(t *testing.T) {
	fake := newFakeGoogle(t)
	fake.calendarHandler = func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"items":[
			{"id":"main@example.test","selected":true},
			{"id":"work@example.test","selected":false}
		]}`)
	}
	client := newCalendarClientWithToken(t, fake)

	ids, err := client.ResolveCalendars(context.Background(), nil)
	if err != nil {
		t.Fatalf("ResolveCalendars() error = %v", err)
	}
	if len(ids) != 1 || ids[0] != "main@example.test" {
		t.Fatalf("ResolveCalendars() = %v, want only the selected calendar", ids)
	}
}

func TestEventsPagesSkipsCancelledAndSortsByStart(t *testing.T) {
	fake := newFakeGoogle(t)
	fake.calendarHandler = func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasPrefix(r.URL.Path, "/calendars/main@example.test/events") {
			http.NotFound(w, r)
			return
		}
		query := r.URL.Query()
		if query.Get("singleEvents") != "true" || query.Get("orderBy") != "startTime" {
			http.Error(w, "missing expansion parameters", http.StatusBadRequest)
			return
		}
		if query.Get("pageToken") == "" {
			fmt.Fprint(w, `{"nextPageToken":"page-2","items":[
				{"id":"late","summary":"Tarde","status":"confirmed","start":{"dateTime":"2026-10-18T18:00:00+02:00"},"end":{"dateTime":"2026-10-18T19:00:00+02:00"}},
				{"id":"gone","summary":"Cancelado","status":"cancelled","start":{"dateTime":"2026-10-18T09:00:00+02:00"},"end":{"dateTime":"2026-10-18T10:00:00+02:00"}}
			]}`)
			return
		}
		fmt.Fprint(w, `{"items":[
			{"id":"holiday","status":"confirmed","start":{"date":"2026-10-18"},"end":{"date":"2026-10-19"}},
			{"id":"early","summary":"Temprano","status":"confirmed","htmlLink":"https://www.google.com/calendar/event?eid=abc","start":{"dateTime":"2026-10-18T08:30:00+02:00"},"end":{"dateTime":"2026-10-18T09:00:00+02:00"}}
		]}`)
	}
	client := newCalendarClientWithToken(t, fake)

	from := time.Date(2026, 10, 18, 0, 0, 0, 0, time.UTC)
	events, err := client.Events(context.Background(), []string{"main@example.test"}, from, from.AddDate(0, 0, 1))
	if err != nil {
		t.Fatalf("Events() error = %v", err)
	}

	if len(events) != 3 {
		t.Fatalf("Events() returned %d events, want 3 (cancelled one skipped): %+v", len(events), events)
	}
	titles := []string{events[0].Title, events[1].Title, events[2].Title}
	wantTitles := []string{"(sin título)", "Temprano", "Tarde"}
	for i := range wantTitles {
		if titles[i] != wantTitles[i] {
			t.Fatalf("titles = %v, want %v", titles, wantTitles)
		}
	}
	if !events[0].AllDay || events[0].Start != "2026-10-18" {
		t.Fatalf("all-day event = %+v", events[0])
	}
	if events[1].AllDay || events[1].Calendar != "main@example.test" {
		t.Fatalf("timed event = %+v", events[1])
	}
	if events[1].Link != "https://www.google.com/calendar/event?eid=abc" {
		t.Fatalf("link = %q, want the htmlLink from Google", events[1].Link)
	}
}

func TestEventsReportsUnauthorizedAsExpiredSession(t *testing.T) {
	fake := newFakeGoogle(t)
	fake.calendarHandler = func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
	}
	client := newCalendarClientWithToken(t, fake)

	_, err := client.Events(context.Background(), []string{"main@example.test"}, time.Now(), time.Now().Add(time.Hour))
	if !errors.Is(err, ErrSessionExpired) {
		t.Fatalf("Events() error = %v, want ErrSessionExpired", err)
	}
}

func TestEventsJSONUsesDashboardFieldNames(t *testing.T) {
	data, err := json.Marshal(Event{ID: "1", Calendar: "c", Title: "t", Start: "s", End: "e", AllDay: true})
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{`"allDay":true`, `"calendar":"c"`, `"start":"s"`} {
		if !strings.Contains(string(data), want) {
			t.Fatalf("json %s is missing %s", data, want)
		}
	}
}
