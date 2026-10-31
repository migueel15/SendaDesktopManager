package integration

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSyncCursorFilesUpdatesOnlyExistingLines(t *testing.T) {
	home := t.TempDir()
	write := func(rel, text string) string {
		path := filepath.Join(home, rel)
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(text), 0o640); err != nil {
			t.Fatal(err)
		}
		return path
	}
	gtk := write(".config/gtk-3.0/settings.ini", "[Settings]\ngtk-cursor-theme-name=Old\ngtk-cursor-theme-size=26\n#gtk-font=x\n")
	xres := write(".Xresources", "! Xcursor.theme: Keep\nXcursor.theme: Old\n")
	xsettings := write(".config/xsettingsd/xsettingsd.conf", "Gtk/CursorThemeName \"Old\"\nNet/ThemeName \"T\"\n")
	real := write("dotfiles/gtkrc", "gtk-cursor-theme-name=\"Old\"\n")
	if err := os.Symlink(real, filepath.Join(home, ".gtkrc-2.0")); err != nil {
		t.Fatal(err)
	}
	unrelated := write(".icons/default/index.theme", "[Icon Theme]\nName=Default\n")

	changed, err := SyncCursorFiles(home, "macOS", 32)
	if err != nil {
		t.Fatal(err)
	}
	if len(changed) != 4 {
		t.Fatalf("changed = %v", changed)
	}
	for path, want := range map[string]string{
		gtk:       "[Settings]\ngtk-cursor-theme-name=macOS\ngtk-cursor-theme-size=32\n#gtk-font=x\n",
		xres:      "! Xcursor.theme: Keep\nXcursor.theme: macOS\n",
		xsettings: "Gtk/CursorThemeName \"macOS\"\nNet/ThemeName \"T\"\n",
		real:      "gtk-cursor-theme-name=\"macOS\"\n",
		unrelated: "[Icon Theme]\nName=Default\n",
	} {
		data, _ := os.ReadFile(path)
		if string(data) != want {
			t.Errorf("%s = %q", path, data)
		}
	}
	if info, _ := os.Lstat(filepath.Join(home, ".gtkrc-2.0")); info.Mode()&os.ModeSymlink == 0 {
		t.Error("symlink replaced")
	}
	if info, _ := os.Stat(gtk); info.Mode().Perm() != 0o640 {
		t.Errorf("mode = %v", info.Mode())
	}
	if !strings.HasSuffix(xres, ".Xresources") || !IsCursorXresources(xres) {
		t.Error("xresources not recognised")
	}
}

func TestSyncCursorFilesEmptyValuesKeepFile(t *testing.T) {
	home := t.TempDir()
	path := filepath.Join(home, ".Xresources")
	if err := os.WriteFile(path, []byte("Xcursor.theme: Old\nXcursor.size: 24\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if changed, err := SyncCursorFiles(home, "", 0); err != nil || len(changed) != 0 {
		t.Fatalf("changed = %v, err = %v", changed, err)
	}
}
