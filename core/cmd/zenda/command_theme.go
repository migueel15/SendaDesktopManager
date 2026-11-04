package main

import "github.com/spf13/cobra"

var themeSubcommands []func() *cobra.Command

// registerThemeSubcommand lets independent command files register from init.
func registerThemeSubcommand(factory func() *cobra.Command) {
	themeSubcommands = append(themeSubcommands, factory)
}

func themeCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "theme", Short: "Manage shell themes"}
	for _, factory := range themeSubcommands {
		cmd.AddCommand(factory())
	}
	return cmd
}

func reloadShellTheme(cmd *cobra.Command) error {
	pid := readPidData()
	if pid <= 0 || !isProcessRunning(pid) {
		return nil
	}
	_, err := callShellIPCResult(cmd, "theme", "reload")
	return err
}
