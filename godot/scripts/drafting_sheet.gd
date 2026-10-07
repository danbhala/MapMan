class_name DraftingSheet
extends RefCounted
## The drafting table (docs/drafting-table.md): sheet 001-E with the player's
## drafts and the levels friends sent, the editor a draft is drawn on, the
## share sheet with its code and QR, and the sheet a code is typed or pasted
## into. Static functions that build onto the Menus sheet they are given, with
## its helpers, as WardrobeSheet does. Buttons report action strings that
## main.gd handles; painting on the grid happens here, and each stroke is
## saved as it ends. Loads only with the game scene, so it may name Save.

## Every word the drafting table adds to the sheets: English msgids (i18n/).
const TEXT := {
	"title": "DRAFTING TABLE",
	"number": "001-E",
	"your_drafts": "YOUR DRAFTS",
	"received": "RECEIVED LEVELS",
	"none_received": "LEVELS FRIENDS SEND YOU APPEAR HERE",
	"draft_cell": "D%d",
	"received_cell": "R%d",
	"empty": "EMPTY",
	"draft": "DRAFT",
	"signed": "SIGNED",
	"enter_code": "ENTER A LEVEL CODE",
	"how": "DRAW A LEVEL · BEAT IT · SHARE ITS CODE",
	"cleared": "LEVEL CLEARED WITH %ds LEFT",
	# 001-F: a code to play
	"code_number": "001-F",
	"code_title": "LEVEL CODE",
	"type_or_paste": "TYPE OR PASTE A LEVEL CODE",
	"paste": "PASTE",
	"play_code": "PLAY THIS LEVEL",
	"bad_code": "THAT CODE DOESN'T READ. CHECK IT AND TRY AGAIN",
	"newer_code": "THIS LEVEL NEEDS A NEWER VERSION OF MAPMAN",
	"on_clipboard": "A LEVEL CODE IS ON THE CLIPBOARD",
	# 001-G: scanning a friend's QR code
	"scan_number": "001-G",
	"scan": "SCAN A QR CODE",
	"point_camera": "POINT THE CAMERA AT THE QR CODE ON A FRIEND'S SHARE SHEET",
	"looking": "LOOKING FOR A QR CODE…",
	"no_camera": "NO CAMERA FOUND",
	"no_permission": "MAPMAN ISN'T ALLOWED TO USE THE CAMERA. ALLOW IT IN THE PHONE'S SETTINGS",
	"not_a_level": "THAT QR CODE ISN'T A MAPMAN LEVEL",
	"type_instead": "TYPE A CODE INSTEAD",
	"play_it": "PLAY IT",
	"not_now": "NOT NOW",
	# Dn: the editor
	"draft_title": "DRAFT %d",
	"back": "BACK",
	"undo": "UNDO",
	"clear": "CLEAR",
	"test": "TEST",
	"share": "SHARE",
	"code_meter": "CODE",
	"meter": "%d/%d",
	"need_start": "PLACE ONE START TILE",
	"need_exit": "PLACE AT LEAST ONE EXIT",
	"test_to_sign": "TEST IT AND REACH AN EXIT TO SIGN IT",
	"ready": "SIGNED · READY TO SHARE",
	"tool_status": "%s  ·  %s",
	"vanish": ["VANISH · %d MOVE", "VANISH · %d MOVES"],
	# Dn-S: sharing
	"share_number": "D%d-S",
	"scan_or_send": "SCAN THE QR WITH A PHONE CAMERA, OR SEND THE CODE",
	"copy_code": "COPY CODE",
	"copied": "CODE COPIED",
	"back_to_draft": "BACK TO THE DRAFT",
	# the pause sheet over a draft or a received level
	"suspended_draft": "WORK SUSPENDED · DRAFT %d",
	"suspended_received": "WORK SUSPENDED · RECEIVED LEVEL",
	# for screen readers
	"a11y_draft_empty": "Draft %d, empty",
	"a11y_draft": "Draft %d",
	"a11y_draft_signed": "Draft %d, signed",
	"a11y_received": "Received level %d",
	"a11y_code": "Level code",
	"a11y_qr": "QR code of the level",
	"a11y_camera": "Camera view",
}
## The palette: each tile the editor can place, with its name (a msgid; ""
## for the vanish tiles, named by TEXT.vanish with their moves). HIDE_TOOL
## marks tiles that start hidden instead of placing one.
const TOOLS := [
	[" ", "ERASER"],
	["c", "PATH"],
	["b", "START TILE"],
	["n", "EXIT"],
	["e", "EXIT"],
	["s", "EXIT"],
	["w", "EXIT"],
	["d", "DEATH TILE"],
	["p", "STAR"],
	["l", "EXTRA LIFE"],
	["m", "EXTRA TIME"],
	["t", "TIME LOST"],
	["y", "STICKY TILE"],
	["r", "REVERSE TILE"],
	["k", "CRUMBLE TILE"],
	["j", "ICE"],
	["^", "SPIKES"],
	["%", "OFF-BEAT SPIKES"],
	["v", ""],
	["x", ""],
	["h", "HIDE TILES"],
	["u", "UNHIDE TILES"],
	["i", "INVISIBLE PATH"],
	["@", "HIDEABLE STAR"],
	["!", "HIDEABLE DEATH TILE"],
	["+", "HIDEABLE EXTRA LIFE"],
	[Draft.HIDE_TOOL, "STARTS HIDDEN"],
]
const QrCode := preload("res://addons/kenyoni/qr_code/qr_code.gd")
## Sheet 001-E: the cells of the two rows.
const CELL := Vector2(90, Blueprint.TAP_HEIGHT)
const CELL_PITCH := 98.0
const DRAFTS_Y := 80.0
const RECEIVED_HEAD_Y := 132.0
const RECEIVED_Y := 150.0
const ROW_PITCH := 48.0
## Under the cells: the two ways to get a friend's level, side by side, the
## note and the way back.
const ITEMS_Y := 248.0
const ITEMS_H := 40.0
const HALF_W := 286.0
const NOTE_Y := 292.0
const RETURN_Y := 306.0
## The editor, on the 667 × 375 panel: the status line, the grid (cells in
## the tiles' own 32:23 shape), the buttons under it, and the palette and
## code meter down the far side, clear of a dev build's DEV button.
const STATUS_Y := 44.0
const GRID_POS := Vector2(24, 62)
const GRID_CELL := Vector2(29, 29.0 * 23.0 / 32.0)
const BUTTONS_Y := 326.0
const BUTTON := Vector2(92, 34)
const BUTTON_GAP := 8.25
const PALETTE_POS := Vector2(532, 88)
const SWATCH := 26.0
const SWATCH_PITCH := 28.0
const PALETTE_COLUMNS := 4
const METER_Y := 292.0
const METER_W := 120.0
## The share sheet: the QR's place and size, and how many groups of four
## make a line of the code.
const QR_POS := Vector2(452, 60)
const QR_SIZE := 180.0
const GROUPS_PER_LINE := 4
## The scan sheet's camera view, right of the words and clear of a dev
## build's DEV button.
const VIEW_POS := Vector2(436, 84)
const VIEW_SIZE := Vector2(196, 147)

## The tile the palette has picked, kept while the editor is closed (a test).
static var tool := "c"

# --- 001-E: the drafting table --------------------------------------------------------


## drafts: Draft for each slot; received: codes, newest first, two rows of
## them. A cell shows the level's name, if it has one. note: a line about
## the last level played, in place of the usual one.
static func build(m: Menus, drafts: Array, received: Array, note := "") -> void:
	m._open("drafting", TEXT.number, m.tr(TEXT.title))
	m._columns([m.tr(TEXT.your_drafts)], [Menus.LIST_X])
	for i in Draft.SLOTS:
		var d: Draft = drafts[i]
		var detail := m.tr(TEXT.empty)
		var a11y := TEXT.a11y_draft_empty
		if d.signed:
			detail = m.tr(TEXT.signed)
			a11y = TEXT.a11y_draft_signed
		elif not d.is_empty():
			detail = m.tr(TEXT.draft)
			a11y = TEXT.a11y_draft
		if d.name != "" and not d.is_empty():
			detail = d.name
		var pos := Vector2(Menus.LIST_X + i * CELL_PITCH, DRAFTS_Y)
		var title: String = TEXT.draft_cell % (i + 1)
		_named_cell(m, pos, title, detail, "draft %d" % i, m.tr(a11y) % (i + 1))
	var head := m._row(RECEIVED_HEAD_Y, 16)
	m._text(head, m.tr(TEXT.received), 11, Blueprint.FAINT, Menus.LIST_X, 0, 560.0)
	m._reveal(head)
	if received.is_empty():
		var none := m._row(RECEIVED_Y + 12, 16)
		m._text(none, m.tr(TEXT.none_received), 10, Blueprint.FAINT, Menus.LIST_X, 0, 560.0)
		m._reveal(none)
	for i in mini(received.size(), Draft.RECEIVED_KEPT):
		@warning_ignore("integer_division")
		var pos := Vector2(
			Menus.LIST_X + (i % Draft.SLOTS) * CELL_PITCH,
			RECEIVED_Y + (i / Draft.SLOTS) * ROW_PITCH
		)
		var code: String = received[i]
		var name: String = Save.received_name(code)
		var title: String = TEXT.received_cell % (i + 1)
		var a11y: String = m.tr(TEXT.a11y_received) % (i + 1)
		_named_cell(m, pos, title, name if name != "" else code.left(4), "received %d" % i, a11y)
	var half := Vector2(HALF_W, ITEMS_H)
	for i in 2:
		var text: String = [TEXT.enter_code, TEXT.scan][i]
		var x := Menus.LIST_X + i * (HALF_W + CELL_PITCH - CELL.x)
		var b := Blueprint.item(
			m._panel, "%02d  %s" % [i + 1, m.tr(text)], Vector2(m._mx(x, HALF_W), ITEMS_Y), half
		)
		b.alignment = m._align()
		b.accessibility_name = m._sentence(m.tr(text))
		m._connect(b, ["enter code", "scan code"][i])
		m._reveal(b)
	var line := note if note != "" else m.tr(TEXT.how)
	m._note(m.tr(Menus.TEXT.note) % line, NOTE_Y)
	m._return_item(RETURN_Y)
	m._focus_first()


## A cell of the table whose detail line may be a name the player typed,
## which keeps to the cell.
static func _named_cell(
	m: Menus, pos: Vector2, title: String, detail: String, act: String, a11y: String
) -> void:
	var b := m._cell(pos, CELL, true, title, detail, act, a11y)
	for l in b.get_parent().get_children():
		if l is Label and l.text == detail:
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.clip_text = true
			l.size.x = CELL.x - 16.0


# --- 001-F: a level code ----------------------------------------------------------------


## The sheet a code is typed or pasted into. error: "" or why the last one
## didn't play ("bad" or "newer").
static func build_code_entry(m: Menus, text: String, error := "") -> void:
	m._open("enter_code", TEXT.code_number, m.tr(TEXT.code_title))
	m._note(m.tr(TEXT.type_or_paste), Menus.LIST_TOP, Blueprint.FAINT, 11)
	var edit := line_edit(m, Vector2(Menus.LIST_X, 84), 560.0, m.tr(TEXT.a11y_code))
	edit.text = text
	edit.placeholder_text = LevelCode.PREFIX + " 0MM3-C7P1-…"
	edit.text_direction = Control.TEXT_DIRECTION_LTR
	edit.text_submitted.connect(func(_t: String): m.action.emit("play code"))
	m._item(1, m.tr(TEXT.paste), "paste code", 144)
	m._item(2, m.tr(TEXT.play_code), "play code", 188)
	if error != "":
		var why: String = TEXT.newer_code if error == "newer" else TEXT.bad_code
		m._note(m.tr(why), 240, Blueprint.PINK, 11)
	_back_row(m, "<  " + m.tr(TEXT.title), "drafting table", 282)
	m.code_input = edit


## A box to type into, in the sheet's ink, `w` wide at `at`.
static func line_edit(m: Menus, at: Vector2, w: float, a11y: String) -> LineEdit:
	var edit := LineEdit.new()
	m._panel.add_child(edit)
	edit.position = Vector2(m._mx(at.x, w), at.y)
	Blueprint.fit(edit, Vector2(w, Blueprint.TAP_HEIGHT))
	edit.add_theme_font_override("font", Blueprint.mono(700))
	edit.add_theme_font_size_override("font_size", 18)
	edit.add_theme_color_override("font_color", Blueprint.INK)
	edit.add_theme_color_override("font_placeholder_color", Blueprint.DIM)
	edit.add_theme_color_override("caret_color", Blueprint.GOLD)
	var box := StyleBoxFlat.new()
	box.bg_color = Blueprint.HOVER
	box.border_color = Blueprint.INK
	box.set_border_width_all(1)
	box.content_margin_left = 12
	box.content_margin_right = 12
	edit.add_theme_stylebox_override("normal", box)
	edit.add_theme_stylebox_override("focus", box)
	edit.accessibility_name = a11y
	m._reveal(edit)
	return edit


## A code found on the clipboard as the game opened: play it, or not.
static func build_found(m: Menus, code: String) -> void:
	m._open("found_code", TEXT.code_number, m.tr(TEXT.code_title))
	m._note(m.tr(TEXT.on_clipboard), Menus.LIST_TOP, Blueprint.FAINT, 11)
	var l := m._text(m._panel, code_lines(code), 18, Blueprint.INK, Menus.LIST_X, 84, 300.0, 700)
	l.text_direction = Control.TEXT_DIRECTION_LTR
	m._reveal(l)
	m._item(1, m.tr(TEXT.play_it), "play found code", 190)
	m._item(2, m.tr(TEXT.not_now), "main menu", 234)
	m._hero_on("tilt")
	m._focus_first()


# --- 001-G: scanning a QR code ---------------------------------------------------------


## The camera view and what it is doing; a code it reads is played at once
## (main.gd's "scanned" action), or the status line says why not.
static func build_scan(m: Menus) -> void:
	m._open("scan", TEXT.scan_number, m.tr(TEXT.scan))
	m._note(m.tr(TEXT.point_camera), Menus.LIST_TOP, Blueprint.FAINT, 11)
	var line := m._note(m.tr(TEXT.looking), 128, Blueprint.GOLD, 11)
	line.name = "ScanStatus"
	line.accessibility_live = DisplayServer.LIVE_POLITE
	m._item(1, m.tr(TEXT.type_instead), "enter code", 188)
	_back_row(m, "<  " + m.tr(TEXT.title), "drafting table", 282)
	var at := Vector2(m._mx(VIEW_POS.x, VIEW_SIZE.x), VIEW_POS.y)
	var back := ColorRect.new()
	back.color = Blueprint.HOVER
	back.position = at
	back.size = VIEW_SIZE
	m._panel.add_child(back)
	m._reveal(back)
	var view := QrScanner.new()
	view.position = at
	view.size = VIEW_SIZE
	view.accessibility_name = m.tr(TEXT.a11y_camera)
	view.status.connect(func(kind: String): scan_status(m, kind))
	view.read.connect(_on_scanned.bind(m))
	m._panel.add_child(view)
	_viewfinder(m, at)
	m._focus_first()


## The frame round the camera view, with gold corners to aim with.
static func _viewfinder(m: Menus, at: Vector2) -> void:
	var r := Rect2(at, VIEW_SIZE)
	var edge := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end])
	edge.append_array([Vector2(r.position.x, r.end.y), r.position])
	m._reveal(Blueprint.line(m._panel, edge, Blueprint.INK))
	var inner := r.grow(-14.0)
	var arm := 16.0
	for corner in [
		inner.position,
		Vector2(inner.end.x, inner.position.y),
		inner.end,
		Vector2(inner.position.x, inner.end.y)
	]:
		var sx := 1.0 if corner.x < r.get_center().x else -1.0
		var sy := 1.0 if corner.y < r.get_center().y else -1.0
		var points := PackedVector2Array(
			[corner + Vector2(0, sy * arm), corner, corner + Vector2(sx * arm, 0)]
		)
		m._reveal(Blueprint.line(m._panel, points, Blueprint.GOLD, 2.0))


## Show what the scanner is doing (QrScanner.status), or why a code it read
## won't play ("not_a_level", "newer").
static func scan_status(m: Menus, kind: String) -> void:
	if m._panel == null:
		return
	var line := m._panel.find_child("ScanStatus", false, false) as Label
	if line == null:
		return
	var words := {
		"looking": TEXT.looking,
		"no_camera": TEXT.no_camera,
		"no_permission": TEXT.no_permission,
		"not_a_level": TEXT.not_a_level,
		"newer": TEXT.newer_code,
	}
	line.text = m.tr(words.get(kind, TEXT.not_a_level))
	line.add_theme_color_override(
		"font_color", Blueprint.GOLD if kind == "looking" else Blueprint.PINK
	)


static func _on_scanned(text: String, m: Menus) -> void:
	# A MAPMAN code from a newer game still goes on, to be told so.
	var t := text.strip_edges()
	var ours := t.to_upper().contains(LevelCode.PREFIX)
	if LevelCode.find(t) == "" and not ours:
		scan_status(m, "not_a_level")
	else:
		m.action.emit("scanned " + t)


# --- Dn-S: sharing ----------------------------------------------------------------------


## The share sheet of the level with code `code`, numbered `number`
## ("D1-S"); its second row goes back with `back_act`, labelled `back`.
static func build_share(
	m: Menus, code: String, number: String, back: String, back_act: String, copied := false
) -> void:
	m._open("share", number, m.tr(TEXT.share))
	m._note(m.tr(TEXT.scan_or_send), Menus.LIST_TOP, Blueprint.FAINT, 11)
	var l := m._text(m._panel, code_lines(code), 18, Blueprint.INK, Menus.LIST_X, 98, 300.0, 700)
	l.text_direction = Control.TEXT_DIRECTION_LTR
	l.accessibility_name = m.tr(TEXT.a11y_code) + ": " + code
	m._reveal(l)
	m._item(1, m.tr(TEXT.copy_code), "copy code", 214)
	m._item(2, back, back_act, 258)
	if copied:
		m._note(m.tr(TEXT.copied), 310, Blueprint.GOLD, 11)
	var qr := TextureRect.new()
	qr.texture = ImageTexture.create_from_image(qr_image(LevelCode.link(code)))
	qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	qr.position = Vector2(m._mx(QR_POS.x, QR_SIZE), QR_POS.y)
	qr.size = Vector2(QR_SIZE, QR_SIZE)
	qr.accessibility_name = m.tr(TEXT.a11y_qr)
	m._panel.add_child(qr)
	m._reveal(qr)
	if number.begins_with("D"):
		m._stamp(m.tr(TEXT.signed), Vector2(470, 256), Blueprint.GOLD, Menus.STAMP_DELAY, false)
	m._focus_first()


## A code over as many lines as it needs, GROUPS_PER_LINE groups to a line.
static func code_lines(code: String) -> String:
	var groups := code.split("-")
	var lines: PackedStringArray = []
	for i in range(0, groups.size(), GROUPS_PER_LINE):
		lines.append("-".join(groups.slice(i, i + GROUPS_PER_LINE)))
	return "\n".join(lines)


## A QR code of `text` in the sheet's colours: blue modules on white, which
## phone cameras read, with the quiet zone the standard asks for.
static func qr_image(text: String) -> Image:
	var qr := QrCode.new(QrCode.ErrorCorrection.MEDIUM)
	# A link has small letters, so goes byte by byte; a bare code is smaller
	# as alphanumeric.
	if text == text.to_upper():
		qr.put_alphanumeric(text)
	else:
		qr.put_byte(text.to_utf8_buffer())
	var modules := qr.encode()
	return QrCode.generate_image(modules, 4, Blueprint.INK, Blueprint.FIELD, 4)


# --- Dn: the editor --------------------------------------------------------------------


## The editor for `draft`. signed_now: it was just signed by a test, so the
## stamp slams down.
static func build_editor(m: Menus, draft: Draft, signed_now := false) -> void:
	m._open("editor", TEXT.draft_cell % (draft.slot + 1), m.tr(TEXT.draft_title) % (draft.slot + 1))
	# The title block would sit on the palette; the editor is a work surface.
	m._block.visible = false
	var editor := Editor.new()
	editor.setup(m, draft)
	m._panel.add_child(editor)
	if draft.signed:
		var at := Vector2(390, 262)
		if signed_now:
			m._stamp(m.tr(TEXT.signed), at, Blueprint.GOLD, Menus.STAMP_DELAY, false)
		else:
			Blueprint.stamp(m._panel, m.tr(TEXT.signed), Vector2(m._mx(at.x, 120.0), at.y))
	m._focus_first()


## The pause sheet over a draft ("D1") or a received level ("R"): its number
## and status, and a way back that ends at the drafting table.
static func build_pause(m: Menus, number: String) -> void:
	m._open("pause", number + "-A", m._t("paused_title"))
	var status: String = m.tr(TEXT.suspended_received)
	var end: String = m._t("end_game")
	if number.begins_with("D"):
		status = m.tr(TEXT.suspended_draft) % int(number.substr(1))
		end = m.tr(TEXT.back_to_draft)
	m._note(status, Menus.LIST_TOP, Blueprint.FAINT, 11)
	m._item(1, m._t("resume"), "unpause", 90)
	m._item(2, end, "end custom", 138)
	m._pause_tail()


## A row on the panel, like the parts list's way back, that reports `act`.
static func _back_row(m: Menus, text: String, act: String, y: float) -> void:
	_back_row_at(m, text, act, Menus.LIST_X, Menus.LIST_W, y)


static func _back_row_at(m: Menus, text: String, act: String, x: float, w: float, y: float) -> void:
	var b := Blueprint.item(
		m._panel, text, Vector2(m._mx(x, w), y), Vector2(w, Blueprint.TAP_HEIGHT)
	)
	b.alignment = m._align()
	m._connect(b, act)
	m._reveal(b)


## The editor's controls over the panel: the status line, the grid, the
## buttons, the palette and the code meter. It keeps them in step with the
## draft after every stroke, and saves the draft as each stroke ends.
class Editor:
	extends Control

	var m: Menus
	var draft: Draft
	var _status: Label
	var _meter: Label
	var _undo: Button
	var _clear: Button
	var _share: Button
	var _test: Button
	var _swatches := {}

	func setup(menus: Menus, d: Draft) -> void:
		m = menus
		draft = d
		position = Vector2.ZERO
		size = Menus.SHEET
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_status = m._text(self, "", 10, Blueprint.FAINT, GRID_POS.x, STATUS_Y, 493.0)
		var grid := DraftGrid.new()
		grid.draft = draft
		grid.position = Vector2(m._mx(GRID_POS.x, GRID_CELL.x * Draft.COLUMNS), GRID_POS.y)
		grid.size = Vector2(GRID_CELL.x * Draft.COLUMNS, GRID_CELL.y * Draft.ROWS)
		grid.stroke_ended.connect(_stroke_ended)
		add_child(grid)
		var names := ["back", "undo", "clear", "test", "share"]
		var acts := ["drafting table", "", "", "test draft", "share draft"]
		var buttons: Array[Button] = []
		for i in names.size():
			var x := GRID_POS.x + i * (BUTTON.x + BUTTON_GAP)
			buttons.append(_button(m.tr(TEXT[names[i]]), x, acts[i]))
		_undo = buttons[1]
		_clear = buttons[2]
		_test = buttons[3]
		_share = buttons[4]
		_undo.pressed.connect(_on_undo)
		_clear.pressed.connect(_on_clear)
		for i in TOOLS.size():
			_swatch(i)
		var head := m._text(
			self, m.tr(TEXT.code_meter), 10, Blueprint.FAINT, PALETTE_POS.x, METER_Y, 50.0
		)
		head.autowrap_mode = TextServer.AUTOWRAP_OFF
		_meter = m._text(self, "", 14, Blueprint.INK, PALETTE_POS.x, METER_Y + 12, METER_W, 700)
		_meter.text_direction = Control.TEXT_DIRECTION_LTR
		m._reveal(self)
		_refresh()

	func _button(text: String, x: float, act: String) -> Button:
		var b := Blueprint.item(self, text, Vector2(m._mx(x, BUTTON.x), BUTTONS_Y), BUTTON)
		b.add_theme_font_size_override("font_size", 13)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var box := StyleBoxFlat.new()
		box.bg_color = Color.TRANSPARENT
		box.border_color = Blueprint.INK
		box.set_border_width_all(1)
		box.content_margin_left = 6
		box.content_margin_right = 6
		b.add_theme_stylebox_override("normal", box)
		var off: StyleBoxFlat = box.duplicate()
		off.border_color = Blueprint.DIM
		b.add_theme_stylebox_override("disabled", off)
		if act != "":
			b.pressed.connect(func(): m.action.emit(act))
		return b

	func _swatch(i: int) -> void:
		var t: String = TOOLS[i][0]
		@warning_ignore("integer_division")
		var row := i / PALETTE_COLUMNS
		var col := i % PALETTE_COLUMNS
		var x := PALETTE_POS.x + col * SWATCH_PITCH
		var cell := Control.new()
		cell.position = Vector2(m._mx(x, SWATCH), PALETTE_POS.y + row * SWATCH_PITCH)
		cell.size = Vector2(SWATCH, SWATCH)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cell)
		var look := TileSwatch.new()
		look.tile = t
		look.size = cell.size
		cell.add_child(look)
		var b := Button.new()
		b.theme = Blueprint.theme()
		b.size = cell.size
		b.accessibility_name = _tool_name(i)
		m._clear_button(b)
		cell.add_child(b)
		b.pressed.connect(_pick.bind(t))
		_swatches[t] = look

	func _tool_name(i: int) -> String:
		if TOOLS[i][1] == "":
			var moves := LevelMap.vanish_moves(TOOLS[i][0], 25)
			return m.tr_n(TEXT.vanish[0], TEXT.vanish[1], moves) % moves
		return m.tr(TOOLS[i][1])

	func _pick(t: String) -> void:
		DraftingSheet.tool = t
		_refresh()

	func _on_undo() -> void:
		if draft.undo():
			Save.store_draft(draft)
			queue_redraw_grid()
			_refresh()

	## Wipe the grid, as one step UNDO can take back.
	func _on_clear() -> void:
		draft.begin_stroke()
		draft.clear()
		Save.store_draft(draft)
		queue_redraw_grid()
		_refresh()

	func queue_redraw_grid() -> void:
		for c in get_children():
			if c is DraftGrid:
				c.queue_redraw()

	func _stroke_ended() -> void:
		Save.store_draft(draft)
		_refresh()

	## The status line, the buttons and the meter, as the draft now is.
	func _refresh() -> void:
		var state := TEXT.test_to_sign
		match draft.problem():
			"start":
				state = TEXT.need_start
			"exit":
				state = TEXT.need_exit
		if draft.signed:
			state = TEXT.ready
		var picked := 0
		for i in TOOLS.size():
			if TOOLS[i][0] == DraftingSheet.tool:
				picked = i
		_status.text = m.tr(TEXT.tool_status) % [_tool_name(picked), m.tr(state)]
		_undo.disabled = not draft.can_undo()
		_clear.disabled = draft.is_empty()
		_test.disabled = draft.problem() != ""
		_share.disabled = not draft.signed
		var length := LevelCode.length(draft.code())
		_meter.text = TEXT.meter % [length, Draft.SHORT_CODE]
		var long := length > Draft.SHORT_CODE
		_meter.add_theme_color_override("font_color", Blueprint.PINK if long else Blueprint.INK)
		for t in _swatches:
			_swatches[t].picked = t == DraftingSheet.tool
			_swatches[t].queue_redraw()


## A palette swatch: the tile's own art in a box, gold when picked.
class TileSwatch:
	extends Control

	var tile := "c"
	var picked := false

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		if picked:
			draw_rect(box, Blueprint.PRESS)
		draw_rect(box, Blueprint.GOLD if picked else Blueprint.FAINT, false, 1.5 if picked else 1.0)
		var w := size.x - 6.0
		var art := Rect2(Vector2(3, (size.y - w * 23.0 / 32.0) / 2.0), Vector2(w, w * 23.0 / 32.0))
		match tile:
			" ":
				draw_line(art.position, art.end, Blueprint.INK, 1.5)
				draw_line(
					Vector2(art.position.x, art.end.y),
					Vector2(art.end.x, art.position.y),
					Blueprint.INK,
					1.5
				)
			Draft.HIDE_TOOL:
				draw_texture_rect(DraftGrid.texture("c"), art, false, Color(1, 1, 1, 0.35))
				DraftGrid.dashed_box(self, art.grow(1.0), Blueprint.INK)
			_:
				draw_texture_rect(DraftGrid.texture(tile), art, false)
				if tile == "%":
					DraftGrid.offbeat_mark(self, Vector2(2, size.y - 2), 9)
				if tile == "x" or tile == "v":
					var font := Blueprint.mono(800)
					var moves := str(LevelMap.vanish_moves(tile, 25))
					draw_string(
						font,
						Vector2(2, size.y - 2),
						moves,
						HORIZONTAL_ALIGNMENT_LEFT,
						-1,
						9,
						Blueprint.GOLD
					)


## The grid a draft is drawn on: drag a finger to paint with the picked tile,
## each stroke one step of undo.
class DraftGrid:
	extends Control

	signal stroke_ended

	static var _textures := {}

	var draft: Draft
	## A level card's map: shown, never painted.
	var read_only := false
	var _painting := false
	var _last := Vector2i(-1, -1)
	var _changed := false
	## For the hide tool: whether this stroke hides tiles or shows them.
	var _hide_on := true

	## The art of tile `t`; spikes show raised, so they read as spikes.
	static func texture(t: String) -> Texture2D:
		var file := "spikes_up.png" if t in ["^", "%"] else LevelMap.texture_file(t)
		if not _textures.has(file):
			_textures[file] = load(LevelMap.TILE_DIR + file)
		return _textures[file]

	## "½" in gold: spikes half a beat behind the others.
	static func offbeat_mark(c: CanvasItem, at: Vector2, font_size: int) -> void:
		var font := Blueprint.mono(800)
		c.draw_string(font, at, "½", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Blueprint.GOLD)

	## A box in dashes: a tile that starts hidden.
	static func dashed_box(c: CanvasItem, r: Rect2, color: Color) -> void:
		var corners := [
			r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)
		]
		for i in 4:
			c.draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 1.0, 3.0)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE if read_only else Control.MOUSE_FILTER_STOP

	func _cell_size() -> Vector2:
		return Vector2(size.x / Draft.COLUMNS, size.y / Draft.ROWS)

	func _key_at(pos: Vector2) -> Vector2i:
		var c := _cell_size()
		return Vector2i(floori(pos.x / c.x), floori(pos.y / c.y))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if event.pressed:
				_begin(_key_at(event.position))
			elif _painting:
				_end()
		elif event is InputEventMouseMotion and _painting:
			accept_event()
			_drag_to(_key_at(event.position))

	func _begin(key: Vector2i) -> void:
		if not Draft.on_grid(key):
			return
		_painting = true
		_changed = false
		draft.begin_stroke()
		_hide_on = not draft.hidden.has(key)
		_last = key
		_apply(key)

	func _drag_to(key: Vector2i) -> void:
		if key == _last:
			return
		# Every cell on the way, so a quick swipe leaves no gaps.
		var steps := maxi(absi(key.x - _last.x), absi(key.y - _last.y))
		for i in range(1, steps + 1):
			var t := float(i) / steps
			_apply(Vector2i(roundi(lerpf(_last.x, key.x, t)), roundi(lerpf(_last.y, key.y, t))))
		_last = key

	func _apply(key: Vector2i) -> void:
		var t := DraftingSheet.tool
		var done := false
		if t == Draft.HIDE_TOOL:
			done = draft.set_hidden(key, _hide_on)
		else:
			done = draft.paint(key, t)
		if done:
			_changed = true
			queue_redraw()

	func _end() -> void:
		_painting = false
		if not _changed:
			draft.undo()
		queue_redraw()
		stroke_ended.emit()

	func _draw() -> void:
		var c := _cell_size()
		# A clean board over the sheet, so its own grid lines don't show
		# through the cells (they don't line up with them).
		draw_rect(Rect2(Vector2.ZERO, size), Blueprint.FIELD)
		var line := Blueprint.GRID
		for x in Draft.COLUMNS + 1:
			draw_line(Vector2(x * c.x, 0), Vector2(x * c.x, size.y), line, 1.0)
		for y in Draft.ROWS + 1:
			draw_line(Vector2(0, y * c.y), Vector2(size.x, y * c.y), line, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Blueprint.FAINT, false, 1.2)
		for y in Draft.ROWS:
			for x in Draft.COLUMNS:
				var key := Vector2i(x, y)
				var t := draft.tile(key)
				if t == " ":
					continue
				var r := Rect2(Vector2(x * c.x, y * c.y), c).grow(-1.0)
				var faded := draft.hidden.has(key)
				var tint := Color(1, 1, 1, 0.35 if faded else LevelMap.TILE_ALPHA)
				draw_texture_rect(texture(t), r, false, tint)
				if faded:
					dashed_box(self, r, Blueprint.INK)
				if t == "%":
					offbeat_mark(self, Vector2(r.position.x + 1, r.end.y - 1), 8)
		if _painting and Draft.on_grid(_last):
			var at := Rect2(Vector2(_last.x * c.x, _last.y * c.y), c)
			draw_rect(at, Blueprint.GOLD, false, 2.0)
