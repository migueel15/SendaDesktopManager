package main

import (
	"fmt"
	"os/exec"

	"github.com/migueel15/SendaDesktopManager/core/internal/googlecalendar"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/spf13/cobra"
)

func calendarCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "calendar",
		Short: "Manage the Google Calendar connection",
	}
	cmd.AddCommand(calendarLoginCmd(), calendarStatusCmd(), calendarLogoutCmd())
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

func newCalendarClient() *googlecalendar.Client {
	creds := googlecalendar.Credentials{
		ClientID:     paths.Setting("SENDA_GOOGLE_CLIENT_ID"),
		ClientSecret: paths.Setting("SENDA_GOOGLE_CLIENT_SECRET"),
	}
	store := googlecalendar.TokenStore{Path: paths.GoogleCalendarTokenFile()}
	return googlecalendar.NewClient(creds, store)
}
