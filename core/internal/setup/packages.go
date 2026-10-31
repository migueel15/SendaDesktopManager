package setup

// Requirement maps something Senda uses to the Arch package providing it.
// Command is checked on PATH; when it is empty, the package itself is checked
// with pacman, for fonts, themes, and daemons that have no command.
type Requirement struct {
	Command string
	Package string
}

// Requirements lists everything Senda needs, in the order it is reported.
var Requirements = []Requirement{
	{Command: "qs", Package: "quickshell"},
	{Command: "hyprctl", Package: "hyprland"},
	{Command: "hypridle", Package: "hypridle"},
	{Command: "pkexec", Package: "polkit"},
	{Command: "jq", Package: "jq"},
	{Command: "nmcli", Package: "networkmanager"},
	{Command: "wpctl", Package: "wireplumber"},
	{Command: "upower", Package: "upower"},
	{Command: "bluetoothctl", Package: "bluez-utils"},
	{Package: "bluez"},
	{Command: "blueberry", Package: "blueberry"},
	{Command: "brightnessctl", Package: "brightnessctl"},
	{Command: "ddcutil", Package: "ddcutil"},
	{Command: "ffplay", Package: "ffmpeg"},
	{Command: "xdg-open", Package: "xdg-utils"},
	{Command: "secret-tool", Package: "libsecret"},
	{Command: "python3", Package: "python"},
	{Command: "grim", Package: "grim"},
	{Command: "wl-copy", Package: "wl-clipboard"},
	{Command: "pw-record", Package: "pipewire"},
	{Package: "sound-theme-freedesktop"},
	{Package: "inter-font"},
	{Package: "ttf-nerd-fonts-symbols"},
}

// Label names the requirement in messages: the command when there is one,
// otherwise the package.
func (r Requirement) Label() string {
	if r.Command != "" {
		return r.Command
	}
	return r.Package
}

// MissingRequirements returns the requirements that are not present, keeping
// the order of Requirements. Commands are looked up with lookPath; packages
// without a command are checked with installed.
func MissingRequirements(lookPath func(string) (string, error), installed func(string) bool) []Requirement {
	var missing []Requirement
	for _, req := range Requirements {
		if req.Command == "" {
			if !installed(req.Package) {
				missing = append(missing, req)
			}
			continue
		}
		if _, err := lookPath(req.Command); err != nil {
			missing = append(missing, req)
		}
	}
	return missing
}
