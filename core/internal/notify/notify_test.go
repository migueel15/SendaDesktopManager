package notify

import (
	"testing"

	"github.com/godbus/dbus/v5"
)

func TestNotificationArguments(t *testing.T) {
	args := arguments("Summary", "Body")
	if signature := dbus.SignatureOf(args...).String(); signature != "susssasa{sv}i" {
		t.Fatal(signature)
	}
	if args[0] != "Senda" || args[3] != "Summary" || args[4] != "Body" || args[7] != int32(-1) {
		t.Fatal(args)
	}
}
