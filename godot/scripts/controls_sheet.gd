class_name ControlsSheet
extends RefCounted
## Sheet 001-E, opened from the CONTROLS row of the options: steer by tilting
## the phone or with the floating touch stick (TouchStick), how little tilt
## moves MapMan (TiltInput.SENSITIVITY) and the tilt gauge. Static functions
## that build onto the Menus sheet they are given, like WardrobeSheet; this
## only loads with the game scene, so it may name the Save autoload.

## Every word the sheet adds: English msgids (i18n/).
const TEXT := {
	"number": "001-E",
	"title": "CONTROLS",
	"modes": ["TILT", "TOUCH"],
	"items": ["TILT TO MOVE", "DRAG TO MOVE"],
	"sensitivity": "TILT SENSITIVITY",
	"levels": ["LOW", "NORMAL", "HIGH"],
	"gauge": "TILT GAUGE",
	"tilt_only": "TILT ONLY",
}
const MODES: Array[String] = ["tilt", "touch"]


## The way MapMan is steered now, for the options' CONTROLS row.
static func mode_name() -> String:
	return TranslationServer.translate(TEXT.modes[1 if Save.controls == "touch" else 0])


## Saves the choice a row reported: "controls tilt|touch", "sensitivity <n>"
## or "tilt gauge on|off".
static func choose(act: String) -> void:
	if act.begins_with("controls "):
		Save.controls = act.get_slice(" ", 1)
	elif act.begins_with("sensitivity "):
		Save.tilt_sensitivity = clampi(int(act.get_slice(" ", 1)), 0, TEXT.levels.size() - 1)
	else:
		Save.tilt_gauge = act == "tilt gauge on"
	Save.save_all()


## Rows report "controls tilt", "controls touch", "sensitivity <0-2>" (the
## next level round from the current one) and "tilt gauge on/off"; with
## touch chosen, the two tilt rows are greyed out and report nothing.
static func build(m: Menus) -> void:
	m._open("controls", TEXT.number, m.tr(TEXT.title))
	m._columns(
		[m._t("col_parameter"), m._t("col_value")], [Menus.TEXT_X, Menus.TEXT_X + 20 * Menus.CHAR_W]
	)
	var y := Menus.OPTIONS_TOP
	for i in MODES.size():
		_toggle(m, m.tr(TEXT.items[i]), Save.controls == MODES[i], "controls " + MODES[i], y)
		y += Menus.OPTIONS_PITCH
	# Steering by touch, the tilt rows stay in place, greyed out.
	var tilt := Save.controls != "touch"
	var level := clampi(Save.tilt_sensitivity, 0, TEXT.levels.size() - 1)
	var value: String = m.tr(TEXT.levels[level]) if tilt else m.tr(TEXT.tilt_only)
	var sens := m._value_row(m.tr(TEXT.sensitivity), value, y, tilt)
	sens.accessibility_name = Menus.TEXT.a11y_toggle % [m._sentence(m.tr(TEXT.sensitivity)), value]
	if tilt:
		m._connect(sens, "sensitivity %d" % ((level + 1) % TEXT.levels.size()))
	y += Menus.OPTIONS_PITCH
	if tilt:
		var gauge_act := "tilt gauge " + ("off" if Save.tilt_gauge else "on")
		_toggle(m, m.tr(TEXT.gauge), Save.tilt_gauge, gauge_act, y)
	else:
		var gauge := m._value_row(m.tr(TEXT.gauge), m.tr(TEXT.tilt_only), y, false)
		gauge.accessibility_name = (
			Menus.TEXT.a11y_toggle % [m._sentence(m.tr(TEXT.gauge)), m.tr(TEXT.tilt_only)]
		)
	y += Menus.OPTIONS_PITCH
	var pos := Vector2(m._mx(Menus.LIST_X, Menus.LIST_W), y)
	var back := Blueprint.item(
		m._panel, "<  " + m._t("options_title"), pos, Vector2(Menus.LIST_W, Menus.OPTIONS_PITCH)
	)
	back.alignment = m._align()
	back.accessibility_name = m._sentence(m._t("options_title"))
	m._connect(back, "options")
	m._reveal(back)
	m._hero_on("tilt")
	m._focus_first()


## A row with a box: [X] when `on`.
static func _toggle(m: Menus, name: String, on: bool, act: String, y: float) -> void:
	var b := m._value_row(name, Menus.TEXT.on if on else Menus.TEXT.off, y)
	var state: String = m._t("a11y_on") if on else m._t("a11y_off")
	b.accessibility_name = Menus.TEXT.a11y_toggle % [m._sentence(name), state]
	m._connect(b, act)
