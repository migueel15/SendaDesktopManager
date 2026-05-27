package main

import (
	"github.com/migueel15/SendaDesktopManager/core/internal/user"
	"github.com/spf13/cobra"
)

var userCmd = &cobra.Command{
	Use:   "user",
	Short: "User related commands",
}

var profileCmd = &cobra.Command{
	Use:   "profile",
	Short: "User profile picture actions",
}

var setProfileCmd = &cobra.Command{
	Use:   "set",
	Short: "Set user profile picture",
	Run: func(cmd *cobra.Command, args []string) {
		user, err := user.LoadUser()
		if err != nil {
			return
		}

		user.SetProfilePicture(args[0])
	},
}

var removeProfileCmd = &cobra.Command{
	Use:   "remove",
	Short: "Remove user profile picture",
	Run: func(cmd *cobra.Command, args []string) {
		user, err := user.LoadUser()
		if err != nil {
			return
		}

		user.RemoveProfilePicture()
	},
}

func init() {
	userCmd.AddCommand(profileCmd)
	profileCmd.AddCommand(setProfileCmd)
	profileCmd.AddCommand(removeProfileCmd)
}
