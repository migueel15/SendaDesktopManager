package quickshell

import (
	"encoding/json"
	"errors"
	"reflect"
	"testing"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/wallpaper"
)

func TestSetIPCContract(t *testing.T) {
	for _, explicit := range []bool{false, true} {
		options := wallpaper.SetOptions{}
		expected := `{"path":"/images/a b.png","monitor":"","resize":"crop","transition":{"type":"none","durationMs":3000,"pos":null,"bezier":[0.61,0.18,0.48,0.9]}}`
		if explicit {
			monitor := wallpaper.Monitor("DP-1")
			resize := wallpaper.ResizeFit
			options = wallpaper.SetOptions{Monitor: &monitor, Resize: &resize, Animation: &wallpaper.Animation{
				Kind: wallpaper.AnimationOuter, Duration: 1250 * time.Millisecond, FPS: 144,
				Origin: &wallpaper.Position{X: 100, Y: 200}, Bezier: [4]float64{0, -1, 1, 2},
			}}
			expected = `{"path":"/images/a b.png","monitor":"DP-1","resize":"fit","transition":{"type":"outer","durationMs":1250,"pos":{"x":100,"y":200},"bezier":[0,-1,1,2]}}`
		}
		calls := 0
		backend := NewBackend(func(target, function string, args ...string) (string, error) {
			calls++
			if target != "wallpaper" || function != "set" || len(args) != 1 {
				t.Fatalf("call = %s %s %v", target, function, args)
			}
			var got, want interface{}
			if err := json.Unmarshal([]byte(args[0]), &got); err != nil {
				t.Fatal(err)
			}
			if err := json.Unmarshal([]byte(expected), &want); err != nil {
				t.Fatal(err)
			}
			if !reflect.DeepEqual(got, want) {
				t.Fatalf("JSON = %s, want %s", args[0], expected)
			}
			return "", nil
		})
		if err := wallpaper.NewService(backend).Set(wallpaper.Wallpaper{Path: "/images/a b.png"}, options); err != nil {
			t.Fatal(err)
		}
		if calls != 1 {
			t.Fatalf("calls = %d", calls)
		}
	}
}

func TestSetPropagatesErrorsThroughService(t *testing.T) {
	transport := errors.New("shell unavailable")
	for _, tc := range []struct {
		result string
		err    error
		want   string
	}{
		{err: transport, want: "shell unavailable"}, {result: "unknown monitor", want: "unknown monitor"},
	} {
		backend := NewBackend(func(string, string, ...string) (string, error) { return tc.result, tc.err })
		err := wallpaper.NewService(backend).Set(wallpaper.Wallpaper{}, wallpaper.SetOptions{})
		if err == nil || err.Error() != tc.want {
			t.Fatalf("error = %v, want %q", err, tc.want)
		}
		if tc.err != nil && !errors.Is(err, transport) {
			t.Fatal("transport error identity lost")
		}
	}
}
