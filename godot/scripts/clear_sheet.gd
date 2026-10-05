class_name ClearSheet
extends RefCounted
## The level clear of the main game: the bonuses count into the score, then
## NEXT, WARDROBE and MAIN MENU come up under the total. Static functions that
## build onto the Menus sheet they are given, with its own helpers, as
## WardrobeSheet does; their words are in Menus.TEXT. The count-up serves
## the final inspection too.

## Where its table starts and its pitch (tighter than Menus.ROW_H, to make
## room for the buttons), the buttons' row, their widths in reading order
## with the gap between them, and the small print when no slip takes its place.
const ROWS_Y := 80.0
const PITCH := 30.0
const BUTTONS_Y := 232.0
const BUTTON_WS := [112.0, 126.0, 126.0]
const GAP := 8.0
const BUTTON_FONT := 14
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

## The DOUBLE IT slip's words (msgids, i18n/catalog.json).
## DOUBLE IT, on the slip WEAR IT uses: a little wider for its longer word.
const DOUBLE_W := 124.0
const TEXT := {
	"ad_bonus": "AD BONUS",
	"double_points": "DOUBLE THE POINTS",
	"watch_ad": "WATCH A SHORT AD",
	"double_it": "DOUBLE IT",
	"points_doubled": "POINTS DOUBLED",
}


## Level clear: the bonuses are added into the score one row at a time, then
## NEXT, WARDROBE and MAIN MENU come up under the total. A tap before then
## finishes the count; after it, a tap goes on to the next level. `args` are
## Menus.show_end_level's: score, level_bonus, time_bonus, stars, checkpoint,
## level, seconds_left (the clock at the exit, the time bonus's quantity),
## last (level 100: the final sheet comes next), released (the look this
## first clear released, if any, for a slip with a button to wear it) and
## more: "tries" (how many tries the replay shows: WATCH REPLAY when there
## are any) and "double" (the DOUBLE IT slip, ad_slip()).
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
	var more: Dictionary = args[9] if args.size() > 9 else {}
	var tries: int = more.get("tries", 0)
	var double: int = more.get("double", 0)
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
	var texts := [m._t("next"), m.tr(WardrobeSheet.TEXT.title), m._t("menu")]
	var a11y := [m._t("next_level"), texts[1], m._t("main_menu")]
	var acts := ["next level", "clear wardrobe", "leave clear"]
	var buttons: Array[Button] = []
	var x := Menus.LIST_X
	for i in acts.size():
		buttons.append(_side_button(m, x, BUTTON_WS[i], texts[i], a11y[i], acts[i]))
		x += BUTTON_WS[i] + GAP
	if tries > 0:
		buttons.append(_replay_button(m, tries))
	if released != "":
		WardrobeSheet.release_slip(m, released)
	elif double != 0:
		var offer := ad_slip(m, double)
		if offer:
			buttons.append(offer)
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
		m._first_button = buttons[0]
		m._focus_first()
	count_up(m, total, score, rows, all_in)


## The DOUBLE IT slip where a release slip would go: a rewarded ad doubles
## the sheet's points (double -1: on offer, returning its button), or says it
## did (the points it added). Words in TEXT.
static func ad_slip(m: Menus, double: int) -> Button:
	var slip := WardrobeSheet._slip(m, WardrobeSheet.SLIP_Y, WardrobeSheet.SLIP_H)
	var times := Blueprint.label(slip, "×2", 26, Blueprint.GOLD, Vector2.ZERO, 800, 64.0)
	times.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	times.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Blueprint.fit(times, Vector2(64, slip.size.y))
	times.position.x = WardrobeSheet._flip(m, 4, 64, slip.size.x)
	var room := DOUBLE_W + 8.0
	var done := double > 0
	var lines := (
		[m.tr(TEXT.points_doubled), Menus.TEXT.plus % double]
		if done
		else [m.tr(TEXT.double_points), m.tr(TEXT.watch_ad)]
	)
	WardrobeSheet._slip_text(m, slip, m.tr(TEXT.ad_bonus), 10, Blueprint.GOLD, 78, 6, 800, room)
	WardrobeSheet._slip_text(m, slip, lines[0], 15, Blueprint.INK, 78, 20, 800, room)
	WardrobeSheet._slip_text(m, slip, lines[1], 10, Blueprint.FAINT, 78, 42, 500, room)
	var w := DOUBLE_W
	var at := Vector2(WardrobeSheet._flip(m, slip.size.x - 8.0 - w, w, slip.size.x), 9)
	var b: Button = null
	if not done:
		b = Blueprint.item(slip, m.tr(TEXT.double_it), at, Vector2(w, Blueprint.TAP_HEIGHT))
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.accessibility_name = "%s, %s" % [m._sentence(m.tr(TEXT.double_it)), m.tr(TEXT.watch_ad)]
		m._connect(b, "double it")
	m._reveal(slip)
	return b


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
