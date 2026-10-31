package hyprctl

import (
	"fmt"
	"strconv"
	"strings"
)

// These helpers build the Lua expressions of Hyprland's configuration API.
// Both runtime dispatches and generated configuration files use them.

// DspExec returns the dispatcher that runs a shell command.
func DspExec(command string) string { return "hl.dsp.exec_cmd(" + strconv.Quote(command) + ")" }

// DspSubmap returns the dispatcher that switches submap.
func DspSubmap(name string) string { return "hl.dsp.submap(" + strconv.Quote(name) + ")" }

// DspFocusWindow returns the dispatcher that focuses a client by address.
func DspFocusWindow(address string) string {
	return fmt.Sprintf(`hl.dsp.focus({ window = "address:%s" })`, address)
}

// DspSendShortcut returns the dispatcher that sends a key combination.
func DspSendShortcut(mods, key string) string {
	return fmt.Sprintf("hl.dsp.send_shortcut({mods = %s, key = %s})", strconv.Quote(mods), strconv.Quote(key))
}

// DspDpmsOn returns the dispatcher that turns the monitors on.
func DspDpmsOn() string { return `hl.dsp.dpms({action = "on"})` }

// DspExit returns the dispatcher that ends the session.
func DspExit() string { return "hl.dsp.exit()" }

// DispatchCommand returns a shell command that runs dispatcher, for programs
// such as hypridle that execute shell strings.
func DispatchCommand(dispatcher string) string { return "hyprctl dispatch '" + dispatcher + "'" }

// BindOptions are the optional fields of a key binding.
type BindOptions struct {
	Description string
	// Universal keeps the bind active in every submap.
	Universal bool
}

// BindLua returns the Lua statement that binds combo to dispatcher.
func BindLua(combo, dispatcher string, opts BindOptions) string {
	options := ""
	if opts.Universal {
		options += "submap_universal = true, "
	}
	options += "description = " + strconv.Quote(opts.Description)
	return fmt.Sprintf("hl.bind(%s, %s, { %s })", strconv.Quote(combo), dispatcher, options)
}

// DefineSubmap returns the Lua statement that defines a submap with binds.
func DefineSubmap(name string, binds ...string) string {
	body := ""
	for _, b := range binds {
		body += "\t" + b + "\n"
	}
	return "hl.define_submap(" + strconv.Quote(name) + ", function()\n" + body + "end)"
}

// OnStart returns the Lua statement that runs command when Hyprland starts.
func OnStart(command string) string {
	return OnStartExpr(strconv.Quote(command))
}

// OnStartExpr is OnStart for a command that is a Lua expression.
func OnStartExpr(expr string) string {
	return fmt.Sprintf("hl.on(\"hyprland.start\", function() hl.exec_cmd(%s) end)", expr)
}

// EnvLua returns the Lua statement that sets a session variable.
func EnvLua(name, value string) string {
	return fmt.Sprintf("hl.env(%s, %s)", strconv.Quote(name), strconv.Quote(value))
}

// SetCursorCommand returns the shell command that applies a cursor theme.
func SetCursorCommand(theme string, size int) string {
	return fmt.Sprintf("hyprctl setcursor '%s' %d", strings.ReplaceAll(theme, "'", "'\\''"), size)
}

// SessionLockConfig returns the Lua statement with the session lock options.
func SessionLockConfig(xray, blur bool) string {
	return fmt.Sprintf("hl.config({ misc = { allow_session_lock_restore = true, session_lock_xray = %t, session_lock_blur = %t } })", xray, blur)
}

// WindowRule describes where Hyprland places the windows that match it.
type WindowRule struct {
	Name string
	// MatchTitle is a regular expression for the window title.
	MatchTitle string
	Float      bool
	// Center places a floating window in the middle of its monitor, which is
	// the focused one when the window opens.
	Center bool
}

// WindowRuleLua returns the Lua statement that registers rule.
func WindowRuleLua(rule WindowRule) string {
	effects := ""
	if rule.Float {
		effects += ", float = true"
	}
	if rule.Center {
		effects += ", center = true"
	}
	return fmt.Sprintf("hl.window_rule({ name = %s, match = { title = %s }%s })", strconv.Quote(rule.Name), strconv.Quote(rule.MatchTitle), effects)
}

// MonitorRule is the configuration of one monitor.
type MonitorRule struct {
	Output, Mode, Position, Scale string
	Transform                     int
	// Mirror is the output this monitor duplicates.
	Mirror   string
	Disabled bool
}

// MonitorLua returns the Lua statement that configures a monitor.
func MonitorLua(rule MonitorRule) string {
	if rule.Disabled {
		return fmt.Sprintf("hl.monitor({ output = %s, disabled = true })", strconv.Quote(rule.Output))
	}
	mirror := ""
	if rule.Mirror != "" {
		mirror = ", mirror = " + strconv.Quote(rule.Mirror)
	}
	return fmt.Sprintf("hl.monitor({ output = %s, mode = %s, position = %s, scale = %s, transform = %d%s })", strconv.Quote(rule.Output), strconv.Quote(rule.Mode), strconv.Quote(rule.Position), strconv.Quote(rule.Scale), rule.Transform, mirror)
}
