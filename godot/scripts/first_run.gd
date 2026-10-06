class_name FirstRun
extends Button
## A player's very first launch: TAP TO START asks how they want to steer
## (tilt or the touch stick, ControlsSheet's two modes) and then opens the
## tutorial by itself instead of the main menu, with SKIP » in the header's
## corner (the intro's corner note) back to the main menu. After the second
## lesson, or sooner if one lesson costs three tries, it asks once whether
## the steering suits them, offering the other way. Anyone who has played
## before, or who opened the game with a level link, gets the main menu as
## always. Starting the tutorial clears `Save.first_play`, so this happens
## once, whether the lessons are finished, skipped or left halfway.

## Every word the two sheets add: English msgids (i18n/).
const TEXT := {
	"number": "000",
	"choose": "HOW DO YOU WANT TO STEER? YOU CAN CHANGE IT IN OPTIONS",
	"check": "HOW IS THE STEERING GOING?",
	"keep": "KEEP %s",
	"try": "TRY %s",
}
## The check-in comes after this many lessons...
const CHECK_AFTER_LESSONS := 2
## ...or after this many tries lost on one lesson.
const CHECK_AFTER_TRIES := 3

## The game (main.gd).
var _game: Node
var _checked := false
var _lesson := 0
var _lost := 0
var _was_dead := false


## Nothing played yet: no game or tutorial started, no level reached in
## practice, nothing finished, and no level link waiting to be played.
## `link` stands in for the launch link in tests.
static func applies(link := "") -> bool:
	if link == "":
		link = DraftingTable.launch_link()
	return (
		Save.first_play
		and not Save.has_completed
		and Save.checkpoints.is_empty()
		and Save.bests.is_empty()
		and Save.furthest_level <= 1
		and LevelCode.find(link) == ""
	)


## After TAP TO START: the first run on a first launch, else the main menu
## (and a level code found on the clipboard).
static func after_title(game: Node) -> void:
	if applies():
		start(game)
	else:
		game.show_start_menu()
		game.drafting.check_clipboard()


## Asks how to steer, then opens the tutorial. A phone that can't be tilted
## (`ask` false) has nothing to choose: straight into the first lesson.
static func start(game: Node, ask := TiltInput.has_accelerometer()) -> FirstRun:
	var run := FirstRun.new()
	run._game = game
	game.hud.header.add_child(run)
	game.menus.action.connect(run._on_action)
	if ask:
		run._show_choice()
	else:
		run._checked = true  # one way to steer, nothing to check
		run._begin_tutorial()
	return run


func _ready() -> void:
	visible = false
	flat = true
	focus_mode = Control.FOCUS_NONE
	text = tr(Intro.TEXT.skip) + "  »"
	accessibility_name = tr(Intro.TEXT.skip)
	add_theme_font_override("font", Blueprint.mono(800))
	add_theme_font_size_override("font_size", 12)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		add_theme_color_override(state, Blueprint.INK)
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	size = get_combined_minimum_size()
	pressed.connect(_skip)
	if Blueprint.motion():
		var tw := create_tween().set_loops()
		tw.tween_property(self, "modulate:a", 0.35, 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(self, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)


## Gone once the tutorial is over (it runs on into level 1, or was ended
## from the pause); hidden under the pause and while a lost life plays.
func _process(_delta: float) -> void:
	if _game.menus.current == "steer":
		return  # the tutorial hasn't started yet
	if not _game.tutorial or not _game.game_active:
		queue_free()
		return
	visible = not _game.menus.visible and not _game.dead
	var header: Control = get_parent()
	position = Vector2(header.size.x - 12 - size.x, (header.size.y - size.y) / 2.0)
	_watch_lessons()


## Counts lessons cleared and tries lost on this one, for the check-in.
func _watch_lessons() -> void:
	if _game.level != _lesson:
		_lesson = _game.level
		_lost = 0
	var dead: bool = _game.dead
	if dead and not _was_dead:
		_lost += 1
	_was_dead = dead
	if _checked or dead or _game.menus.visible:
		return
	if _lesson > CHECK_AFTER_LESSONS or _lost >= CHECK_AFTER_TRIES:
		_show_check()


func _show_choice() -> void:
	var m: Menus = _game.menus
	m._open("steer", TEXT.number, tr(ControlsSheet.TEXT.title))
	m._note(tr(TEXT.choose), Menus.LIST_TOP, Blueprint.FAINT, 11)
	var names: Array[String] = []
	for item in ControlsSheet.TEXT.items:
		names.append(tr(item))
	m._items(names, ["first run tilt", "first run touch"], 84)
	m._hero_on("tilt")
	m._focus_first()


## Once: keep this way of steering, or try the other.
func _show_check() -> void:
	_checked = true
	var m: Menus = _game.menus
	var touch := Save.controls == "touch"
	var now := tr(ControlsSheet.TEXT.items[1 if touch else 0])
	var other := tr(ControlsSheet.TEXT.items[0 if touch else 1])
	m._open("steer_check", TEXT.number, tr(ControlsSheet.TEXT.title))
	m._note(tr(TEXT.check), Menus.LIST_TOP, Blueprint.FAINT, 11)
	m._items([tr(TEXT.keep) % now, tr(TEXT.try) % other], ["first run keep", "first run swap"], 84)
	m._hero_on("tilt")
	m._focus_first()


func _on_action(act: String) -> void:
	match act:
		"first run tilt", "first run touch":
			_steer(act.get_slice(" ", 2))
			_begin_tutorial()
		"first run keep":
			_game._on_menu_action("unpause")
		"first run swap":
			_steer("tilt" if Save.controls == "touch" else "touch")
			_game._on_menu_action("unpause")


func _steer(mode: String) -> void:
	ControlsSheet.choose("controls " + mode)
	_game.steering.apply()


func _begin_tutorial() -> void:
	_game.menus.close()
	_game.new_game(1, true)


func _skip() -> void:
	_game._on_menu_action("end tutorial")
	queue_free()


func _exit_tree() -> void:
	if _game.menus.action.is_connected(_on_action):
		_game.menus.action.disconnect(_on_action)
