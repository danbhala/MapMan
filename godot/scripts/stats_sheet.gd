class_name StatsSheet
extends RefCounted
## The play stats question (sheet 001-J, asked once over the main menu, the
## Stats autoload says when) and the PRIVACY sheet (001-I, from the Options):
## play stats on or off, and the privacy policy. Static functions that build
## onto the Menus sheet they are given, like ControlsSheet; this only loads
## with the game scene, so it may name the autoloads. docs/stats.md.

## The privacy policy on the game's page (site/privacy.html).
const POLICY_URL := "https://danbhala.github.io/MapMan/privacy.html"

## Every word the sheets add: English msgids (i18n/).
const TEXT := {
	"ask_number": "001-J",
	"ask_title": "PLAY STATS",
	"ask_intro": "HELP MAKE MAPMAN BETTER WITH ANONYMOUS PLAY STATS?",
	"ask_what": "WHICH LEVELS ARE STARTED, CLEARED OR LOST, AND WHERE",
	"ask_never": "NO NAME, NO ACCOUNT, NO ADVERTISING ID",
	"ask_change": "CHANGE IT ANY TIME: %s > %s",
	"ask_items": ["YES, SEND PLAY STATS", "NO THANKS"],
	"policy": "PRIVACY POLICY",
	"number": "001-I",
	"title": "PRIVACY",
	"share": "SHARE PLAY STATS",
	"open": "OPEN",
	"id_note": "STATS ID %s: QUOTE IT TO HAVE ITS STATS DELETED",
	"off_note": "NOTHING IS SENT. TURNING STATS ON STARTS A NEW RANDOM ID",
}


## Handles the sheets' actions: "privacy", "stats yes|no" (the question),
## "stats on|off" (the PRIVACY row) and "privacy policy"; false for any other.
static func handle(act: String, m: Menus) -> bool:
	match act:
		"privacy":
			build(m)
		"stats on", "stats off":
			Stats.choose(act == "stats on")
			build(m)
		"stats yes", "stats no":
			Stats.choose(act == "stats yes")
			m.action.emit("main menu")
		"privacy policy":
			OS.shell_open(POLICY_URL)
		_:
			return false
	return true


## 001-J: the question, yes and no alike, then the policy.
static func build_question(m: Menus) -> void:
	m._open("stats_question", TEXT.ask_number, m.tr(TEXT.ask_title))
	m._note(m.tr(TEXT.ask_intro), Menus.LIST_TOP, Blueprint.INK, 11)
	m._note(m.tr(TEXT.ask_what), 84)
	m._note(m.tr(TEXT.ask_never), 100)
	m._note(m.tr(TEXT.ask_change) % [m._t("options_title"), m.tr(TEXT.title)], 116)
	var texts: Array[String] = []
	for t in TEXT.ask_items:
		texts.append(m.tr(t))
	m._items(texts, ["stats yes", "stats no"], 142)
	_row(m, "  " + m.tr(TEXT.policy) + "  >", "privacy policy", 238)
	m._hero_on("tilt")
	m._focus_first()


## 001-I: SHARE PLAY STATS, the policy, and the way back to the Options.
static func build(m: Menus) -> void:
	m._open("privacy", TEXT.number, m.tr(TEXT.title))
	m._columns(
		[m._t("col_parameter"), m._t("col_value")], [Menus.TEXT_X, Menus.TEXT_X + 20 * Menus.CHAR_W]
	)
	var y := Menus.OPTIONS_TOP
	var on := Stats.on()
	var share := m.tr(TEXT.share)
	var b := m._value_row(share, Menus.TEXT.on if on else Menus.TEXT.off, y, Stats.available())
	var state: String = m._t("a11y_on") if on else m._t("a11y_off")
	b.accessibility_name = Menus.TEXT.a11y_toggle % [m._sentence(share), state]
	m._connect(b, "stats " + ("off" if on else "on"), Stats.available())
	y += Menus.OPTIONS_PITCH
	var policy := m._value_row(m.tr(TEXT.policy), m.tr(TEXT.open), y)
	policy.accessibility_name = m._sentence(m.tr(TEXT.policy))
	m._connect(policy, "privacy policy")
	y += Menus.OPTIONS_PITCH
	_row(m, "<  " + m._t("options_title"), "options", y)
	if Stats.available():
		var note: String = (
			m.tr(TEXT.id_note) % Stats.install_id.left(8).to_upper() if on else m.tr(TEXT.off_note)
		)
		m._note(note, y + Menus.OPTIONS_PITCH + 12)
	m._hero_on("tilt")
	m._focus_first()


## PRIVACY in the Options' corner, opening 001-I.
static func privacy_button(m: Menus) -> void:
	var at := ClearSheet.REPLAY_POS
	var pos := Vector2(m._mx(at.x, ClearSheet.REPLAY_W), at.y)
	var size := Vector2(ClearSheet.REPLAY_W, Blueprint.TAP_HEIGHT)
	var b := Blueprint.item(m._panel, m.tr(TEXT.title), pos, size)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.accessibility_name = m._sentence(m.tr(TEXT.title))
	m._connect(b, "privacy")
	m._reveal(b)


## A full-width row with no number that reports `act`.
static func _row(m: Menus, text: String, act: String, y: float) -> void:
	var pos := Vector2(m._mx(Menus.LIST_X, Menus.LIST_W), y)
	var b := Blueprint.item(m._panel, text, pos, Vector2(Menus.LIST_W, Menus.OPTIONS_PITCH))
	b.alignment = m._align()
	b.accessibility_name = m._sentence(text.strip_edges().trim_prefix("<").strip_edges())
	m._connect(b, act)
	m._reveal(b)
