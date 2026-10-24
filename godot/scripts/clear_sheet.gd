class_name ClearSheet
extends RefCounted
## The level clear of the main game: the bonuses count into the score, then
## MENU, WARDROBE and NEXT come up under the total, NEXT solid at the far end. Static functions that
## build onto the Menus sheet they are given, with its own helpers, as
## WardrobeSheet does; their words are in Menus.TEXT. The count-up serves
## the final inspection too.

## Where its table starts and its pitch (tighter than Menus.ROW_H, to make
## room for the buttons), the buttons' row, their widths in reading order
## (MENU, WARDROBE, NEXT: the way on sits at the far end, where the eye
## finishes the row; MENU takes whatever WARDROBE leaves) with the gap after
## each, and the small print when no slip takes its place.
const ROWS_Y := 80.0
const PITCH := 30.0
const BUTTONS_Y := 232.0
const BUTTON_WS := [84.0, 116.0, 164.0]
const GAPS := [4.0, 12.0]
const BUTTON_FONT := 14
const NEXT_FONT := 16
## NEXT's arrow: a chevron this tall, this far in from the button's far end,
## that nudges forward this far and back once a beat while NEXT waits.
const ARROW_H := 12.0
const ARROW_IN := 18.0
const ARROW_NUDGE := 4.0
const ARROW_BEAT := 0.9
const NOTE_Y := 296.0
## WATCH REPLAY, under MapMan on the far side.
const REPLAY_POS := Vector2(448, 248)
const REPLAY_W := 196.0

## The count-up: each row's figure and the TOTAL climb together in at most
## TICKS ticks this far apart, so a big bonus takes no longer than a small
## one, and the ticks rise in pitch by up to TICK_RISE on the way to the total.
const TICKS := 16
const TICK := 0.05
const TICK_RISE := 0.6


## Level clear: the bonuses are added into the score one row at a time, then
## MENU, WARDROBE and NEXT come up under the total. A tap before then
## finishes the count; after it, a tap goes on to the next level. `args` are
## Menus.show_end_level's: score, level_bonus, time_bonus, stars, checkpoint,
## level, seconds_left (the clock at the exit, the time bonus's quantity),
## last (level 100: the final sheet comes next), released (the look this
## first clear released, if any, for a slip with a button to wear it) and
## tries (how many tries the replay shows: WATCH REPLAY when there are any).
static func end_level(m: Menus, args: Array) -> void:
	var score: int = args[0]
	var level_bonus: int = args[1]
	var time_bonus: int = args[2]
	var stars: int = args[3]
	var checkpoint: bool = args[4]
	var level: int = args[5]
	var seconds_left: int = args[6]
	var last: bool = args[7]
	var released: String = args[8]
	var tries: int = args[9] if args.size() > 9 else 0
	# The question before quitting from here numbers itself after this sheet.
	m._level = level
	m._tutorial = false
	var title: String = (
		(m._t("checkpoint_title") if checkpoint else m._t("inspection_title")) % level
	)
	m._open("end_level", "%03d" % level, title, Blueprint.GOLD if checkpoint else Blueprint.INK)
	var col_names := [m._t("col_item"), m._t("col_qty"), m._t("col_value")]
	m._columns(col_names, [Menus.LIST_X, 226], true)
	var clock := seconds_left if seconds_left >= 0 else time_bonus * 2
	var specs := [
		[m._t("level_bonus"), "1", level_bonus],
		[m._t("time_bonus"), m._t("seconds") % clock, time_bonus],
	]
	if stars > 0:
		specs.append([m._t("stars_collected"), str(stars), stars])
	var rows := []
	var y := ROWS_Y
	for s in specs:
		var row := m._table_row(y, s[0], s[1], Menus.TEXT.plus % s[2])
		rows.append({"node": row, "points": s[2], "value": row.get_meta("value")})
		y += PITCH
	var total := m._total(y + 4, str(score))
	if checkpoint:
		m._note(m._t("checkpoint_saved"), y + 40, Blueprint.GOLD, 11)
	# Three kinds of button, so the way on can't be missed: MENU a quiet word,
	# WARDROBE an outlined box, NEXT solid with an arrow, at the end of the row.
	# Laid from the far end, so a long word in WARDROBE takes room from MENU.
	var end := Menus.LIST_X + Menus.LIST_W
	var next := _side_button(m, 0.0, BUTTON_WS[2], m._t("next"), m._t("next_level"), "next level")
	var arrow := _solid(m, next)
	_place(m, next, end - BUTTON_WS[2], BUTTON_WS[2])
	var wardrobe_text := m.tr(WardrobeSheet.TEXT.title)
	var wardrobe := _side_button(
		m, 0.0, BUTTON_WS[1], wardrobe_text, wardrobe_text, "clear wardrobe"
	)
	_outlined(wardrobe)
	var ww := maxf(BUTTON_WS[1], wardrobe.get_combined_minimum_size().x)
	var wx := end - BUTTON_WS[2] - GAPS[1] - ww
	_place(m, wardrobe, wx, ww)
	var menu := _side_button(m, 0.0, BUTTON_WS[0], m._t("menu"), m._t("main_menu"), "leave clear")
	_quiet(menu)
	_place(m, menu, Menus.LIST_X, wx - GAPS[0] - Menus.LIST_X)
	# NEXT first: it takes the focus and a gamepad's first press.
	var buttons: Array[Button] = [next, wardrobe, menu]
	if tries > 0:
		buttons.append(_replay_button(m, tries))
	if released != "":
		WardrobeSheet.release_slip(m, released)
	else:
		m._note(m._t("tap_final") if last else m._t("tap_next") % (level + 1), NOTE_Y)
	m._hero_on("tilt")
	var passed := Vector2(470, m._over_head(90, Menus.HERO_POS.y))
	if m._animate:
		# Out of reach until the count is in: a tap until then finishes it.
		for b in buttons:
			b.modulate.a = 0.0
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.focus_mode = Control.FOCUS_NONE
		m._tap_to(Menus.FINISH, 0.2)
	var all_in := func():
		m._stamp(m._t("passed"), passed, Blueprint.GOLD, 0.0)
		for b in buttons:
			if b.modulate.a < 1.0:
				Blueprint.reveal(b)
			b.mouse_filter = Control.MOUSE_FILTER_STOP
			b.focus_mode = Control.FOCUS_ALL
		m._tap_to("next level")
		m._first_button = next
		m._focus_first()
		_nudge(m, arrow)
	count_up(m, total, score, rows, all_in)


## One of the level clear's buttons, side by side under the TOTAL, `w` wide
## from `x` (mirrored on a right-to-left sheet).
static func _side_button(
	m: Menus, x: float, w: float, text: String, a11y: String, act: String
) -> Button:
	var pos := Vector2(m._mx(x, w), BUTTONS_Y)
	var b := Blueprint.item(m._panel, text, pos, Vector2(w, Blueprint.TAP_HEIGHT))
	b.add_theme_font_size_override("font_size", BUTTON_FONT)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.accessibility_name = m._sentence(a11y)
	m._connect(b, act)
	return b


## Move a level clear button to `x`, `w` wide (mirrored on a right-to-left sheet).
static func _place(m: Menus, b: Button, x: float, w: float) -> void:
	b.position.x = m._mx(x, w)
	Blueprint.fit(b, Vector2(w, Blueprint.TAP_HEIGHT))


## MENU: a word on the sheet, no rule under it, for the way out.
static func _quiet(b: Button) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.content_margin_left = 4
	box.content_margin_right = 4
	_styles(b, box, Blueprint.FAINT)


## WARDROBE: a box ruled all round, for a side trip.
static func _outlined(b: Button) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = Blueprint.INK
	box.set_border_width_all(1)
	box.content_margin_left = 8
	box.content_margin_right = 8
	_styles(b, box, Blueprint.INK)


## NEXT: filled with ink, its word in the sheet's own blue, bold, with a
## chevron at the far end pointing on (back, on a right-to-left sheet).
## Returns the chevron, for _nudge.
static func _solid(m: Menus, b: Button) -> Line2D:
	var box := StyleBoxFlat.new()
	box.bg_color = Blueprint.INK
	box.content_margin_left = 12
	box.content_margin_right = 12
	if m._rtl:
		box.content_margin_left += ARROW_IN
	else:
		box.content_margin_right += ARROW_IN
	_styles(b, box, Blueprint.field)
	b.add_theme_font_override("font", Blueprint.mono(800))
	b.add_theme_font_size_override("font_size", NEXT_FONT)
	var size: Vector2 = b.get_meta("fit")
	var tip := ARROW_IN if m._rtl else size.x - ARROW_IN
	var back := 5.0 if m._rtl else -5.0
	var mid := size.y / 2.0
	var h := ARROW_H / 2.0
	var arrow := Line2D.new()
	arrow.points = PackedVector2Array(
		[Vector2(tip + back, mid - h), Vector2(tip, mid), Vector2(tip + back, mid + h)]
	)
	arrow.default_color = Blueprint.field
	arrow.width = 2.5
	arrow.joint_mode = Line2D.LINE_JOINT_ROUND
	arrow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	arrow.end_cap_mode = Line2D.LINE_CAP_ROUND
	arrow.antialiased = true
	b.add_child(arrow)
	return arrow


## One look for a button in every state: a touch shades it, as on any sheet.
static func _styles(b: Button, normal: StyleBoxFlat, ink: Color) -> void:
	var hover: StyleBoxFlat = normal.duplicate()
	var pressed: StyleBoxFlat = normal.duplicate()
	if normal.bg_color.a > 0.0:
		hover.bg_color = normal.bg_color.darkened(0.06)
		pressed.bg_color = normal.bg_color.darkened(0.18)
	else:
		hover.bg_color = Blueprint.HOVER
		pressed.bg_color = Blueprint.PRESS
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	for n in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color",
		"font_hover_pressed_color",
	]:
		b.add_theme_color_override(n, ink)


## NEXT's chevron steps forward and back once a beat while the sheet waits:
## the one thing moving says which way to go. Still with reduced motion.
static func _nudge(m: Menus, arrow: Line2D) -> void:
	if not m._animate:
		return
	var step := Vector2(-ARROW_NUDGE if m._rtl else ARROW_NUDGE, 0.0)
	var tw := m.create_tween().set_loops()
	m._tweens.append(tw)
	tw.tween_property(arrow, "position", step, ARROW_BEAT * 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(arrow, "position", Vector2.ZERO, ARROW_BEAT * 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(ARROW_BEAT * 0.4)


## WATCH REPLAY: every try at the level played back at once (Replay).
static func _replay_button(m: Menus, tries: int) -> Button:
	var pos := Vector2(m._mx(REPLAY_POS.x, REPLAY_W), REPLAY_POS.y)
	var text := m.tr("WATCH REPLAY")
	var b := Blueprint.item(m._panel, text, pos, Vector2(REPLAY_W, Blueprint.TAP_HEIGHT))
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.accessibility_name = (
		"%s, %s" % [m._sentence(text), m._sentence(m.tr_n("%d TRY", "%d TRIES", tries) % tries)]
	)
	m._connect(b, "replay")
	return b


## The TOTAL counts up from `start` as each row is revealed in turn, the
## row's own figure counting up from +0 with it; `rows` are [{"node":
## CanvasItem, "points": int, "value": Label (optional)}]. When it's all in
## the total gives a bump and `then` runs (at once with reduced motion).
static func count_up(m: Menus, label: Label, start: int, rows: Array, then: Callable) -> void:
	var all := 0
	for r in rows:
		all += r.points
	if not m._animate:
		label.text = str(start + all)
		then.call()
		return
	var tw := m.create_tween()
	m._tweens.append(tw)
	tw.tween_interval(Menus.DRAW_ON)
	var done := 0
	for r in rows:
		var node: CanvasItem = r.node
		node.modulate.a = 0.0
		var value: Label = r.get("value")
		var points: int = r.points
		if value != null and points > 0:
			value.text = Menus.TEXT.plus % 0
		tw.tween_callback(func(): Blueprint.reveal(node))
		tw.tween_interval(0.2)
		var ticks := mini(points, TICKS)
		for i in ticks:
			@warning_ignore("integer_division")
			var upto := points * (i + 1) / ticks
			var pitch := 1.0 + TICK_RISE * float(done + upto) / float(all)
			tw.tween_interval(TICK)
			tw.tween_callback(_tick.bind(label, start + done + upto, value, upto, pitch))
		done += points
	tw.tween_callback(_bump.bind(m, label))
	tw.tween_interval(0.2)
	tw.tween_callback(then)


static func _tick(label: Label, total: int, value: Label, upto: int, pitch: float) -> void:
	label.text = str(total)
	if value != null:
		value.text = Menus.TEXT.plus % upto
	Audio.play("star", 0.2, pitch)


## The total swells and settles back, from its reading edge, as it lands.
static func _bump(m: Menus, label: Label) -> void:
	label.pivot_offset = Vector2(0.0 if m._rtl else label.size.x, label.size.y / 2.0)
	var tw := m.create_tween()
	m._tweens.append(tw)
	(
		tw
		. tween_property(label, "scale", Vector2.ONE, 0.3)
		. from(Vector2.ONE * 1.35)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
