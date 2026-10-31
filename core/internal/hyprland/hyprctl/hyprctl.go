// Package hyprctl is the only place where Senda talks to Hyprland. Every
// hyprctl invocation, dispatcher expression, JSON reply format and the event
// socket live here, so a change in Hyprland's API is fixed in one package.
package hyprctl

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

// Runner executes a command and returns its standard output. It matches
// stt.Runner, so callers can inject the runners they already use in tests.
type Runner = func(ctx context.Context, stdin io.Reader, name string, args ...string) ([]byte, error)

func execRunner(ctx context.Context, stdin io.Reader, name string, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Stdin = stdin
	return cmd.Output()
}

// Client sends requests to the running Hyprland through hyprctl.
type Client struct{ run Runner }

// New returns a client that uses run, or executes hyprctl when run is nil.
func New(run Runner) Client {
	if run == nil {
		run = execRunner
	}
	return Client{run: run}
}

// SignatureEnv is the variable through which Hyprland identifies its running
// instance; hyprctl and the event socket need it.
const SignatureEnv = "HYPRLAND_INSTANCE_SIGNATURE"

// InSession reports whether hyprctl can reach a running Hyprland.
func InSession() bool { return InSessionEnv(os.Getenv) }

// InSessionEnv is InSession with an injected environment lookup.
func InSessionEnv(getenv func(string) string) bool { return getenv(SignatureEnv) != "" }

func (c Client) call(ctx context.Context, args ...string) (string, error) {
	out, err := c.run(ctx, nil, "hyprctl", args...)
	text := strings.TrimSpace(string(out))
	if err != nil {
		return text, fmt.Errorf("hyprctl %s: %s: %w", args[0], text, err)
	}
	return text, nil
}

// expectOK runs a request whose only successful reply is "ok".
func (c Client) expectOK(ctx context.Context, args ...string) error {
	text, err := c.call(ctx, args...)
	if err != nil {
		return err
	}
	if text != "ok" {
		return fmt.Errorf("hyprctl %s: respuesta inesperada: %q", args[0], text)
	}
	return nil
}

func (c Client) query(ctx context.Context, into any, args ...string) error {
	out, err := c.run(ctx, nil, "hyprctl", append([]string{"-j"}, args...)...)
	if err != nil {
		return fmt.Errorf("hyprctl -j %s: %s: %w", strings.Join(args, " "), strings.TrimSpace(string(out)), err)
	}
	if err := json.Unmarshal(out, into); err != nil {
		return fmt.Errorf("hyprctl -j %s: respuesta inválida: %w", strings.Join(args, " "), err)
	}
	return nil
}

// Dispatch runs a dispatcher expression built with the Dsp* helpers.
func (c Client) Dispatch(ctx context.Context, dispatcher string) error {
	return c.expectOK(ctx, "dispatch", dispatcher)
}

// Eval runs Lua code in the running configuration.
func (c Client) Eval(ctx context.Context, code string) error {
	return c.expectOK(ctx, "eval", code)
}

// Repl evaluates a Lua expression and returns its printed value.
func (c Client) Repl(ctx context.Context, expression string) (string, error) {
	return c.call(ctx, "repl", expression)
}

// Reload rereads the configuration and fails when it reports errors.
func (c Client) Reload(ctx context.Context) error {
	if err := c.expectOK(ctx, "reload"); err != nil {
		return err
	}
	text, err := c.call(ctx, "configerrors")
	if err != nil {
		return err
	}
	if text != "" {
		return fmt.Errorf("hyprctl configerrors: %s", text)
	}
	return nil
}

// Window is a mapped client.
type Window struct {
	Address string `json:"address"`
	Class   string `json:"class"`
	Title   string `json:"title"`
}

// ActiveWindow returns the focused client.
func (c Client) ActiveWindow(ctx context.Context) (Window, error) {
	var w Window
	return w, c.query(ctx, &w, "activewindow")
}

// Windows lists the mapped clients.
func (c Client) Windows(ctx context.Context) ([]Window, error) {
	var ws []Window
	return ws, c.query(ctx, &ws, "clients")
}

// Monitor is a monitor known to Hyprland, enabled or not.
type Monitor struct {
	Name           string   `json:"name"`
	Description    string   `json:"description"`
	Width          int      `json:"width"`
	Height         int      `json:"height"`
	RefreshRate    float64  `json:"refreshRate"`
	X              int      `json:"x"`
	Y              int      `json:"y"`
	Scale          float64  `json:"scale"`
	Transform      int      `json:"transform"`
	Disabled       bool     `json:"disabled"`
	MirrorOf       string   `json:"mirrorOf"`
	AvailableModes []string `json:"availableModes"`
}

// Monitors lists every connected monitor, including disabled ones.
func (c Client) Monitors(ctx context.Context) ([]Monitor, error) {
	var ms []Monitor
	return ms, c.query(ctx, &ms, "monitors", "all")
}

// Keyboards returns the names of the keyboards Hyprland knows.
func (c Client) Keyboards(ctx context.Context) ([]string, error) {
	var devices struct {
		Keyboards []struct {
			Name string `json:"name"`
		} `json:"keyboards"`
	}
	if err := c.query(ctx, &devices, "devices"); err != nil {
		return nil, err
	}
	names := make([]string, 0, len(devices.Keyboards))
	for _, k := range devices.Keyboards {
		names = append(names, k.Name)
	}
	return names, nil
}

// Bind is a registered key binding.
type Bind struct {
	Modmask     int    `json:"modmask"`
	Submap      string `json:"submap"`
	Key         string `json:"key"`
	Arg         string `json:"arg"`
	Dispatcher  string `json:"dispatcher"`
	Description string `json:"description"`
}

// LuaDispatcher is the dispatcher Hyprland reports for binds defined in Lua.
const LuaDispatcher = "__lua"

// Binds lists the registered key bindings.
func (c Client) Binds(ctx context.Context) ([]Bind, error) {
	var bs []Bind
	return bs, c.query(ctx, &bs, "binds")
}

// FocusWindow focuses the client with the given address.
func (c Client) FocusWindow(ctx context.Context, address string) error {
	if _, err := strconv.ParseUint(address, 0, 64); err != nil {
		return fmt.Errorf("dirección de ventana inválida %q", address)
	}
	return c.Dispatch(ctx, DspFocusWindow(address))
}

// SendShortcut sends a key combination to the active window. Mods is a
// space separated list such as "CTRL SHIFT". Physical modifiers do not
// interfere because Hyprland sets the modifier state itself.
func (c Client) SendShortcut(ctx context.Context, mods, key string) error {
	return c.Dispatch(ctx, DspSendShortcut(mods, key))
}

// Submap switches to the named submap; "reset" returns to the default one.
func (c Client) Submap(ctx context.Context, name string) error {
	return c.Dispatch(ctx, DspSubmap(name))
}

// SetDeviceEnabled enables or disables an input device.
func (c Client) SetDeviceEnabled(ctx context.Context, name string, enabled bool) error {
	return c.Eval(ctx, "hl.device({name="+strconv.Quote(name)+", enabled="+strconv.FormatBool(enabled)+"})")
}

// AddWindowRule registers rule in the running session. Windows mapped after
// it, such as one about to be opened, follow it until the next reload.
func (c Client) AddWindowRule(ctx context.Context, rule WindowRule) error {
	return c.Eval(ctx, WindowRuleLua(rule))
}

// SetCursor applies a cursor theme to the running session.
func (c Client) SetCursor(ctx context.Context, theme string, size int) error {
	return c.expectOK(ctx, "setcursor", theme, strconv.Itoa(size))
}

// Option returns the current value of a configuration option as text.
func (c Client) Option(ctx context.Context, name string) (string, error) {
	var raw map[string]any
	if err := c.query(ctx, &raw, "getoption", name); err != nil {
		return "", err
	}
	for _, key := range []string{"str", "float", "int"} {
		switch v := raw[key].(type) {
		case string:
			return strings.ReplaceAll(v, "[[EMPTY]]", ""), nil
		case float64:
			return strconv.FormatFloat(v, 'f', -1, 64), nil
		}
	}
	return "", fmt.Errorf("opción sin valor: %s", name)
}

// Exit ends the Hyprland session.
func (c Client) Exit(ctx context.Context) error { return c.Dispatch(ctx, DspExit()) }
