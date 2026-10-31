package integration

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// renderParts splits a generation into Lua and hypridle text.
func renderParts(s Settings, exe string) (lua, idle []byte, err error) {
	files, err := Render(s, exe)
	for _, f := range files {
		switch filepath.Ext(f.Name) {
		case ".lua":
			lua = append(lua, f.Content...)
		case ".conf":
			idle = f.Content
		}
	}
	return lua, idle, err
}

func generatedHome(t *testing.T) string {
	t.Helper()
	home := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", home)
	t.Setenv("SENDA_HOME", filepath.Join(home, "senda"))
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "")
	moduleOverride = ""
	t.Cleanup(func() { moduleOverride = "" })
	if !strings.HasPrefix(DefaultDir(), home) {
		t.Skip("config dir not isolated: " + DefaultDir())
	}
	return filepath.Dir(filepath.Dir(DefaultDir()))
}

func TestFolderHasOneFilePerModuleAndIgnoresEverything(t *testing.T) {
	generatedHome(t)
	s := DefaultSettings()
	s.IdleMode = IdleModeSenda
	if err := WriteFiles(s, "/usr/bin/senda"); err != nil {
		t.Fatal(err)
	}
	for _, m := range generatedModules {
		data := read(t, filepath.Join(Dir(), m.Name+".lua"))
		if !strings.HasPrefix(data, moduleHeader) {
			t.Fatalf("%s sin cabecera: %s", m.Name, data)
		}
		if !strings.Contains(read(t, ModulePath()), `"`+m.Name+`"`) {
			t.Fatalf("init.lua no carga %s", m.Name)
		}
	}
	if !strings.HasSuffix(read(t, filepath.Join(Dir(), ".gitignore")), "\n*\n") {
		t.Fatal("gitignore no ignora todo")
	}
}

func TestStaleModulesGoButUserFilesStay(t *testing.T) {
	generatedHome(t)
	stale, user := filepath.Join(Dir(), "old.lua"), filepath.Join(Dir(), "mine.lua")
	put(t, stale, moduleHeader+"\n")
	put(t, user, "user()\n")
	if err := WriteFiles(DefaultSettings(), "/usr/bin/senda"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(stale); !os.IsNotExist(err) {
		t.Fatal("módulo obsoleto conservado")
	}
	if read(t, user) != "user()\n" {
		t.Fatal("archivo del usuario modificado")
	}
}

func TestMovedFolderIsFollowedWithoutSession(t *testing.T) {
	root := generatedHome(t)
	moved := filepath.Join(root, "hypr", "modules", "senda")
	put(t, filepath.Join(moved, "init.lua"), moduleHeader+"\n")
	put(t, filepath.Join(root, "hypr", "hyprland.lua"), "require(\"modules.senda.init\")\n")
	if Dir() != moved {
		t.Fatalf("got %s", Dir())
	}
}

func TestLocateFollowsLoadedFolder(t *testing.T) {
	root := generatedHome(t)
	moved := filepath.Join(root, "elsewhere", "init.lua")
	put(t, moved, moduleHeader+"\n")
	Locate(Link{Loaded: true, Source: moved})
	if ModulePath() != moved {
		t.Fatalf("got %s", ModulePath())
	}
	// Deleted: the import still points there.
	os.Remove(moved)
	Locate(Link{Loaded: true, Source: moved})
	if ModulePath() != moved {
		t.Fatalf("deleted: got %s", ModulePath())
	}
	// A legacy module is not a location.
	legacy := filepath.Join(root, "hypr", "modules", "senda.lua")
	put(t, legacy, moduleHeader+"\n")
	Locate(Link{Loaded: true, Source: legacy})
	if ModulePath() != filepath.Join(DefaultDir(), "init.lua") {
		t.Fatalf("legacy: got %s", ModulePath())
	}
}

func TestMigrateFromSingleModuleKeepsOneReference(t *testing.T) {
	root := generatedHome(t)
	main := filepath.Join(root, "hypr", "hyprland.lua")
	legacy := filepath.Join(root, "hypr", "modules", "senda.lua")
	idle := filepath.Join(root, "senda", "hypridle.conf")
	put(t, main, "user()\n"+legacyManagedReference+"\n")
	put(t, legacy, moduleHeader+"\n")
	put(t, idle, "# Generado por Senda.\n")
	if err := WriteFiles(DefaultSettings(), "/usr/bin/senda"); err != nil {
		t.Fatal(err)
	}
	warnings, err := Migrate()
	if err != nil || len(warnings) != 0 {
		t.Fatal(warnings, err)
	}
	if got := read(t, main); got != "user()\n"+managedReference+"\n" {
		t.Fatalf("main: %q", got)
	}
	for _, path := range []string{legacy, idle} {
		if _, err := os.Stat(path); !os.IsNotExist(err) {
			t.Fatalf("%s conservado", path)
		}
	}
}

func TestReferencedLegacyModuleIsEmptied(t *testing.T) {
	root := generatedHome(t)
	legacy := filepath.Join(root, "hypr", "modules", "senda.lua")
	put(t, filepath.Join(root, "hypr", "hyprland.lua"), legacyRequireLine+"\n")
	put(t, filepath.Join(root, "hypr", "modules", "x.lua"), "local s = require(\"modules.senda\")\n")
	put(t, legacy, moduleHeader+"\nhl.bind(\"a\")\n")
	warnings, err := Migrate()
	if err != nil || len(warnings) != 1 {
		t.Fatal(warnings, err)
	}
	if strings.Contains(read(t, legacy), "hl.bind") {
		t.Fatal("binds duplicados")
	}
}

func TestEnsureLinkedAddsImportWhenLegacyLoaded(t *testing.T) {
	root := generatedHome(t)
	main := filepath.Join(root, "hypr", "hyprland.lua")
	put(t, main, "user()\n")
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "x")
	f := &fakeHyprland{source: filepath.Join(root, "hypr", "modules", "senda.lua"), reloaded: true}
	if _, err := EnsureLinked(context.Background(), f.run); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(read(t, main), RequireLine) {
		t.Fatal("sin import")
	}
}

// The folder must load from any location with the real Lua semantics.
func TestInitLoadsModulesWhereverItIs(t *testing.T) {
	lua, err := exec.LookPath("lua")
	if err != nil {
		t.Skip("sin lua")
	}
	root := generatedHome(t)
	s := DefaultSettings()
	s.IdleMode = IdleModeSenda
	files, err := Render(s, "/usr/bin/senda")
	if err != nil {
		t.Fatal(err)
	}
	dir := filepath.Join(root, "it's moved", "senda")
	for _, f := range files {
		put(t, filepath.Join(dir, f.Name), string(f.Content))
	}
	stub := `local any = setmetatable({}, { __index = function(t) return t end, __call = function(t) return t end })
hl = setmetatable({ on = function(_, f) f() end, exec_cmd = function(c) print(c) end }, { __index = function() return any end })
`
	entry := filepath.Join(root, "run.lua")
	put(t, entry, stub+"dofile(arg[1])\nprint(senda_module_version())\n")
	out, err := exec.Command(lua, entry, filepath.Join(dir, "init.lua")).CombinedOutput()
	if err != nil {
		t.Fatalf("%v: %s", err, out)
	}
	if !strings.Contains(string(out), "hypridle -c '"+strings.ReplaceAll(dir, "'", `'\''`)+"/hypridle.conf'") {
		t.Fatalf("ruta de hypridle: %s", out)
	}
}
