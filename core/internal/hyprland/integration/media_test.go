package integration

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestMediaModuleBindsEveryKey(t *testing.T) {
	generatedHome(t)
	out, err := renderMediaModule(moduleInput{Command: "'/bin/senda'"})
	if err != nil {
		t.Fatal(err)
	}
	if got := strings.Count(out, "hl.bind("); got != len(mediaKeys) {
		t.Fatalf("binds = %d\n%s", got, out)
	}
	for _, want := range []string{
		`hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, `,
		`hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, description`,
		`hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("'/bin/senda' brightness up"), { locked = true, repeating = true, `,
		`hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("'/bin/senda' media play-pause"), { locked = true, description`,
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %s\n%s", want, out)
		}
	}
}

func TestMediaModuleLeavesUserKeys(t *testing.T) {
	generatedHome(t)
	hypr := filepath.Dir(hyprConfigFile())
	if err := os.MkdirAll(hypr, 0o700); err != nil {
		t.Fatal(err)
	}
	config := `require("mine")
-- hl.bind("XF86AudioPlay", x)
hl.bind("SUPER + XF86AudioNext", x)
hl.bind(mod .. " + 1", x)
`
	if err := os.WriteFile(hyprConfigFile(), []byte(config), 0o600); err != nil {
		t.Fatal(err)
	}
	mine := `hl.bind("XF86AudioMute", exec("x"), {
	locked = true,
})
hl.bind(' + xf86audioprev', x)
`
	if err := os.WriteFile(filepath.Join(hypr, "mine.lua"), []byte(mine), 0o600); err != nil {
		t.Fatal(err)
	}
	out, err := renderMediaModule(moduleInput{Command: "senda"})
	if err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{`"XF86AudioMute"`, `"XF86AudioPrev"`} {
		if strings.Contains(out, key) {
			t.Errorf("%s belongs to the user\n%s", key, out)
		}
	}
	for _, key := range []string{`"XF86AudioPlay"`, `"XF86AudioNext"`, `"XF86AudioRaiseVolume"`} {
		if !strings.Contains(out, key) {
			t.Errorf("%s must stay\n%s", key, out)
		}
	}
}

func TestMediaModuleLeavesConfKeys(t *testing.T) {
	generatedHome(t)
	main := strings.TrimSuffix(hyprConfigFile(), ".lua") + ".conf"
	if err := os.MkdirAll(filepath.Dir(main), 0o700); err != nil {
		t.Fatal(err)
	}
	config := "bindel = , XF86AudioLowerVolume, exec, x\nbind = SUPER, XF86AudioMute, exec, x\n"
	if err := os.WriteFile(main, []byte(config), 0o600); err != nil {
		t.Fatal(err)
	}
	out, err := renderMediaModule(moduleInput{Command: "senda"})
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(out, `"XF86AudioLowerVolume"`) || !strings.Contains(out, `"XF86AudioMute"`) {
		t.Errorf("conf detection failed\n%s", out)
	}
}
