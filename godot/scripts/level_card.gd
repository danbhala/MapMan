class_name LevelCard
extends RefCounted
## A drafting table level's own sheet, opened by tapping its cell: the map,
## its name, how it has gone (tries, wins, best time) and what to do with it.
## Also the sheets for renaming and deleting it. DraftingTable fills `Card`
## and handles the actions; this only draws.

const TEXT := {
	"made_by_you": "MADE BY YOU",
	"from_friend": "FROM A FRIEND",
	"received_title": "RECEIVED LEVEL %d",
	"played": "PLAYED",
	"cleared": "CLEARED",
	"best": "BEST",
	"left": "%ds LEFT",
	"none": "—",
	"play": "PLAY",
	"edit": "EDIT",
	"remix": "REMIX",
	"delete": "DELETE",
	"rename": "RENAME",
	"watch_replay": "WATCH REPLAY",
	"replay_title": "REPLAY — %s",
	"keep_it": "KEEP IT",
	"back_to_level": "BACK TO THE LEVEL",
	"delete_draft": "DELETE DRAFT %d?",
	"delete_received": "DELETE RECEIVED LEVEL %d?",
	"delete_note": "ITS NAME, BEST TIME AND GHOST GO WITH IT. THIS CAN'T BE UNDONE",
	"name_it": "NAME THIS LEVEL · ONLY YOU SEE IT",
	"save_name": "SAVE THE NAME",
	"no_slot": "ALL 6 DRAFTS ARE IN USE: DELETE ONE TO REMIX",
	"new_best": "CLEARED WITH %ds LEFT · NEW BEST",
	"a11y_name": "Level name",
	"a11y_preview": "The level's map",
}

## The map's place and cell (the tiles' own 32:23 shape), the name line, the
## note and the figures under it, and the column of actions down the side.
const PREVIEW_POS := Vector2(40, 60)
const PREVIEW_CELL := Vector2(22, 22.0 * 23.0 / 32.0)
const NAME_Y := 256.0
const RENAME_POS := Vector2(262, 254)
const RENAME_SIZE := Vector2(160, 32)
const NOTE_Y := 286.0
const STATS_Y := 304.0
const STAT_PITCH := 120.0
const ACTIONS_X := 428.0
const ACTIONS_W := 216.0
const ACTIONS_Y := 54.0
const ACTION_PITCH := 48.0
const BACK_Y := 312.0


## What a card shows. `draft` is the map (a received level as a Draft).
class Card:
	extends RefCounted
	var number := ""
	var title := ""
	var kind_line := ""
	var draft: Draft
	var name := ""
	var source := ""
	var stats := {}
	var can_play := true
	var can_share := true
	## "edit" for a draft, "remix" for a received level.
	var edit := "edit"
	var can_edit := true
	var replay := false
	## A gold line about the last try, in place of the source.
	var note := ""


static func build(m: Menus, c: Card) -> void:
	m._open("card", c.number, c.name if c.name != "" else c.title)
	# The title block would sit on the actions; the map takes the sheet.
	m._block.visible = false
	m._text(m._panel, c.kind_line, 11, Blueprint.FAINT, Menus.LIST_X, 40, 380.0)
	var grid := preview(m, c.draft, PREVIEW_POS, PREVIEW_CELL)
	grid.accessibility_name = m.tr(TEXT.a11y_preview)
	var shown := c.name if c.name != "" else c.title
	var name := m._text(m._panel, shown, 20, Blueprint.INK, Menus.LIST_X, NAME_Y, 216.0, 800)
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	m._reveal(name)
	var r := Blueprint.item(
		m._panel,
		"✎ " + m.tr(TEXT.rename),
		Vector2(m._mx(RENAME_POS.x, RENAME_SIZE.x), RENAME_POS.y),
		RENAME_SIZE
	)
	r.alignment = m._align()
	m._connect(r, "card rename")
	m._reveal(r)
	var note := c.note if c.note != "" else c.source
	m._text(
		m._panel,
		note,
		10,
		Blueprint.GOLD if c.note != "" else Blueprint.FAINT,
		Menus.LIST_X,
		NOTE_Y,
		380.0
	)
	var best: int = c.stats.get("best", -1)
	var figures := [
		[TEXT.played, str(c.stats.get("played", 0))],
		[TEXT.cleared, str(c.stats.get("cleared", 0))],
		[TEXT.best, m.tr(TEXT.left) % best if best >= 0 else TEXT.none],
	]
	for i in figures.size():
		var x := Menus.LIST_X + i * STAT_PITCH
		var row := m._row(STATS_Y, 34)
		m._text(row, m.tr(figures[i][0]), 10, Blueprint.FAINT, x, 0, STAT_PITCH - 10.0)
		var v := m._text(row, figures[i][1], 15, Blueprint.INK, x, 13, STAT_PITCH - 10.0, 700)
		v.text_direction = (
			Control.TEXT_DIRECTION_LTR
			if figures[i][1] == TEXT.none
			else (Blueprint.direction(figures[i][1]))
		)
		m._reveal(row)
	var acts := [
		[TEXT.play, "card play", c.can_play, Blueprint.INK],
		[
			TEXT.edit if c.edit == "edit" else TEXT.remix,
			"card " + c.edit,
			c.can_edit,
			Blueprint.INK
		],
		[DraftingSheet.TEXT.share, "card share", c.can_share, Blueprint.INK],
	]
	if c.replay:
		acts.append([TEXT.watch_replay, "card replay", true, Blueprint.INK])
	acts.append([TEXT.delete, "card delete", true, Blueprint.PINK])
	for i in acts.size():
		_action(
			m,
			i + 1,
			m.tr(acts[i][0]),
			acts[i][1],
			ACTIONS_Y + i * ACTION_PITCH,
			acts[i][2],
			acts[i][3]
		)
	DraftingSheet._back_row_at(
		m, "<  " + m.tr(DraftingSheet.TEXT.title), "drafting table", ACTIONS_X, ACTIONS_W, BACK_Y
	)
	m._focus_first()


## A numbered action in the side column; pink for one that takes things away.
static func _action(
	m: Menus, index: int, text: String, act: String, y: float, enabled: bool, color: Color
) -> Button:
	var pos := Vector2(m._mx(ACTIONS_X, ACTIONS_W), y)
	var b := Blueprint.item(
		m._panel, "%02d  %s" % [index, text], pos, Vector2(ACTIONS_W, Blueprint.TAP_HEIGHT), enabled
	)
	b.alignment = m._align()
	b.accessibility_name = m._sentence(text)
	if enabled and color != Blueprint.INK:
		b.add_theme_color_override("font_color", color)
		b.add_theme_color_override("font_hover_color", color)
		b.add_theme_color_override("font_focus_color", color)
	m._connect(b, act, enabled)
	m._reveal(b)
	return b


## The map of `draft`, drawn like the editor's grid but not to be painted.
static func preview(m: Menus, draft: Draft, at: Vector2, cell: Vector2) -> Control:
	var g := DraftingSheet.DraftGrid.new()
	g.draft = draft
	g.read_only = true
	g.size = Vector2(cell.x * Draft.COLUMNS, cell.y * Draft.ROWS)
	g.position = Vector2(m._mx(at.x, g.size.x), at.y)
	m._panel.add_child(g)
	m._reveal(g)
	return g


## Are you sure: the map, small, what goes, and KEEP IT first.
static func build_delete(m: Menus, c: Card, question: String) -> void:
	m._open("card_delete", c.number + "-X", m.tr(TEXT.delete))
	m._block.visible = false
	preview(m, c.draft, Vector2(Menus.LIST_X, 60), Vector2(14, 14.0 * 23.0 / 32.0))
	var q := m._text(m._panel, question, 18, Blueprint.INK, Menus.LIST_X, 196, 380.0, 800)
	m._reveal(q)
	if c.name != "":
		m._text(m._panel, c.name, 14, Blueprint.INK, Menus.LIST_X, 222, 380.0, 700)
	var l := m._note(m.tr(TEXT.delete_note), 248, Blueprint.FAINT, 10)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action(m, 1, m.tr(TEXT.keep_it), "card", ACTIONS_Y, true, Blueprint.INK)
	_action(
		m, 2, m.tr(TEXT.delete), "card delete yes", ACTIONS_Y + ACTION_PITCH, true, Blueprint.PINK
	)
	m._focus_first()


## The name typed in; it stays on this phone.
static func build_rename(m: Menus, c: Card) -> void:
	m._open("card_rename", c.number + "-N", m.tr(TEXT.rename))
	m._note(m.tr(TEXT.name_it), Menus.LIST_TOP, Blueprint.FAINT, 11)
	var edit := DraftingSheet.line_edit(m, Vector2(Menus.LIST_X, 84), 380.0, m.tr(TEXT.a11y_name))
	edit.text = c.name
	edit.max_length = Draft.NAME_MAX
	edit.placeholder_text = c.title
	edit.text_direction = Control.TEXT_DIRECTION_AUTO
	edit.text_submitted.connect(func(_t: String): m.action.emit("card rename save"))
	m._item(1, m.tr(TEXT.save_name), "card rename save", 144)
	DraftingSheet._back_row(m, "<  " + (c.name if c.name != "" else c.title), "card", 282)
	m.code_input = edit
	edit.grab_focus.call_deferred()
