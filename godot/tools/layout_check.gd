## The text layout rules every screen must meet, whatever the language: each
## piece of text fits the box it was given, stays inside the sheet's frame,
## and crosses no other text. Shared by tests/unit/test_i18n.gd (every sheet
## in every language, in CI) and tools/i18n_shots.gd (the same, with
## pictures, on a local machine).
##
## A Label or Button grows to hold its text, so its own rect says little:
## the box a piece was given is kept in its "fit" metadata (Blueprint.fit),
## and the box the text takes on screen is measured here (text_box).
extends RefCounted


## Every visible label and button with text under `from`.
static func texts(from: Node) -> Array[Control]:
	var found: Array[Control] = []
	for c in from.find_children("*", "Control", true, false):
		if (c is Label or c is Button) and c.text != "" and c.is_visible_in_tree():
			found.append(c)
	return found


## The box the text itself takes on screen, from the control's font,
## alignment and style margins.
static func text_box(c: Control) -> Rect2:
	var font: Font = c.get_theme_font("font")
	var font_size := c.get_theme_font_size("font_size")
	var style: StyleBox = c.get_theme_stylebox("normal")
	var inner := c.get_global_rect()
	inner.position += Vector2(style.get_margin(SIDE_LEFT), style.get_margin(SIDE_TOP))
	inner.size -= style.get_minimum_size()
	var wrap: bool = c is Label and c.autowrap_mode != TextServer.AUTOWRAP_OFF
	var h_align: HorizontalAlignment = c.horizontal_alignment if c is Label else c.alignment
	var flags := TextServer.BREAK_MANDATORY
	if wrap:
		flags |= (
			TextServer.BREAK_WORD_BOUND
			| TextServer.BREAK_ADAPTIVE
			| TextServer.BREAK_TRIM_EDGE_SPACES
		)
	var size := font.get_multiline_string_size(
		c.text, h_align, inner.size.x if wrap else -1.0, font_size, -1, flags
	)
	var v_align := VERTICAL_ALIGNMENT_CENTER
	if c is Label:
		v_align = c.vertical_alignment
		var lines: int = mini(c.get_line_count(), c.get_visible_line_count())
		var spacing: int = c.get_theme_constant("line_spacing")
		size.y = lines * c.get_line_height() + maxi(lines - 1, 0) * spacing
	var pos := inner.position
	match h_align:
		HORIZONTAL_ALIGNMENT_RIGHT:
			pos.x = inner.end.x - size.x
		HORIZONTAL_ALIGNMENT_CENTER:
			pos.x = inner.position.x + (inner.size.x - size.x) / 2.0
	match v_align:
		VERTICAL_ALIGNMENT_BOTTOM:
			pos.y = inner.end.y - size.y
		VERTICAL_ALIGNMENT_CENTER:
			pos.y = inner.position.y + (inner.size.y - size.y) / 2.0
	return Rect2(pos, size)


static func _quote(c: Control) -> String:
	return "'%s'" % c.text.replace("\n", " / ")


## What is wrong with the text under `roots`, one line each; empty when the
## screen lays out cleanly. `bounds` is the area text may use.
static func problems(roots: Array, bounds: Rect2) -> PackedStringArray:
	var out: PackedStringArray = []
	var found: Array[Control] = []
	for r in roots:
		found.append_array(texts(r))
	var boxes: Array[Rect2] = []
	for c in found:
		var box := text_box(c)
		boxes.append(box)
		if c.has_meta("fit"):
			var fit: Vector2 = c.get_meta("fit")
			if c is Label and c.autowrap_mode != TextServer.AUTOWRAP_OFF:
				if c.get_line_count() > c.get_visible_line_count():
					out.append(
						(
							"%s is cut: %d lines, %d fit"
							% [_quote(c), c.get_line_count(), c.get_visible_line_count()]
						)
					)
			else:
				var need: float = c.get_minimum_size().x
				if need > fit.x + 0.5:
					out.append("%s needs %dpx of %d" % [_quote(c), need, fit.x])
		if not bounds.encloses(box):
			out.append("%s runs off the sheet" % _quote(c))
	for i in found.size():
		for j in range(i + 1, found.size()):
			if _ink(found[i], boxes[i]).intersects(_ink(found[j], boxes[j])):
				out.append("%s crosses %s" % [_quote(found[i]), _quote(found[j])])
	return out


## Where the letters themselves can be: a line box has room above capitals
## and below the baseline that most text leaves empty, so two lines may sit
## that close without touching.
static func _ink(c: Control, box: Rect2) -> Rect2:
	var slack := 0.15 * c.get_theme_font_size("font_size")
	return box.grow_individual(-1.0, -slack, -1.0, -slack)
