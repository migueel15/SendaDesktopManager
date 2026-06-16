package main

import (
	"os/exec"
	"strings"

	"github.com/spf13/cobra"
)

var brightnessCmd = &cobra.Command{
	Use:   "brightness",
	Short: "Brightness related commands",
}

var brightnessUpCmd = &cobra.Command{
	Use:   "up",
	Short: "Brightness up by 10%",
	RunE: func(cmd *cobra.Command, args []string) error {
		c := exec.Command("ddcutil", "detect")
		out, err := c.Output()
		if err != nil {
			return err
		}
		listID := getDisplayIds(string(out))
		for _, id := range listID {
			c := exec.Command("ddcutil", "setvcp", "--display", id, "10", "+", "10")
			err := c.Run()
			if err != nil {
				return err
			}
		}

		return nil
	},
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
	brightnessCmd.AddCommand(brightnessUpCmd)
}
