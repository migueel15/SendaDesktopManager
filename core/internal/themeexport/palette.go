package themeexport

import "math"

// ANSINames orders the 16 terminal colors as color0..color15.
var ANSINames = []string{"black", "red", "green", "yellow", "blue", "magenta", "cyan", "white", "brightBlack", "brightRed", "brightGreen", "brightYellow", "brightBlue", "brightMagenta", "brightCyan", "brightWhite"}

// Palette is the data every template receives.
type Palette struct {
	Name string
	// C holds the 21 theme colors.
	C map[string]string
	// T holds colors derived for terminals and editors: the ANSI names plus orange.
	T map[string]string
	// ANSI is T in color0..color15 order.
	ANSI []string
	// K holds the theme mapped onto Catppuccin's color names (see catppuccin.go).
	K    map[string]string
	Dark bool
}

// Derive builds the template palette from the theme colors. The semantic
// colors map directly to red, green and yellow; blue, magenta and cyan reuse a
// theme color with a close hue or are synthesized from primary's saturation
// and lightness so they stay in the same family.
func Derive(name string, colors map[string]string) Palette {
	c := colors
	used := map[string]bool{}
	pool := []string{"info", "primary", "secondary", "focus", "accent"}
	_, ps, pl := hsl(c["primary"])
	ps, pl = math.Max(0.45, math.Min(0.85, ps)), math.Max(0.62, math.Min(0.75, pl))
	pick := func(target float64) string {
		best, bestDistance := "", 36.0
		for _, key := range pool {
			h, s, l := hsl(c[key])
			if used[c[key]] || s < 0.4 || l < 0.55 || l > 0.85 {
				continue
			}
			if d := hueDistance(h, target); d < bestDistance {
				best, bestDistance = key, d
			}
		}
		if best == "" {
			return fromHSL(target, ps, pl)
		}
		used[c[best]] = true
		return c[best]
	}
	t := map[string]string{
		"black":  c["surfaceVariant"],
		"red":    c["error"],
		"green":  c["success"],
		"yellow": c["warning"],
		"blue":   pick(220),
		"white":  c["textMuted"],
	}
	t["magenta"] = pick(300)
	t["cyan"] = pick(185)
	t["brightBlack"] = c["overlay"]
	t["brightWhite"] = c["white"]
	for _, key := range []string{"red", "green", "yellow", "blue", "magenta", "cyan"} {
		t["bright"+string(key[0]-32)+key[1:]] = lighten(t[key], 0.18)
	}
	t["orange"] = mix(c["error"], c["warning"], 0.5)
	ansi := make([]string, len(ANSINames))
	for i, key := range ANSINames {
		ansi[i] = t[key]
	}
	return Palette{Name: name, C: c, T: t, ANSI: ansi, K: deriveCatppuccin(c, t), Dark: isDark(c["background"])}
}
