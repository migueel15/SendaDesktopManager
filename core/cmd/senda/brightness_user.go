package main

import (
	"fmt"
	"os/exec"
	"strconv"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/brightness"

	"github.com/spf13/cobra"
)

const brightnessStep = 10

var brightnessCmd = &cobra.Command{
	Use:   "brightness",
	Short: "Brightness related commands",
}

var brightnessUpCmd = &cobra.Command{
	Use:   "up",
	Short: "Brightness up by 10%",
	RunE: func(cmd *cobra.Command, args []string) error {
		return changeBrightness(cmd, brightnessStep)
	},
}

var brightnessDownCmd = &cobra.Command{
	Use:   "down",
	Short: "Brightness down by 10%",
	RunE: func(cmd *cobra.Command, args []string) error {
		return changeBrightness(cmd, -brightnessStep)
	},
}

var brightnessGetCmd = &cobra.Command{
	Use:   "get",
	Short: "Print the backlight percentage; prints nothing without a backlight",
	RunE: func(cmd *cobra.Command, args []string) error {
		if !brightness.Available() {
			return nil
		}
		percent, err := brightness.Get(cmd.Context())
		if err != nil {
			return err
		}
		fmt.Fprintln(cmd.OutOrStdout(), percent)
		return nil
	},
}

// changeBrightness adjusts the backlight first because ddcutil can take
// seconds, so the OSD responds at once. External monitors are best effort: a
// machine without DDC support must not fail.
func changeBrightness(cmd *cobra.Command, step int) error {
	var backlightErr error
	if brightness.Available() {
		var percent int
		percent, backlightErr = brightness.Change(cmd.Context(), step)
		if backlightErr == nil {
			// The shell may not be running; the brightness has changed anyway.
			_, _ = callShellIPC(cmd, "brightness", "show", strconv.Itoa(percent))
		}
	}
	if err := changeExternalBrightness(step); err != nil {
		fmt.Fprintln(cmd.ErrOrStderr(), "external monitors:", err)
	}
	return backlightErr
}

func changeExternalBrightness(step int) error {
	out, err := exec.Command("ddcutil", "detect").Output()
	if err != nil {
		return err
	}
	sign, amount := "+", step
	if step < 0 {
		sign, amount = "-", -step
	}
	for _, id := range getDisplayIds(string(out)) {
		c := exec.Command("ddcutil", "setvcp", "--display", id, "10", sign, strconv.Itoa(amount))
		if err := c.Run(); err != nil {
			return err
		}
	}
	return nil
}

func getDisplayIds(out string) []string {
	var listID []string

	for _, line := range strings.Split(out, "\n") {
		if strings.Contains(line, "Display") {
			listID = append(listID, strings.Split(line, " ")[1])
		}
	}

	return listID
}

func init() {
	brightnessCmd.AddCommand(brightnessUpCmd, brightnessDownCmd, brightnessGetCmd)
}
