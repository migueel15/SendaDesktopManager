package user

import (
	"fmt"
	"os"
	"os/user"
	"path/filepath"

	"github.com/godbus/dbus/v5"
)

const (
	accountsServiceName = "org.freedesktop.Accounts"
	userInterface       = "org.freedesktop.Accounts.User"
)

type User struct {
	userName string
	icon     string
}

type UserManager interface {
	GetUserName() string
	GetProfilePicture() string
	SetProfilePicture(path string)
	RemoveProfilePicture()
}

func LoadUser() (*User, error) {
	conn, err := dbus.SystemBus()
	if err != nil {
		return nil, nil
	}
	defer conn.Close()

	obj := currentUserObject(conn)

	name, err := getStringProperty(obj, userInterface+".UserName")
	if err != nil {
		return nil, err
	}
	icon, err := getStringProperty(obj, userInterface+".IconFile")
	if err != nil {
		return nil, err
	}

	return &User{
		userName: name,
		icon:     icon,
	}, nil
}

func (u *User) GetUserName() string {
	return u.userName
}

func (u *User) GetProfilePicture() string {
	return u.icon
}

func (u *User) SetProfilePicture(newIconPath string) error {
	absPath, err := filepath.Abs(newIconPath)
	if err != nil {
		return err
	}

	conn, err := dbus.SystemBus()
	if err != nil {
		return err
	}
	defer conn.Close()

	obj := currentUserObject(conn)

	call := obj.Call(userInterface+".SetIconFile", 0, absPath)
	if call.Err != nil {
		return call.Err
	}

	icon, err := getStringProperty(obj, userInterface+".IconFile")
	if err != nil {
		return err
	}

	u.icon = icon
	return nil
}

func (u *User) RemoveProfilePicture() error {

	conn, err := dbus.SystemBus()
	if err != nil {
		return err
	}
	defer conn.Close()

	uid := os.Getuid()
	path := dbus.ObjectPath(fmt.Sprintf("/org/freedesktop/Accounts/User%d", uid))
	user.Current()

	obj := conn.Object("org.freedesktop.Accounts", path)
	call := obj.Call("org.freedesktop.Accounts.User.SetIconFile", 0, "")

	if call.Err != nil {
		return call.Err
	}

	iconData, err := obj.GetProperty("org.freedesktop.Accounts.User.IconFile")
	u.icon = iconData.Value().(string)

	return nil
}

func currentUserObject(conn *dbus.Conn) dbus.BusObject {
	uid := os.Getuid()
	path := dbus.ObjectPath(fmt.Sprintf("/org/freedesktop/Accounts/User%d", uid))

	return conn.Object(accountsServiceName, path)
}

func getStringProperty(obj dbus.BusObject, property string) (string, error) {
	value, err := obj.GetProperty(property)
	if err != nil {
		return "", err
	}

	str, ok := value.Value().(string)
	if !ok {
		return "", fmt.Errorf("unexpected property type for %s: %T", property, value.Value())
	}

	return str, nil
}
