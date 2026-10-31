package integration

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/hyprctl"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

const (
	KeyDisplays         = "SENDA_DISPLAYS"
	KeyDisplaysPrevious = "SENDA_DISPLAYS_PREVIOUS"
)

// MonitorSelector finds the monitors the user defines.
var MonitorSelector = Selector{LuaCall: "hl.monitor", Field: "output", ConfKeyword: "monitor"}

// DisplayRule is a monitor configured from Senda.
type DisplayRule struct {
	Name        string  `json:"name"`
	Description string  `json:"description,omitempty"`
	Mode        string  `json:"mode"`
	Position    string  `json:"position"`
	Scale       float64 `json:"scale"`
	Transform   int     `json:"transform"`
	// Mirror is the selector of the monitor this one duplicates.
	Mirror   string `json:"mirror,omitempty"`
	Disabled bool   `json:"disabled,omitempty"`
}

// Output is how the rule names its monitor. The description follows the
// monitor when it changes port.
func (r DisplayRule) Output() string { return monitorOutput(r.Name, r.Description) }

func monitorOutput(name, description string) string {
	if description != "" {
		return "desc:" + description
	}
	return name
}

var (
	modeRe     = regexp.MustCompile(`^\d+x\d+(@\d+(\.\d+)?)?$`)
	positionRe = regexp.MustCompile(`^-?\d+x-?\d+$`)
)

// Validate rejects a rule Hyprland could not apply.
func (r DisplayRule) Validate() error {
	switch {
	case r.Name == "":
		return fmt.Errorf("pantalla sin nombre")
	case !modeRe.MatchString(r.Mode) && r.Mode != "preferred":
		return fmt.Errorf("modo inválido: %q (usa 1920x1080@60)", r.Mode)
	case !positionRe.MatchString(r.Position):
		return fmt.Errorf("posición inválida: %q (usa 1920x0)", r.Position)
	case r.Scale < 0.25 || r.Scale > 10:
		return fmt.Errorf("escala inválida: %v (de 0.25 a 10)", r.Scale)
	case r.Transform < 0 || r.Transform > 7:
		return fmt.Errorf("rotación inválida: %d (de 0 a 7)", r.Transform)
	}
	return nil
}

func (r DisplayRule) lua() string {
	return hyprctl.MonitorLua(hyprctl.MonitorRule{Output: r.Output(), Mode: r.Mode, Position: r.Position, Scale: strconv.FormatFloat(r.Scale, 'f', -1, 64), Transform: r.Transform, Mirror: r.Mirror, Disabled: r.Disabled})
}

// DisplayLines returns the monitor statements of a generated module, so a stale
// module can be noticed whatever else differs in it.
func DisplayLines(module []byte) string {
	var lines []string
	for _, line := range strings.Split(string(module), "\n") {
		if strings.HasPrefix(line, "hl.monitor(") {
			lines = append(lines, line)
		}
	}
	return strings.Join(lines, "\n")
}

// ParseDisplays reads a stored value; empty means no rules.
func ParseDisplays(value string) ([]DisplayRule, error) {
	if value == "" {
		return nil, nil
	}
	var rules []DisplayRule
	if err := json.Unmarshal([]byte(value), &rules); err != nil {
		return nil, fmt.Errorf("pantallas guardadas inválidas: %w", err)
	}
	for _, rule := range rules {
		if err := rule.Validate(); err != nil {
			return nil, err
		}
	}
	return rules, nil
}

func encodeDisplays(rules []DisplayRule) (string, error) {
	if len(rules) == 0 {
		return "", nil
	}
	data, err := json.Marshal(rules)
	return string(data), err
}

// StoredDisplays returns every saved rule, including those the user overrides,
// which are kept in case the user removes their definition.
func StoredDisplays(path string) (rules, previous []DisplayRule, err error) {
	values, err := config.Load(path)
	if err != nil {
		return nil, nil, err
	}
	if rules, err = ParseDisplays(values[KeyDisplays]); err != nil {
		return nil, nil, err
	}
	previous, err = ParseDisplays(values[KeyDisplaysPrevious])
	return rules, previous, err
}

// StoreDisplays saves rules and what they replaced, which undo restores. A nil
// previous from StoredDisplays means there is nothing to undo.
func StoreDisplays(path string, rules, previous []DisplayRule) error {
	current, err := encodeDisplays(rules)
	if err != nil {
		return err
	}
	// "[]" records that undo would clear every rule; empty means no undo.
	old := "[]"
	if len(previous) > 0 {
		if old, err = encodeDisplays(previous); err != nil {
			return err
		}
	}
	return config.Set(path, map[string]string{KeyDisplays: current, KeyDisplaysPrevious: old})
}

// ApplyDisplayChanges updates the running session from one set of rules to
// another, touching only the monitors that differ.
func ApplyDisplayChanges(ctx context.Context, run stt.Runner, before, after []DisplayRule) error {
	client := hyprctl.New(run)
	current := map[string]DisplayRule{}
	for _, rule := range after {
		current[rule.Output()] = rule
	}
	for _, rule := range before {
		if _, kept := current[rule.Output()]; !kept {
			return client.Reload(ctx)
		}
	}
	return evalChanged(ctx, client, before, after)
}

// evalChanged sends every changed monitor in one request, so Hyprland handles
// them together.
func evalChanged(ctx context.Context, client hyprctl.Client, before, after []DisplayRule) error {
	old := map[string]DisplayRule{}
	for _, rule := range before {
		old[rule.Output()] = rule
	}
	var statements []string
	for _, rule := range after {
		if prior, ok := old[rule.Output()]; !ok || prior != rule {
			statements = append(statements, rule.lua())
		}
	}
	if len(statements) == 0 {
		return nil
	}
	return client.Eval(ctx, strings.Join(statements, " "))
}

// ApplyTrial applies after in the session only, and returns how to put the
// changed monitors back as they are now. Nothing is saved, so a restart during
// the trial also returns to the last confirmed state.
func ApplyTrial(ctx context.Context, run stt.Runner, before, after []DisplayRule) (func() error, error) {
	client := hyprctl.New(run)
	monitors, err := client.Monitors(ctx)
	if err != nil {
		return nil, err
	}
	old := map[string]DisplayRule{}
	for _, rule := range before {
		old[rule.Output()] = rule
	}
	var live []DisplayRule
	for _, rule := range after {
		if prior, ok := old[rule.Output()]; ok && prior == rule {
			continue
		}
		for _, m := range monitors {
			if monitorOutput(m.Name, m.Description) == rule.Output() {
				live = append(live, liveRule(m, monitors))
			}
		}
	}
	restore := func() error { return evalChanged(context.Background(), client, nil, live) }
	if err := evalChanged(ctx, client, before, after); err != nil {
		restore()
		return nil, err
	}
	return restore, nil
}

// LockDisplayWatch takes the session-wide watcher lock. The kernel releases it
// when the process dies, however that happens.
func LockDisplayWatch() (func(), error) {
	path := filepath.Join(os.TempDir(), fmt.Sprintf("senda-display-watch-%d.lock", os.Getuid()))
	file, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, err
	}
	if err := syscall.Flock(int(file.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		file.Close()
		return nil, err
	}
	return func() { file.Close() }, nil
}

// claimedBy returns the user definition that controls a monitor. A catch-all
// only supplies defaults, so it claims nothing; a computed target could be any
// monitor, so it claims all of them.
func claimedBy(defs []Definition, name, description string) *Definition {
	for i := range defs {
		d := &defs[i]
		if d.Dynamic || (d.Value != "" && (d.Value == name || (description != "" && d.Value == "desc:"+description))) {
			return d
		}
	}
	return nil
}

// withoutClaimed drops the rules the user's own configuration overrides.
func withoutClaimed(rules []DisplayRule, defs []Definition) []DisplayRule {
	kept := make([]DisplayRule, 0, len(rules))
	for _, rule := range rules {
		if claimedBy(defs, rule.Name, rule.Description) == nil {
			kept = append(kept, rule)
		}
	}
	return kept
}

// Display is a connected monitor and who controls it.
type Display struct {
	Name        string   `json:"name"`
	Description string   `json:"description"`
	X           int      `json:"x"`
	Y           int      `json:"y"`
	Width       int      `json:"width"`
	Height      int      `json:"height"`
	RefreshRate float64  `json:"refreshRate"`
	Scale       float64  `json:"scale"`
	Transform   int      `json:"transform"`
	Enabled     bool     `json:"enabled"`
	MirrorOf    string   `json:"mirrorOf"`
	Modes       []string `json:"modes"`
	// ManagedBy is user, senda, or empty when nobody configured the monitor.
	ManagedBy string `json:"managedBy"`
	// Source is where the user defines it, when ManagedBy is user.
	Source string `json:"source,omitempty"`
}

// DisplayState is what `senda display show` reports.
type DisplayState struct {
	Displays []Display `json:"displays"`
	CanUndo  bool      `json:"canUndo"`
}

// InspectDisplays joins the live monitors with their owners.
func InspectDisplays(ctx context.Context, run stt.Runner, rules []DisplayRule, canUndo bool) (DisplayState, error) {
	monitors, err := hyprctl.New(run).Monitors(ctx)
	if err != nil {
		return DisplayState{}, err
	}
	defs, err := UserDefinitions(MonitorSelector)
	if err != nil {
		return DisplayState{}, fmt.Errorf("leer la configuración de Hyprland: %w", err)
	}
	state := DisplayState{Displays: make([]Display, 0, len(monitors)), CanUndo: canUndo}
	for _, m := range monitors {
		d := Display{Name: m.Name, Description: m.Description, X: m.X, Y: m.Y, Width: m.Width, Height: m.Height, RefreshRate: m.RefreshRate, Scale: m.Scale, Transform: m.Transform, Enabled: !m.Disabled, MirrorOf: m.MirrorOf, Modes: []string{}}
		for _, mode := range m.AvailableModes {
			d.Modes = append(d.Modes, strings.TrimSuffix(mode, "Hz"))
		}
		if claim := claimedBy(defs, m.Name, m.Description); claim != nil {
			d.ManagedBy, d.Source = "user", claim.Source()
		} else if findRule(rules, m) >= 0 {
			d.ManagedBy = "senda"
		}
		state.Displays = append(state.Displays, d)
	}
	return state, nil
}

func findRule(rules []DisplayRule, m hyprctl.Monitor) int {
	output := monitorOutput(m.Name, m.Description)
	for i, rule := range rules {
		if rule.Output() == output {
			return i
		}
	}
	return -1
}

// DisplayChange edits a monitor's rule; unset fields stay as they are.
type DisplayChange struct {
	Mode      string   `json:"mode,omitempty"`
	Position  string   `json:"position,omitempty"`
	Scale     *float64 `json:"scale,omitempty"`
	Transform *int     `json:"transform,omitempty"`
	// Mirror is a monitor name; "none" stops mirroring.
	Mirror  *string `json:"mirror,omitempty"`
	Enabled *bool   `json:"enabled,omitempty"`
}

// DisplayEdit is a change to the named monitor.
type DisplayEdit struct {
	Name string `json:"name"`
	DisplayChange
}

// ChangeDisplay returns rules with the change applied. A monitor without a rule
// starts from its live state, so the rest of its configuration holds.
func ChangeDisplay(ctx context.Context, run stt.Runner, rules []DisplayRule, name string, change DisplayChange) ([]DisplayRule, error) {
	monitors, target, err := liveDisplay(ctx, run, name)
	if err != nil {
		return nil, err
	}
	out := append([]DisplayRule(nil), rules...)
	i := findRule(out, target)
	if i < 0 {
		out = append(out, ruleFromLive(target))
		i = len(out) - 1
	}
	rule := &out[i]
	if change.Mode != "" {
		rule.Mode = change.Mode
	}
	if change.Position != "" {
		rule.Position = change.Position
	}
	if change.Scale != nil {
		rule.Scale = *change.Scale
	}
	if change.Transform != nil {
		rule.Transform = *change.Transform
	}
	if change.Mirror != nil {
		rule.Mirror = ""
		if *change.Mirror != "none" {
			if rule.Mirror, err = mirrorTarget(monitors, target, *change.Mirror); err != nil {
				return nil, err
			}
		}
	}
	if change.Enabled != nil {
		rule.Disabled = !*change.Enabled
		if rule.Disabled && !anotherEnabled(monitors, name) {
			return nil, fmt.Errorf("no se puede apagar la única pantalla activa")
		}
	}
	if err := rule.Validate(); err != nil {
		return nil, err
	}
	return out, nil
}

// AdoptDisplays stores the live state of every monitor without a rule, so that
// removing the user's definitions changes nothing. Rules of monitors the user
// still defines stay inactive until then.
func AdoptDisplays(ctx context.Context, run stt.Runner, rules []DisplayRule) ([]DisplayRule, error) {
	monitors, err := hyprctl.New(run).Monitors(ctx)
	if err != nil {
		return nil, err
	}
	out := append([]DisplayRule(nil), rules...)
	for _, m := range monitors {
		if findRule(out, m) >= 0 {
			continue
		}
		out = append(out, liveRule(m, monitors))
	}
	return out, nil
}

// NormalizeLayout moves the arrangement so its top-left corner is 0x0, keeping
// the monitors' relative places. A user-defined monitor cannot move, so then
// the arrangement stays where it is.
func NormalizeLayout(ctx context.Context, run stt.Runner, rules []DisplayRule) ([]DisplayRule, error) {
	monitors, err := hyprctl.New(run).Monitors(ctx)
	if err != nil {
		return nil, err
	}
	defs, err := UserDefinitions(MonitorSelector)
	if err != nil {
		return nil, fmt.Errorf("leer la configuración de Hyprland: %w", err)
	}
	return normalizeLayout(rules, monitors, defs), nil
}

func normalizeLayout(rules []DisplayRule, monitors []hyprctl.Monitor, defs []Definition) []DisplayRule {
	out := append([]DisplayRule(nil), rules...)
	type place struct{ index, x, y int }
	var places []place
	minX, minY := 0, 0
	for _, m := range monitors {
		i := findRule(out, m)
		if i < 0 {
			out = append(out, ruleFromLive(m))
			i = len(out) - 1
		}
		if out[i].Disabled || out[i].Mirror != "" {
			continue
		}
		if claimedBy(defs, m.Name, m.Description) != nil {
			return rules
		}
		var x, y int
		if _, err := fmt.Sscanf(out[i].Position, "%dx%d", &x, &y); err != nil {
			return rules
		}
		if len(places) == 0 || x < minX {
			minX = x
		}
		if len(places) == 0 || y < minY {
			minY = y
		}
		places = append(places, place{i, x, y})
	}
	if minX == 0 && minY == 0 {
		return rules
	}
	for _, p := range places {
		out[p.index].Position = fmt.Sprintf("%dx%d", p.x-minX, p.y-minY)
	}
	return out
}

// ResetDisplay removes a monitor's rule, handing it back to Hyprland.
func ResetDisplay(ctx context.Context, run stt.Runner, rules []DisplayRule, name string) ([]DisplayRule, error) {
	_, target, err := liveDisplay(ctx, run, name)
	if err != nil {
		return nil, err
	}
	i := findRule(rules, target)
	if i < 0 {
		return nil, fmt.Errorf("Senda no gestiona %s", name)
	}
	return append(append([]DisplayRule(nil), rules[:i]...), rules[i+1:]...), nil
}

// liveDisplay finds a monitor Senda may change: the user always wins.
func liveDisplay(ctx context.Context, run stt.Runner, name string) ([]hyprctl.Monitor, hyprctl.Monitor, error) {
	monitors, err := hyprctl.New(run).Monitors(ctx)
	if err != nil {
		return nil, hyprctl.Monitor{}, err
	}
	for _, m := range monitors {
		if m.Name != name {
			continue
		}
		defs, err := UserDefinitions(MonitorSelector)
		if err != nil {
			return nil, m, fmt.Errorf("leer la configuración de Hyprland: %w", err)
		}
		if claim := claimedBy(defs, m.Name, m.Description); claim != nil {
			return nil, m, fmt.Errorf("%s lo gestiona tu configuración (%s)", name, claim.Source())
		}
		return monitors, m, nil
	}
	return nil, hyprctl.Monitor{}, fmt.Errorf("no hay ninguna pantalla llamada %q", name)
}

func ruleFromLive(m hyprctl.Monitor) DisplayRule {
	mode := "preferred"
	if m.Width > 0 && m.Height > 0 {
		mode = fmt.Sprintf("%dx%d@%.2f", m.Width, m.Height, m.RefreshRate)
	}
	scale := m.Scale
	if scale <= 0 {
		scale = 1
	}
	return DisplayRule{Name: m.Name, Description: m.Description, Mode: mode, Position: fmt.Sprintf("%dx%d", m.X, m.Y), Scale: scale, Transform: m.Transform, Disabled: m.Disabled}
}

// liveRule is ruleFromLive with the monitor it mirrors.
func liveRule(m hyprctl.Monitor, monitors []hyprctl.Monitor) DisplayRule {
	rule := ruleFromLive(m)
	for _, target := range monitors {
		if target.Name == m.MirrorOf {
			rule.Mirror = monitorOutput(target.Name, target.Description)
		}
	}
	return rule
}

func mirrorTarget(monitors []hyprctl.Monitor, source hyprctl.Monitor, name string) (string, error) {
	if name == source.Name {
		return "", fmt.Errorf("una pantalla no puede duplicarse a sí misma")
	}
	for _, m := range monitors {
		if m.Name != name {
			continue
		}
		if m.Disabled || (m.MirrorOf != "" && m.MirrorOf != "none") {
			return "", fmt.Errorf("%s debe estar activa y no duplicar otra pantalla", name)
		}
		return monitorOutput(m.Name, m.Description), nil
	}
	return "", fmt.Errorf("no hay ninguna pantalla llamada %q", name)
}

func anotherEnabled(monitors []hyprctl.Monitor, name string) bool {
	for _, m := range monitors {
		if m.Name != name && !m.Disabled {
			return true
		}
	}
	return false
}
