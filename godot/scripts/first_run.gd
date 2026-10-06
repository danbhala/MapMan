class_name FirstRun
extends Button
## A player's very first launch: TAP TO START opens the tutorial by itself
## instead of the main menu, with SKIP » in the header's corner (the intro's
## corner note) back to the main menu. Anyone who has played before, or who
## opened the game with a level link, gets the main menu as always.
## Starting the tutorial clears `Save.first_play`, so this happens once,
## whether the lessons are finished, skipped or left halfway.

## The game (main.gd).
var _game: Node


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


## After TAP TO START: the tutorial if this is a first launch (true), else
## nothing, and the caller opens the main menu (false).
static func begin(game: Node) -> bool:
	if not applies():
		return false
	start(game)
	return true


## Opens the tutorial on its first lesson, with the skip in the corner.
static func start(game: Node) -> FirstRun:
	game.menus.close()
	game.new_game(1, true)
	var skip := FirstRun.new()
	skip._game = game
	game.hud.header.add_child(skip)
	return skip


func _ready() -> void:
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
	if not _game.tutorial or not _game.game_active:
		queue_free()
		return
	visible = not _game.menus.visible and not _game.dead
	var header: Control = get_parent()
	position = Vector2(header.size.x - 12 - size.x, (header.size.y - size.y) / 2.0)


func _skip() -> void:
	_game._on_menu_action("end tutorial")
	queue_free()
