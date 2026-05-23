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
}

type AnimationKind string

const (
	AnimationNone   AnimationKind = "none"
	AnimationFade   AnimationKind = "fade"
	AnimationGrow   AnimationKind = "grow"
	AnimationWipe   AnimationKind = "wipe"
	AnimationRandom AnimationKind = "random"
	AnimationWave   AnimationKind = "wave"
)

type ResizeMode string

const (
	ResizeNone    ResizeMode = "none"
	ResizeCrop    ResizeMode = "crop"
	ResizeFit     ResizeMode = "fit"
	ResizeStretch ResizeMode = "stretch"
)

type Position struct {
	X int
	Y int
}

type SetOptions struct {
	Monitor   *Monitor
	Animation *Animation
	Resize    *ResizeMode
}

type Backend interface {
	Set(wallpaper Wallpaper, options SetOptions) error
}
