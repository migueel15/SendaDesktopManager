package main

import "github.com/spf13/cobra"

var mediaCmd = &cobra.Command{
	Use:   "media",
	Short: "Control the active media player",
}

// mediaAction asks the shell, which already tracks the MPRIS players.
func mediaAction(use, short, function string) *cobra.Command {
	return &cobra.Command{
		Use:   use,
		Short: short,
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			_, err := callShellIPC(cmd, "media", function)
			return err
		},
	}
}

func init() {
	mediaCmd.AddCommand(
		mediaAction("play-pause", "Toggle playback", "playPause"),
		mediaAction("next", "Skip to the next track", "next"),
		mediaAction("previous", "Go back to the previous track", "previous"),
	)
}
