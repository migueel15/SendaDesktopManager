package setup

// Requirement maps a command that Senda uses to the Arch package providing it.
type Requirement struct {
	Command string
	Package string
}

// Requirements lists the commands Senda needs, in the order they are reported.
var Requirements = []Requirement{
	{Command: "qs", Package: "quickshell"},
	{Command: "awww", Package: "awww"},
	{Command: "jq", Package: "jq"},
	{Command: "nmcli", Package: "networkmanager"},
	{Command: "wpctl", Package: "wireplumber"},
	{Command: "hyprlock", Package: "hyprlock"},
	{Command: "python3", Package: "python"},
}

// MissingRequirements returns the requirements whose command cannot be found
// by lookPath, keeping the order of Requirements.
func MissingRequirements(lookPath func(string) (string, error)) []Requirement {
	var missing []Requirement
	for _, req := range Requirements {
		if _, err := lookPath(req.Command); err != nil {
			missing = append(missing, req)
		}
	}
	return missing
}
