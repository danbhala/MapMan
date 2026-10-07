class_name ToolboxSheet
extends RefCounted
## Sheet 001-T, the Toolbox (docs/toolbox.md): the three branches of tools
## with their tiers, the card of the tool picked with its BUY and belt
## buttons, the belt, Fresh Sheet and the bank. Static functions that build
## onto the Menus sheet they are given, like WardrobeSheet; the Toolbox's
## rules are in Toolbox. Loads only with the game scene, so it may name Save.

## Every word the sheet adds: English msgids (i18n/). The tools' names,
## blurbs and tier lines are in Toolbox.
const TEXT := {
	"number": "001-T",
	"title": "TOOLBOX",
	"branch": "%02d  %s",
	"in_bank": "IN THE BANK",
	"spent": "★ %s / ★ %s SPENT",
	"locked": "LOCKED",
	"on_belt": "ON BELT",
	"owned": "OWNED",
	"limits":
	{
		"recharge": "RECHARGES",
		"try": "ONCE A TRY",
		"sheet": "ONCE A SHEET",
		"game": "ONCE A GAME",
		"every_try": "EVERY TRY",
	},
	"tiers": ["I", "II", "III"],
	"buy": "BUY %s  ★ %d",
	"all_owned": "EVERY TIER OWNED",
	"more_to_go": "★ %d MORE TO GO",
	"buy_first": "BUY %s FIRST",
	"put_on_belt": "PUT ON BELT",
	"take_off_belt": "TAKE OFF BELT",
	"belt_full": "BELT FULL",
	"belt": "BELT",
	"third_slot": "SHEET %d",
	"fresh_sheet": "FRESH SHEET",
	"fresh_buy": "BUY FOR ★ %d",
	"fresh_take": "TAKE BACK ★ %s",
	"fresh_nothing": "NOTHING SPENT",
	"fresh_between": "BETWEEN SHEETS ONLY",
	"back": "<  SHEET %s",
	"star": "★ %s",
	# for screen readers
	"a11y_tool": "%s, tier %d of 3",
	"a11y_tool_none": "%s, not owned",
	"a11y_tool_locked": "%s, locked",
	"a11y_bank": "%d stars in the bank",
}
## The branch columns' left edges and width, and the nodes' pitch.
const COLUMN_XS := [36.0, 186.0, 336.0]
const COLUMN_W := 150.0
const BRANCH_Y := 52.0
const NODE_Y := 108.0
const NODE_PITCH := 64.0
const ICON_W := 48.0
## The card: its divider, left edge and width.
const CARD_RULE_X := 486.0
const CARD_X := 498.0
const CARD_W := 152.0
const BLURB_H := 45.0
const TIER_Y := 169.0
const TIER_PITCH := 22.0
## The BUY and belt buttons' place down the card, and their size.
const BUY_Y := 180.0
const BELT_Y := 212.0
const CARD_BUTTON := Vector2(160, 28)
## The bank, top right.
const BANK_X := 520.0
const BANK_W := 135.0
## The bottom strip: the belt's slots, Fresh Sheet and the way back.
const STRIP_Y := 296.0
const SLOT_X := 104.0
const SLOT_PITCH := 44.0
const SLOT_Y := 316.0
const FRESH_POS := Vector2(240, 296)
const FRESH_SIZE := Vector2(180, 46)
const BACK_POS := Vector2(428, 296)
const BACK_SIZE := Vector2(120, 44)
## The TOOLBOX row over MapMan on the main menu, with the stars in the bank
## at its far end. Reports "toolbox".
const ROW_POS := Vector2(436, 72)
const ROW_SIZE := Vector2(196, Blueprint.TAP_HEIGHT)
const COUNT_W := 68.0


## The sheet, with `box.selected`'s card. Each row of a column is a button
## reporting "tool <id>"; the card's report "buy <id>" and "belt <id>";
## Fresh Sheet reports "fresh sheet" and the way back "toolbox back".
static func build(m: Menus, box: Toolbox) -> void:
	m._open("toolbox", TEXT.number, m.tr(TEXT.title))
	_bank(m)
	var marks := Marks.new()
	m._panel.add_child(marks)
	var selected_button: Button = null
	for b in Toolbox.BRANCHES.size():
		var x: float = COLUMN_XS[b]
		var head := m._row(BRANCH_Y, 28)
		var title: String = TEXT.branch % [b + 1, m.tr(Toolbox.BRANCHES[b][0])]
		m._text(head, title, 11, Blueprint.INK, x, 0, COLUMN_W - 4.0, 800)
		m._text(
			head, m.tr(Toolbox.BRANCHES[b][1]), 9, Blueprint.FAINT, x + 24.0, 15, COLUMN_W - 28.0
		)
		m._reveal(head)
		var tools := Toolbox.branch_tools(b)
		for j in tools.size():
			var button := _node(m, marks, box, tools[j], x, NODE_Y + j * NODE_PITCH, j > 0)
			if tools[j].id == box.selected:
				selected_button = button
	_card(m, marks, box)
	_strip(m, marks, box)
	if selected_button != null:
		m._first_button = selected_button
	m._focus_first()


## The bank, top right: the stars to spend, and what is spent of the whole.
static func _bank(m: Menus) -> void:
	var row := m._row(12, 46)
	var stars := m._text(
		row, TEXT.star % _figure(Save.bank), 20, Blueprint.GOLD, BANK_X, 0, BANK_W, 800
	)
	stars.accessibility_name = m.tr(TEXT.a11y_bank) % Save.bank
	m._text(row, m.tr(TEXT.in_bank), 9, Blueprint.FAINT, BANK_X, 25, BANK_W)
	var spent := (
		m.tr(TEXT.spent) % [_figure(Toolbox.spent_stars(Save)), _figure(Toolbox.tree_price())]
	)
	m._text(row, spent, 8, Blueprint.FAINT, BANK_X, 36, BANK_W)
	m._reveal(row)


## "1,455" for a star count, as the catalog shows figures.
static func _figure(n: int) -> String:
	var s := str(n)
	if n >= 1000:
		s = s.left(s.length() - 3) + "," + s.right(3)
	return s


## One tool's row in its column: icon, name, tier pips and what's next.
static func _node(
	m: Menus, marks: Marks, box: Toolbox, tool: Dictionary, x: float, y: float, joined: bool
) -> Button:
	var id: String = tool.id
	var owned := Save.tool_tier(id)
	var open := Toolbox.unlocked(id, Save)
	var cell := Control.new()
	cell.position = Vector2(m._mx(x, COLUMN_W), y - NODE_PITCH / 2.0 + 4.0)
	cell.size = Vector2(COLUMN_W, NODE_PITCH - 8.0)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m._panel.add_child(cell)
	var icon_x := _flip(m, 26.0, 0.0, COLUMN_W)
	var icon_y := NODE_PITCH / 2.0 - 4.0
	if joined:
		var line_x := m._mx(x + 26.0, 0.0)
		marks.lines.append(
			[
				Vector2(line_x, y - NODE_PITCH + ICON_W * 0.4),
				Vector2(line_x, y - ICON_W * 0.4),
				Color(1, 1, 1, 0.8 if open else 0.3)
			]
		)
	var alpha := 1.0 if owned > 0 else (0.6 if open else 0.35)
	ToolIcons.tile(cell, id if open else "lock", Vector2(icon_x, icon_y), ICON_W, alpha)
	if id == box.selected:
		marks.rings.append(
			[cell.position + Vector2(icon_x, icon_y - 1.0), 31.0, Blueprint.INK, 1.0]
		)
	if Save.on_belt(id):
		marks.rings.append(
			[cell.position + Vector2(icon_x, icon_y - 1.0), 27.0, Blueprint.GOLD, 2.0]
		)
	var ink := Blueprint.INK if open else Blueprint.FAINT
	var name: String = m.tr(tool.name)
	_cell_text(m, cell, name, 11, ink, 56.0, 10.0, 94.0, 700)
	var pips := ""
	for t in Toolbox.TIERS:
		pips += "●" if t < owned else "○"
	_cell_text(
		m, cell, pips, 10, Blueprint.GOLD if owned > 0 else Blueprint.FAINT, 56.0, 25.0, 30.0
	)
	var next := Toolbox.next_price(id, owned)
	if not open:
		_cell_text(m, cell, m.tr(TEXT.locked), 9, Blueprint.FAINT, 88.0, 26.0, 60.0, 600)
	elif next > 0:
		_cell_text(m, cell, TEXT.star % _figure(next), 9, Blueprint.GOLD, 88.0, 26.0, 60.0, 600)
	if Save.on_belt(id):
		_cell_text(m, cell, m.tr(TEXT.on_belt), 9, Blueprint.GOLD, 56.0, 39.0, 92.0, 700)
	var b := Button.new()
	b.theme = Blueprint.theme()
	cell.add_child(b)
	b.size = cell.size
	if not open:
		b.accessibility_name = m.tr(TEXT.a11y_tool_locked) % name
	elif owned == 0:
		b.accessibility_name = m.tr(TEXT.a11y_tool_none) % name
	else:
		b.accessibility_name = m.tr(TEXT.a11y_tool) % [name, owned]
	m._clear_button(b)
	m._connect(b, "tool " + id)
	m._reveal(cell, 0.03)
	return b


## The card of the tool picked: icon, name, how often it works, what it
## does, its three tiers, and the BUY and belt buttons.
static func _card(m: Menus, marks: Marks, box: Toolbox) -> void:
	var tool := Toolbox.tool(box.selected)
	var id: String = tool.id
	var owned := Save.tool_tier(id)
	var open := Toolbox.unlocked(id, Save)
	var rule_x := m._mx(CARD_RULE_X, 0.0)
	marks.lines.append([Vector2(rule_x, 56), Vector2(rule_x, 290), Color(1, 1, 1, 0.3)])
	var card := m._row(56, 240)
	var icon_at := Vector2(m._mx(CARD_X + CARD_W / 2.0, 0.0), 16)
	ToolIcons.tile(card, id if open else "lock", icon_at, 44.0, 1.0 if open else 0.4)
	m._text(card, m.tr(tool.name), 13, Blueprint.INK, CARD_X, 38, CARD_W, 800)
	var limit: String = tool.limit
	if id == "look":
		limit = "every_try"
	m._text(card, m.tr(TEXT.limits[limit]), 9, Blueprint.FAINT, CARD_X, 53, CARD_W)
	# Wrapped over up to three lines (m._text would turn the wrap off).
	var blurb := Blueprint.label(
		card,
		m.tr(tool.blurb),
		8,
		Blueprint.FAINT,
		Vector2(m._mx(CARD_X, CARD_W), 66),
		500,
		CARD_W,
		m._align()
	)
	# Wrapping doesn't refresh the label's minimum size by itself, and the
	# unwrapped line would keep its width whatever the box says.
	blurb.update_minimum_size()
	Blueprint.fit(blurb, Vector2(CARD_W, BLURB_H))
	var next := Toolbox.next_price(id, owned)
	var can_buy := open and next > 0 and next <= Save.bank
	for t in Toolbox.TIERS:
		var y := TIER_Y - 56 + t * TIER_PITCH
		var have := t < owned
		var ink := Blueprint.INK if have or t == owned else Blueprint.FAINT
		m._text(card, TEXT.tiers[t], 10, ink, CARD_X, y, 20.0, 800)
		m._text(card, Toolbox.tier_text(id, t + 1), 8, ink, CARD_X + 18.0, y + 12, CARD_W - 18.0)
		# Its price; the next tier's says what the bank is short of.
		var status: String = TEXT.star % Toolbox.price(id, t + 1)
		var colour := Blueprint.GOLD
		if have:
			status = m.tr(TEXT.owned)
			colour = Blueprint.MINT
		elif t == owned and open and not can_buy:
			status = m.tr(TEXT.more_to_go) % (next - Save.bank)
			colour = Blueprint.FAINT
		var l := m._text(card, status, 9, colour, CARD_X + 52.0, y + 1, 100.0, 700)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if m._rtl else HORIZONTAL_ALIGNMENT_RIGHT
		var rx := m._mx(CARD_X, CARD_W)
		Blueprint.rule(card, y + 21, rx, rx + CARD_W, Color(1, 1, 1, 0.25))
	# What's next: BUY the next tier, or why not.
	if not open:
		var up: String = m.tr(Toolbox.tool(Toolbox.above(id)).name)
		m._text(card, m.tr(TEXT.buy_first) % up, 9, Blueprint.FAINT, CARD_X, BUY_Y + 8, CARD_W)
	elif next < 0:
		m._text(card, m.tr(TEXT.all_owned), 9, Blueprint.FAINT, CARD_X, BUY_Y + 8, CARD_W)
	else:
		var tier_name: String = TEXT.tiers[owned]
		var buy := _card_button(
			m, card, m.tr(TEXT.buy) % [tier_name, next], BUY_Y, "buy " + id, can_buy
		)
		if not can_buy:
			var note: String = m.tr(TEXT.more_to_go) % (next - Save.bank)
			buy.accessibility_name = m._sentence(buy.text) + ", " + m._sentence(note)
	if owned > 0:
		var on := Save.on_belt(id)
		var full := not on and Save.belt.size() >= Toolbox.belt_slots(Save)
		var text: String = m.tr(
			TEXT.take_off_belt if on else (TEXT.belt_full if full else TEXT.put_on_belt)
		)
		_card_button(m, card, text, BELT_Y, "belt " + id, not full)
	m._reveal(card)


## A button across the card, `y` down it.
static func _card_button(
	m: Menus, card: Control, text: String, y: float, act: String, enabled: bool
) -> Button:
	var pos := Vector2(m._mx(CARD_X - 4.0, CARD_BUTTON.x), y)
	var b := Blueprint.item(card, text, pos, CARD_BUTTON, enabled)
	b.add_theme_font_size_override("font_size", 12)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.accessibility_name = m._sentence(text)
	m._connect(b, act, enabled)
	return b


## The bottom strip: the belt's slots, Fresh Sheet and the way back.
static func _strip(m: Menus, marks: Marks, box: Toolbox) -> void:
	var strip := m._row(STRIP_Y, 50)
	m._text(strip, m.tr(TEXT.belt), 11, Blueprint.INK, COLUMN_XS[0], 12, 60.0, 800)
	var slots := Toolbox.belt_slots(Save)
	var belt := box.belt()
	for i in Toolbox.BELT_SLOTS + 1:
		var at := Vector2(m._mx(SLOT_X + i * SLOT_PITCH, 0.0), SLOT_Y - STRIP_Y)
		var open := i < slots
		var filled := i < belt.size()
		var ring: Color = Blueprint.GOLD if filled else Color(1, 1, 1, 0.3)
		marks.rings.append([Vector2(at.x, SLOT_Y - 1.0), 21.0, ring, 1.6 if filled else 1.0])
		if filled:
			ToolIcons.tile(strip, belt[i], at, 30.0)
		elif not open:
			ToolIcons.tile(strip, "lock", at, 26.0, 0.35)
			var cap := m._text(
				strip,
				m.tr(TEXT.third_slot) % Toolbox.THIRD_SLOT_LEVEL,
				8,
				Blueprint.FAINT,
				SLOT_X + i * SLOT_PITCH - 24.0,
				40,
				48.0
			)
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var div_x := m._mx(230.0, 0.0)
	marks.lines.append([Vector2(div_x, STRIP_Y), Vector2(div_x, STRIP_Y + 44), Color(1, 1, 1, 0.3)])
	# Fresh Sheet: bought once, then every star spent comes back, between sheets.
	var fresh := Control.new()
	fresh.position = Vector2(m._mx(FRESH_POS.x, FRESH_SIZE.x), 0)
	fresh.size = FRESH_SIZE
	fresh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(fresh)
	ToolIcons.tile(fresh, "fresh", Vector2(_flip(m, 22.0, 0.0, FRESH_SIZE.x), 23.0), 34.0)
	_cell_text(m, fresh, m.tr(TEXT.fresh_sheet), 11, Blueprint.INK, 44.0, 4.0, 132.0, 800)
	var sub := ""
	var can := true
	var spent := Toolbox.spent_stars(Save)
	if not Save.fresh_sheet:
		sub = m.tr(TEXT.fresh_buy) % Toolbox.FRESH_SHEET_PRICE
		can = Save.bank >= Toolbox.FRESH_SHEET_PRICE
	elif box.from == "pause":
		sub = m.tr(TEXT.fresh_between)
		can = false
	elif spent == 0:
		sub = m.tr(TEXT.fresh_nothing)
		can = false
	else:
		sub = m.tr(TEXT.fresh_take) % _figure(spent)
	_cell_text(m, fresh, sub, 9, Blueprint.GOLD if can else Blueprint.FAINT, 44.0, 21.0, 132.0, 600)
	var fb := Button.new()
	fb.theme = Blueprint.theme()
	fresh.add_child(fb)
	fb.size = FRESH_SIZE
	fb.disabled = not can
	if not can:
		fb.focus_mode = Control.FOCUS_NONE
	fb.accessibility_name = m._sentence(m.tr(TEXT.fresh_sheet)) + ", " + m._sentence(sub)
	m._clear_button(fb)
	m._connect(fb, "fresh sheet", can)
	# The way back to the sheet this one was opened from.
	var number := "001"
	match box.from:
		"pause":
			number = m._level_number("A")
		"clear":
			number = "%03d" % m._level
	var back_text: String = m.tr(TEXT.back) % m._isolated(number)
	var back := Blueprint.item(
		strip, back_text, Vector2(m._mx(BACK_POS.x, BACK_SIZE.x), 0), BACK_SIZE
	)
	back.add_theme_font_size_override("font_size", 10)
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.accessibility_name = m._sentence(m.tr(TEXT.back) % number)
	m._connect(back, "toolbox back")
	m._reveal(strip)


## A line of text in a cell, `x` in from its reading edge and `w` wide.
static func _cell_text(
	m: Menus,
	cell: Control,
	text: String,
	size: int,
	ink: Color,
	x: float,
	y: float,
	w: float,
	weight := 500
) -> Label:
	var pos := Vector2(_flip(m, x, w, cell.size.x), y)
	var l := Blueprint.label(cell, text, size, ink, pos, weight, w, m._align())
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


## The x of a piece `w` wide at `x` in a box `total` wide, mirrored on a
## right-to-left sheet (Menus._mx for the whole sheet).
static func _flip(m: Menus, x: float, w: float, total: float) -> float:
	return total - x - w if m._rtl else x


## The lines and rings drawn on the sheet in one node.
class Marks:
	extends Node2D
	var lines := []  # [from, to, color]
	var rings := []  # [centre, radius, color, width]

	func _draw() -> void:
		for l in lines:
			draw_line(l[0], l[1], l[2], 1.2, true)
		for r in rings:
			draw_arc(r[0], r[1], 0, TAU, 48, r[2], r[3], true)


# --- 001: the way in ---------------------------------------------------------------


static func main_menu_row(m: Menus) -> void:
	var pos := Vector2(m._mx(ROW_POS.x, ROW_SIZE.x), ROW_POS.y)
	var b := Blueprint.item(m._panel, m.tr(TEXT.title), pos, ROW_SIZE)
	b.alignment = m._align()
	b.accessibility_name = m._sentence(m.tr(TEXT.title)) + ", " + m.tr(TEXT.a11y_bank) % Save.bank
	# The bank is figures at the row's far end (inside its 12 px margin);
	# figures read left to right in every language (Blueprint.label).
	var x := 12.0 if m._rtl else ROW_SIZE.x - 12.0 - COUNT_W
	var figures: String = TEXT.star % _figure(Save.bank)
	var l := Blueprint.label(b, figures, 16, Blueprint.GOLD, Vector2(x, 0), 500, COUNT_W)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if m._rtl else HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Blueprint.fit(l, Vector2(COUNT_W, ROW_SIZE.y))
	m._connect(b, "toolbox")
	m._reveal(b)
