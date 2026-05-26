package user

import (
	"testing"
)

func TestName(t *testing.T) {
	user, _ := LoadUser()
	username := user.GetUserName()
	pic := user.GetProfilePicture()

	user.SetProfilePicture("/home/miguel/.config/hypr/wallpapers/arch.jpg")
	t.Log(username)
	t.Log(pic)

	// user.RemoveProfilePicture()
	// t.Log(username)
	// t.Log(pic)
}
