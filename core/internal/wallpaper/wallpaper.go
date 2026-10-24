package wallpaper

import (
	"time"
)

type Wallpaper struct {
	Path string
}

type Monitor string

type Animation struct {
	Kind     AnimationKind
	Duration time.Duration
	FPS      int
	Origin   *Position
	Angle    *int
	Bezier   [4]float64
}

type AnimationKind string

const (
	AnimationNone   AnimationKind = "none"
	AnimationFade   AnimationKind = "fade"
	AnimationGrow   AnimationKind = "grow"
	AnimationWipe   AnimationKind = "wipe"
	AnimationRandom AnimationKind = "random"
	AnimationWave   AnimationKind = "wave"
	AnimationCenter AnimationKind = "center"
	AnimationAny    AnimationKind = "any"
	AnimationOuter  AnimationKind = "outer"
)

type ResizeMode string

const (
	ResizeNone    ResizeMode = "none"
	ResizeCrop    ResizeMode = "crop"
	ResizeFit     ResizeMode = "fit"
	ResizeStretch ResizeMode = "stretch"
)

type Position struct {
	X int `json:"x"`
	Y int `json:"y"`
}

type SetOptions struct {
	Monitor   *Monitor
	Animation *Animation
	Resize    *ResizeMode
}
