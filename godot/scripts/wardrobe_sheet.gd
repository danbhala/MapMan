class_name WardrobeSheet
extends RefCounted
## The wardrobe on the sheets (docs/wardrobe): the WARDROBE row on the main
## menu, sheet 001-D with every look in the order it is released, and the gold
## slips that say a look has been released. Static functions that build onto
## the Menus sheet they are given, with its own helpers; Menus calls them.
## Like menus.gd, this only loads with the game scene, so it may name the Save
## autoload (godot/CLAUDE.md).

## Every word the wardrobe adds to the sheets: English msgids (i18n/). The
## looks' and the tiers' names are in Wardrobe.
const TEXT := {
	"title": "WARDROBE",
	"number": "001-D",
	"count": "%d/%d",
	"new": "NEW",
	"released": ["%d OF %d RELEASED", "%d OF %d RELEASED"],
	"tap_to_wear": "TAP ONE TO WEAR IT",
	"level": "LV %d",
	"start": "START",
	"the_end": "THE END",
	"worn": "WORN",
	"released_at": "RELEASED AT LEVEL %d",
	"from_the_start": "IN THE WARDROBE FROM THE START",
	"for_finishing": "RELEASED FOR FINISHING THE GAME",
	"new_in_wardrobe": "NEW IN THE WARDROBE",
	"wear_it": "WEAR IT FROM THE WARDROBE ON SHEET 001",
	"mapwoman_joins": "MAPWOMAN JOINS THE WARDROBE",
	"play_as_her": "PLAY AS HER: MAPMAN WAITS FOR YOU AT THE END",
	# for screen readers
	"a11y_row": "Wardrobe, %d of %d released",
	"a11y_worn": "%s, worn",
	"a11y_locked": "Locked, released at level %d",
	"a11y_locked_end": "Locked, released for finishing the game",
}
## The WARDROBE row on the main menu, under MapMan and clear of the title
## block on a 16:9 screen: room for the catalog's 12 letters of WARDROBE
## (GUARDA-ROUPA) beside its count, which takes this much at the far end
## (five figures); the NEW tag's far edge and top.
const ROW_POS := Vector2(436, 246)
const ROW_SIZE := Vector2(196, Blueprint.TAP_HEIGHT)
const COUNT_W := 52.0
const TAG_END := ROW_POS.x + ROW_SIZE.x + 8.0
const TAG_Y := ROW_POS.y - 10.0
## Sheet 001-D: a cell per look, six to a row from the parts list's edge.
const COLUMNS := 6
const CELL := Vector2(60, 52)
const PITCH := Vector2(64, 57)
const CELLS_Y := 72.0
const NOTE_Y := 54.0
const RETURN_Y := 306.0
## Where MapMan stands in a cell, and how small he is there.
const FIGURE_AT := Vector2(30, 40)
const FIGURE_SCALE := 0.36
## Over the hero: the worn look's name and its details, in a column this wide;
## two lines of details still clear the tallest look's hat.
const INFO_X := 436.0
const INFO_W := 204.0
const NAME_Y := 50.0
const DETAIL_Y := 72.0
## The WORN stamp's place (Blueprint.stamp: its text's top left).
const STAMP_AT := Vector2(446, 254)
## The release slips, along the bottom of the level clear and the end sheets.
const SLIP_Y := 288.0
const SLIP_H := 62.0
const END_SLIP_Y := 244.0
const END_SLIP_H := 50.0

# --- 001: the way in ---------------------------------------------------------------


## The WARDROBE row under MapMan on the main menu, with how many looks are
## released, and a NEW tag while one of them hasn't been seen. Reports
## "wardrobe".
static func main_menu_row(m: Menus) -> void:
	var count := _released_count()
	var total := Wardrobe.LOOKS.size()
	var pos := Vector2(m._mx(ROW_POS.x, ROW_SIZE.x), ROW_POS.y)
	var b := Blueprint.item(m._panel, m.tr(TEXT.title), pos, ROW_SIZE)
	b.alignment = m._align()
	b.accessibility_name = m.tr(TEXT.a11y_row) % [count, total]
	# The count is figures at the row's far end (inside its 12 px margin);
	# figures read left to right in every language (Blueprint.label).
	var x := 12.0 if m._rtl else ROW_SIZE.x - 12.0 - COUNT_W
	var figures: String = TEXT.count % [count, total]
	var l := Blueprint.label(b, figures, 16, Blueprint.INK, Vector2(x, 0), 500, COUNT_W)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if m._rtl else HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Blueprint.fit(l, Vector2(COUNT_W, ROW_SIZE.y))
	m._connect(b, "wardrobe")
	m._reveal(b)
	if Save.unseen() > 0:
		_tag(m, m.tr(TEXT.new))


## A small gold tag, a stamp the size of a note, askew on the row's corner.
static func _tag(m: Menus, text: String) -> void:
	var n := Node2D.new()
	n.rotation = Blueprint.STAMP_ROTATION
	m._panel.add_child(n)
	var l := Blueprint.label(n, text, 11, Blueprint.GOLD, Vector2.ZERO, 800)
	l.size = l.get_minimum_size()
	var box := l.size + Vector2(10, 4)
	Blueprint.line(n, Blueprint.box_points(Vector2(-5, -2), box), Blueprint.GOLD, 1.2)
	n.position = Vector2(m._mx(TAG_END - box.x, box.x) + 5.0, TAG_Y)
	m._reveal(n)


# --- 001-D: the wardrobe ------------------------------------------------------------


## Sheet 001-D: every look in the order it is released, six to a row, each
## framed in its tier's colour. A released look is a button that reports
## "wear <id>"; a locked one is drawn in hidden lines, with the level that
## releases it. MapMan stands on the right in the look he wears, under its
## name, with a WORN stamp. The focus starts on the worn look.
static func build(m: Menus) -> void:
	# Redrawn after a tap on another look: the stamp lands on the new one.
	var before := ""
	if m.current == "wardrobe" and m._hero != null:
		before = m._hero.outfit
	m._open("wardrobe", TEXT.number, m.tr(TEXT.title))
	var count := _released_count()
	var total := Wardrobe.LOOKS.size()
	var tally: String = m.tr_n(TEXT.released[0], TEXT.released[1], count) % [count, total]
	var note: String = m.tr(Menus.TEXT.note) % (tally + " · " + m.tr(TEXT.tap_to_wear))
	# One line: wrapped, it would run into the first row of cells.
	var line := m._text(m._panel, note, 10, Blueprint.FAINT, Menus.LIST_X, NOTE_Y, Menus.LIST_W)
	m._reveal(line)
	var worn := Wardrobe.look(Save.worn)
	if worn.is_empty():
		worn = Wardrobe.look("classic")
	_worn_info(m, worn)
	var worn_cell: Button = null
	for i in Wardrobe.LOOKS.size():
		var b := _cell(m, i)
		if Wardrobe.LOOKS[i].id == worn.id:
			worn_cell = b
	m._return_item(RETURN_Y)
	m._hero_on("tilt")
	_worn_stamp(m, before != "" and before != worn.id)
	if worn_cell != null and not worn_cell.disabled:
		m._first_button = worn_cell
	m._focus_first()


## The cell of the `i`th look: a button with him in it, or, while it is
## locked, his outline in hidden lines; when it is released, underneath.
static func _cell(m: Menus, i: int) -> Button:
	var look: Dictionary = Wardrobe.LOOKS[i]
	var id: String = look.id
	@warning_ignore("integer_division")
	var row := i / COLUMNS
	var at := Vector2(Menus.LIST_X + (i % COLUMNS) * PITCH.x, CELLS_Y + row * PITCH.y)
	var cell := Control.new()
	cell.position = Vector2(m._mx(at.x, CELL.x), at.y)
	cell.size = CELL
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m._panel.add_child(cell)
	var open := Save.is_released(id)
	var worn := open and id == Save.worn
	var colour: Color = Wardrobe.TIER_COLOURS[look.tier]
	if open:
		if worn:
			Blueprint.rect(cell, Blueprint.HOVER, Vector2.ONE, CELL - Vector2(2, 2))
		var width := 1.6 if worn else 0.9
		Blueprint.line(cell, Blueprint.box_points(Vector2.ZERO, CELL), colour, width)
		var p := _miniature(cell, id, FIGURE_AT, FIGURE_SCALE)
		p.look = Vector2(-0.15 if m._rtl else 0.15, 0.1)
		# New since the wardrobe was last opened (Classic never is).
		if id in Save.released and id not in Save.seen:
			var dot := Polygon2D.new()
			dot.polygon = Blueprint.ellipse_points(Vector2(_flip(m, 53, 0, CELL.x), 7), 3, 3, 12)
			dot.color = Blueprint.GOLD
			dot.antialiased = true
			cell.add_child(dot)
	else:
		var hidden := HiddenLines.new()
		hidden.frame_colour = Color(colour, colour.a * 0.5)
		cell.add_child(hidden)
	var ink := Blueprint.INK if open else Blueprint.FAINT
	var when := _when(m, look.level)
	var cap := Blueprint.label(
		cell, when, 9, ink, Vector2(2, 39), 600, CELL.x - 4.0, HORIZONTAL_ALIGNMENT_CENTER
	)
	cap.autowrap_mode = TextServer.AUTOWRAP_OFF
	var b := Button.new()
	b.theme = Blueprint.theme()
	cell.add_child(b)
	b.size = CELL
	b.disabled = not open
	if not open:
		b.focus_mode = Control.FOCUS_NONE
	b.accessibility_name = _a11y(m, look, open, worn)
	m._clear_button(b)
	m._connect(b, "wear " + id, open)
	m._reveal(cell, 0.03)
	return b


## When a look is released, as its cell says it: "LV 35", START or THE END.
static func _when(m: Menus, level: int) -> String:
	if level == 0:
		return m.tr(TEXT.start)
	if level == Wardrobe.THE_END:
		return m.tr(TEXT.the_end)
	return m.tr(TEXT.level) % level


## A cell for screen readers: "Cowboy, Uncommon" or "Cowboy, worn", or when
## a locked one is released (its name stays a secret).
static func _a11y(m: Menus, look: Dictionary, open: bool, worn: bool) -> String:
	if not open:
		if look.level == Wardrobe.THE_END:
			return m.tr(TEXT.a11y_locked_end)
		return m.tr(TEXT.a11y_locked) % look.level
	var name := m._sentence(m.tr(look.name))
	if worn:
		return m.tr(TEXT.a11y_worn) % name
	var tier := _tier(m, look)
	if tier == "":
		return name
	return Menus.TEXT.a11y_toggle % [name, m._sentence(tier)]


## A look's tier in the language on screen; "" for Classic, which has none.
static func _tier(m: Menus, look: Dictionary) -> String:
	var msgid: String = Wardrobe.TIERS[look.tier]
	return m.tr(msgid) if msgid != "" else ""


## The worn look's name over the hero, with its tier and when it came.
static func _worn_info(m: Menus, look: Dictionary) -> void:
	var name: String = m.tr(look.name)
	m._reveal(m._text(m._panel, name, 16, Blueprint.INK, INFO_X, NAME_Y, INFO_W, 800))
	var detail := _detail(m, look)
	m._reveal(m._text(m._panel, detail, 10, Blueprint.FAINT, INFO_X, DETAIL_Y, INFO_W))


## "UNCOMMON · RELEASED AT LEVEL 35", on two lines when that is too long for
## the column; Classic has been there from the start. Broken by hand, not
## wrapped, so the layout check sees a line that is still too long.
static func _detail(m: Menus, look: Dictionary) -> String:
	var level: int = look.level
	if level == 0:
		return m.tr(TEXT.from_the_start)
	var when: String = m.tr(TEXT.released_at) % level
	if level == Wardrobe.THE_END:
		when = m.tr(TEXT.for_finishing)
	var tier := _tier(m, look)
	if tier == "":
		return when
	var line := tier + " · " + when
	var font := Blueprint.mono(500)
	if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= INFO_W:
		return line
	return tier + "\n" + when


## WORN, stamped beside him: it slams down as the sheet opens, and again on a
## new look when he changes; he cheers as it lands.
static func _worn_stamp(m: Menus, changed: bool) -> void:
	var slam := Blueprint.motion() and (m._animate or changed)
	var delay := Menus.STAMP_DELAY if m._animate else 0.0
	var n := Blueprint.stamp(m._panel, m.tr(TEXT.worn), STAMP_AT, Blueprint.GOLD, slam, delay)
	# Mirrored by its own width, so a short stamp keeps clear of him.
	var w: float = (n.get_child(0) as Control).size.x + 20.0
	n.position.x = m._mx(STAMP_AT.x - 10.0, w) + 10.0
	if not slam:
		m._cheer()
		return
	var tw := m.create_tween()
	m._tweens.append(tw)
	tw.tween_callback(m._cheer).set_delay(delay + Menus.STAMP_FALL)


# --- the release slips ----------------------------------------------------------------


## A level cleared for the first time released look `id`: a gold slip along
## the bottom of its sheet shows him in it, cheering, with its name and tier.
static func release_slip(m: Menus, id: String) -> void:
	var look := Wardrobe.look(id)
	if look.is_empty():
		return
	var slip := _slip(m, SLIP_Y, SLIP_H)
	_miniature(slip, id, Vector2(_flip(m, 36, 0, slip.size.x), 56), 0.56).cheer()
	var name: String = m.tr(look.name)
	var tier := _tier(m, look)
	if tier != "":
		name += "  ·  " + tier
	_slip_text(m, slip, m.tr(TEXT.new_in_wardrobe), 10, Blueprint.GOLD, 78, 6, 800)
	_slip_text(m, slip, name, 15, Blueprint.INK, 78, 20, 800)
	_slip_text(m, slip, m.tr(TEXT.wear_it), 10, Blueprint.FAINT, 78, 42, 500)
	m._reveal(slip)


## Finishing the game released MapWoman: a slip on the last sheet says she
## can be played now.
static func mapwoman_slip(m: Menus) -> void:
	var slip := _slip(m, END_SLIP_Y, END_SLIP_H)
	_miniature(slip, "mapwoman", Vector2(_flip(m, 30, 0, slip.size.x), 46), 0.48).cheer()
	_slip_text(m, slip, m.tr(TEXT.mapwoman_joins), 13, Blueprint.GOLD, 64, 6, 800)
	_slip_text(m, slip, m.tr(TEXT.play_as_her), 10, Blueprint.FAINT, 64, 28, 500)
	m._reveal(slip)


## A gold slip as wide as the parts list, `height` tall from `y`.
static func _slip(m: Menus, y: float, height: float) -> Control:
	var size := Vector2(Menus.LIST_W, height)
	var slip := Control.new()
	slip.position = Vector2(m._mx(Menus.LIST_X, size.x), y)
	slip.size = size
	slip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m._panel.add_child(slip)
	Blueprint.rect(slip, Color(Blueprint.GOLD, 0.08), Vector2.ONE, size - Vector2(2, 2))
	Blueprint.line(slip, Blueprint.box_points(Vector2.ZERO, size), Blueprint.GOLD, 1.4)
	return slip


## A line of a slip from `x` to its far margin, on the reading side.
static func _slip_text(
	m: Menus, slip: Control, text: String, size: int, ink: Color, x: float, y: float, weight: int
) -> void:
	var w := slip.size.x - x - 8.0
	var pos := Vector2(_flip(m, x, w, slip.size.x), y)
	var l := Blueprint.label(slip, text, size, ink, pos, weight, w, m._align())
	l.autowrap_mode = TextServer.AUTOWRAP_OFF


# --- helpers ------------------------------------------------------------------------


## Looks in the wardrobe, Classic included.
static func _released_count() -> int:
	return Save.released.size() + 1


## The x of a piece `w` wide at `x` in a box `total` wide, mirrored on a
## right-to-left sheet (Menus._mx for the whole sheet).
static func _flip(m: Menus, x: float, w: float, total: float) -> float:
	return total - x - w if m._rtl else x


## A small MapMan in look `id`, his feet at `feet`, standing still: only the
## hero of a sheet moves. Shown at once, as the sheet fades in around him.
static func _miniature(parent: Node, id: String, feet: Vector2, s: float) -> Player:
	var p := Player.new()
	p.outfit = id
	p.auto_look = false
	p.position = feet
	p.scale = Vector2(s, s)
	parent.add_child(p)
	p.is_hidden = false
	p.visible = true
	return p


## A look still locked, in hidden lines (the dashes a drawing uses for parts
## out of sight): the cell's frame, and MapMan's outline with a question mark
## on his head where the look will be.
class HiddenLines:
	extends Node2D
	var size := CELL
	var frame_colour := Blueprint.FAINT
	var colour := Color(1, 1, 1, 0.55)
	## His feet, and his size, as the cells draw him.
	var feet := FIGURE_AT
	var figure_scale := FIGURE_SCALE

	func _draw() -> void:
		_dashes(Blueprint.box_points(Vector2.ZERO, size), frame_colour, 0.6, 3.0, 2.0)
		# The rest is in his own units (Player): the feet a little above the
		# point he stands on, the bell of a body, the round head.
		var s := figure_scale * Player.FIGURE_SCALE
		draw_set_transform(feet + Vector2(0, -Player.FEET_LIFT * figure_scale), 0.0, Vector2(s, s))
		var hem := OutfitPen.HEM - OutfitPen.RISE
		for side: float in [-1.0, 1.0]:
			var leg := PackedVector2Array(
				[Vector2(side * 7.5, hem - 1.0), Vector2(side * 7.5, 0.0)]
			)
			_dashes(leg, colour, 1.6, 4.0, 3.0)
		var bell := PackedVector2Array()
		var tall := OutfitPen.HEM - OutfitPen.BODY_TOP
		for i in 25:
			var a := PI * i / 24.0
			bell.append(Vector2(cos(a) * OutfitPen.BODY_HALF, -sin(a) * tall))
		for i in range(1, 25):
			var a := PI * i / 24.0
			bell.append(Vector2(-cos(a) * OutfitPen.BODY_HALF, sin(a) * OutfitPen.LIP))
		for i in bell.size():
			bell[i].y += hem
		_dashes(bell, colour, 1.6, 4.0, 3.0)
		var head := Vector2(0, -62 - OutfitPen.RISE)
		_dashes(Blueprint.ellipse_points(head, 15.0, 15.0, 24), colour, 1.6, 4.0, 3.0)
		var font := Blueprint.mono(800)
		draw_string(font, head + Vector2(-6.6, 7.6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, colour)
		draw_set_transform(Vector2.ZERO)

	## A polyline as dashes `dash` long with `gap` between, the pattern
	## running on round its corners.
	func _dashes(
		points: PackedVector2Array, ink: Color, width: float, dash: float, gap: float
	) -> void:
		var segments := PackedVector2Array()
		var on := true
		var left := dash
		for i in points.size() - 1:
			var a := points[i]
			var b := points[i + 1]
			var length := a.distance_to(b)
			var done := 0.0
			while done < length:
				var step := minf(left, length - done)
				if on:
					segments.append(a.lerp(b, done / length))
					segments.append(a.lerp(b, (done + step) / length))
				done += step
				left -= step
				if left <= 0.0:
					on = not on
					left = dash if on else gap
		if not segments.is_empty():
			draw_multiline(segments, ink, width, true)
