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
const TITLE_BLOCK := Vector2(100, 63)
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
## Boxes that flow across the sheet (the language names): text size, the
## padding either side of it, the gap between boxes, and the row they fill.
const CHIP_SIZE := 15
const CHIP_PAD := 10.0
const CHIP_GAP := 8.0
const CHIP_ROW_W := SHEET.x - 2 * LIST_X
const ROW_H := 34.0
## The options sheet's rows: seven of them, a little tighter than TAP_HEIGHT.
const OPTIONS_TOP := 78.0
const OPTIONS_PITCH := 40.0
## Where MapMan stands, how big he is, and his height in his own units as
## Classic; the dimension line measures the look he wears with
## Player.standing_height().
const HERO_POS := Vector2(520, 230)
const HERO_SCALE := 1.2
const HERO_HEIGHT := 77.0
## How far down the sheet the pair at the end stand.
const PAIR_FEET := 232.0
## The resting tilt follows the phone at this rate (per second); a lean away
## from it turns his eyes this much, and they get there at this rate.
const REST_RATE := 0.4
const LOOK_GAIN := 4.0
const LOOK_RATE := 8.0
## Seconds for the frame to draw on, before a stamp may land on it, and for a
## stamp to fall (Blueprint.stamp) until it hits the sheet. A stamp over
## MapMan's head reaches this far below where it is placed, askew.
const DRAW_ON := 0.5
const STAMP_DELAY := 0.45
const STAMP_FALL := 0.16
const STAMP_DEPTH := 42.0
## A tap on the level clear before the count is in finishes it, rather than
## leaving the sheet.
const FINISH := "finish count"

## Every word on the sheets (plain English until translation comes).
const TEXT := {
	"header": "MAPMAN  —  SHEET %s  —  %s",
	"title_block": "REV %s\nSCALE 1:3\nSHEET %s",
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
	"level_count": ["%d LEVEL", "%d LEVELS"],
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
	# 001-C — language
	"language_number": "001-C",
	"language_title": "LANGUAGE",
	"phone_language": "PHONE'S LANGUAGE",
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
	"pause_note_touch": "NOTE: DRAG TO MOVE · TAP THE SHEET TO PAUSE",
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
	"marks_note": "NOTE: HIDDEN DEATH TILES ARE MARKED FROM NOW ON",
	"route_note": "NOTE: THE SAFE ROUTE IS SKETCHED AS EACH TRY STARTS",
	"skip_sheet": "SKIP THIS SHEET",
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
	"practice_page": "SHEET %d OF %d",
	"released": ["%d PART RELEASED", "%d PARTS RELEASED"],
	# nnn — level clear
	"inspection_title": "LEVEL %d — INSPECTION",
	"checkpoint_title": "LEVEL %d — CHECKPOINT",
	"level_bonus": "LEVEL BONUS",
	"time_bonus": "TIME BONUS",
	"stars_collected": "STARS COLLECTED",
	"seconds": "%d s",
	"tap_next": "TAP TO CONTINUE TO SHEET %03d",
	"tap_final": "TAP TO CONTINUE TO THE FINAL SHEET",
	"next_level": "NEXT LEVEL",
	"next": "NEXT",
	"menu": "MENU",
	"checkpoint_saved": "CHECKPOINT SAVED · RESTART FROM HERE ANY TIME",
	"passed": "PASSED",
	"return_to": "<  RETURN TO SHEET %03d",
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
	"a11y_lives": ["%d life remaining", "%d lives remaining"],
}
## The languages on the language sheet: locale code and the name in that
## language. The codes match the .po files in i18n/.
const LANGUAGES := [
	["en", "English"],
	["es", "Español"],
	["pt_BR", "Português (BR)"],
	["fr", "Français"],
	["it", "Italiano"],
	["de", "Deutsch"],
	["ga", "Gaeilge"],
	["ru", "Русский"],
	["tr", "Türkçe"],
	["id", "Bahasa Indonesia"],
	["ja", "日本語"],
	["ko", "한국어"],
	["zh_CN", "简体中文"],
	["zh_TW", "繁體中文"],
	["ar", "العربية"],
]

var current := ""
## What NO, KEEP PLAYING on the question before quitting reports: back to
## the game, or back to the level clear.
var confirm_back := "unpause"

var _panel: Control
var _bg: ColorRect
var _grid: Blueprint.Grid
var _frame: Line2D
var _header: Label
var _block: Control
var _hero: Player
## Who the hero stands with at the end: MapWoman, or MapMan when she is worn.
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
## Opens the sheet on screen again as it ends up (no motion): the level clear
## sets it, so a tap can finish its count and wearing a look can show on him.
var _redraw := Callable()
## The last level clear's arguments, to reopen it from the wardrobe.
var _clear_args := []
## A press landed on MapMan (he jumped): its release isn't a tap on the sheet.
var _poked := false
## The level the pause sheet was opened on, for the confirm sheet's number;
## 0 on the final sheet after level 100.
var _level := 0
var _tutorial := false
## The options row last toggled, so the redrawn sheet keeps the focus there.
var _refocus_row := -1
## Right-to-left language (Arabic): the sheet is laid out as a mirror image,
## with the parts list on the right and MapMan on the left.
var _rtl := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Every string here is translated once, with tr(); Godot must not try again.
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
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
	# A tap on MapMan (or whoever stands with him) makes him jump, and is
	# nothing else: its release doesn't continue the sheet.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _poke(get_global_transform() * event.position):
			_poked = true
			accept_event()
			return
		if not event.pressed and _poked:
			_poked = false
			accept_event()
			return
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


## Makes whoever stands at `at` (a global position) jump; false when nobody
## does.
func _poke(at: Vector2) -> bool:
	for p in [_hero, _woman]:
		if p == null or not p.visible:
			continue
		var local: Vector2 = p.get_global_transform().affine_inverse() * at
		if p.measure().grow(6.0).has_point(local):
			p.jump()
			Audio.play("star", 0.5, 1.5)
			return true
	return false


## Emits a copy: a signal passes a member variable by reference, and the
## game's handler closes this sheet (clearing _tap_action) before any other
## listener, such as a test, sees the value.
func _emit_tap() -> void:
	var act := _tap_action
	if act == FINISH:
		redraw()
		return
	action.emit(act)


## The sheet on screen again, all in, as a tap mid-count or a change to it
## leaves it; nothing for a sheet that doesn't redraw.
func redraw() -> void:
	if _redraw.is_valid():
		_redraw.call()


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
	_redraw = Callable()
	current = ""
	visible = false


# --- the sheet --------------------------------------------------------------


## A fresh sheet: the field, grid and frame over the whole screen, the header,
## the title block and an empty panel. `number` is the sheet number for the
## header and the title block.
func _open(tag: String, number: String, title: String, frame_color := Blueprint.INK) -> void:
	_animate = Blueprint.motion() and current != tag
	close()
	_rtl = Save.reads_rtl()
	current = tag
	visible = true
	_cascade = 0.0
	_clock = 0.0
	var vp := get_viewport_rect().size
	_bg = Blueprint.rect(self, Blueprint.FIELD, Vector2.ZERO, vp)
	_grid = Blueprint.grid(self, vp)
	_frame = Blueprint.line(self, Blueprint.frame_points(vp), frame_color, Blueprint.FRAME_WIDTH)
	# The sheet number keeps its order inside right-to-left text: "001-B".
	var figure := _isolated(number)
	var heading: String = _t("header") % [figure, title]
	_header = Blueprint.label(self, heading, 14, Blueprint.INK, Vector2.ZERO, 700)
	# "MAPMAN — SHEET 001 — TITLE" starts with Latin letters, so the text
	# itself must say which way the sheet reads.
	_header.text_direction = Control.TEXT_DIRECTION_RTL if _rtl else Control.TEXT_DIRECTION_AUTO
	_header.accessibility_name = _sentence(title)
	_block = _title_block(figure, frame_color)
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
## sheet number.
func _title_block(number: String, color: Color) -> Control:
	var block := Control.new()
	block.size = TITLE_BLOCK
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(block)
	Blueprint.line(block, Blueprint.box_points(Vector2.ZERO, TITLE_BLOCK), color, 1.2)
	# "1.2.0" of "1.2.0-pr.16": the build suffix is on the DEV overlay and
	# would run off the block here.
	var rev: String = Dev.build_info.version.get_slice("-", 0)
	if rev == "":
		rev = TEXT.rev_dev
	var text: String = _t("title_block") % [rev, number]
	Blueprint.label(block, text, 11, Blueprint.INK, Vector2(11, 8))
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
	_header.size = _header.get_minimum_size()
	var header_x := Blueprint.INSET + 16
	if _rtl:
		header_x = vp.x - Blueprint.INSET - 16 - _header.size.x
	_header.position = Vector2(header_x, Blueprint.INSET + 10)
	_block.position = vp - Vector2(Blueprint.INSET, Blueprint.INSET) - TITLE_BLOCK
	if _rtl:
		_block.position.x = Blueprint.INSET


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
	var ts := TextServerManager.get_primary_interface()
	return text.left(1) + ts.string_to_lower(text.substr(1), TranslationServer.get_locale())


## A figure such as "001-B" that must read left to right even inside
## right-to-left text, which would otherwise reorder it to "B-001".
func _isolated(text: String) -> String:
	return char(0x2066) + text + char(0x2069) if _rtl else text


## The x of a piece `w` wide whose left edge is at `x` on a left-to-right
## sheet: the same piece sits at the mirror image on a right-to-left one.
func _mx(x: float, w: float) -> float:
	return SHEET.x - x - w if _rtl else x


## Text in a box hugs the reading side.
func _align() -> HorizontalAlignment:
	return HORIZONTAL_ALIGNMENT_RIGHT if _rtl else HORIZONTAL_ALIGNMENT_LEFT


## A label `w` wide at the mirrored place of `x`, aligned to the reading side.
func _text(
	parent: Node, text: String, size: int, color: Color, x: float, y: float, w: float, weight := 500
) -> Label:
	var l := Blueprint.label(parent, text, size, color, Vector2(_mx(x, w), y), weight, w, _align())
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


## A TEXT entry in the current language: the English is the msgid (i18n/).
func _t(key: String) -> String:
	return tr(TEXT[key])


## A TEXT list in the current language.
func _tl(key: String) -> Array[String]:
	var out: Array[String] = []
	for text in TEXT[key]:
		out.append(tr(text))
	return out


## A TEXT [singular, plural] pair in the current language, filled with n.
func _tn(key: String, n: int) -> String:
	return tr_n(TEXT[key][0], TEXT[key][1], n) % n


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


## Faint column headings over a list, like ITEM and DESCRIPTION, each with
## the room up to the next one. The last can sit flush with the list's right
## edge, as the value column does.
func _columns(names: Array, xs: Array, right_last := false) -> void:
	var row := _row(LIST_TOP, 16)
	var end := LIST_X + LIST_W
	for i in names.size():
		if right_last and i == names.size() - 1:
			var l := _text(row, names[i], 11, Blueprint.FAINT, end - 120.0, 0, 120.0)
			l.horizontal_alignment = (
				HORIZONTAL_ALIGNMENT_LEFT if _rtl else HORIZONTAL_ALIGNMENT_RIGHT
			)
			continue
		var next := end
		if i + 1 < xs.size():
			next = xs[i + 1]
		elif right_last:
			next = end - 120.0
		_text(row, names[i], 11, Blueprint.FAINT, xs[i], 0, next - xs[i] - 8.0)
	_reveal(row)


## A note or status line in the sheet's small print.
func _note(text: String, y: float, color := Blueprint.FAINT, size := 10) -> Label:
	var pos := Vector2(_mx(LIST_X, LIST_W), y)
	var l := Blueprint.label(_panel, text, size, color, pos, 500, LIST_W, _align())
	_reveal(l)
	return l


func _rule(y: float) -> void:
	var x := _mx(LIST_X, LIST_W)
	_reveal(Blueprint.rule(_panel, y, x, x + LIST_W))


## Make a button report `act`; the first one on a sheet gets the focus.
func _connect(b: Button, act: String, enabled := true) -> void:
	if not enabled:
		return
	b.pressed.connect(func(): action.emit(act))
	if _first_button == null:
		_first_button = b


## A row of the parts list, numbered from 1, that reports `act`.
func _item(index: int, text: String, act: String, y: float, enabled := true) -> Button:
	var pos := Vector2(_mx(LIST_X, LIST_W), y)
	var size := Vector2(LIST_W, Blueprint.TAP_HEIGHT)
	var b := Blueprint.item(_panel, "%02d    %s" % [index, text], pos, size, enabled)
	b.alignment = _align()
	b.accessibility_name = _sentence(text)
	_connect(b, act, enabled)
	_reveal(b)
	return b


## A parts list from `y` at `pitch`; `enabled` (optional) says which are open.
func _items(texts: Array, acts: Array, y: float, pitch := 48.0, enabled: Array = []) -> void:
	for i in texts.size():
		var on: bool = enabled[i] if i < enabled.size() else true
		_item(i + 1, texts[i], acts[i], y + i * pitch, on)


## The way back to the main menu, as the last row of a sheet; from a level
## clear, the way back to it (sheet `level`).
func _return_item(y: float, height := Blueprint.TAP_HEIGHT, level := 0) -> void:
	var text: String = _t("return_to") % level if level > 0 else _t("return_item")
	var pos := Vector2(_mx(LIST_X, LIST_W), y)
	var b := Blueprint.item(_panel, text, pos, Vector2(LIST_W, height))
	b.alignment = _align()
	if level > 0:
		b.accessibility_name = _sentence(_t("inspection_title") % level)
		_connect(b, "back to clear")
	else:
		b.accessibility_name = _sentence(_t("main_menu"))
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
	cell.position = Vector2(_mx(pos.x, size.x), pos.y)
	cell.size = size
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(cell)
	var color := Blueprint.INK if open else Blueprint.FAINT
	if open:
		Blueprint.rect(cell, Blueprint.HOVER, Vector2.ONE, size - Vector2(2, 2))
	Blueprint.line(cell, Blueprint.box_points(Vector2.ZERO, size), color, 1.2 if open else 0.8)
	var inner := size.x - 16.0
	var t := Blueprint.label(
		cell, title, 15, color, Vector2(8, 4), 700 if open else 400, inner, _align()
	)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	var d := Blueprint.label(cell, detail, 10, color, Vector2(8, size.y - 18), 500, inner, _align())
	d.autowrap_mode = TextServer.AUTOWRAP_OFF
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
	b.text_direction = Blueprint.direction(text)
	b.add_theme_font_size_override("font_size", 12)
	b.alignment = align
	if _rtl:
		b.alignment = (
			HORIZONTAL_ALIGNMENT_RIGHT
			if align == HORIZONTAL_ALIGNMENT_LEFT
			else HORIZONTAL_ALIGNMENT_LEFT
		)
	b.accessibility_name = a11y
	_clear_button(b)
	_panel.add_child(b)
	b.position = Vector2(_mx(x, 102), 266)
	Blueprint.fit(b, Vector2(102, Blueprint.TAP_HEIGHT))
	_connect(b, act)
	_reveal(b)


## A line of an inspection table: name, quantity (optional) and value.
func _table_row(y: float, name: String, qty: String, value: String) -> Control:
	var row := _row(y)
	_text(row, name, 15, Blueprint.INK, LIST_X, 0, 180.0)
	if qty != "":
		_text(row, qty, 15, Blueprint.INK, 226.0, 0, 60.0)
	row.set_meta("value", _value(row, value, 15, 0))
	var x := _mx(LIST_X, LIST_W)
	Blueprint.rule(row, 26, x, x + LIST_W)
	return row


## A figure in the value column, flush with the list's far edge.
func _value(parent: Node, text: String, size: int, y: float, weight := 700) -> Label:
	var l := _text(parent, text, size, Blueprint.INK, LIST_X + LIST_W - 120.0, y, 120.0, weight)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if _rtl else HORIZONTAL_ALIGNMENT_RIGHT
	return l


## TOTAL under a table, with the double rule; returns the figure's label.
func _total(y: float, text: String) -> Label:
	var row := _row(y)
	_text(row, _t("total"), 15, Blueprint.INK, LIST_X, 0, 180.0, 700)
	var l := _value(row, text, 22, -6)
	var x := _mx(LIST_X, LIST_W)
	Blueprint.rule(row, 26, x, x + LIST_W)
	Blueprint.rule(row, 29, x, x + LIST_W)
	_reveal(row)
	return l


## FINAL SCORE in big figures, with the previous best under it when known.
func _score_block(score: int, previous_best: int) -> void:
	var row := _row(70, 100)
	_text(row, _t("final_score"), 15, Blueprint.INK, LIST_X, 0, 160.0)
	_text(row, str(score), 48, Blueprint.INK, LIST_X, 20, 160.0, 800)
	if previous_best > 0:
		var text: String = _t("previous_best") % previous_best
		_text(row, text, 12, Blueprint.FAINT, LIST_X, 80, 200.0)
	_reveal(row)


## A stamp slams onto the sheet after `delay` (or just sits there, with reduced
## motion or on a redrawn sheet); MapMan cheers as it lands, if it's good news.
func _stamp(text: String, pos: Vector2, color: Color, delay := STAMP_DELAY, cheer := true) -> void:
	var at := Vector2(_mx(pos.x, 120.0), pos.y)
	if not _animate:
		Blueprint.stamp(_panel, text, at, color)
		if cheer:
			_cheer()
		return
	Blueprint.stamp(_panel, text, at, color, true, delay)
	if not cheer:
		return
	var tw := create_tween()
	_tweens.append(tw)
	tw.tween_callback(_cheer).set_delay(delay + STAMP_FALL)


## The y of a stamp placed at `y` over MapMan's head, his feet at `feet`:
## higher when the look he wears stands taller than Classic, so it never
## covers his hat.
func _over_head(y: float, feet: float) -> float:
	var top := feet - (Player.standing_height(Save.worn) + Player.FEET_LIFT) * HERO_SCALE
	# On a whole pixel, so a position stored in floats never rounds down onto
	# the hat.
	return minf(y, floorf(top - STAMP_DEPTH))


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


## MapMan in the look he wears (docs/wardrobe), or in `look` when given;
## with art "woman", MapWoman.
func _figure(art: String, pos: Vector2, look := "") -> Player:
	var p := Player.new()
	p.art = art
	if look != "":
		p.outfit = look
	elif art == "man":
		p.outfit = Save.worn
	p.position = pos
	p.scale = Vector2.ONE * HERO_SCALE
	_panel.add_child(p)
	p.show_player()
	return p


## MapMan on an inked ellipse, with his height dimensioned beside him.
## mode: "tilt" (eyes follow the tilt), "down" (head hung) or "right".
func _hero_on(mode: String) -> void:
	var at := Vector2(_mx(HERO_POS.x, 0), HERO_POS.y)
	var ellipse := Blueprint.ellipse_points(at + Vector2(0, 2), 34, 12)
	Blueprint.line(_panel, ellipse, Blueprint.INK, 1.2)
	_dimension(at)
	_hero = _figure("man", at)
	_hero_mode = mode
	if mode == "right":
		_hero.face_right_idle()
	else:
		_hero.auto_look = false


## A dimension line from his feet to the top of his head, or of his hat.
func _dimension(at: Vector2) -> void:
	var x := at.x + (-50.0 if _rtl else 50.0)
	var height := Player.standing_height(Save.worn)
	var top := at.y - (height + Player.FEET_LIFT) * HERO_SCALE
	var feet := at.y - Player.FEET_LIFT * HERO_SCALE
	var c := Blueprint.FAINT
	Blueprint.line(_panel, PackedVector2Array([Vector2(x, top), Vector2(x, feet)]), c)
	for y: float in [top, feet]:
		Blueprint.line(_panel, PackedVector2Array([Vector2(x - 5, y), Vector2(x + 5, y)]), c)
	var mid := (top + feet) / 2.0 - 7.0
	var label_x := x - 28.0 if _rtl else x + 8.0
	var l := Blueprint.label(
		_panel, str(roundi(feet - top)), 10, c, Vector2(label_x, mid), 500, 20.0
	)
	l.horizontal_alignment = _align()
	l.autowrap_mode = TextServer.AUTOWRAP_OFF


## MapMan and MapWoman together, facing each other, as at the end. Wearing
## MapWoman, she is the hero and MapMan, as he is, stands with her.
func _pair_on() -> void:
	var ellipse := Blueprint.ellipse_points(Vector2(_mx(500, 0), 236), 60, 14)
	Blueprint.line(_panel, ellipse, Blueprint.INK, 1.2)
	_hero = _figure("man", Vector2(_mx(478, 0), PAIR_FEET))
	var partner := "man" if Save.worn == "mapwoman" else "woman"
	_woman = _figure(partner, Vector2(_mx(524, 0), PAIR_FEET), "classic")
	# They face each other, whichever side each stands on.
	if _rtl:
		_hero.flip = -1.0
		_hero.face_left_idle()
		_woman.face_right_idle()
	else:
		_hero.face_right_idle()
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
	_open("main", TEXT.main_number, _t("main_title"))
	_columns([_t("col_item"), _t("col_description")], [TEXT_X, TEXT_X + 6 * CHAR_W])
	var acts := ["play from start", "restart from checkpoint", "practice", "tutorial", "options"]
	_items(_tl("main_items"), acts, 80, 44, [true, has_checkpoint, true, true, true])
	var parts: Array[String] = []
	if highscore > 0:
		parts.append(_t("best_score") % highscore)
	if levels > 0:
		parts.append(_tn("level_count", levels))
	if not parts.is_empty():
		_note(_t("note") % " · ".join(parts), 308)
	_hero_on("tilt")
	WardrobeSheet.main_menu_row(self)
	_focus_first()


func show_first_play() -> void:
	_open("first_play", TEXT.first_number, _t("first_title"))
	_note(_t("first_intro"), LIST_TOP, Blueprint.FAINT, 11)
	_items(_tl("first_items"), ["take tutorial", "play game", "main menu"], 84)
	_hero_on("tilt")
	_focus_first()


func show_options() -> void:
	_open("options", TEXT.options_number, _t("options_title"))
	_columns([_t("col_parameter"), _t("col_value")], [TEXT_X, TEXT_X + 20 * CHAR_W])
	var states := [Save.music_on, Save.fx_on, Save.vibration_on, Save.reduce_motion]
	var acts := ["music", "fx", "vibration", "reduce motion"]
	var refocus := _refocus_row if not _animate else -1
	_refocus_row = -1
	var names := _tl("options")
	for i in acts.size():
		var on: bool = states[i]
		var b := _value_row(names[i], TEXT.on if on else TEXT.off, OPTIONS_TOP + i * OPTIONS_PITCH)
		var state: String = _t("a11y_on") if on else _t("a11y_off")
		b.accessibility_name = TEXT.a11y_toggle % [_sentence(names[i]), state]
		_connect(b, "%s %s" % [acts[i], "off" if on else "on"])
		b.pressed.connect(_remember_row.bind(i))
		if i == refocus:
			_first_button = b
	var y := OPTIONS_TOP + acts.size() * OPTIONS_PITCH
	var steer := _value_row(tr(ControlsSheet.TEXT.title), ControlsSheet.mode_name(), y)
	_connect(steer, "controls")
	var lang := _value_row(_t("language_title"), _language_name(Save.locale), y + OPTIONS_PITCH)
	_connect(lang, "language")
	_return_item(y + 2 * OPTIONS_PITCH, OPTIONS_PITCH)
	_hero_on("tilt")
	_focus_first()


## 001-E, from the options: how MapMan is steered (ControlsSheet).
func show_controls() -> void:
	ControlsSheet.build(self)


## An options row: the parameter on the left, its value in the VALUE column.
func _value_row(name: String, value: String, y: float) -> Button:
	var size := Vector2(LIST_W, OPTIONS_PITCH)
	var b := Blueprint.item(_panel, name, Vector2(_mx(LIST_X, LIST_W), y), size)
	b.alignment = _align()
	# The value column runs from 20 characters in to the row's far margin, at
	# the mirror image on a right-to-left sheet.
	var col := TEXT_X - LIST_X + 20 * CHAR_W
	var w := LIST_W - col - 12.0
	var pos := Vector2(12.0 if _rtl else col, 0)
	var l := Blueprint.label(b, value, 16, Blueprint.INK, pos, 500, w)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if _rtl else HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Blueprint.fit(l, Vector2(w, OPTIONS_PITCH))
	_reveal(b)
	return b


## The name of a locale in its own language; "" is the phone's language.
func _language_name(code: String) -> String:
	for entry in LANGUAGES:
		if entry[0] == code:
			return entry[1]
	return _t("phone_language")


## 001-D: the wardrobe, every look to wear (WardrobeSheet). A released one
## reports "wear <id>". Opened from the level clear of level `back_level`,
## its last row goes back there.
func show_wardrobe(back_level := 0) -> void:
	WardrobeSheet.build(self, back_level)


## The language sheet: the phone's language, then every language in its own
## name, as boxes that flow across the sheet, the current one marked. Picking
## one reports "language <code>".
func show_language() -> void:
	_open("language", TEXT.language_number, _t("language_title"))
	var choices: Array = [["system", _t("phone_language")]]
	choices.append_array(LANGUAGES)
	var x := LIST_X
	var y := 72.0
	for choice in choices:
		var code: String = choice[0]
		var name: String = choice[1]
		var chosen := (Save.locale == "" and code == "system") or Save.locale == code
		var text: String = TEXT.on + " " + name if chosen else name
		var font := Blueprint.mono(700 if chosen else 400)
		var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE).x
		var w := ceilf(text_w) + 2.0 * CHIP_PAD
		if x + w > LIST_X + CHIP_ROW_W:
			x = LIST_X
			y += Blueprint.TAP_HEIGHT + CHIP_GAP
		_chip(Vector2(x, y), w, text, "language " + code, name, chosen)
		x += w + CHIP_GAP
	var back_pos := Vector2(_mx(LIST_X, LIST_W), 318)
	var back := Blueprint.item(_panel, "<  " + _t("options_title"), back_pos)
	back.alignment = _align()
	back.accessibility_name = _sentence(_t("options_title"))
	_connect(back, "options")
	_reveal(back)
	_focus_first()


## A box in a flowing row of choices, `w` wide, its text centred; the chosen
## one is filled and bold. The whole box is a button.
func _chip(pos: Vector2, w: float, text: String, act: String, a11y: String, chosen: bool) -> Button:
	var size := Vector2(w, Blueprint.TAP_HEIGHT)
	var box := Control.new()
	box.position = Vector2(_mx(pos.x, w), pos.y)
	box.size = size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	if chosen:
		Blueprint.rect(box, Blueprint.HOVER, Vector2.ONE, size - Vector2(2, 2))
	var width := 1.2 if chosen else 0.8
	Blueprint.line(box, Blueprint.box_points(Vector2.ZERO, size), Blueprint.INK, width)
	var inner := w - 2.0 * CHIP_PAD
	var l := Blueprint.label(
		box, text, CHIP_SIZE, Blueprint.INK, Vector2(CHIP_PAD, 0), 700 if chosen else 400, inner
	)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Blueprint.fit(l, Vector2(inner, size.y))
	var b := Button.new()
	b.theme = Blueprint.theme()
	b.size = size
	b.accessibility_name = a11y
	_clear_button(b)
	box.add_child(b)
	_connect(b, act)
	_reveal(box, 0.03)
	return b


func _remember_row(row: int) -> void:
	_refocus_row = row


func show_pause(tutorial: bool, level := 0, seconds := -1) -> void:
	_level = level
	_tutorial = tutorial
	_open("pause", _level_number("A"), _t("paused_title"))
	var status: String = _t("suspended_tutorial")
	if not tutorial and level <= 0:
		status = _t("suspended_final")
	elif not tutorial:
		status = _t("suspended") % level
		if seconds >= 0:
			@warning_ignore("integer_division")
			status += _t("remaining") % [seconds / 60, seconds % 60]
	_note(status, LIST_TOP, Blueprint.FAINT, 11)
	_item(1, _t("resume"), "unpause", 90)
	if tutorial:
		_item(2, _t("end_tutorial"), "end tutorial", 138)
	else:
		_item(2, _t("end_game"), "confirm quit", 138)
	_note(_t("pause_note_touch" if Save.controls == "touch" else "pause_note"), 200)
	_hero_on("tilt")
	var hold := Vector2(_mx(230, 120.0), 240)
	_reveal(Blueprint.stamp(_panel, _t("on_hold"), hold, Blueprint.GOLD))
	_focus_first()


## back: what NO, KEEP PLAYING reports ("unpause", or "back to clear").
func show_confirm_quit(back := "unpause") -> void:
	confirm_back = back
	_open("confirm_quit", _level_number("A"), _t("confirm_title"), Blueprint.PINK)
	_note(_t("confirm_question"), LIST_TOP, Blueprint.PINK, 11)
	_item(1, _t("keep_playing"), back, 100)
	_item(2, _t("end_the_game"), "end game", 148)
	_hero_on("tilt")
	_focus_first()


## reason: "death" (a death tile) or "timeout" (the clock ran out).
## help: the assist the next try gets ("", "marks", "route" or "skip",
## main.gd assist_name()); the note says so, and "skip" adds a row for it.
func show_lose_life(lives: int, level := 0, reason := "death", help := "") -> void:
	_level = level
	_open("lose_life", "%03d" % level, _t("defect_title") % level, Blueprint.PINK)
	var timeout := reason == "timeout"
	_note(_t("defect_timeout") if timeout else _t("defect_death"), LIST_TOP, Blueprint.PINK, 11)
	var row := _row(96, 24)
	var l := _text(row, _t("lives_remaining"), 15, Blueprint.INK, LIST_X, 0, 190.0)
	l.accessibility_name = _tn("a11y_lives", lives)
	var discs := clampi(lives, 3, MAX_LIFE_DISCS)
	for i in discs:
		var pts := Blueprint.ellipse_points(Vector2(_mx(250 + i * 36, 0), 8), 11, 10, 20)
		if i < lives:
			var disc := Polygon2D.new()
			disc.polygon = pts
			disc.color = Blueprint.PINK
			disc.antialiased = true
			row.add_child(disc)
		Blueprint.line(row, pts, Blueprint.PINK, 1.5)
	if lives > MAX_LIFE_DISCS:
		var extra: String = TEXT.more_lives % (lives - MAX_LIFE_DISCS)
		var pos := Vector2(_mx(250 + discs * 36 - 8, 40.0), 0)
		var more := Blueprint.label(row, extra, 15, Blueprint.PINK, pos, 700, 40.0)
		more.horizontal_alignment = _align()
	_reveal(row)
	_rule(128)
	_item(1, _t("try_again"), "try again", 150)
	var note: String = _t("timeout_note") if timeout else _t("death_note")
	match help:
		"marks":
			note = _t("marks_note")
		"route", "skip":
			note = _t("route_note")
	if help == "skip":
		_item(2, _t("skip_sheet"), "skip sheet", 194)
		_note(note, 252)
		_stamp(_t("rework"), Vector2(222, 290), Blueprint.PINK, STAMP_DELAY, false)
	else:
		_note(note, 212)
		_stamp(_t("rework"), Vector2(222, 240), Blueprint.PINK, STAMP_DELAY, false)
	_hero_on("down")
	_focus_first()


func show_game_over(score: int, pb: bool, has_checkpoint: bool, previous_best := 0) -> void:
	_open("game_over", TEXT.end_number, _t("game_over_title"), Blueprint.PINK)
	_score_block(score, previous_best)
	_rule(182)
	var acts := ["play from start", "restart from checkpoint", "main menu"]
	_items(_tl("game_over_items"), acts, 192, 44, [true, has_checkpoint, true])
	_hero_on("down")
	if pb:
		_stamp(_t("new_best"), Vector2(220, 100), Blueprint.GOLD)
	_focus_first()


## The checkpoint picker: `reached` holds the levels whose checkpoint is saved.
func show_restart(reached: Array) -> void:
	_open("restart", TEXT.cp_number, _t("checkpoints_title"))
	_columns([_t("checkpoints_header")], [LIST_X])
	for r in CHECKPOINT_ROWS.size():
		for c in CHECKPOINT_ROWS[r].size():
			var level: int = CHECKPOINT_ROWS[r][c]
			var open := level in reached
			var pos := Vector2(LIST_X + c * 100, 80 + r * 50)
			var detail: String = _t("saved") if open else _t("locked")
			var a11y: String = (
				(_t("a11y_checkpoint") if open else _t("a11y_checkpoint_locked")) % level
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
	var title: String = _t("practice_title") % [first, last]
	_open("practice", TEXT.practice_number % (page + 1), title)
	var on_page := last - first + 1
	var heads := _row(56, 12)
	for c in mini(5, on_page):
		_text(heads, _t("practice_columns"), 9, Blueprint.FAINT, LIST_X + c * 118, 0, 108.0)
	_reveal(heads)
	for i in on_page:
		var level := first + i
		var open := level <= furthest
		@warning_ignore("integer_division")
		var pos := Vector2(LIST_X + (i % 5) * 118, 72 + (i / 5) * 50)
		var a11y: String = (_t("a11y_level") if open else _t("a11y_level_locked")) % level
		var act := "practice level %d" % level
		_cell(
			pos,
			Vector2(108, Blueprint.TAP_HEIGHT),
			open,
			_t("part") % level,
			_best_text(bests, level, open),
			act,
			a11y
		)
	var pages := ceili(float(count) / PRACTICE_PAGE)
	# On a right-to-left sheet the earlier page is on the right, pointed at.
	if page > 0:
		var text: String = (TEXT.next_page if _rtl else TEXT.previous_page) % page
		_arrow(
			text,
			"practice page %d" % (page - 1),
			28,
			HORIZONTAL_ALIGNMENT_LEFT,
			_t("a11y_previous")
		)
	if page < pages - 1:
		var text: String = (TEXT.previous_page if _rtl else TEXT.next_page) % (page + 2)
		_arrow(
			text, "practice page %d" % (page + 1), 330, HORIZONTAL_ALIGNMENT_RIGHT, _t("a11y_next")
		)
	var caption: String = _t("practice_page") % [page + 1, pages]
	caption += " · " + _tn("released", mini(furthest, count))
	if note != "":
		caption = note
	var pos := Vector2(_mx(130, 200.0), 281)
	var l := Blueprint.label(
		_panel, caption, 10, Blueprint.FAINT, pos, 500, 200.0, HORIZONTAL_ALIGNMENT_CENTER
	)
	_reveal(l)
	_return_item(312)
	_focus_first()


## A level's best in the practice grid: "9s ★1", "12s", "—", or LOCKED.
func _best_text(bests: Dictionary, level: int, open: bool) -> String:
	if not open:
		return _t("locked")
	var best: Dictionary = bests.get(level, {})
	if best.is_empty():
		return TEXT.no_best
	if best.stars > 0:
		return _t("best_with_stars") % [best.time, best.stars]
	return _t("best") % best.time


## Level clear (ClearSheet): the bonuses count into the score, then NEXT,
## WARDROBE and MAIN MENU. released: the look this first clear released, if
## any.
func show_end_level(
	score: int,
	level_bonus: int,
	time_bonus: int,
	stars: int,
	checkpoint: bool,
	level := 0,
	seconds_left := -1,
	last := false,
	released := ""
) -> void:
	var args := [score, level_bonus, time_bonus, stars, checkpoint, level, seconds_left]
	_clear_args = args + [last, released]
	ClearSheet.end_level(self, _clear_args)
	_redraw = show_end_level.bindv(_clear_args)


## The level clear again, all in (no count), on the way back from the
## wardrobe or the question before quitting it.
func reopen_end_level() -> void:
	current = "end_level"  # as a redraw: it opens settled
	show_end_level.callv(_clear_args)


## released: "mapwoman" when finishing the game this time released her.
func show_congratulations(score: int, pb: bool, released := "") -> void:
	_open("congratulations", TEXT.end_sheet, _t("congratulations_title"), Blueprint.GOLD)
	_score_block(score, 0)
	_rule(182)
	_item(1, _t("main_menu"), "main menu", 192)
	_note(_t("congratulations_note"), 300)
	_pair_on()
	if released == "mapwoman":
		WardrobeSheet.mapwoman_slip(self)
	if pb:
		_stamp(_t("new_best"), Vector2(220, 100), Blueprint.GOLD)
	_focus_first()


## The final inspection: the completion and lives bonuses join the score.
func show_game_complete(score: int, completion_bonus: int, lives_bonus: int) -> void:
	_open("completion", TEXT.end_sheet, _t("completion_title"), Blueprint.GOLD)
	_columns([_t("col_item"), _t("col_value")], [LIST_X], true)
	var specs := [
		[_t("score_at_100"), str(score), 0],
		[_t("completion_bonus"), TEXT.plus % completion_bonus, completion_bonus],
		[_t("lives_bonus"), TEXT.plus % lives_bonus, lives_bonus],
	]
	var rows := []
	var y := 84.0
	for s in specs:
		var row := _table_row(y, s[0], "", s[1])
		rows.append({"node": row, "points": s[2], "value": row.get_meta("value")})
		y += ROW_H
	var total := _total(y + 4, str(score))
	_note(_t("completion_caption"), 260, Blueprint.GOLD, 11)
	_pair_on()
	var approved := Vector2(458, _over_head(84, PAIR_FEET))
	ClearSheet.count_up(
		self, total, score, rows, func(): _stamp(_t("approved"), approved, Blueprint.GOLD, 0.0)
	)
	_tap_to("completion done")
