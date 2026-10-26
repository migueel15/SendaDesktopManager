package themeexport

import (
	"fmt"
	"math"
	"strconv"
)

type rgb struct{ r, g, b float64 }

func parseHex(value string) (rgb, error) {
	if len(value) != 7 || value[0] != '#' {
		return rgb{}, fmt.Errorf("expected #RRGGBB, got %q", value)
	}
	n, err := strconv.ParseUint(value[1:], 16, 32)
	if err != nil {
		return rgb{}, fmt.Errorf("expected #RRGGBB, got %q", value)
	}
	return rgb{float64(n>>16) / 255, float64(n>>8&0xff) / 255, float64(n&0xff) / 255}, nil
}

func mustHex(value string) rgb {
	c, err := parseHex(value)
	if err != nil {
		panic(err)
	}
	return c
}

func (c rgb) hex() string {
	channel := func(v float64) int { return int(math.Round(math.Max(0, math.Min(1, v)) * 255)) }
	return fmt.Sprintf("#%02X%02X%02X", channel(c.r), channel(c.g), channel(c.b))
}

// mix returns a blended toward b by t (0 keeps a, 1 returns b).
func mix(a, b string, t float64) string {
	x, y := mustHex(a), mustHex(b)
	return rgb{x.r + (y.r-x.r)*t, x.g + (y.g-x.g)*t, x.b + (y.b-x.b)*t}.hex()
}

func lighten(c string, t float64) string { return mix(c, "#FFFFFF", t) }
func darken(c string, t float64) string  { return mix(c, "#000000", t) }

// luminance is the WCAG relative luminance.
func luminance(c string) float64 {
	v := mustHex(c)
	linear := func(x float64) float64 {
		if x <= 0.04045 {
			return x / 12.92
		}
		return math.Pow((x+0.055)/1.055, 2.4)
	}
	return 0.2126*linear(v.r) + 0.7152*linear(v.g) + 0.0722*linear(v.b)
}

func isDark(c string) bool { return luminance(c) < 0.18 }

// hsl returns hue in degrees, saturation and lightness in [0,1].
func hsl(c string) (h, s, l float64) {
	v := mustHex(c)
	maxV, minV := math.Max(v.r, math.Max(v.g, v.b)), math.Min(v.r, math.Min(v.g, v.b))
	l = (maxV + minV) / 2
	d := maxV - minV
	if d == 0 {
		return 0, 0, l
	}
	s = d / (1 - math.Abs(2*l-1))
	switch maxV {
	case v.r:
		h = math.Mod((v.g-v.b)/d, 6)
	case v.g:
		h = (v.b-v.r)/d + 2
	default:
		h = (v.r-v.g)/d + 4
	}
	h *= 60
	if h < 0 {
		h += 360
	}
	return h, s, l
}

func fromHSL(h, s, l float64) string {
	c := (1 - math.Abs(2*l-1)) * s
	x := c * (1 - math.Abs(math.Mod(h/60, 2)-1))
	m := l - c/2
	var r, g, b float64
	switch {
	case h < 60:
		r, g, b = c, x, 0
	case h < 120:
		r, g, b = x, c, 0
	case h < 180:
		r, g, b = 0, c, x
	case h < 240:
		r, g, b = 0, x, c
	case h < 300:
		r, g, b = x, 0, c
	default:
		r, g, b = c, 0, x
	}
	return rgb{r + m, g + m, b + m}.hex()
}

func hueDistance(a, b float64) float64 {
	d := math.Abs(a - b)
	return math.Min(d, 360-d)
}
