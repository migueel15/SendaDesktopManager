package themeexport

// catppuccinAccents lists Catppuccin's accent names in palette order.
var catppuccinAccents = []string{"rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach", "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender"}

// deriveCatppuccin maps each Catppuccin color name onto the Senda variable
// that plays the same role, so a syntax group always uses the same variable
// and only its value changes between themes. t holds the terminal colors
// derived in Derive.
func deriveCatppuccin(c, t map[string]string) map[string]string {
	return map[string]string{
		"rosewater": c["white"],
		"flamingo":  c["textMuted"],
		"pink":      lighten(c["accent"], 0.55),
		"mauve":     lighten(c["accent"], 0.3),
		"red":       c["error"],
		"maroon":    mix(c["error"], c["text"], 0.2),
		"peach":     t["orange"],
		"yellow":    c["warning"],
		"green":     c["success"],
		"teal":      mix(c["success"], c["info"], 0.5),
		"sky":       t["cyan"],
		"sapphire":  c["info"],
		"blue":      c["primary"],
		"lavender":  c["secondary"],

		"text":     c["text"],
		"subtext1": c["textMuted"],
		"subtext0": mix(c["textMuted"], c["overlay"], 0.5),
		"overlay2": c["overlay"],
		"overlay1": mix(c["overlay"], c["surfaceRaisedBorder"], 0.25),
		"overlay0": mix(c["overlay"], c["surfaceRaisedBorder"], 0.5),
		"surface2": mix(c["overlay"], c["surfaceRaisedBorder"], 0.8),
		"surface1": c["surfaceRaisedBorder"],
		"surface0": c["surfaceVariant"],
		"base":     c["surface"],
		"mantle":   mix(c["surface"], c["base"], 0.5),
		"crust":    c["base"],
	}
}
