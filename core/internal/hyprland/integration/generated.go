package integration

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/binds"
	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/hyprctl"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/migueel15/SendaDesktopManager/core/internal/version"
)

// generatedModule is one area of the generated folder. To add a module, append
// an entry to generatedModules: its file, its load from init.lua, ownership
// checks, cleanup and uninstall all derive from that list.
type generatedModule struct {
	// Name is the file name without extension, unique in the folder.
	Name string
	// Render returns the module's Lua, without the header. Each module also
	// receives the folder it was loaded from as its vararg (`local dir = ...`).
	Render func(moduleInput) (string, error)
}

// moduleInput is the validated data modules render from.
type moduleInput struct {
	Settings                    Settings
	Lock, Dictation, Screenshot string
	// Command is the Senda executable, quoted for a shell.
	Command string
}

// generatedModules is in load order: later modules win in Hyprland.
var generatedModules = []generatedModule{
	{"lock", renderLockModule},
	{"binds", renderBindsModule},
	{"media", renderMediaModule},
	{"rules", renderRulesModule},
	{"displays", renderDisplaysModule},
	{"input", renderInputModule},
	{"startup", renderStartupModule},
	{"idle", renderIdleModule},
}

func renderLockModule(in moduleInput) (string, error) {
	return hyprctl.SessionLockConfig(in.Settings.Blur, in.Settings.Blur) + "\n" +
		hyprctl.BindLua(in.Lock, hyprctl.DspExec("loginctl lock-session"), hyprctl.BindOptions{Description: "Senda lock"}) + "\n", nil
}

func renderBindsModule(in moduleInput) (string, error) {
	return hyprctl.BindLua(in.Dictation, hyprctl.DspExec(in.Command+" stt toggle"), hyprctl.BindOptions{Description: binds.DictationDescription, Universal: true}) + "\n" +
		hyprctl.BindLua(in.Screenshot, hyprctl.DspExec(in.Command+" screenshot"), hyprctl.BindOptions{Description: "Senda screenshot"}) + "\n", nil
}

func renderRulesModule(moduleInput) (string, error) {
	return hyprctl.WindowRuleLua(SettingsWindowRule()) + "\n", nil
}

func renderDisplaysModule(in moduleInput) (string, error) {
	var out strings.Builder
	for _, rule := range in.Settings.Displays {
		if err := rule.Validate(); err != nil {
			return "", err
		}
		out.WriteString(rule.lua() + "\n")
	}
	return out.String(), nil
}

func renderInputModule(in moduleInput) (string, error) {
	if err := in.Settings.Input.Validate(); err != nil {
		return "", err
	}
	return string(renderInput(in.Settings.Input, CursorSize())), nil
}

// renderStartupModule reconciles at login with what the user may have added
// since the last write, then runs the entries chosen in Settings.
func renderStartupModule(in moduleInput) (string, error) {
	entries, err := renderStartupEntries(in.Settings.Startup)
	if err != nil {
		return "", err
	}
	return hyprctl.OnStart(in.Command+" input sync") + "\n" + entries, nil
}

// renderIdleModule derives the path from the folder that was loaded, so moving
// the folder cannot leave the login without hypridle.
func renderIdleModule(in moduleInput) (string, error) {
	if in.Settings.IdleMode != IdleModeSenda {
		return "", nil
	}
	expr := fmt.Sprintf(`"hypridle -c '" .. dir:gsub("'", "'\\''") .. "/%s'"`, idleFile)
	return "local dir = ...\n" + hyprctl.OnStartExpr("("+expr+")") + "\n", nil
}

const (
	initFile   = "init.lua"
	idleFile   = "hypridle.conf"
	folderName = "senda"
	idleHeader = "# Generado por Senda."
	fileHeader = moduleHeader + " No modificar manualmente.\n"
)

// GeneratedFile is one file of the generated folder.
type GeneratedFile struct {
	Name    string
	Content []byte
}

// Generated is every file of the folder, in a stable order.
type Generated []GeneratedFile

// Text joins the files so that callers can compare whole generations.
func (g Generated) Text() []byte {
	var out []byte
	for _, f := range g {
		out = append(out, f.Content...)
	}
	return out
}

func generatedInit() string {
	names := make([]string, 0, len(generatedModules))
	for _, m := range generatedModules {
		names = append(names, strconv.Quote(m.Name))
	}
	return fmt.Sprintf(`%s-- Los módulos se cargan por ruta para que la carpeta funcione esté donde esté.
local dir = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")
for _, name in ipairs({ %s }) do
	assert(loadfile(dir .. "/" .. name .. ".lua"))(dir)
end
-- Marca de detección: Senda la consulta con hyprctl para localizar esta carpeta.
function %s() return %s end
`, fileHeader, strings.Join(names, ", "), ProbeFunction, strconv.Quote(version.Version))
}

// generatedTargets is every name in the folder with the headers proving Senda
// owns it. It must stay independent from Render so uninstall needs no settings.
func generatedTargets() map[string][]string {
	targets := map[string][]string{
		initFile:     {moduleHeader},
		idleFile:     {idleHeader},
		".gitignore": {idleHeader},
	}
	for _, m := range generatedModules {
		targets[m.Name+".lua"] = []string{moduleHeader}
	}
	return targets
}

// DefaultDir is hypr/senda, used when no loaded configuration points elsewhere.
func DefaultDir() string {
	return filepath.Join(filepath.Dir(paths.ConfigDir()), "hypr", folderName)
}

// Dir is the generated folder: the one Hyprland loaded (see Locate) or, with no
// session to ask, the one hyprland.lua imports; otherwise the default.
func Dir() string {
	if moduleOverride != "" {
		return filepath.Dir(moduleOverride)
	}
	if !InSession() {
		if dir := configuredDir(); dir != "" {
			return dir
		}
	}
	return DefaultDir()
}

// ModulePath is the folder's entry file, the one Hyprland imports.
func ModulePath() string { return filepath.Join(Dir(), initFile) }

// IdlePath is the generated hypridle configuration.
func IdlePath() string { return filepath.Join(Dir(), idleFile) }

// configuredDir follows literal requires from hyprland.lua to a generated
// init.lua. It lets commands outside a session respect a moved folder.
func configuredDir() string {
	hypr := filepath.Dir(hyprConfigFile())
	seen := map[string]bool{}
	var visit func(string) string
	visit = func(path string) string {
		if seen[path] {
			return ""
		}
		seen[path] = true
		data, err := os.ReadFile(path)
		if err != nil {
			return ""
		}
		text := string(data)
		if strings.HasPrefix(text, moduleHeader) {
			if filepath.Base(path) == initFile {
				return filepath.Dir(path)
			}
			return ""
		}
		for _, m := range luaRequire.FindAllStringSubmatch(stripComments(text, true), -1) {
			rel := filepath.FromSlash(strings.ReplaceAll(m[1], ".", "/"))
			for _, next := range []string{rel + ".lua", filepath.Join(rel, initFile)} {
				if dir := visit(filepath.Join(hypr, next)); dir != "" {
					return dir
				}
			}
		}
		return ""
	}
	return visit(hyprConfigFile())
}

// CheckTargets refuses to replace any file Senda does not own.
func CheckTargets() error {
	dir := Dir()
	for name, headers := range generatedTargets() {
		if err := checkTarget(filepath.Join(dir, name), headers...); err != nil {
			return err
		}
	}
	return nil
}

// ReadGenerated returns what is on disk, comparable with Generated.Text.
func ReadGenerated() ([]byte, error) {
	dir := Dir()
	if _, err := os.Stat(filepath.Join(dir, initFile)); err != nil {
		return nil, err
	}
	var out []byte
	for _, name := range generatedNames() {
		data, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil && !os.IsNotExist(err) {
			return nil, err
		}
		out = append(out, data...)
	}
	return out, nil
}

// generatedNames is the order Render uses.
func generatedNames() []string {
	names := []string{initFile}
	for _, m := range generatedModules {
		names = append(names, m.Name+".lua")
	}
	return append(names, idleFile, ".gitignore")
}

// WriteFiles regenerates the folder completely. Ownership is checked before
// any replacement; each replacement is atomic and errors are returned instead
// of hiding partial writes.
func WriteFiles(s Settings, executable string) error {
	s.Input = s.Input.WithDefaults().withoutUser(DetectInput(LoadUserConfig(), SessionEnvFiles()))
	files, err := Render(s, executable)
	if err != nil {
		return err
	}
	if err := CheckTargets(); err != nil {
		return err
	}
	unlock, err := lockFile("generate", syscall.LOCK_EX)
	if err != nil {
		return fmt.Errorf("bloquear el módulo: %w", err)
	}
	defer unlock()
	dir := Dir()
	for _, f := range files {
		if err := binds.Write(filepath.Join(dir, f.Name), f.Content); err != nil {
			return fmt.Errorf("escribir %s: %w", f.Name, err)
		}
	}
	if built, err := executableBuilt(); err == nil {
		if err := os.WriteFile(filepath.Join(dir, generatorFile), []byte(strconv.FormatInt(built, 10)), 0o644); err != nil {
			return fmt.Errorf("escribir %s: %w", generatorFile, err)
		}
	}
	return removeStaleModules(dir)
}

// generatorFile records the build time of the binary that last wrote the module.
const generatorFile = ".generator"

func executableBuilt() (int64, error) {
	// Unlike the path, this survives the binary being replaced on disk.
	stat, err := os.Stat("/proc/self/exe")
	if err != nil {
		return 0, err
	}
	return stat.ModTime().UnixNano(), nil
}

// SupersededGenerator reports whether a newer binary wrote the module. It only
// restrains automatic writes: an explicit command may still downgrade it.
func SupersededGenerator() bool {
	built, err := executableBuilt()
	return err == nil && newerGenerator(Dir(), built)
}

func newerGenerator(dir string, built int64) bool {
	data, err := os.ReadFile(filepath.Join(dir, generatorFile))
	if err != nil {
		return false
	}
	writer, err := strconv.ParseInt(strings.TrimSpace(string(data)), 10, 64)
	return err == nil && writer > built
}

// removeStaleModules deletes generated modules a previous version wrote.
func removeStaleModules(dir string) error {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return err
	}
	targets := generatedTargets()
	for _, entry := range entries {
		path := filepath.Join(dir, entry.Name())
		if _, known := targets[entry.Name()]; known || filepath.Ext(path) != ".lua" {
			continue
		}
		if ok, _ := owned(path, moduleHeader); ok {
			if err := os.Remove(path); err != nil {
				return err
			}
		}
	}
	return nil
}
