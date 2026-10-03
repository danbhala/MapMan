extends Node
## Persistent player data: options, best score, completed checkpoints.
## Replaces the dot-files the Pythonista version wrote next to the script.

const PATH := "user://mapman.cfg"

var music_on := true
var fx_on := true
## "sitting" or "standing": how far the phone is tilted back when neutral.
var playing_position := "sitting"
var highscore := 0
var first_play := true
var has_completed := false
## level number -> best score when that checkpoint was reached
var checkpoints := {}
## Tests turn this off so they never overwrite the player's real progress.
var persist := true

var _cfg := ConfigFile.new()


func _ready() -> void:
	load_all()


func load_all() -> void:
	if _cfg.load(PATH) != OK:
		return
	music_on = _cfg.get_value("options", "music", true)
	fx_on = _cfg.get_value("options", "fx", true)
	playing_position = _cfg.get_value("options", "playing_position", "sitting")
	if playing_position not in ["sitting", "standing"]:
		playing_position = "sitting"
	highscore = _cfg.get_value("progress", "highscore", 0)
	first_play = _cfg.get_value("progress", "first_play", true)
	has_completed = _cfg.get_value("progress", "has_completed", false)
	var cps: Dictionary = _cfg.get_value("progress", "checkpoints", {})
	checkpoints.clear()
	for key in cps:
		checkpoints[int(key)] = int(cps[key])


func save_all() -> void:
	if not persist:
		return
	_cfg.set_value("options", "music", music_on)
	_cfg.set_value("options", "fx", fx_on)
	_cfg.set_value("options", "playing_position", playing_position)
	_cfg.set_value("progress", "highscore", highscore)
	_cfg.set_value("progress", "first_play", first_play)
	_cfg.set_value("progress", "has_completed", has_completed)
	_cfg.set_value("progress", "checkpoints", checkpoints)
	_cfg.save(PATH)


func checkpoint_reached(level: int, score: int) -> void:
	if not checkpoints.has(level) or score > checkpoints[level]:
		checkpoints[level] = score
	save_all()


func has_any_checkpoint() -> bool:
	return not checkpoints.is_empty()


## Returns true when this is a new personal best.
func submit_score(score: int) -> bool:
	if score > highscore:
		highscore = score
		save_all()
		return true
	return false
