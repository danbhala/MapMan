class_name Blueprint
extends RefCounted
## The Blueprint look: an engineering drawing on blue paper. The palette, the
## fonts and the sheet furniture (grid, frame, rules, stamps, list items) that
## the menus, the HUD and the playing field share.
##
## Every colour here was checked against FIELD for contrast: ink and the
## three accents all clear WCAG AA for small text (FAINT 5.4:1, PINK 5.3:1,
## LILAC 5.1:1, MINT 6.6:1, GOLD 7.1:1, INK 10.3:1).

const FIELD := Color("#16407a")
const GRID := Color(1, 1, 1, 0.12)
const INK := Color.WHITE
const FAINT := Color(1, 1, 1, 0.66)
const DIM := Color(1, 1, 1, 0.55)
const PINK := Color("#ff9fb5")
const GOLD := Color("#ffd166")
const LILAC := Color("#c9a6ff")
const MINT := Color("#8be0c8")
const STRIP := Color(0, 0, 0, 0.35)
const BAR := Color(0, 0, 0, 0.45)
const PRESS := Color(1, 1, 1, 0.22)
const HOVER := Color(1, 1, 1, 0.1)

const GRID_STEP := 25.0
## The drawing frame's inset from the screen edge.
const INSET := 12.0
const FRAME_WIDTH := 1.5
const FONT_PATH := "res://assets/fonts/JetBrainsMono-Variable.ttf"
## The star, heart and skull JetBrains Mono lacks, from a DejaVu Sans subset,
## so they draw the same on every machine instead of from a system font.
const SYMBOLS_PATH := "res://assets/fonts/MapManSymbols.ttf"
## Scripts JetBrains Mono has no glyphs for, as Noto Sans subsets cut down to
## the characters the translations use (tools/subset_fonts.py).
const SCRIPT_FONTS := [
	"res://assets/fonts/i18n/NotoSansArabic-Subset.ttf",
	"res://assets/fonts/i18n/NotoSansJP-Subset.ttf",
	"res://assets/fonts/i18n/NotoSansKR-Subset.ttf",
	"res://assets/fonts/i18n/NotoSansSC-Subset.ttf",
	"res://assets/fonts/i18n/NotoSansTC-Subset.otf",
]
const STAMP_ROTATION := -0.12
## The height of a tappable row or cell: 48 dp on a 360-450 dp phone screen.
const TAP_HEIGHT := 44.0

static var _fonts := {}
static var _theme: Theme
static var _focus_ring: StyleBox
static var _focus_none: StyleBox


## JetBrains Mono at a weight (400 regular .. 800 extra bold).
static func mono(weight := 500) -> Font:
	if not _fonts.has(weight):
		var v := FontVariation.new()
		v.base_font = load(FONT_PATH)
		v.variation_opentype = {
			TextServerManager.get_primary_interface().name_to_tag("wght"): weight
		}
		var fallbacks: Array[Font] = [load(SYMBOLS_PATH)]
		for path in SCRIPT_FONTS:
			if ResourceLoader.exists(path):
				# The same weight for the fallback, so bold stays bold in every script.
				var f := FontVariation.new()
				f.base_font = load(path)
				f.variation_opentype = {
					TextServerManager.get_primary_interface().name_to_tag("wght"): weight
				}
				fallbacks.append(f)
		v.fallbacks = fallbacks
		_fonts[weight] = v
	return _fonts[weight]


## False when the player asked for less motion: animations then skip to the end.
## Looks Save up in the tree rather than naming the autoload: scripts a test
## names at parse time (LevelMap, and so this one) compile before the
## autoloads exist, and a bare `Save` there is a compile error.
static func motion() -> bool:
	var save := autoload("Save")
	return save == null or not save.reduce_motion


## An autoload by name, or null outside the game (see motion()).
static func autoload(name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(name)


## The theme for buttons on a sheet: a parts-list row with a rule under it.
static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font = mono(500)
		_theme.default_font_size = 16
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color.TRANSPARENT
		normal.border_color = INK
		normal.border_width_bottom = 1
		normal.content_margin_left = 12
		normal.content_margin_right = 12
		var hover: StyleBoxFlat = normal.duplicate()
		hover.bg_color = HOVER
		var pressed: StyleBoxFlat = normal.duplicate()
		pressed.bg_color = PRESS
		var focus := StyleBoxFlat.new()
		focus.draw_center = false
		focus.border_color = INK
		focus.set_border_width_all(1)
		_focus_ring = focus
		_focus_none = StyleBoxEmpty.new()
		var disabled: StyleBoxFlat = normal.duplicate()
		disabled.border_color = DIM
		_theme.set_stylebox("normal", "Button", normal)
		_theme.set_stylebox("hover", "Button", hover)
		_theme.set_stylebox("pressed", "Button", pressed)
		_theme.set_stylebox("hover_pressed", "Button", pressed)
		# The ring only shows once a key or a gamepad is used (show_focus).
		_theme.set_stylebox("focus", "Button", _focus_none)
		_theme.set_stylebox("disabled", "Button", disabled)
		for n in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			_theme.set_color(n, "Button", INK)
		_theme.set_color("font_hover_pressed_color", "Button", INK)
		_theme.set_color("font_disabled_color", "Button", DIM)
	return _theme


## Draw the focus ring on the focused button: on for keys and gamepads, off
## for touch and the mouse, where a ring round the first row only confuses.
static func show_focus(on: bool) -> void:
	theme().set_stylebox("focus", "Button", _focus_ring if on else _focus_none)


# --- building blocks ----------------------------------------------------------


static func label(
	parent: Node,
	text: String,
	size: int,
	color := INK,
	pos := Vector2.ZERO,
	weight := 500,
	width := 0.0,
	align := HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Into the tree before it is sized: a control sized outside the tree
	# measures its text with the default theme's font, and keeps that box.
	parent.add_child(l)
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", mono(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.text_direction = direction(text)
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fit(l, Vector2(width, l.size.y))
	return l


## The way a text reads: right-to-left scripts decide for themselves, and
## everything else (figures like "+10" or "T-0:20" included) reads left to
## right, whatever the phone's language.
static func direction(text: String) -> Control.TextDirection:
	for ch in text:
		var c := ch.unicode_at(0)
		var rtl: bool = (
			(c >= 0x0590 and c <= 0x08FF)
			or (c >= 0xFB1D and c <= 0xFDFF)
			or (c >= 0xFE70 and c <= 0xFEFF)
		)
		if rtl:
			return Control.TEXT_DIRECTION_AUTO
	return Control.TEXT_DIRECTION_LTR


## Size a control to the box it was given, and remember the box: a control
## grows to hold its text, so the layout check (tools/layout_check.gd) needs
## the size that was meant.
static func fit(c: Control, size: Vector2) -> void:
	c.set_meta("fit", size)
	c.size = size


## A row of the parts list: "01    PLAY FROM START", with a rule under it.
static func item(
	parent: Node, text: String, pos: Vector2, size := Vector2(380, TAP_HEIGHT), enabled := true
) -> Button:
	var b := Button.new()
	b.theme = theme()
	parent.add_child(b)
	b.text = text
	b.text_direction = direction(text)
	b.position = pos
	fit(b, size)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not enabled
	if not enabled:
		b.focus_mode = Control.FOCUS_NONE
	b.accessibility_name = text.strip_edges()
	return b


static func line(parent: Node, points: PackedVector2Array, color := INK, width := 1.0) -> Line2D:
	var l := Line2D.new()
	l.points = points
	l.default_color = color
	l.width = width
	l.antialiased = true
	parent.add_child(l)
	return l


static func rect(parent: Node, color: Color, pos: Vector2, size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## A horizontal rule.
static func rule(parent: Node, y: float, x0: float, x1: float, color := INK) -> Line2D:
	return line(parent, PackedVector2Array([Vector2(x0, y), Vector2(x1, y)]), color, 1.0)


## The five points of a closed rectangle, for Line2D.
static func box_points(pos: Vector2, size: Vector2) -> PackedVector2Array:
	return PackedVector2Array(
		[pos, pos + Vector2(size.x, 0), pos + size, pos + Vector2(0, size.y), pos]
	)


static func ellipse_points(centre: Vector2, rx: float, ry: float, n := 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := TAU * i / n
		pts.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## The drawing frame: a rectangle INSET from the edge of `size`.
static func frame_points(size: Vector2) -> PackedVector2Array:
	return box_points(Vector2(INSET, INSET), size - Vector2(INSET, INSET) * 2.0)


## The first `share` (0..1) of a polyline, by length: for drawing a line on.
static func truncated(points: PackedVector2Array, share: float) -> PackedVector2Array:
	if points.size() < 2 or share >= 1.0:
		return points
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	var left := total * clampf(share, 0.0, 1.0)
	var out := PackedVector2Array([points[0]])
	for i in points.size() - 1:
		var seg := points[i].distance_to(points[i + 1])
		if seg <= left:
			out.append(points[i + 1])
			left -= seg
			if left <= 0.0:
				break
		else:
			out.append(points[i].lerp(points[i + 1], left / seg if seg > 0.0 else 1.0))
			break
	return out


# --- motion -------------------------------------------------------------------


## Draw a line on from its first point, like a pen: `seconds` for the whole length.
static func draw_on(l: Line2D, seconds: float, delay := 0.0) -> void:
	if not motion():
		return
	var full := l.points
	l.points = truncated(full, 0.0)
	var tw := l.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(k: float): l.points = truncated(full, k), 0.0, 1.0, seconds)


## Fade a node in with a small lift, after `delay` seconds.
static func reveal(node: CanvasItem, delay := 0.0, seconds := 0.35) -> void:
	if not motion():
		return
	node.modulate.a = 0.0
	var tw := node.create_tween().set_parallel()
	tw.tween_property(node, "modulate:a", 1.0, seconds).set_delay(delay)
	if node is Control:
		var y: float = node.position.y
		(
			tw
			. tween_property(node, "position:y", y, seconds)
			. from(y + 6.0)
			. set_delay(delay)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT)
		)


## A rubber stamp: bold text in a box, a little askew. `slam` drops it onto the
## sheet (scale and alpha) the way a hand would; off with reduced motion.
static func stamp(
	parent: Node, text: String, pos: Vector2, color := GOLD, slam := false, delay := 0.0
) -> Node2D:
	var n := Node2D.new()
	n.position = pos
	n.rotation = STAMP_ROTATION
	parent.add_child(n)
	var l := label(n, text, 22, color, Vector2.ZERO, 800)
	l.size = l.get_minimum_size()
	var w := l.size.x + 20.0
	line(n, box_points(Vector2(-10, -4), Vector2(w, 40)), color, 2.0)
	if not slam or not motion():
		return n
	n.scale = Vector2(2.6, 2.6)
	n.modulate.a = 0.0
	var tw := n.create_tween().set_parallel()
	if delay > 0.0:
		tw.tween_interval(delay)
		# chain() alone: set_parallel() here would cancel the step it opens.
		tw.chain()
	tw.tween_property(n, "scale", Vector2(0.94, 0.94), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	tw.tween_property(n, "modulate:a", 1.0, 0.08)
	tw.tween_property(n, "rotation", STAMP_ROTATION, 0.16).from(STAMP_ROTATION - 0.18)
	tw.chain().tween_property(n, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tw.chain().tween_callback(func(): autoload("Audio").play("stamp"))
	return n


## The faint grid of the drawing paper, drawn in one node.
class Grid:
	extends Node2D
	var size := Vector2(667, 375)
	var color := GRID

	func _draw() -> void:
		var x := 0.0
		while x <= size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), color, 1.0)
			x += GRID_STEP
		var y := 0.0
		while y <= size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), color, 1.0)
			y += GRID_STEP


static func grid(parent: Node, size: Vector2, color := GRID) -> Grid:
	var g := Grid.new()
	g.size = size
	g.color = color
	parent.add_child(g)
	return g
