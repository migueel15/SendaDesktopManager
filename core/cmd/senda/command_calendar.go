package main

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/googlecalendar"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/spf13/cobra"
)

func calendarCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "calendar",
		Short: "Manage the Google Calendar connection",
	}
	cmd.AddCommand(calendarLoginCmd(), calendarStatusCmd(), calendarLogoutCmd(), calendarListCmd(), calendarEventsCmd())
	return cmd
}

func calendarLoginCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "login",
		Short: "Connect Senda to a Google account",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			client := newCalendarClient()
			err := client.Login(cmd.Context(), func(authURL string) error {
				fmt.Fprintf(cmd.OutOrStdout(), "Open this link to connect Google Calendar:\n%s\n", authURL)
				// The printed link is the fallback when no browser opens.
				_ = exec.Command("xdg-open", authURL).Start()
				return nil
			})
			if err != nil {
				return err
			}
			fmt.Fprintln(cmd.OutOrStdout(), "Google Calendar connected.")
			return nil
		},
	}
}

func calendarStatusCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show whether Google Calendar is connected",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			connected, err := newCalendarClient().Connected()
			if err != nil {
				return err
			}
			if connected {
				fmt.Fprintln(cmd.OutOrStdout(), "connected")
			} else {
				fmt.Fprintln(cmd.OutOrStdout(), "not connected")
			}
			return nil
		},
	}
}

func calendarLogoutCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "logout",
		Short: "Disconnect Google Calendar and revoke Senda's access",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			if err := newCalendarClient().Logout(cmd.Context()); err != nil {
				return err
			}
			fmt.Fprintln(cmd.OutOrStdout(), "Google Calendar disconnected.")
			return nil
		},
	}
}

func calendarListCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "Print the visible Google calendars as JSON",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			calendars, err := newCalendarClient().ListCalendars(cmd.Context())
			if err != nil {
				return err
			}
			return writeJSON(cmd, map[string]any{"calendars": calendars})
		},
	}
}

func calendarEventsCmd() *cobra.Command {
	var from, to string
	cmd := &cobra.Command{
		Use:   "events --from YYYY-MM-DD --to YYYY-MM-DD",
		Short: "Print the events in a date range as JSON",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			start, err := time.ParseInLocation("2006-01-02", from, time.Local)
			if err != nil {
				return fmt.Errorf("--from must be YYYY-MM-DD: %w", err)
			}
			end, err := time.ParseInLocation("2006-01-02", to, time.Local)
			if err != nil {
				return fmt.Errorf("--to must be YYYY-MM-DD: %w", err)
			}
			if !end.After(start) {
				return fmt.Errorf("--to must be after --from")
			}

			client := newCalendarClient()
			calendarIDs, err := client.ResolveCalendars(cmd.Context(), configuredCalendars())
			if err != nil {
				return err
			}
			events, err := client.Events(cmd.Context(), calendarIDs, start, end)
			if err != nil {
				return err
			}
			return writeJSON(cmd, map[string]any{"events": events})
		},
	}
	cmd.Flags().StringVar(&from, "from", "", "first day to include (YYYY-MM-DD)")
	cmd.Flags().StringVar(&to, "to", "", "day after the last one to include (YYYY-MM-DD)")
	_ = cmd.MarkFlagRequired("from")
	_ = cmd.MarkFlagRequired("to")
	return cmd
}

// configuredCalendars reads SENDA_GOOGLE_CALENDARS, a comma-separated list of
// calendar IDs chosen in the settings panel. An empty list means "use the
// calendars Google shows as selected".
func configuredCalendars() []string {
	var ids []string
	for _, id := range strings.Split(paths.Setting("SENDA_GOOGLE_CALENDARS"), ",") {
		if id = strings.TrimSpace(id); id != "" {
			ids = append(ids, id)
		}
	}
	return ids
}

func writeJSON(cmd *cobra.Command, value any) error {
	encoder := json.NewEncoder(cmd.OutOrStdout())
	return encoder.Encode(value)
}

func newCalendarClient() *googlecalendar.Client {
	creds := googlecalendar.ResolveCredentials(
		paths.Setting(keyGoogleClientID),
		paths.Secret(keyGoogleClientSecret),
	)
	store := googlecalendar.TokenStore{Path: paths.GoogleCalendarTokenFile()}
	return googlecalendar.NewClient(creds, store)
}
