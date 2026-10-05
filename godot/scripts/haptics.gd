class_name Haptics
extends RefCounted
## Phone vibration to go with each sound effect: a light tick per step, a
## firmer knock for hazards and a long buzz on death. Not in the original.
## Off when Save.vibration_on is false; does nothing on desktop.

## Sound effect name -> [milliseconds, strength 0-1].
const PATTERNS := {
	"step": [12, 0.25],
	"star": [15, 0.3],
	"points": [30, 0.5],
	"life": [40, 0.6],
	"hide": [30, 0.5],
	"vanish": [30, 0.5],
	"reverse": [30, 0.5],
	"end_level": [50, 0.7],
	"sticky": [80, 0.8],
	"crumble": [60, 0.7],  # the tile behind MapMan falling away
	"checkpoint": [120, 0.8],
	"love": [150, 0.4],
	"lose_life": [250, 1.0],
	"toggle": [40, 0.6],  # turning vibration on in the options
	"stamp": [60, 0.9],  # a rubber stamp landing on a menu sheet
	"recentre": [25, 0.5],  # tapping the tilt gauge to take a new level
}

## The last buzz requested, for tests: [name, milliseconds, strength].
static var last: Array = []


static func feel(name: String) -> void:
	if not Save.vibration_on or not PATTERNS.has(name):
		return
	var p: Array = PATTERNS[name]
	last = [name, p[0], p[1]]
	Input.vibrate_handheld(p[0], p[1])
