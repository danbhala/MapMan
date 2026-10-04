class_name ClearSheet
extends RefCounted
## The sheets between two levels of the main game: the level clear, where the
## bonuses count into the score and NEXT LEVEL and MAIN MENU come up, and the
## ready sheet, where the next level waits until the player starts it (with
## the wardrobe a tap away). Static functions that build onto the Menus sheet
## they are given, with its own helpers, as WardrobeSheet does; their words
## are in Menus.TEXT.

## The level clear: where its table starts and its pitch (tighter than
## Menus.ROW_H, to make room for its two buttons side by side), the buttons'
## row and width, and the small print when no slip takes its place.
const ROWS_Y := 80.0
const PITCH := 30.0
const BUTTONS_Y := 232.0
const BUTTON_W := 186.0
const NOTE_Y := 296.0
## WATCH REPLAY, under MapMan on the far side.
const REPLAY_POS := Vector2(448, 248)
const REPLAY_W := 196.0


## Level clear: the bonuses are added into the score one row at a time, then
## NEXT LEVEL and MAIN MENU come up under the total. A tap before then
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
	var buttons: Array[Button] = [
		_side_button(m, 0, m._t("next_level"), "next level"),
		_side_button(m, 1, m._t("main_menu"), "leave clear"),
	]
	if tries > 0:
		buttons.append(_replay_button(m, tries))
	if released != "":
		WardrobeSheet.release_slip(m, released)
	else:
		m._note(m._t("tap_final") if last else m._t("tap_next") % (level + 1), NOTE_Y)
	m._hero_on("right")
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
	m._count_up(total, score, rows, all_in)


## One of the level clear's two buttons, side by side under the TOTAL: `i` 0
## on the reading side.
static func _side_button(m: Menus, i: int, text: String, act: String) -> Button:
	var x := Menus.LIST_X + i * (Menus.LIST_W - BUTTON_W)
	var pos := Vector2(m._mx(x, BUTTON_W), BUTTONS_Y)
	var b := Blueprint.item(m._panel, text, pos, Vector2(BUTTON_W, Blueprint.TAP_HEIGHT))
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.accessibility_name = m._sentence(text)
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


## Before a level of the main game, a moment to get ready (and to change
## look): the clock the level gives, the best time on it, and MapMan in the
## look he wears. Tapping the sheet, or a shake, starts the level.
static func ready_sheet(m: Menus, level: int, seconds: int, best: Dictionary) -> void:
	m._level = level
	m._tutorial = false
	m._open("ready", "%03d" % level, m._t("ready_title") % level)
	@warning_ignore("integer_division")
	var parts: Array[String] = [m._t("on_the_clock") % [seconds / 60, seconds % 60]]
	if not best.is_empty():
		parts.append(m._t("your_best") % m._best_text({level: best}, level, true))
	m._note(" · ".join(parts), Menus.LIST_TOP, Blueprint.FAINT, 11)
	m._item(1, m._t("start_level") % level, "start level", 90)
	m._item(2, m.tr(WardrobeSheet.TEXT.title), "wardrobe", 138)
	m._item(3, m._t("main_menu"), "leave ready", 186)
	m._note(m._t("tap_start"), 250)
	m._hero_on("tilt")
	m._tap_to("start level")
	m._focus_first()
