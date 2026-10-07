class_name Expressions
extends RefCounted
## MapMan's expressions (a prototype): each sets Player's dials (look, lids,
## smile, gaze, head tilt and drop, hops, lying down) for a moment `t`
## seconds into it. Player.emote() plays one; tools/expressions_sheet.gd draws
## them all.

## How long the one-shot expressions take; doze and lie last until woken.
const PERIOD := 4.0
const LENGTHS := {"wake": 1.1, "gasp": 1.0, "doze": INF, "lie": INF}

## What matters more wins: a smaller reaction never cuts off a bigger one
## (a wink waits out the dizziness), a bigger one takes over at once.
const PRIORITIES := {
	"wink": 1,
	"curious": 1,
	"determined": 1,
	"blink": 1,
	"squint": 2,
	"dizzy": 2,
	"happy": 2,
	"proud": 2,
	"surprised": 2,
	"scared": 3,
	"gasp": 3,
	"sad": 3,
	"doze": 0,
	"lie": 0,
	"sleepy": 0,
	"wake": 4,
}


static func priority(id: String) -> int:
	return PRIORITIES.get(id, 1)


static func length(id: String) -> float:
	return LENGTHS.get(id, PERIOD)


# --- timing helpers ---------------------------------------------------------------


static func ramp(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)


## 0 before `start`, up to 1 over `rise`, held for `hold`, back to 0 over `fall`.
static func pulse(x: float, start: float, rise: float, hold: float, fall: float) -> float:
	return (
		ramp(start, start + rise, x)
		* (1.0 - ramp(start + rise + hold, start + rise + hold + fall, x))
	)


## A blink starting at `at`: shut and open again over `span` seconds.
static func blink_at(x: float, at: float, span := 0.16) -> float:
	return clampf(1.0 - absf(x - at - span / 2.0) / (span / 2.0), 0.0, 1.0)


## A hop starting at `at`, `span` long, as Player's _hop dial (1 .. 0).
static func hop_at(x: float, at: float, span: float) -> float:
	if x < at or x > at + span:
		return 0.0
	return 1.0 - (x - at) / span


## Tiny, never-still drift, so nobody stands machine-perfect.
static func drift(x: float, offset: float) -> Vector2:
	return Vector2(
		sin(x * 1.7 + offset) * 0.06 + sin(x * 4.3 + offset * 2.0) * 0.025,
		sin(x * 1.3 + offset * 3.0) * 0.04
	)


# --- the expressions --------------------------------------------------------------


## Every expression dial back to rest.
static func reset(p: Player) -> void:
	p.head_roll = 0.0
	p.head_drop = 0.0
	p.gaze = Vector2.ZERO
	p.lid = Vector2.ZERO
	p.lid_tilt = 0.0
	p.smile = Vector2.ZERO
	p.lower = 0.0
	p.eye_size = Vector2.ONE
	p.lean = 0.0
	p.zzz = 0.0


## Sets every dial for expression `id` at `t` seconds into it.
static func apply(p: Player, id: String, t: float) -> void:
	reset(p)
	p.look = Vector2(0.1, 0.1) + drift(t, float(id.hash() % 100))
	match id:
		"blink":
			p.look.x += sin(t * TAU / PERIOD) * 0.35
			p._blink = maxf(blink_at(t, 1.0), maxf(blink_at(t, 2.9), blink_at(t, 3.15)))
		"wink":
			var w := pulse(t, 1.2, 0.14, 0.75, 0.2)
			var lean := pulse(t, 0.9, 0.35, 1.0, 0.45)
			p.look = Vector2(0.3, 0.15) + drift(t, 3.0)
			p.head_roll = 0.13 * lean
			p.smile = Vector2(0.0, w)
			p.lower = 0.2 * w
			p.squash = 0.12 * pulse(t, 1.15, 0.08, 0.0, 0.3)
			p._blink = blink_at(t, 3.4)
		"squint":
			var s := pulse(t, 0.3, 0.45, 2.6, 0.4)
			p.lid = Vector2(0.38, 0.38) * s
			p.lower = 0.55 * s
			var slide := ramp(0.7, 1.0, t) - 2.0 * ramp(1.7, 2.0, t) + ramp(2.7, 3.0, t)
			p.look = Vector2(0.15 + slide * 0.75, 0.1) + drift(t, 5.0) * 0.5
			p.head_roll = -0.07 * s
		"happy":
			var h := pulse(t, 0.4, 0.25, 2.7, 0.3)
			p.smile = Vector2(h, h)
			p.look = Vector2(0.0, 0.05) + drift(t, 7.0)
			p._hop = maxf(hop_at(t, 0.9, 0.42), hop_at(t, 1.45, 0.42))
			p.squash = 0.35 * (pulse(t, 1.32, 0.02, 0.0, 0.25) + pulse(t, 1.87, 0.02, 0.0, 0.3))
			p.head_roll = 0.08 * sin(t * 5.0) * h
		"sad":
			var s := pulse(t, 0.4, 1.0, 1.7, 0.7)
			p.head_drop = 5.5 * s
			p.look = Vector2(0.1 - 0.15 * s, 0.1 + 0.9 * s) + drift(t, 9.0) * 0.4
			p.gaze = Vector2(0.0, 2.6 * s)
			p.lid = Vector2(0.38, 0.38) * s
			p.lid_tilt = 0.95 * s
			p.head_roll = 0.1 * s
			p.squash = 0.14 * s
			p._blink = blink_at(t, 2.3, 0.5)
		"surprised":
			var pop := pulse(t, 0.8, 0.07, 1.4, 0.6)
			p.eye_size = Vector2.ONE * (1.0 + 0.6 * pop)
			p.look = Vector2(0.0, 0.0) + drift(t, 11.0) * 0.3
			p._hop = hop_at(t, 0.8, 0.3)
			p.squash = 0.3 * pulse(t, 1.08, 0.02, 0.0, 0.25)
			p._blink = maxf(blink_at(t, 2.45, 0.14), blink_at(t, 2.68, 0.14))
		"sleepy":
			var down := ramp(0.2, 2.35, t) * (1.0 - ramp(2.4, 2.5, t))
			var snap := pulse(t, 2.4, 0.06, 0.3, 0.5)
			p.lid = Vector2.ONE * (0.25 + 0.72 * down) * (1.0 - snap)
			p.lid.x += 0.05 * down
			p.head_drop = 4.5 * down
			p.head_roll = 0.16 * down
			p.look = Vector2(0.05, 0.1 + 0.6 * down) + drift(t, 13.0) * 0.3
			p.eye_size = Vector2.ONE * (1.0 + 0.3 * snap)
			p._hop = hop_at(t, 2.4, 0.25)
			p.lid = p.lid.lerp(Vector2(0.3, 0.32), ramp(3.0, 3.9, t))
		"determined":
			var d := pulse(t, 0.25, 0.35, 3.0, 0.3)
			p.lid = Vector2(0.32, 0.32) * d
			p.lid_tilt = -1.0 * d
			p.look = Vector2(0.0, 0.15) + drift(t, 15.0) * 0.3
			p.squash = 0.35 * (pulse(t, 1.2, 0.03, 0.0, 0.3) + pulse(t, 2.1, 0.03, 0.0, 0.3))
			p.head_drop = 1.2 * d
		"scared":
			var s := pulse(t, 0.2, 0.15, 3.2, 0.4)
			p.eye_size = Vector2.ONE * (1.0 + 0.3 * s)
			p.lid_tilt = 0.7 * s
			var dart := [-0.85, 0.8, -0.6, 0.9, -0.9, 0.2]
			var k := clampi(int((t - 0.3) / 0.5), 0, dart.size() - 1)
			p.look = Vector2(lerpf(0.1, dart[k], s), 0.05) + drift(t, 17.0) * 0.3
			p.shake_x = sin(t * 70.0) * 0.9 * s
			p.head_drop = 2.0 * s
			p.squash = 0.12 * s
		"dizzy":
			p.spin = ramp(0.0, 0.6, t) if t < 0.6 else 0.0
			var w := pulse(t, 0.55, 0.2, 2.6, 0.6)
			var a := t * 9.0
			p.gaze = Vector2(cos(a), sin(a)) * 1.4 * w
			p.lid = Vector2(0.2, 0.25) * w
			p.head_roll = sin(t * 3.4) * 0.16 * w
			p.shake_x = sin(t * 3.4 - 0.6) * 3.0 * w
			p.look = Vector2(0.0, 0.05)
		"curious":
			var c := pulse(t, 0.4, 0.5, 2.3, 0.5)
			p.head_roll = 0.3 * c
			p.eye_size = Vector2(1.0 + 0.25 * c, 1.0 - 0.1 * c)
			p.lid = Vector2(0.0, 0.18 * c)
			p.look = Vector2(0.1 + 0.4 * c, 0.1 - 0.25 * c) + drift(t, 19.0)
			p._blink = blink_at(t, 2.2)
		"proud":
			var pr := pulse(t, 0.4, 0.55, 2.4, 0.5)
			p.lid = Vector2(0.55, 0.55) * pr
			p.smile = Vector2(0.25, 0.25) * pr
			p.look = Vector2(0.1 - 0.1 * pr, 0.1 - 0.4 * pr) + drift(t, 21.0) * 0.4
			p.gaze = Vector2(0.0, -1.4 * pr)
			p.head_drop = -2.0 * pr
			p.head_roll = -0.06 * pr + sin(t * 2.2) * 0.03 * pr
		"doze":
			# Lids sink and his head nods; he catches himself once, then sleeps.
			var catch := pulse(t, 2.2, 0.12, 0.2, 0.6)
			var down := ramp(0.0, 4.5, t) * (1.0 - 0.6 * catch)
			p.lid = Vector2.ONE * minf(1.0, 0.2 + 0.85 * down)
			p.head_drop = 5.0 * down
			p.head_roll = 0.15 * down
			p.look = Vector2(0.05, 0.1 + 0.6 * down)
			p.squash = 0.06 * down + sin(t * 1.7) * 0.03 * ramp(4.0, 5.0, t)
		"lie":
			# Topples onto his side, eyes shut, and the Zs drift up.
			var fall := ramp(0.0, 0.7, t)
			p.lean = fall * fall
			p.lid = Vector2.ONE
			p.look = Vector2(0.0, 0.3)
			p.squash = (
				0.3 * pulse(t, 0.68, 0.03, 0.0, 0.3) + sin(t * 1.7) * 0.04 * ramp(1.0, 1.5, t)
			)
			p.zzz = ramp(1.0, 2.0, t)
		"gasp":
			# Caught out (a death tile, lost time): eyes pop at once.
			var pop := pulse(t, 0.0, 0.05, 0.5, 0.4)
			p.eye_size = Vector2.ONE * (1.0 + 0.55 * pop)
			p.look = Vector2(0.0, 0.0)
		"wake":
			# Woken with a jolt: up off the floor, eyes popping.
			p.lean = p.woke_from * (1.0 - ramp(0.0, 0.3, t))
			var pop := pulse(t, 0.0, 0.06, 0.3, 0.6)
			p.eye_size = Vector2.ONE * (1.0 + 0.55 * pop)
			p._hop = 1.0 - clampf(t / 0.35, 0.0, 1.0) if t < 0.35 else 0.0
			p.look = Vector2(0.0, 0.0)
			p._blink = maxf(blink_at(t, 0.65, 0.14), blink_at(t, 0.85, 0.14))
	p.queue_redraw()
