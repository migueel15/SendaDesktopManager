package googlecalendar

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sort"
	"time"
)

const (
	maxEventPages   = 20
	eventsPageSize  = "250"
	untitledEvent   = "(sin título)"
	dateLayout      = "2006-01-02"
	cancelledStatus = "cancelled"
)

// Calendar is one entry in the user's calendar list.
type Calendar struct {
	ID       string `json:"id"`
	Summary  string `json:"summary"`
	Selected bool   `json:"selected"`
}

// Event is what the dashboard draws. Start and End are RFC 3339 for timed
// events and YYYY-MM-DD for all-day events, which is when AllDay is true.
type Event struct {
	ID       string `json:"id"`
	Calendar string `json:"calendar"`
	Title    string `json:"title"`
	Start    string `json:"start"`
	End      string `json:"end"`
	AllDay   bool   `json:"allDay"`
	// Link opens the event in Google Calendar, as Google returns it.
	Link string `json:"link"`
}

type calendarListResponse struct {
	Items []struct {
		ID       string `json:"id"`
		Summary  string `json:"summary"`
		Selected bool   `json:"selected"`
		Hidden   bool   `json:"hidden"`
	} `json:"items"`
}

type googleEventTime struct {
	DateTime string `json:"dateTime"`
	Date     string `json:"date"`
}

type googleEvent struct {
	ID       string          `json:"id"`
	Status   string          `json:"status"`
	Summary  string          `json:"summary"`
	HTMLLink string          `json:"htmlLink"`
	Start    googleEventTime `json:"start"`
	End      googleEventTime `json:"end"`
}

type eventsResponse struct {
	Items         []googleEvent `json:"items"`
	NextPageToken string        `json:"nextPageToken"`
}

// ListCalendars returns the calendars in the user's list, without the ones the
// user has hidden in Google Calendar.
func (c *Client) ListCalendars(ctx context.Context) ([]Calendar, error) {
	var response calendarListResponse
	if err := c.getJSON(ctx, c.endpoints.Calendar+"/users/me/calendarList", url.Values{
		"maxResults": {"250"},
	}, &response); err != nil {
		return nil, err
	}

	calendars := []Calendar{}
	for _, item := range response.Items {
		if item.Hidden {
			continue
		}
		calendars = append(calendars, Calendar{ID: item.ID, Summary: item.Summary, Selected: item.Selected})
	}
	return calendars, nil
}

// ResolveCalendars returns the IDs to read. A configured list wins; otherwise
// it uses the calendars Google shows as selected, which matches what the user
// sees in Google Calendar.
func (c *Client) ResolveCalendars(ctx context.Context, configured []string) ([]string, error) {
	if len(configured) > 0 {
		return configured, nil
	}

	calendars, err := c.ListCalendars(ctx)
	if err != nil {
		return nil, err
	}
	ids := []string{}
	for _, calendar := range calendars {
		if calendar.Selected {
			ids = append(ids, calendar.ID)
		}
	}
	return ids, nil
}

// Events returns the events that start in [from, to) on the given calendars,
// with recurring events expanded into single occurrences, sorted by start.
func (c *Client) Events(ctx context.Context, calendarIDs []string, from, to time.Time) ([]Event, error) {
	events := []Event{}
	for _, id := range calendarIDs {
		calendarEvents, err := c.calendarEvents(ctx, id, from, to)
		if err != nil {
			return nil, err
		}
		events = append(events, calendarEvents...)
	}

	sort.SliceStable(events, func(i, j int) bool {
		return sortKey(events[i].Start).Before(sortKey(events[j].Start))
	})
	return events, nil
}

func (c *Client) calendarEvents(ctx context.Context, calendarID string, from, to time.Time) ([]Event, error) {
	endpoint := c.endpoints.Calendar + "/calendars/" + url.PathEscape(calendarID) + "/events"

	events := []Event{}
	pageToken := ""
	for page := 0; page < maxEventPages; page++ {
		query := url.Values{
			"timeMin":      {from.Format(time.RFC3339)},
			"timeMax":      {to.Format(time.RFC3339)},
			"singleEvents": {"true"},
			"orderBy":      {"startTime"},
			"maxResults":   {eventsPageSize},
		}
		if pageToken != "" {
			query.Set("pageToken", pageToken)
		}

		var response eventsResponse
		if err := c.getJSON(ctx, endpoint, query, &response); err != nil {
			return nil, err
		}
		for _, item := range response.Items {
			if item.Status == cancelledStatus {
				continue
			}
			events = append(events, toEvent(item, calendarID))
		}

		if response.NextPageToken == "" {
			return events, nil
		}
		pageToken = response.NextPageToken
	}
	return nil, fmt.Errorf("calendar has more than %d pages of events in the range", maxEventPages)
}

func toEvent(item googleEvent, calendarID string) Event {
	event := Event{
		ID:       item.ID,
		Calendar: calendarID,
		Title:    item.Summary,
		Link:     item.HTMLLink,
	}
	if event.Title == "" {
		event.Title = untitledEvent
	}
	if item.Start.Date != "" {
		event.AllDay = true
		event.Start = item.Start.Date
		event.End = item.End.Date
		return event
	}
	event.Start = item.Start.DateTime
	event.End = item.End.DateTime
	return event
}

// sortKey converts a Start value to a time so timed and all-day events sort
// together. All-day events sort at local midnight.
func sortKey(start string) time.Time {
	if parsed, err := time.Parse(time.RFC3339, start); err == nil {
		return parsed
	}
	if parsed, err := time.ParseInLocation(dateLayout, start, time.Local); err == nil {
		return parsed
	}
	return time.Time{}
}

func (c *Client) getJSON(ctx context.Context, endpoint string, query url.Values, target any) error {
	token, err := c.AccessToken(ctx)
	if err != nil {
		return err
	}

	request, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint+"?"+query.Encode(), nil)
	if err != nil {
		return err
	}
	request.Header.Set("Authorization", "Bearer "+token)

	response, err := c.http.Do(request)
	if err != nil {
		return fmt.Errorf("reach google calendar: %w", err)
	}
	defer response.Body.Close()

	body, err := io.ReadAll(io.LimitReader(response.Body, maxResponse))
	if err != nil {
		return err
	}
	switch response.StatusCode {
	case http.StatusOK:
		if err := json.Unmarshal(body, target); err != nil {
			return fmt.Errorf("decode google calendar response: %w", err)
		}
		return nil
	case http.StatusUnauthorized:
		return ErrSessionExpired
	default:
		return fmt.Errorf("google calendar request failed with status %d", response.StatusCode)
	}
}
