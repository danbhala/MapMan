extends Node
## Persistent player data: options, best score, completed checkpoints, the
## wardrobe. Replaces the dot-files the Pythonista version wrote next to the
## script.

## The language on screen changed (use_locale).
signal locale_changed

const PATH := "user://mapman.cfg"

var music_on := true
var fx_on := true
var vibration_on := true
## Skip the decorative animation (stamps, sheets drawing on, tiles folding).
var reduce_motion := false
## The tilt gauge in the corner of the field (TiltDial).
var tilt_gauge := true
## How MapMan is steered: "tilt" (the phone) or "touch" (the floating stick).
var controls := "tilt"
## How little tilt moves MapMan: 0 low, 1 normal, 2 high (TiltInput.SENSITIVITY).
var tilt_sensitivity := 1
## Show the level's best run as a ghost beside MapMan.
var ghost_on := true
## Locale code of the chosen language, or "" to follow the phone's.
var locale := ""
## "sitting" or "standing": how far the phone is tilted back when neutral.
var playing_position := "sitting"
var highscore := 0
var first_play := true
var has_completed := false
## Finishing the game added lessons to the tutorial it hasn't shown yet:
## the main menu says NEW on TUTORIAL until then.
var new_lessons := false
## level number -> best score when that checkpoint was reached
var checkpoints := {}
## The furthest level reached in the main game; practice unlocks up to it.
var furthest_level := 1
## level number -> {"time": best seconds left, "stars": most stars}
var bests := {}
## level number -> the best run there (RunRecord.encode()): the most time left.
var ghosts := {}
## The look MapMan wears (a Wardrobe id), and the looks released so far, in
## the order they came. Classic is always there and never listed.
var worn := "classic"
var released: Array[String] = []
## Released looks the wardrobe has shown: the main menu says NEW until then.
var seen: Array[String] = []
## The drafting table (DraftingSheet): each draft slot as Draft.to_save()
## made it ({} while empty), the codes of levels friends sent, newest first,
## and the last code found on the clipboard, so it is offered only once.
var drafts: Array = []
var received: Array[String] = []
var clipboard_seen := ""
## The names players gave received levels, by code (LevelCode.clean()); a
## draft keeps its own. Names stay on this phone: codes never carry them.
var received_names := {}
## Each drafting table level's record, by code (LevelCode.clean()): "played"
## tries, "cleared" wins, "best" most seconds left (-1 before a win) and
## "ghost", its best run (RunRecord.encode()). A changed draft is a new code,
## so its record starts afresh.
var level_stats := {}
## Tests turn this off so they never overwrite the player's real progress.
var persist := true

var _cfg := ConfigFile.new()


func _ready() -> void:
	load_all()
	apply_locale()


## Use the chosen language, or the phone's when none is chosen.
func apply_locale() -> void:
	use_locale(locale if locale != "" else OS.get_locale())


## Show the game in `code` without changing the choice: apply_locale() picks
## the code, tests pass one to stand in for the phone's.
func use_locale(code: String) -> void:
	TranslationServer.set_locale(code)
	Blueprint.prefer_script(shown_locale())
	locale_changed.emit()


## The language on screen: that of the translation closest to the locale in
## force, or English when there is none for it.
func shown_locale() -> String:
	var t := TranslationServer.get_translation_object(TranslationServer.get_locale())
	return t.locale if t != null else "en"


## Whether the language on screen reads right to left: Arabic does, English
## shown on a Hebrew phone does not.
func reads_rtl() -> bool:
	var ts := TextServerManager.get_primary_interface()
	return ts.is_locale_right_to_left(shown_locale())


## Switch language for good: "" follows the phone again.
func set_locale(code: String) -> void:
	locale = code
	apply_locale()
	save_all()


## path: tests load an old save from elsewhere; the game uses PATH.
func load_all(path := PATH) -> void:
	# A fresh file each time: ConfigFile.load() keeps keys from a file loaded
	# before, which a second load (tests load old saves) would inherit.
	_cfg = ConfigFile.new()
	if _cfg.load(path) != OK:
		return
	music_on = _cfg.get_value("options", "music", true)
	fx_on = _cfg.get_value("options", "fx", true)
	vibration_on = _cfg.get_value("options", "vibration", true)
	reduce_motion = _cfg.get_value("options", "reduce_motion", false)
	tilt_gauge = _cfg.get_value("options", "tilt_gauge", true)
	controls = _cfg.get_value("options", "controls", "tilt")
	if controls not in ["tilt", "touch"]:
		controls = "tilt"
	tilt_sensitivity = clampi(_cfg.get_value("options", "tilt_sensitivity", 1), 0, 2)
	ghost_on = _cfg.get_value("options", "ghost", true)
	locale = _cfg.get_value("options", "locale", "")
	# A language this build no longer ships falls back to the phone's.
	if locale != "" and locale != "en" and locale not in TranslationServer.get_loaded_locales():
		locale = ""
	playing_position = _cfg.get_value("options", "playing_position", "sitting")
	if playing_position not in ["sitting", "standing"]:
		playing_position = "sitting"
	highscore = _cfg.get_value("progress", "highscore", 0)
	first_play = _cfg.get_value("progress", "first_play", true)
	has_completed = _cfg.get_value("progress", "has_completed", false)
	new_lessons = _cfg.get_value("progress", "new_lessons", false)
	var cps: Dictionary = _cfg.get_value("progress", "checkpoints", {})
	checkpoints.clear()
	for key in cps:
		checkpoints[int(key)] = int(cps[key])
	# Saves from before practice mode have no furthest level: count what they
	# had reached (a checkpoint restarts on the level after it).
	var seeded := 1
	for level in checkpoints:
		seeded = maxi(seeded, level + 1)
	if has_completed:
		seeded = 100
	furthest_level = _cfg.get_value("progress", "furthest_level", seeded)
	var saved_bests: Dictionary = _cfg.get_value("progress", "bests", {})
	bests.clear()
	for key in saved_bests:
		var b: Dictionary = saved_bests[key]
		bests[int(key)] = {"time": int(b.get("time", 0)), "stars": int(b.get("stars", 0))}
	var saved_ghosts: Dictionary = _cfg.get_value("progress", "ghosts", {})
	ghosts.clear()
	for key in saved_ghosts:
		if saved_ghosts[key] is String:
			ghosts[int(key)] = saved_ghosts[key]
	released = _looks(_cfg.get_value("wardrobe", "released", []))
	seen = _looks(_cfg.get_value("wardrobe", "seen", []))
	drafts = []
	var saved_drafts: Variant = _cfg.get_value("drafting", "drafts", [])
	if saved_drafts is Array:
		drafts = saved_drafts.slice(0, Draft.SLOTS)
	received.clear()
	for code in _cfg.get_value("drafting", "received", []):
		if code is String and LevelCode.decode(code).has("rows"):
			received.append(code)
	clipboard_seen = str(_cfg.get_value("drafting", "clipboard_seen", ""))
	received_names.clear()
	var saved_names: Variant = _cfg.get_value("drafting", "names", {})
	if saved_names is Dictionary:
		for code in saved_names:
			if code is String and saved_names[code] is String:
				received_names[code] = saved_names[code]
	level_stats.clear()
	var saved_stats: Variant = _cfg.get_value("drafting", "stats", {})
	if saved_stats is Dictionary:
		for code in saved_stats:
			if code is String and saved_stats[code] is Dictionary:
				level_stats[code] = _stat_of(saved_stats[code])
	# Saves from before the wardrobe have the progress but not the looks.
	sync_wardrobe()
	var saved_worn: Variant = _cfg.get_value("wardrobe", "worn", "classic")
	worn = saved_worn if saved_worn is String and is_released(saved_worn) else "classic"


## path: tests write to a file of their own; the game uses PATH.
func save_all(path := PATH) -> void:
	if not persist:
		return
	_cfg.set_value("options", "music", music_on)
	_cfg.set_value("options", "fx", fx_on)
	_cfg.set_value("options", "vibration", vibration_on)
	_cfg.set_value("options", "reduce_motion", reduce_motion)
	_cfg.set_value("options", "tilt_gauge", tilt_gauge)
	_cfg.set_value("options", "controls", controls)
	_cfg.set_value("options", "tilt_sensitivity", tilt_sensitivity)
	_cfg.set_value("options", "ghost", ghost_on)
	_cfg.set_value("options", "locale", locale)
	_cfg.set_value("options", "playing_position", playing_position)
	_cfg.set_value("progress", "highscore", highscore)
	_cfg.set_value("progress", "first_play", first_play)
	_cfg.set_value("progress", "has_completed", has_completed)
	_cfg.set_value("progress", "new_lessons", new_lessons)
	_cfg.set_value("progress", "checkpoints", checkpoints)
	_cfg.set_value("progress", "furthest_level", furthest_level)
	_cfg.set_value("progress", "bests", bests)
	_cfg.set_value("progress", "ghosts", ghosts)
	_cfg.set_value("wardrobe", "worn", worn)
	_cfg.set_value("wardrobe", "released", released)
	_cfg.set_value("wardrobe", "seen", seen)
	_cfg.set_value("drafting", "drafts", drafts)
	_cfg.set_value("drafting", "received", received)
	_cfg.set_value("drafting", "clipboard_seen", clipboard_seen)
	_cfg.set_value("drafting", "names", received_names)
	_cfg.set_value("drafting", "stats", level_stats)
	_cfg.save(path)


func checkpoint_reached(level: int, score: int) -> void:
	if not checkpoints.has(level) or score > checkpoints[level]:
		checkpoints[level] = score
	save_all()


func level_reached(level: int) -> void:
	if level > furthest_level:
		furthest_level = level
		save_all()


## Keeps the best time left and the most stars separately; true if either improved.
func record_best(level: int, time_left: int, stars: int) -> bool:
	var old: Dictionary = bests.get(level, {"time": -1, "stars": -1})
	if time_left <= old.time and stars <= old.stars:
		return false
	bests[level] = {"time": maxi(time_left, old.time), "stars": maxi(stars, old.stars)}
	save_all()
	return true


## Keeps `run` as the level's ghost if it won with more time left than the
## one kept so far; true if it did.
func record_ghost(level: int, run: RunRecord) -> bool:
	if not run.won():
		return false
	var old := RunRecord.decode(ghosts.get(level, ""))
	if old != null and run.time_left <= old.time_left:
		return false
	ghosts[level] = run.encode()
	save_all()
	return true


func has_any_checkpoint() -> bool:
	return not checkpoints.is_empty()


## Returns true when this is a new personal best.
func submit_score(score: int) -> bool:
	if score > highscore:
		highscore = score
		save_all()
		return true
	return false


# --- the wardrobe (docs/wardrobe) -------------------------------------------------


func is_released(id: String) -> bool:
	return id == "classic" or id in released


## Puts a look in the wardrobe; true if it wasn't there before.
func release(id: String) -> bool:
	if not Wardrobe.is_look(id) or is_released(id):
		return false
	released.append(id)
	save_all()
	return true


## Wears a released look; false (and no change) for any other id.
func wear(id: String) -> bool:
	if not is_released(id):
		return false
	worn = id
	save_all()
	return true


## The wardrobe has been looked at: nothing in it is new any more.
func mark_seen() -> void:
	if seen == released:
		return
	seen = released.duplicate()
	save_all()


## Released looks the wardrobe hasn't shown yet.
func unseen() -> int:
	var n := 0
	for id in released:
		if id not in seen:
			n += 1
	return n


## Releases every look the progress has earned: a save from before the
## wardrobe, or a level skipped in a dev build.
func sync_wardrobe() -> void:
	for id in Wardrobe.earned(furthest_level, has_completed):
		if not is_released(id):
			released.append(id)


## The known looks in a list read from the save, each once.
func _looks(saved: Variant) -> Array[String]:
	var out: Array[String] = []
	if saved is Array:
		for id in saved:
			if id is String and id != "classic" and Wardrobe.is_look(id) and id not in out:
				out.append(id)
	return out


# --- the drafting table -----------------------------------------------------------


## The drafting table opens once the first checkpoint (level 10) is cleared.
func drafting_open() -> bool:
	return furthest_level > 10 or has_completed


## Every draft slot, as a Draft.
func all_drafts() -> Array[Draft]:
	var out: Array[Draft] = []
	for i in Draft.SLOTS:
		out.append(Draft.from_save(i, drafts[i] if i < drafts.size() else {}))
	return out


func store_draft(draft: Draft) -> void:
	while drafts.size() < Draft.SLOTS:
		drafts.append({})
	drafts[draft.slot] = {} if draft.is_empty() else draft.to_save()
	forget_unused()
	save_all()


## Keeps a code a friend sent at the front of the list (once). A full list
## lets go of its oldest unnamed level, or its oldest if all have names.
func receive(code: String) -> void:
	var tidy := LevelCode.pretty(code)
	received.erase(tidy)
	received.push_front(tidy)
	while received.size() > Draft.RECEIVED_KEPT:
		var drop := received.size() - 1
		for i in range(received.size() - 1, -1, -1):
			if received_name(received[i]) == "":
				drop = i
				break
		received.remove_at(drop)
	forget_unused()
	save_all()


## Takes received level `index` off the drafting table, with its name and record.
func delete_received(index: int) -> void:
	if index < 0 or index >= received.size():
		return
	received.remove_at(index)
	forget_unused()
	save_all()


## Empties draft slot `slot`, and forgets its record.
func delete_draft(slot: int) -> void:
	store_draft(Draft.new(slot))


func received_name(code: String) -> String:
	return received_names.get(LevelCode.clean(code), "")


func name_received(code: String, name: String) -> void:
	var key := LevelCode.clean(code)
	if name == "":
		received_names.erase(key)
	else:
		received_names[key] = name
	save_all()


## The record of the level with code `code` (see level_stats).
func level_stat(code: String) -> Dictionary:
	return level_stats.get(LevelCode.clean(code), _stat_of({}))


## A try at a drafting table level began.
func level_tried(code: String) -> void:
	var key := LevelCode.clean(code)
	var s := level_stat(key)
	s.played += 1
	level_stats[key] = s
	save_all()


## A drafting table level was won with `time_left` seconds left (run: the try,
## or null); true if it beat the best so far.
func level_won(code: String, time_left: int, run: RunRecord) -> bool:
	var key := LevelCode.clean(code)
	var s := level_stat(key)
	s.cleared += 1
	var best: bool = time_left > s.best
	if best:
		s.best = time_left
	if run != null and run.won():
		var old := RunRecord.decode(s.ghost)
		if old == null or run.time_left > old.time_left:
			s.ghost = run.encode()
	level_stats[key] = s
	save_all()
	return best


## Records and names of levels no longer on the drafting table go.
func forget_unused() -> void:
	var keep := {}
	for code in received:
		keep[LevelCode.clean(code)] = true
	for d in all_drafts():
		var code := d.code()
		if code != "":
			keep[LevelCode.clean(code)] = true
	for table: Dictionary in [level_stats, received_names]:
		for key in table.keys():
			if not keep.has(key):
				table.erase(key)


static func _stat_of(saved: Dictionary) -> Dictionary:
	var ghost: Variant = saved.get("ghost", "")
	return {
		"played": maxi(int(saved.get("played", 0)), 0),
		"cleared": maxi(int(saved.get("cleared", 0)), 0),
		"best": maxi(int(saved.get("best", -1)), -1),
		"ghost": ghost if ghost is String else "",
	}
