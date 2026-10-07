class_name RevisionB
extends RefCounted
## Revision B, the second game, for main.gd: the hundred sheets mirrored and
## reworked with the crumble, ice and spike tiles (data/levels_b.json, made
## by tools/remix.py), opened by finishing the first game. It is played with
## its own save track (Save.rev_b), no assists and the Redline look
## (Blueprint.revise()). Loads only with the game scene, so it may name Save.

const PATH := "res://data/levels_b.json"

var levels: Array = []
var check_points: Array = []

## main.gd (untyped: it has no class_name).
var _game


func _init(game) -> void:
	_game = game
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	levels = data["levels"]
	check_points = data["check_points"]


## PLAY REVISION B: its checkpoints sheet once it has saved one, else sheet 1.
func open() -> void:
	if not Save.rev_b_open():
		return
	if Save.track_b.checkpoints.is_empty():
		start(1)
		return
	Audio.play_menu()
	_game.menus.show_restart(Save.track_b.checkpoints.keys(), true)


## A Revision B game from sheet `level`.
func start(level := 1) -> void:
	if not Save.rev_b_open():
		return
	_game.menus.close()
	_game.custom = ""
	_game.new_game(clampi(level, 1, levels.size()), false, true)


## Menu actions of Revision B's: "revision b" (the main menu row) and
## "B<n>" (its checkpoints sheet). True if `act` was one.
func action(act: String) -> bool:
	if act == "revision b":
		open()
	elif act.begins_with("B") and act.substr(1).is_valid_int():
		start(int(act.substr(1)))
	else:
		return false
	return true
