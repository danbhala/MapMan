class_name Menus
extends Control
## Every menu is a drawing sheet on blue paper. The frame, the grid, the header
## and the title block hug the screen; the sheet's parts list, notes, stamps and
## MapMan himself sit on a 667×375 panel centred in it (`_panel`). Every button
## reports its action string (the strings the original used) through the
## `action` signal; main.gd handles them in _on_menu_action().

signal action(name: String)

## Practice grid: levels per page, as 5 columns of 4 rows.
const PRACTICE_PAGE := 20
## The panel every sheet is laid out on; wider screens get margins.
const SHEET := Vector2(667, 375)
const TITLE_BLOCK := Vector2(200, 63)
## The checkpoint picker's cells, top row first.
const CHECKPOINT_ROWS := [[80, 85, 90, 95], [50, 60, 70, 75], [10, 20, 30, 40]]
## The lose-life sheet draws this many life discs at most, then "+N".
const MAX_LIFE_DISCS := 6
## The parts list: its left edge and width, where text starts inside a row,
## the width of one character of the 16 px row font (0.6 em), and the column
## headings' y.
const LIST_X := 40.0
const LIST_W := 380.0
const TEXT_X := 52.0
const CHAR_W := 9.6
const LIST_TOP := 60.0
const ROW_H := 34.0
## Where MapMan stands, how big he is, and his height in his own units.
const HERO_POS := Vector2(520, 230)
const HERO_SCALE := 1.2
const HERO_HEIGHT := 77.0
## The resting tilt follows the phone at this rate (per second); a lean away
## from it turns his eyes this much, and they get there at this rate.
const REST_RATE := 0.4
const LOOK_GAIN := 4.0
const LOOK_RATE := 8.0
## Seconds for the frame to draw on, before a stamp may land on it, and for a
## stamp to fall (Blueprint.stamp) until it hits the sheet.
const DRAW_ON := 0.5
const STAMP_DELAY := 0.45
const STAMP_FALL := 0.16
## The total counts up a point per tick, five at a time past BIG_ROW points.
const TICK := 0.1
const BIG_ROW := 50

## Every word on the sheets (plain English until translation comes).
const TEXT := {
	"header": "MAPMAN  —  SHEET %s  —  %s",
	"title_block": "REV %s\nSCALE 1:3\nSHEET %s",
	"drawn_by": "DRAWN BY\ndanbhala\n2026",
	"rev_dev": "DEV",
	"col_item": "ITEM",
	"col_description": "DESCRIPTION",
	"col_parameter": "PARAMETER",
	"col_value": "VALUE",
	"col_qty": "QTY",
	"return_item": "<  RETURN TO SHEET 001",
	"main_menu": "MAIN MENU",
	"total": "TOTAL",
	"plus": "+%d",
	"note": "NOTE: %s",
	# 001 — main menu
	"main_number": "001",
	"main_title": "MAIN MENU",
	"main_items":
	["PLAY FROM START", "CONTINUE FROM CHECKPOINT", "PRACTICE A LEVEL", "TUTORIAL", "OPTIONS"],
	"best_score": "BEST SCORE %d",
	"level_count": "%d LEVELS",
	# 000 — first run
	"first_number": "000",
	"first_title": "FIRST RUN",
	"first_intro": "NEW TO MAPMAN? THE TUTORIAL TAKES A MINUTE",
	"first_items": ["TAKE THE TUTORIAL", "SKIP TO THE GAME", "MAIN MENU"],
	# 001-B — options
	"options_number": "001-B",
	"options_title": "OPTIONS",
	"options": ["MUSIC", "SOUND EFFECTS", "VIBRATION", "REDUCE MOTION"],
	"on": "[X]",
	"off": "[ ]",
	# nnn-A — paused, and the question before quitting
	"paused_title": "PAUSED",
	"suspended": "WORK SUSPENDED AT LEVEL %d",
	"remaining": " · T-%d:%02d REMAINING",
	"suspended_tutorial": "WORK SUSPENDED · TUTORIAL",
	"suspended_final": "WORK SUSPENDED · FINAL SHEET",
	"final_number": "END",
	"resume": "RESUME",
	"end_game": "END GAME",
	"end_tutorial": "END TUTORIAL",
	"pause_note": "NOTE: TILT TO MOVE · TAP THE SHEET TO PAUSE",
	"on_hold": "ON HOLD",
	"confirm_title": "CONFIRM",
	"confirm_question": "END THIS GAME?\nPROGRESS SINCE THE LAST CHECKPOINT IS LOST",
	"keep_playing": "NO, KEEP PLAYING",
	"end_the_game": "YES, END THE GAME",
	# nnn — a life lost
	"defect_title": "LEVEL %d — DEFECT",
	"defect_death": "DEFECT: STEPPED ON A DEATH TILE",
	"defect_timeout": "DEFECT: OUT OF TIME",
	"lives_remaining": "LIVES REMAINING",
	"more_lives": "+%d",
	"try_again": "TRY AGAIN FROM THE START TILE",
	"death_note": "NOTE: ROUTE AROUND THE DEATH TILES",
	"timeout_note": "NOTE: T-0:20 PER SHEET · TAKE THE SHORT WAY",
	"rework": "REWORK",
	# END — game over
	"end_number": "END",
	"game_over_title": "GAME OVER",
	"final_score": "FINAL SCORE",
	"previous_best": "PREVIOUS BEST  %d",
	"game_over_items": ["PLAY FROM START", "RESTART FROM A CHECKPOINT", "MAIN MENU"],
	"new_best": "NEW BEST",
	# CP — the checkpoint picker
	"cp_number": "CP",
	"checkpoints_title": "CHECKPOINTS",
	"checkpoints_header": "RESTART FROM A SAVED CHECKPOINT",
	"saved": "SAVED",
	"locked": "LOCKED",
	# P-nn — practice
	"practice_number": "P-%02d",
	"practice_title": "PRACTICE — LEVELS %d–%d",
	"practice_columns": "PART   BEST",
	"part": "L%02d",
	"best_with_stars": "%ds ★%d",
	"best": "%ds",
	"no_best": "—",
	"previous_page": "<  P-%02d",
	"next_page": "P-%02d  >",
	"practice_caption": "SHEET %d OF %d · %d PARTS RELEASED",
	# nnn — level clear
	"inspection_title": "LEVEL %d — INSPECTION",
	"checkpoint_title": "LEVEL %d — CHECKPOINT",
	"level_bonus": "LEVEL BONUS",
	"time_bonus": "TIME BONUS",
	"stars_collected": "STARS COLLECTED",
	"seconds": "%d s",
	"tap_next": "TAP TO CONTINUE TO SHEET %03d",
	"tap_final": "TAP TO CONTINUE TO THE FINAL SHEET",
	"checkpoint_saved": "CHECKPOINT SAVED · RESTART FROM HERE ANY TIME",
	"passed": "PASSED",
	# 100 — the end
	"end_sheet": "100",
	"congratulations_title": "CONGRATULATIONS",
	"congratulations_note": "ALL 100 SHEETS APPROVED · EVERY LEVEL IS OPEN IN PRACTICE",
	"completion_title": "FINAL INSPECTION",
	"score_at_100": "SCORE AT LEVEL 100",
	"completion_bonus": "COMPLETION BONUS",
	"lives_bonus": "LIVES REMAINING ×50",
	"completion_caption": "ALL 100 SHEETS APPROVED · THANK YOU FOR PLAYING",
	"approved": "APPROVED",
	# for screen readers
	"a11y_previous": "Previous page",
	"a11y_next": "Next page",
	"a11y_level": "Level %d",
	"a11y_level_locked": "Level %d, locked",
	"a11y_checkpoint": "Restart after level %d",
	"a11y_checkpoint_locked": "Checkpoint at level %d, not reached",
	"a11y_toggle": "%s, %s",
	"a11y_on": "on",
	"a11y_off": "off",
	"a11y_lives": "%d lives remaining",
}

var current := ""

var _panel: Control
var _bg: ColorRect
var _grid: Blueprint.Grid
var _frame: Line2D
var _header: Label
var _block: Control
var _hero: Player
var _woman: Player
## "tilt" (eyes follow the tilt, or the mouse), "down" (head hung), "right",
## or "pair" (the two of them, facing each other).
var _hero_mode := ""
var _first_button: Control
var _tap_action := ""
var _tap_ready_at := 0.0
## Tweens of our own (count-ups, cheers) to stop when the sheet closes.
var _tweens: Array[Tween] = []
## Whether the sheet now opening plays its opening motion: not with reduced
## motion, and not when the same sheet is redrawn (an options toggle).
var _animate := true
## Seconds into the opening cascade so far: each row revealed adds its pitch.
var _cascade := 0.0
## Seconds since the sheet opened, for the idle glance.
var _clock := 0.0
## The phone's resting gravity, a slow average, so a lean reads the same
## however the phone is held.
var _rest := Vector3.ZERO
## A desktop: his eyes follow the mouse once it has moved.
var _mouse_seen := false
## The level the pause sheet was opened on, for the confirm sheet's number;
## 0 on the final sheet after level 100.
var _level := 0
var _tutorial := false
## The options row last toggled, so the redrawn sheet keeps the focus there.
var _refocus_row := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_layout)


func _process(delta: float) -> void:
	if _hero == null:
		return
	_clock += delta
	match _hero_mode:
		"tilt":
			_hero.look = _hero.look.lerp(_look_target(delta), minf(1.0, delta * LOOK_RATE))
		"down":
			_hero.look = Vector2(0.0, 0.6)
	_hero.tick(delta)
	if _woman:
		_woman.tick(delta)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_seen = true
	# The focus ring is for keys and gamepads; a finger or a mouse hides it.
	if event is InputEventKey or event is InputEventJoypadButton:
		Blueprint.show_focus(true)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		Blueprint.show_focus(true)
	elif event is InputEventMouseButton or event is InputEventScreenTouch:
		Blueprint.show_focus(false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _tap_action == "":
		return
	if Time.get_ticks_msec() / 1000.0 < _tap_ready_at:
		return
	var tapped := event.is_action_pressed("ui_accept") or event.is_action_pressed("shake")
	if tapped:
		get_viewport().set_input_as_handled()
		_emit_tap()


func _gui_input(event: InputEvent) -> void:
	# Taps on the sheet (not on a button) for "tap to continue" menus.
	if _tap_action == "" or Time.get_ticks_msec() / 1000.0 < _tap_ready_at:
		return
	if (
		event is InputEventMouseButton
		and not event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		accept_event()
		_emit_tap()


## Emits a copy: a signal passes a member variable by reference, and the
## game's handler closes this sheet (clearing _tap_action) before any other
## listener, such as a test, sees the value.
func _emit_tap() -> void:
	var act := _tap_action
	action.emit(act)


func close() -> void:
	for tw in _tweens:
		if tw.is_valid():
			tw.kill()
	_tweens.clear()
	for c in get_children():
		c.queue_free()
	_panel = null
	_hero = null
	_woman = null
	_hero_mode = ""
	_first_button = null
	_tap_action = ""
	current = ""
	visible = false


# --- the sheet --------------------------------------------------------------


## A fresh sheet: the field, grid and frame over the whole screen, the header,
## the title block and an empty panel. `number` is the sheet number for the
## header and the title block.
func _open(tag: String, number: String, title: String, frame_color := Blueprint.INK) -> void:
	_animate = Blueprint.motion() and current != tag
	close()
	current = tag
	visible = true
	_cascade = 0.0
	_clock = 0.0
	var vp := get_viewport_rect().size
	_bg = Blueprint.rect(self, Blueprint.FIELD, Vector2.ZERO, vp)
	_grid = Blueprint.grid(self, vp)
	_frame = Blueprint.line(self, Blueprint.frame_points(vp), frame_color, Blueprint.FRAME_WIDTH)
	var heading: String = TEXT.header % [number, title]
	_header = Blueprint.label(self, heading, 14, Blueprint.INK, Vector2.ZERO, 700)
	_header.accessibility_name = _sentence(title)
	_block = _title_block(number, frame_color)
	_panel = Control.new()
	_panel.size = SHEET
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_layout()
	if _animate:
		Blueprint.draw_on(_frame, DRAW_ON)
		Blueprint.reveal(_header, 0.1)
		Blueprint.reveal(_block, 0.3)


## The title block in the frame's bottom-right corner: revision, scale and
## sheet number on the left, who drew it on the right.
func _title_block(number: String, color: Color) -> Control:
	var block := Control.new()
	block.size = TITLE_BLOCK
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(block)
	Blueprint.line(block, Blueprint.box_points(Vector2.ZERO, TITLE_BLOCK), color, 1.2)
	var mid := TITLE_BLOCK.x / 2.0
	Blueprint.line(block, PackedVector2Array([Vector2(mid, 0), Vector2(mid, TITLE_BLOCK.y)]), color)
	var rev: String = Dev.build_info.version
	if rev == "":
		rev = TEXT.rev_dev
	var left: String = TEXT.title_block % [rev, number]
	Blueprint.label(block, left, 11, Blueprint.INK, Vector2(11, 8))
	Blueprint.label(block, TEXT.drawn_by, 11, Blueprint.INK, Vector2(mid + 11, 8))
	return block


## Centre the panel and fit the frame to the screen (also on a resize).
func _layout() -> void:
	if _panel == null:
		return
	var vp := get_viewport_rect().size
	_panel.position = ((vp - SHEET) / 2.0).floor()
	_bg.size = vp
	_grid.size = vp
	_grid.queue_redraw()
	_frame.points = Blueprint.frame_points(vp)
	_header.position = Vector2(Blueprint.INSET + 16, Blueprint.INSET + 10)
	_block.position = vp - Vector2(Blueprint.INSET, Blueprint.INSET) - TITLE_BLOCK


## The sheet number of the level being played, with a sub-sheet letter.
func _level_number(suffix: String) -> String:
	var number: String = "%03d" % _level
	if _tutorial:
		number = "T"
	elif _level <= 0:
		number = TEXT.final_number
	return number + "-" + suffix


## "PLAY FROM START" -> "Play from start", for screen readers.
func _sentence(text: String) -> String:
	return text.left(1) + text.substr(1).to_lower()


# --- the parts ----------------------------------------------------------------


## A strip across the panel at `y`, so a row's pieces can fade in as one.
func _row(y: float, height := ROW_H) -> Control:
	var row := Control.new()
	row.position = Vector2(0, y)
	row.size = Vector2(SHEET.x, height)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	return row


## Fade a row in, each a little after the one before, when the sheet opens.
func _reveal(node: CanvasItem, pitch := 0.07) -> void:
	if _animate:
		Blueprint.reveal(node, 0.1 + _cascade)
	_cascade += pitch


## Faint column headings over a list, like ITEM and DESCRIPTION. The last one
## can sit flush with the list's right edge.
func _columns(names: Array, xs: Array, right_last := false) -> void:
	var row := _row(LIST_TOP, 16)
	for i in names.size():
		if right_last and i == names.size() - 1:
			var right := LIST_X + LIST_W - 120.0
			var pos := Vector2(right, 0)
			Blueprint.label(
				row, names[i], 11, Blueprint.FAINT, pos, 500, 120.0, HORIZONTAL_ALIGNMENT_RIGHT
			)
		else:
			Blueprint.label(row, names[i], 11, Blueprint.FAINT, Vector2(xs[i], 0))
	_reveal(row)


## A note or status line in the sheet's small print.
func _note(text: String, y: float, color := Blueprint.FAINT, size := 10) -> Label:
	var l := Blueprint.label(_panel, text, size, color, Vector2(LIST_X, y), 500, LIST_W)
	_reveal(l)
	return l


func _rule(y: float) -> void:
	_reveal(Blueprint.rule(_panel, y, LIST_X, LIST_X + LIST_W))


## Make a button report `act`; the first one on a sheet gets the focus.
func _connect(b: Button, act: String, enabled := true) -> void:
	if not enabled:
		return
	b.pressed.connect(func(): action.emit(act))
	if _first_button == null:
		_first_button = b


## A row of the parts list, numbered from 1, that reports `act`.
func _item(index: int, text: String, act: String, y: float, enabled := true) -> Button:
	var pos := Vector2(LIST_X, y)
	var b := Blueprint.item(_panel, "%02d    %s" % [index, text], pos, Vector2(LIST_W, 40), enabled)
	b.accessibility_name = _sentence(text)
	_connect(b, act, enabled)
	_reveal(b)
	return b


## A parts list from `y` at `pitch`; `enabled` (optional) says which are open.
func _items(texts: Array, acts: Array, y: float, pitch := 48.0, enabled: Array = []) -> void:
	for i in texts.size():
		var on: bool = enabled[i] if i < enabled.size() else true
		_item(i + 1, texts[i], acts[i], y + i * pitch, on)


## The way back to the main menu, as the last row of a sheet.
func _return_item(y: float) -> void:
	var b := Blueprint.item(_panel, TEXT.return_item, Vector2(LIST_X, y))
	b.accessibility_name = _sentence(TEXT.main_menu)
	_connect(b, "main menu")
	_reveal(b)


## A button that draws nothing of its own, over a cell drawn by hand.
func _clear_button(b: Button) -> void:
	var clear := StyleBoxFlat.new()
	clear.draw_center = false
	b.add_theme_stylebox_override("normal", clear)
	b.add_theme_stylebox_override("disabled", clear)


## A boxed cell of a grid (the checkpoint and practice pickers): a title and a
## detail line, filled faintly when open. The whole cell is a button.
func _cell(
	pos: Vector2,
	size: Vector2,
	open: bool,
	title: String,
	detail: String,
	act: String,
	a11y: String
) -> Button:
	var cell := Control.new()
	cell.position = pos
	cell.size = size
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(cell)
	var color := Blueprint.INK if open else Blueprint.FAINT
	if open:
		Blueprint.rect(cell, Blueprint.HOVER, Vector2.ONE, size - Vector2(2, 2))
	Blueprint.line(cell, Blueprint.box_points(Vector2.ZERO, size), color, 1.2 if open else 0.8)
	Blueprint.label(cell, title, 15, color, Vector2(8, 4), 700 if open else 400)
	Blueprint.label(cell, detail, 10, color, Vector2(8, size.y - 18))
	var b := Button.new()
	b.theme = Blueprint.theme()
	b.size = size
	b.disabled = not open
	if not open:
		b.focus_mode = Control.FOCUS_NONE
	b.accessibility_name = a11y
	_clear_button(b)
	cell.add_child(b)
	_connect(b, act, open)
	_reveal(cell, 0.03)
	return b


## A page arrow on the practice sheet.
func _arrow(text: String, act: String, x: float, align: HorizontalAlignment, a11y: String) -> void:
	var b := Button.new()
	b.theme = Blueprint.theme()
	b.text = text
	b.add_theme_font_size_override("font_size", 12)
	b.alignment = align
	b.position = Vector2(x, 266)
	b.size = Vector2(102, Blueprint.TAP_HEIGHT)
	b.accessibility_name = a11y
	_clear_button(b)
	_panel.add_child(b)
	_connect(b, act)
	_reveal(b)


## A line of an inspection table: name, quantity (optional) and value.
func _table_row(y: float, name: String, qty: String, value: String) -> Control:
	var row := _row(y)
	Blueprint.label(row, name, 15, Blueprint.INK, Vector2(LIST_X, 0))
	if qty != "":
		Blueprint.label(row, qty, 15, Blueprint.INK, Vector2(226, 0))
	var right := LIST_X + LIST_W - 120.0
	var pos := Vector2(right, 0)
	Blueprint.label(row, value, 15, Blueprint.INK, pos, 700, 120.0, HORIZONTAL_ALIGNMENT_RIGHT)
	Blueprint.rule(row, 26, LIST_X, LIST_X + LIST_W)
	return row


## TOTAL under a table, with the double rule; returns the figure's label.
func _total(y: float, text: String) -> Label:
	var row := _row(y)
	Blueprint.label(row, TEXT.total, 15, Blueprint.INK, Vector2(LIST_X, 0), 700)
	var pos := Vector2(LIST_X + LIST_W - 120.0, -6)
	var l := Blueprint.label(
		row, text, 22, Blueprint.INK, pos, 700, 120.0, HORIZONTAL_ALIGNMENT_RIGHT
	)
	Blueprint.rule(row, 26, LIST_X, LIST_X + LIST_W)
	Blueprint.rule(row, 29, LIST_X, LIST_X + LIST_W)
	_reveal(row)
	return l


## FINAL SCORE in big figures, with the previous best under it when known.
func _score_block(score: int, previous_best: int) -> void:
	var row := _row(70, 100)
	Blueprint.label(row, TEXT.final_score, 15, Blueprint.INK, Vector2(LIST_X, 0))
	Blueprint.label(row, str(score), 48, Blueprint.INK, Vector2(LIST_X, 20), 800)
	if previous_best > 0:
		var text: String = TEXT.previous_best % previous_best
		Blueprint.label(row, text, 12, Blueprint.FAINT, Vector2(LIST_X, 80))
	_reveal(row)


## The TOTAL counts up from `start` as each row is revealed in turn, a tick
## at a time; `rows` are [{"node": CanvasItem, "points": int}]. `then` runs
## once it's all in (at once with reduced motion).
func _count_up(label: Label, start: int, rows: Array, then: Callable) -> void:
	var sum := [start]
	if not _animate:
		for r in rows:
			sum[0] += r.points
		label.text = str(sum[0])
		then.call()
		return
	var tw := create_tween()
	_tweens.append(tw)
	tw.tween_interval(DRAW_ON)
	for r in rows:
		var node: CanvasItem = r.node
		node.modulate.a = 0.0
		tw.tween_callback(func(): Blueprint.reveal(node))
		tw.tween_interval(0.25)
		var step: int = 5 if r.points > BIG_ROW else 1
		var left: int = r.points
		while left > 0:
			var take := mini(step, left)
			left -= take
			tw.tween_interval(TICK)
			tw.tween_callback(_tick.bind(label, sum, take))
	tw.tween_callback(then)


func _tick(label: Label, sum: Array, take: int) -> void:
	sum[0] += take
	label.text = str(sum[0])
	Audio.play("star", 0.2)


## A stamp slams onto the sheet after `delay` (or just sits there, with reduced
## motion or on a redrawn sheet); MapMan cheers as it lands, if it's good news.
func _stamp(text: String, pos: Vector2, color: Color, delay := STAMP_DELAY, cheer := true) -> void:
	if not _animate:
		Blueprint.stamp(_panel, text, pos, color)
		if cheer:
			_cheer()
		return
	Blueprint.stamp(_panel, text, pos, color, true, delay)
	if not cheer:
		return
	var tw := create_tween()
	_tweens.append(tw)
	tw.tween_callback(_cheer).set_delay(delay + STAMP_FALL)


## Wide eyes and a hop (just the eyes with reduced motion: nothing landed).
func _cheer() -> void:
	for p in [_hero, _woman]:
		if p == null:
			continue
		if Blueprint.motion():
			p.cheer()
		else:
			p.happy = 1.0


# --- the hero ---------------------------------------------------------------------


func _figure(art: String, pos: Vector2) -> Player:
	var p := Player.new()
	p.art = art
	p.position = pos
	p.scale = Vector2.ONE * HERO_SCALE
	_panel.add_child(p)
	p.show_player()
	return p


## MapMan on an inked ellipse, with his height dimensioned beside him.
## mode: "tilt" (eyes follow the tilt), "down" (head hung) or "right".
func _hero_on(mode: String) -> void:
	var ellipse := Blueprint.ellipse_points(HERO_POS + Vector2(0, 2), 34, 12)
	Blueprint.line(_panel, ellipse, Blueprint.INK, 1.2)
	_dimension()
	_hero = _figure("man", HERO_POS)
	_hero_mode = mode
	if mode == "right":
		_hero.face_right_idle()
	else:
		_hero.auto_look = false


## A dimension line from his feet to the top of his head.
func _dimension() -> void:
	var x := HERO_POS.x + 50.0
	var top := HERO_POS.y - (HERO_HEIGHT + Player.FEET_LIFT) * HERO_SCALE
	var feet := HERO_POS.y - Player.FEET_LIFT * HERO_SCALE
	var c := Blueprint.FAINT
	Blueprint.line(_panel, PackedVector2Array([Vector2(x, top), Vector2(x, feet)]), c)
	for y: float in [top, feet]:
		Blueprint.line(_panel, PackedVector2Array([Vector2(x - 5, y), Vector2(x + 5, y)]), c)
	var mid := (top + feet) / 2.0 - 7.0
	Blueprint.label(_panel, str(roundi(feet - top)), 10, c, Vector2(x + 8, mid))


## MapMan and MapWoman together, facing each other, as at the end.
func _pair_on() -> void:
	var ellipse := Blueprint.ellipse_points(Vector2(500, 236), 60, 14)
	Blueprint.line(_panel, ellipse, Blueprint.INK, 1.2)
	_hero = _figure("man", Vector2(478, 232))
	_hero.face_right_idle()
	_woman = _figure("woman", Vector2(524, 232))
	_woman.flip = -1.0
	_woman.face_left_idle()
	_hero_mode = "pair"


## Where MapMan looks: the way the phone is tilted (relative to how it is
## held), the mouse on a desktop, or a slow glance about when neither has
## been seen (so screenshots stay the same from run to run).
func _look_target(delta: float) -> Vector2:
	if TiltInput.has_accelerometer():
		var g := Input.get_gravity().normalized()
		if _rest == Vector3.ZERO:
			_rest = g
		else:
			_rest = _rest.lerp(g, minf(1.0, delta * REST_RATE)).normalized()
		return _clamp_look(TiltInput.steer_from_gravity(g, _rest) * LOOK_GAIN)
	if _mouse_seen:
		var head := _hero.global_position - Vector2(0, 62.0 * HERO_SCALE)
		return _clamp_look((get_global_mouse_position() - head) / 150.0)
	return Vector2(sin(_clock * 0.8) * 0.5, sin(_clock * 0.5) * 0.2)


## Looking up further than this would turn his back (Player draws no face).
func _clamp_look(v: Vector2) -> Vector2:
	return Vector2(clampf(v.x, -1.0, 1.0), clampf(v.y, -0.5, 1.0))


# --- tap to continue, focus ---------------------------------------------------------


func _focus_first() -> void:
	if _first_button:
		_first_button.call_deferred("grab_focus")


func _tap_to(act: String, delay := 0.3) -> void:
	_tap_action = act
	_tap_ready_at = Time.get_ticks_msec() / 1000.0 + delay


# --- the menus -----------------------------------------------------------


func show_main(highscore: int, has_checkpoint: bool, levels := 0) -> void:
	_open("main", TEXT.main_number, TEXT.main_title)
	_columns([TEXT.col_item, TEXT.col_description], [TEXT_X, TEXT_X + 6 * CHAR_W])
	var acts := ["play from start", "restart from checkpoint", "practice", "tutorial", "options"]
	_items(TEXT.main_items, acts, 80, 44, [true, has_checkpoint, true, true, true])
	var parts: Array[String] = []
	if highscore > 0:
		parts.append(TEXT.best_score % highscore)
	if levels > 0:
		parts.append(TEXT.level_count % levels)
	if not parts.is_empty():
		_note(TEXT.note % " · ".join(parts), 308)
	_hero_on("tilt")
	_focus_first()


func show_first_play() -> void:
	_open("first_play", TEXT.first_number, TEXT.first_title)
	_note(TEXT.first_intro, LIST_TOP, Blueprint.FAINT, 11)
	_items(TEXT.first_items, ["take tutorial", "play game", "main menu"], 84)
	_hero_on("tilt")
	_focus_first()


func show_options() -> void:
	_open("options", TEXT.options_number, TEXT.options_title)
	_columns([TEXT.col_parameter, TEXT.col_value], [TEXT_X, TEXT_X + 20 * CHAR_W])
	var states := [Save.music_on, Save.fx_on, Save.vibration_on, Save.reduce_motion]
	var acts := ["music", "fx", "vibration", "reduce motion"]
	var refocus := _refocus_row if not _animate else -1
	_refocus_row = -1
	for i in acts.size():
		var on: bool = states[i]
		var text := "%-20s%s" % [TEXT.options[i], TEXT.on if on else TEXT.off]
		var b := Blueprint.item(_panel, text, Vector2(LIST_X, 80 + i * 44))
		var state: String = TEXT.a11y_on if on else TEXT.a11y_off
		b.accessibility_name = TEXT.a11y_toggle % [_sentence(TEXT.options[i]), state]
		_connect(b, "%s %s" % [acts[i], "off" if on else "on"])
		b.pressed.connect(_remember_row.bind(i))
		_reveal(b)
		if i == refocus:
			_first_button = b
	_return_item(80 + acts.size() * 44)
	_hero_on("tilt")
	_focus_first()


func _remember_row(row: int) -> void:
	_refocus_row = row


func show_pause(tutorial: bool, level := 0, seconds := -1) -> void:
	_level = level
	_tutorial = tutorial
	_open("pause", _level_number("A"), TEXT.paused_title)
	var status: String = TEXT.suspended_tutorial
	if not tutorial and level <= 0:
		status = TEXT.suspended_final
	elif not tutorial:
		status = TEXT.suspended % level
		if seconds >= 0:
			@warning_ignore("integer_division")
			status += TEXT.remaining % [seconds / 60, seconds % 60]
	_note(status, LIST_TOP, Blueprint.FAINT, 11)
	_item(1, TEXT.resume, "unpause", 90)
	if tutorial:
		_item(2, TEXT.end_tutorial, "end tutorial", 138)
	else:
		_item(2, TEXT.end_game, "confirm quit", 138)
	_note(TEXT.pause_note, 200)
	_hero_on("tilt")
	_reveal(Blueprint.stamp(_panel, TEXT.on_hold, Vector2(230, 240), Blueprint.GOLD))
	_focus_first()


func show_confirm_quit() -> void:
	_open("confirm_quit", _level_number("A"), TEXT.confirm_title, Blueprint.PINK)
	_note(TEXT.confirm_question, LIST_TOP, Blueprint.PINK, 11)
	_item(1, TEXT.keep_playing, "unpause", 100)
	_item(2, TEXT.end_the_game, "end game", 148)
	_hero_on("tilt")
	_focus_first()


## reason: "death" (a death tile) or "timeout" (the clock ran out).
func show_lose_life(lives: int, level := 0, reason := "death") -> void:
	_level = level
	_open("lose_life", "%03d" % level, TEXT.defect_title % level, Blueprint.PINK)
	var timeout := reason == "timeout"
	_note(TEXT.defect_timeout if timeout else TEXT.defect_death, LIST_TOP, Blueprint.PINK, 11)
	var row := _row(96, 24)
	var l := Blueprint.label(row, TEXT.lives_remaining, 15, Blueprint.INK, Vector2(LIST_X, 0))
	l.accessibility_name = TEXT.a11y_lives % lives
	var discs := clampi(lives, 3, MAX_LIFE_DISCS)
	for i in discs:
		var pts := Blueprint.ellipse_points(Vector2(250 + i * 36, 8), 11, 10, 20)
		if i < lives:
			var disc := Polygon2D.new()
			disc.polygon = pts
			disc.color = Blueprint.PINK
			disc.antialiased = true
			row.add_child(disc)
		Blueprint.line(row, pts, Blueprint.PINK, 1.5)
	if lives > MAX_LIFE_DISCS:
		var extra: String = TEXT.more_lives % (lives - MAX_LIFE_DISCS)
		var pos := Vector2(250 + discs * 36 - 8, 0)
		Blueprint.label(row, extra, 15, Blueprint.PINK, pos, 700)
	_reveal(row)
	_rule(128)
	_item(1, TEXT.try_again, "try again", 150)
	_note(TEXT.timeout_note if timeout else TEXT.death_note, 212)
	_hero_on("down")
	_stamp(TEXT.rework, Vector2(222, 240), Blueprint.PINK, STAMP_DELAY, false)
	_focus_first()


func show_game_over(score: int, pb: bool, has_checkpoint: bool, previous_best := 0) -> void:
	_open("game_over", TEXT.end_number, TEXT.game_over_title, Blueprint.PINK)
	_score_block(score, previous_best)
	_rule(182)
	var acts := ["play from start", "restart from checkpoint", "main menu"]
	_items(TEXT.game_over_items, acts, 192, 44, [true, has_checkpoint, true])
	_hero_on("down")
	if pb:
		_stamp(TEXT.new_best, Vector2(220, 100), Blueprint.GOLD)
	_focus_first()


## The checkpoint picker: `reached` holds the levels whose checkpoint is saved.
func show_restart(reached: Array) -> void:
	_open("restart", TEXT.cp_number, TEXT.checkpoints_title)
	_columns([TEXT.checkpoints_header], [LIST_X])
	for r in CHECKPOINT_ROWS.size():
		for c in CHECKPOINT_ROWS[r].size():
			var level: int = CHECKPOINT_ROWS[r][c]
			var open := level in reached
			var pos := Vector2(LIST_X + c * 100, 80 + r * 50)
			var detail: String = TEXT.saved if open else TEXT.locked
			var a11y: String = (
				(TEXT.a11y_checkpoint if open else TEXT.a11y_checkpoint_locked) % level
			)
			var size := Vector2(90, Blueprint.TAP_HEIGHT)
			_cell(pos, size, open, str(level), detail, "L%d" % level, a11y)
	_return_item(240)
	_hero_on("tilt")
	_focus_first()


## Practice: pick any level reached in the main game and play just that one.
## furthest: levels 1..furthest are open. bests: Save.bests.
## note: shown in place of the caption, e.g. how the last practice run went.
func show_practice(page: int, furthest: int, bests: Dictionary, count: int, note := "") -> void:
	var first := page * PRACTICE_PAGE + 1
	var last := mini(first + PRACTICE_PAGE - 1, count)
	var title: String = TEXT.practice_title % [first, last]
	_open("practice", TEXT.practice_number % (page + 1), title)
	var on_page := last - first + 1
	var heads := _row(56, 12)
	for c in mini(5, on_page):
		var pos := Vector2(LIST_X + c * 118, 0)
		Blueprint.label(heads, TEXT.practice_columns, 9, Blueprint.FAINT, pos)
	_reveal(heads)
	for i in on_page:
		var level := first + i
		var open := level <= furthest
		@warning_ignore("integer_division")
		var pos := Vector2(LIST_X + (i % 5) * 118, 72 + (i / 5) * 50)
		var a11y: String = (TEXT.a11y_level if open else TEXT.a11y_level_locked) % level
		var act := "practice level %d" % level
		_cell(
			pos,
			Vector2(108, Blueprint.TAP_HEIGHT),
			open,
			TEXT.part % level,
			_best_text(bests, level, open),
			act,
			a11y
		)
	var pages := ceili(float(count) / PRACTICE_PAGE)
	if page > 0:
		var text: String = TEXT.previous_page % page
		_arrow(
			text, "practice page %d" % (page - 1), 28, HORIZONTAL_ALIGNMENT_LEFT, TEXT.a11y_previous
		)
	if page < pages - 1:
		var text: String = TEXT.next_page % (page + 2)
		_arrow(
			text, "practice page %d" % (page + 1), 330, HORIZONTAL_ALIGNMENT_RIGHT, TEXT.a11y_next
		)
	var caption: String = TEXT.practice_caption % [page + 1, pages, mini(furthest, count)]
	if note != "":
		caption = note.to_upper()
	var pos := Vector2(130, 281)
	var l := Blueprint.label(
		_panel, caption, 10, Blueprint.FAINT, pos, 500, 200.0, HORIZONTAL_ALIGNMENT_CENTER
	)
	_reveal(l)
	_return_item(312)
	_focus_first()


## A level's best in the practice grid: "9s ★1", "12s", "—", or LOCKED.
func _best_text(bests: Dictionary, level: int, open: bool) -> String:
	if not open:
		return TEXT.locked
	var best: Dictionary = bests.get(level, {})
	if best.is_empty():
		return TEXT.no_best
	if best.stars > 0:
		return TEXT.best_with_stars % [best.time, best.stars]
	return TEXT.best % best.time


## Level clear: the bonuses are added into the score one row at a time.
## seconds_left: the clock at the exit, shown as the time bonus's quantity.
## last: this was level 100, so the final sheet comes next.
func show_end_level(
	score: int,
	level_bonus: int,
	time_bonus: int,
	stars: int,
	checkpoint: bool,
	level := 0,
	seconds_left := -1,
	last := false
) -> void:
	var title: String = (TEXT.checkpoint_title if checkpoint else TEXT.inspection_title) % level
	_open("end_level", "%03d" % level, title, Blueprint.GOLD if checkpoint else Blueprint.INK)
	_columns([TEXT.col_item, TEXT.col_qty, TEXT.col_value], [LIST_X, 226], true)
	var clock := seconds_left if seconds_left >= 0 else time_bonus * 2
	var specs := [
		[TEXT.level_bonus, "1", level_bonus],
		[TEXT.time_bonus, TEXT.seconds % clock, time_bonus],
	]
	if stars > 0:
		specs.append([TEXT.stars_collected, str(stars), stars])
	var rows := []
	var y := 84.0
	for s in specs:
		rows.append({"node": _table_row(y, s[0], s[1], TEXT.plus % s[2]), "points": s[2]})
		y += ROW_H
	var total := _total(y + 4, str(score))
	if checkpoint:
		_note(TEXT.checkpoint_saved, 244, Blueprint.GOLD, 11)
	_note(TEXT.tap_final if last else TEXT.tap_next % (level + 1), 264, Blueprint.FAINT, 11)
	_hero_on("right")
	_count_up(
		total, score, rows, func(): _stamp(TEXT.passed, Vector2(470, 90), Blueprint.GOLD, 0.0)
	)
	_tap_to("next level")


func show_congratulations(score: int, pb: bool) -> void:
	_open("congratulations", TEXT.end_sheet, TEXT.congratulations_title, Blueprint.GOLD)
	_score_block(score, 0)
	_rule(182)
	_item(1, TEXT.main_menu, "main menu", 192)
	_note(TEXT.congratulations_note, 300)
	_pair_on()
	if pb:
		_stamp(TEXT.new_best, Vector2(220, 100), Blueprint.GOLD)
	_focus_first()


## The final inspection: the completion and lives bonuses join the score.
func show_game_complete(score: int, completion_bonus: int, lives_bonus: int) -> void:
	_open("completion", TEXT.end_sheet, TEXT.completion_title, Blueprint.GOLD)
	_columns([TEXT.col_item, TEXT.col_value], [LIST_X], true)
	var specs := [
		[TEXT.score_at_100, str(score), 0],
		[TEXT.completion_bonus, TEXT.plus % completion_bonus, completion_bonus],
		[TEXT.lives_bonus, TEXT.plus % lives_bonus, lives_bonus],
	]
	var rows := []
	var y := 84.0
	for s in specs:
		rows.append({"node": _table_row(y, s[0], "", s[1]), "points": s[2]})
		y += ROW_H
	var total := _total(y + 4, str(score))
	_note(TEXT.completion_caption, 260, Blueprint.GOLD, 11)
	_pair_on()
	_count_up(
		total, score, rows, func(): _stamp(TEXT.approved, Vector2(458, 84), Blueprint.GOLD, 0.0)
	)
	_tap_to("completion done")
