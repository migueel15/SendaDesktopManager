package theme

import (
	"encoding/json"
	"errors"
	"image"
	"image/color"
	"image/gif"
	"image/jpeg"
	"image/png"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"strings"
	"testing"
)

const assets = "../../../quickshell/themes"

func write(t *testing.T, path string, data []byte) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, data, 0644); err != nil {
		t.Fatal(err)
	}
}
func fixture(t *testing.T) (string, map[string]interface{}) {
	t.Helper()
	data, err := os.ReadFile(filepath.Join(assets, "template.json"))
	if err != nil {
		t.Fatal(err)
	}
	var value map[string]interface{}
	if err := json.Unmarshal(data, &value); err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	f, err := os.Create(filepath.Join(dir, "wallpaper.png"))
	if err != nil {
		t.Fatal(err)
	}
	if err := png.Encode(f, image.NewRGBA(image.Rect(0, 0, 2, 2))); err != nil {
		t.Fatal(err)
	}
	f.Close()
	return dir, value
}
func save(t *testing.T, dir string, value interface{}) string {
	t.Helper()
	data, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(dir, "theme.json")
	write(t, path, data)
	return path
}
func field(t *testing.T, err error, want string) {
	t.Helper()
	var v *ValidationError
	if !errors.As(err, &v) || v.Field != want {
		t.Fatalf("error = %v, want field %s", err, want)
	}
}

func TestContractAssets(t *testing.T) {
	dir, value := fixture(t)
	if _, err := Load(save(t, dir, value)); err != nil {
		t.Fatal(err)
	}
	builtin, err := Load(filepath.Join(assets, "zenda-ice/theme.json"))
	if err != nil {
		t.Fatal(err)
	}
	if DefaultTheme != "zenda-ice" || builtin.Name != DefaultTheme {
		t.Fatal("default theme mismatch")
	}
	data, err := os.ReadFile(filepath.Join(assets, "theme.schema.json"))
	if err != nil {
		t.Fatal(err)
	}
	var schema struct {
		Schema     string `json:"$schema"`
		Properties map[string]struct {
			Required []string `json:"required"`
		} `json:"properties"`
	}
	if err := json.Unmarshal(data, &schema); err != nil {
		t.Fatal(err)
	}
	if schema.Schema != "https://json-schema.org/draft/2020-12/schema" || !reflect.DeepEqual(schema.Properties["colors"].Required, ColorKeys) {
		t.Fatal("schema contract mismatch")
	}
	qml, err := os.ReadFile("../../../quickshell/common/Theme.qml")
	if err != nil {
		t.Fatal(err)
	}
	block := strings.Split(strings.Split(string(qml), "component Colors: QtObject {")[1], "\n\t}")[0]
	matches := regexp.MustCompile(`(?:readonly\s+)?property\s+color\s+(\w+):\s*"(#[a-fA-F0-9]{6})"`).FindAllStringSubmatch(block, -1)
	keys := []string{}
	for _, match := range matches {
		keys = append(keys, match[1])
		if builtin.Colors[match[1]] != match[2] {
			t.Errorf("color mismatch: %s", match[1])
		}
	}
	if !reflect.DeepEqual(keys, ColorKeys) {
		t.Fatalf("palette keys = %v", keys)
	}
}

func TestLoadRejectsInvalidFields(t *testing.T) {
	cases := []struct {
		name, want string
		mutate     func(map[string]interface{})
	}{
		{"missing-name", "name", func(v map[string]interface{}) { delete(v, "name") }},
		{"missing-wallpaper", "wallpaper", func(v map[string]interface{}) { delete(v, "wallpaper") }},
		{"missing-colors", "colors", func(v map[string]interface{}) { delete(v, "colors") }},
		{"unknown-field", "json", func(v map[string]interface{}) { v["extra"] = true }},
		{"missing-color", "colors.base", func(v map[string]interface{}) { delete(v["colors"].(map[string]interface{}), "base") }},
		{"unknown-color", "colors.extra", func(v map[string]interface{}) { v["colors"].(map[string]interface{})["extra"] = "#000000" }},
		{"invalid-hex", "colors.base", func(v map[string]interface{}) { v["colors"].(map[string]interface{})["base"] = "#abc" }},
		{"color-type", "colors.base", func(v map[string]interface{}) { v["colors"].(map[string]interface{})["base"] = 42 }},
		{"invalid-name", "name", func(v map[string]interface{}) { v["name"] = "Bad_name" }},
		{"long-name", "name", func(v map[string]interface{}) { v["name"] = strings.Repeat("a", 41) }},
		{"missing-image", "wallpaper", func(v map[string]interface{}) { v["wallpaper"] = "absent.png" }},
		{"null-colors", "colors", func(v map[string]interface{}) { v["colors"] = nil }},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			dir, v := fixture(t)
			tc.mutate(v)
			_, err := Load(save(t, dir, v))
			field(t, err, tc.want)
		})
	}
	for _, raw := range []string{"{", "null", "[]", "{}{}"} {
		t.Run(raw, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "theme.json")
			write(t, path, []byte(raw))
			_, err := Load(path)
			field(t, err, "json")
		})
	}
}

func TestCheckImage(t *testing.T) {
	img := image.NewRGBA(image.Rect(0, 0, 3, 3))
	img.Set(0, 0, color.White)
	for _, format := range []string{"png", "jpeg", "gif"} {
		t.Run(format, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "image")
			f, err := os.Create(path)
			if err != nil {
				t.Fatal(err)
			}
			switch format {
			case "png":
				err = png.Encode(f, img)
			case "jpeg":
				err = jpeg.Encode(f, img, nil)
			case "gif":
				err = gif.Encode(f, img, nil)
			}
			f.Close()
			if err != nil {
				t.Fatal(err)
			}
			if err := CheckImage(path); err != nil {
				t.Fatal(err)
			}
			data, _ := os.ReadFile(path)
			write(t, path, data[:len(data)/2])
			if err := CheckImage(path); err == nil {
				t.Fatal("accepted truncated image")
			}
		})
	}
	dir, v := fixture(t)
	write(t, filepath.Join(dir, "wallpaper.png"), []byte("not an image"))
	_, err := Load(save(t, dir, v))
	field(t, err, "wallpaper")
	if !strings.Contains(err.Error(), "formato no admitido (PNG, JPEG o GIF)") {
		t.Fatal(err)
	}
	write(t, filepath.Join(dir, "wallpaper.png"), []byte("\x89PNG\r\n\x1a\ncorrupt"))
	_, err = Load(save(t, dir, v))
	field(t, err, "wallpaper")
	if err := CheckImage(dir); err == nil {
		t.Fatal("accepted directory")
	}
}

func TestDiscoveryAndExpectedName(t *testing.T) {
	dir, v := fixture(t)
	th, err := Load(save(t, dir, v))
	if err != nil {
		t.Fatal(err)
	}
	if err := Validate(th, dir, "my-theme"); err != nil {
		t.Fatal(err)
	}
	field(t, Validate(th, dir, "other"), "name")
	dirs := Dirs{Builtin: filepath.Join(t.TempDir(), "builtin"), User: filepath.Join(t.TempDir(), "user")}
	th.Wallpaper = filepath.Join(dir, "wallpaper.png")
	for _, item := range []struct{ base, name, declared string }{{dirs.Builtin, "zenda-ice", "zenda-ice"}, {dirs.Builtin, "alpha", "alpha"}, {dirs.User, "zenda-ice", "zenda-ice"}, {dirs.User, "custom", "custom"}, {dirs.User, "mismatch", "wrong"}, {dirs.User, ".temporary", "temp"}} {
		th.Name = item.declared
		save(t, filepath.Join(item.base, item.name), th)
	}
	infos := Discover(dirs)
	names := []string{}
	for _, info := range infos {
		names = append(names, info.Name)
		if !filepath.IsAbs(info.File) || info.Colors == nil {
			t.Fatal(info)
		}
		if info.Valid && !filepath.IsAbs(info.Wallpaper) {
			t.Fatal(info)
		}
	}
	if !reflect.DeepEqual(names, []string{"alpha", "zenda-ice", "custom", "mismatch", "zenda-ice"}) {
		t.Fatal(names)
	}
	for _, index := range []int{3, 4} {
		if infos[index].Valid || infos[index].Field != "name" {
			t.Fatal(infos[index])
		}
	}
	info, ok := Find(dirs, "zenda-ice")
	if !ok || !info.Builtin {
		t.Fatal(info)
	}
	if _, ok := Find(dirs, "missing"); ok {
		t.Fatal("found absent theme")
	}
	if len(Discover(Dirs{})) != 0 {
		t.Fatal("empty dirs")
	}
}

func TestUnreadableWallpaper(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root bypasses file permission checks")
	}
	dir, value := fixture(t)
	path := filepath.Join(dir, "wallpaper.png")
	if err := os.Chmod(path, 0000); err != nil {
		t.Fatal(err)
	}
	defer os.Chmod(path, 0600)
	_, err := Load(save(t, dir, value))
	field(t, err, "wallpaper")
}
