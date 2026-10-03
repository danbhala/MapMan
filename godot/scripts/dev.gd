extends Node
## Developer support: build info, tilt tuning, cheats and the play log.
##
## Tuning values are read by every build (they're the game's real settings);
## changing them, the cheats and the play log's share button only exist in dev
## builds ("MapMan Dev" on the phone, or any run from the editor binary).

signal changed

const TUNING_PATH := "user://dev_tuning.cfg"
const PLAYLOG_PATH := "user://playlog.json"
const BUILD_INFO_PATH := "res://build_info.json"

## Defaults are the values the original game used.
const DEFAULT_TUNING := {
	"tilt_threshold": 0.1,  # tilt (in g) that starts a move
	"keep_threshold": 0.07,  # tilt that keeps moving the same way (new; not in the original)
	"fast_threshold": 0.2,  # tilt above which moves are twice as fast
	"shake_threshold": 0.4,  # user acceleration (in g) that frees a sticky tile
	"invert_x": false,
	"invert_y": false,
}

## Dev tools on/off. Tests switch this off so screenshots match release builds.
var enabled := OS.has_feature("dev") or OS.is_debug_build()
## Tests switch this off so they never write to the phone's real files.
var persist := true

var tuning := DEFAULT_TUNING.duplicate()
var unlimited_time := false
var unlimited_lives := false
var show_tilt := false

## {"version", "commit", "built", "source"}; "source" is "pr-12", "master" or "local".
var build_info := {"version": "", "commit": "", "built": "", "source": "local"}

## level number (String) -> {"attempts", "wins", "deaths", "timeouts",
## "best_time_left", "total_moves", "last_played"}
var playlog := {}


func _ready() -> void:
	_load_build_info()
	_load_tuning()
	_load_playlog()


func t(key: String):
	return tuning.get(key, DEFAULT_TUNING[key])


func build_label() -> String:
	var parts: Array[String] = []
	if build_info.version != "":
		parts.append("v" + build_info.version)
	if build_info.commit != "":
		parts.append(String(build_info.commit).left(7))
	parts.append(build_info.source)
	return " · ".join(parts)


# --- build info --------------------------------------------------------------


func _load_build_info() -> void:
	if not FileAccess.file_exists(BUILD_INFO_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(BUILD_INFO_PATH))
	if data is Dictionary:
		for key in build_info:
			if data.has(key):
				build_info[key] = str(data[key])


# --- tuning ------------------------------------------------------------------


func set_tuning(key: String, value) -> void:
	tuning[key] = value
	_save_tuning()
	changed.emit()


func reset_tuning() -> void:
	tuning = DEFAULT_TUNING.duplicate()
	_save_tuning()
	changed.emit()


## Plain text to paste into a chat or issue when a setting feels right.
func tuning_text() -> String:
	var lines: Array[String] = ["MapMan tilt tuning (%s)" % build_label()]
	for key in DEFAULT_TUNING:
		lines.append("%s = %s" % [key, str(tuning[key])])
	return "\n".join(lines)


func _load_tuning() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(TUNING_PATH) != OK:
		return
	for key in DEFAULT_TUNING:
		tuning[key] = cfg.get_value("tuning", key, DEFAULT_TUNING[key])


func _save_tuning() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	for key in tuning:
		cfg.set_value("tuning", key, tuning[key])
	cfg.save(TUNING_PATH)


# --- play log ----------------------------------------------------------------


## result: "win", "death" or "timeout". Tutorial levels aren't logged.
func record(level: int, result: String, time_left: float, moves: int) -> void:
	var key := str(level)
	var row: Dictionary = (
		playlog
		. get(
			key,
			{
				"attempts": 0,
				"wins": 0,
				"deaths": 0,
				"timeouts": 0,
				"best_time_left": -1.0,
				"total_moves": 0,
				"last_played": "",
			}
		)
	)
	row.attempts += 1
	row.total_moves += moves
	match result:
		"win":
			row.wins += 1
			row.best_time_left = maxf(row.best_time_left, snappedf(time_left, 0.1))
		"death":
			row.deaths += 1
		"timeout":
			row.timeouts += 1
	row.last_played = Time.get_datetime_string_from_system(true)
	playlog[key] = row
	_save_playlog()


func clear_playlog() -> void:
	playlog.clear()
	_save_playlog()


func playlog_summary() -> String:
	var attempts := 0
	var wins := 0
	for row in playlog.values():
		attempts += row.attempts
		wins += row.wins
	return "Levels played: %d · attempts: %d · cleared: %d" % [playlog.size(), attempts, wins]


## Compact JSON for pasting into an issue; godot/tools/playlog_report.py reads it.
func playlog_text() -> String:
	return JSON.stringify({"build": build_label(), "tuning": tuning, "levels": playlog})


func _load_playlog() -> void:
	if not FileAccess.file_exists(PLAYLOG_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PLAYLOG_PATH))
	if data is Dictionary:
		playlog = data


func _save_playlog() -> void:
	if not persist:
		return
	var f := FileAccess.open(PLAYLOG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(playlog))
