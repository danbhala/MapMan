class_name LanguageSheet
extends RefCounted
## Sheet 001-C, the languages: a box for each, flowing across the sheet,
## the chosen one filled. Static functions that build onto the Menus sheet
## they are given, as WardrobeSheet does. Loads only with the game scene, so
## it may name Save.

## Boxes that flow across the sheet (the language names): text size, the
## padding either side of it, the gap between boxes, and the row they fill.
const CHIP_SIZE := 15
const CHIP_PAD := 10.0
const CHIP_GAP := 8.0
const CHIP_ROW_W := Menus.SHEET.x - 2 * Menus.LIST_X


static func build(m: Menus) -> void:
	m._open("language", Menus.TEXT.language_number, m._t("language_title"))
	var choices: Array = [["system", m._t("phone_language")]]
	choices.append_array(Menus.LANGUAGES)
	var x := Menus.LIST_X
	var y := 72.0
	for choice in choices:
		var code: String = choice[0]
		var name: String = choice[1]
		var chosen := (Save.locale == "" and code == "system") or Save.locale == code
		var text: String = Menus.TEXT.on + " " + name if chosen else name
		var font := Blueprint.mono(700 if chosen else 400)
		var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE).x
		var w := ceilf(text_w) + 2.0 * CHIP_PAD
		if x + w > Menus.LIST_X + CHIP_ROW_W:
			x = Menus.LIST_X
			y += Blueprint.TAP_HEIGHT + CHIP_GAP
		_chip(m, Vector2(x, y), w, text, "language " + code, name, chosen)
		x += w + CHIP_GAP
	var back_pos := Vector2(m._mx(Menus.LIST_X, Menus.LIST_W), 318)
	var back := Blueprint.item(m._panel, "<  " + m._t("options_title"), back_pos)
	back.alignment = m._align()
	back.accessibility_name = m._sentence(m._t("options_title"))
	m._connect(back, "options")
	m._reveal(back)
	m._focus_first()


## A box in a flowing row of choices, `w` wide, its text centred; the chosen
## one is filled and bold. The whole box is a button.
static func _chip(
	m: Menus, pos: Vector2, w: float, text: String, act: String, a11y: String, chosen: bool
) -> Button:
	var size := Vector2(w, Blueprint.TAP_HEIGHT)
	var box := Control.new()
	box.position = Vector2(m._mx(pos.x, w), pos.y)
	box.size = size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m._panel.add_child(box)
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
	m._clear_button(b)
	box.add_child(b)
	m._connect(b, act)
	m._reveal(box, 0.03)
	return b
