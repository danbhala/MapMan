extends Node2D
## Game controller. Port of the Game scene in map_man.py: level flow, the
## per-frame movement and tile rules, lives, score, timer and menus.

## The ending: MapMan walks up to MapWoman, they meet, then walk out together.
enum EndingPhase { WAITING, MEETING, LEAVING }

const POINTS_PER_LEVEL := 10
const INITIAL_LIVES := 3
const INITIAL_SECONDS := 20.0
const STOP_TIME := 14.0 / 60.0  # seconds to cross one tile on a gentle tilt
const SLIDE_TIME := 7.0 / 60.0  # seconds per tile while sliding on ice
const FLASH_SECONDS := 2.0  # how long "Bonus Points" etc. stay in the bar
const COMPLETION_BONUS := 100
const LIFE_BONUS := 50
const MEETING_SECONDS := 1.0  # how long MapMan and MapWoman stand facing
## Help for a sheet that keeps beating the player, by lives lost on it this
## session. Each tier keeps the ones before it; clearing the sheet ends them.
const ASSIST_MARKS := 2  # hidden death tiles are marked, and a death step needs a held tilt
const ASSIST_ROUTE := 4  # the safe route is sketched as each try starts
const ASSIST_SKIP := 6  # the lost-life sheet offers to skip the sheet
const ROUTE_SKETCH_SECONDS := 2.5

## The frame, grid and notes take an effect's colour while it is on.
const REVERSE_COLOR := Blueprint.PINK
const VANISH_COLOR := Blueprint.LILAC
const STUCK_COLOR := Blueprint.GOLD
const DEATH_COLOR := Blueprint.PINK
const HIDDEN_COLOR := Blueprint.MINT
## The notes that float up from a tile as it is collected (the time ones translate).
const FLOATS := {"star": "+1 ★", "life": "+1 ♥", "more_time": "+5 S", "less_time": "−5 S"}

var levels: Array = []
var tutorial_levels: Array = []  # the lessons on offer now (see lessons())
var tutorial_all: Array = []  # every lesson in data/tutorial.json
var completion_level: Dictionary = {}
var check_point_levels: Array = []

var map: LevelMap
var player: Player
var hud: Hud
var menus: Menus
var tilt := TiltInput.new()
var dev_panel: DevPanel
var gauge: TiltGauge
## The intro and title screen at launch; null once the main menu is up.
var intro: Intro
## The CONTROLS sheet's choices and the touch stick.
var steering: Steering
## Show the tilt gauge without an accelerometer (screenshots, desktop tests).
var show_gauge_anyway := false

# game state (names follow the original)
var game_active := false
var paused := false
var tutorial := false
## Playing the bonus map after the last level, where MapWoman waits.
var completed := false
## Practising one level from the practice menu: no lives, score or checkpoints.
var practice := false
## Playing a level from the drafting table: "draft" (testing one, which a
## win signs) or "received" (a friend's code). No lives, score or saving.
var custom := ""
## The drafting table's flow: the open draft and the level being played.
var drafting := DraftingTable.new(self)
var level := 1
var score := 0
var lives := INITIAL_LIVES
var stars := 0
var dead := false
var stuck := false:
	set(on):
		stuck = on
		if player:
			player.set_stuck(on)
var reverse := false
var vanish := 0
var end_of_level_points := 0
## Lives lost on each level (level -> count) in the main game this session,
## for the assists. Not saved: a fresh start is a fresh chance.
var losses := {}

var _bg: ColorRect
var _grid: Blueprint.Grid
var _was_moving := false
var _sliding := false  # a slide on ice is under way (one sound per slide)
var _slide_step := Vector2i.ZERO  # the screen direction of the last step, for ice
var _lose_reason := "death"

var _moves := 0  # moves made in this attempt at the level, for the play log
## The direction the player was last steering, so it only needs keep_threshold.
var _held_step := Vector2i.ZERO
## When MapMan last came to rest on a tile; with the assists on, a step onto a
## death tile sooner than guard_hold after it is ignored (a corner overshot).
var _landed_at := 0.0

# the ending (completion.py): MapWoman, the vortex and the hearts
var _woman: Player
var _vortex: LoopingSprite
var _hearts: LoopingSprite
var _woman_key := Vector2i.ZERO
var _ending_phase := EndingPhase.WAITING
var _ending_clock := 0.0
## Take the phone's current angle as "level" on the next frame of play.
var _calibrate_pending := true
var _practice_page := 0
## A level of the main game is cleared and its points not yet banked: its
## level clear is up, or the wardrobe or the question before quitting opened
## from it, and each of those goes back to it.
var _between := false

# every try at this level (for the replay), the best run beside the player
# (made when first needed: a Player draws on the random numbers), the replay
var _tries := Tries.new()

# countdown
var _time_left := INITIAL_SECONDS
var _timer_running := false
var _low_time := false

# when each status flash started (seconds), or -1
var _last_points := -1.0
var _last_more_time := -1.0
var _last_less_time := -1.0
var _last_life := -1.0
var _last_hide := -1.0


func _ready() -> void:
	_load_data()
	add_child(_tries)

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	_bg = ColorRect.new()
	_bg.color = Blueprint.FIELD
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(_bg)
	_grid = Blueprint.grid(bg_layer, _screen_size())

	map = LevelMap.new()
	add_child(map)
	player = Player.new()
	add_child(player)
	_vortex = LoopingSprite.new("vortex", 90)
	_vortex.z_index = 9
	add_child(_vortex)
	_woman = Player.new()
	_woman.art = "woman"
	add_child(_woman)
	_woman.z_index = 11  # in front of MapMan (Player._ready() sets 10)
	_hearts = LoopingSprite.new("hearts", 90)
	_hearts.z_index = 20
	add_child(_hearts)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	hud = Hud.new()
	hud_layer.add_child(hud)
	steering = Steering.new(self, hud_layer)
	gauge = TiltGauge.new()
	gauge.visible = false
	hud_layer.add_child(gauge)
	gauge.recentre.connect(recentre)

	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	menus = Menus.new()
	menu_layer.add_child(menus)
	menus.action.connect(_on_menu_action)

	get_viewport().size_changed.connect(_layout)
	_layout()
	steering.apply()
	if Dev.enabled:
		dev_panel = DevPanel.new(self)
		add_child(dev_panel)

	hud.show_bar(false)
	hud.show_stats(false)
	# Only a real launch plays the intro: tests and tools build Main themselves.
	if get_tree().current_scene == self:
		intro = Intro.new()
		add_child(intro)
		intro.finished.connect(_end_intro)
	else:
		show_start_menu()


func _end_intro() -> void:
	intro.queue_free()
	intro = null
	if not FirstRun.begin(self):
		show_start_menu()
		drafting.check_clipboard()


func _load_data() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	levels = data["levels"]
	check_point_levels = data["check_points"]
	tutorial_all = (
		JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial.json"))["levels"]
	)
	tutorial_levels = lessons()
	completion_level = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/completion.json")
	)


func _layout() -> void:
	var s := get_viewport_rect().size
	tilt.screen_size = s
	gauge.place(s)
	_grid.size = s
	_grid.queue_redraw()


func _screen_size() -> Vector2:
	return get_viewport_rect().size


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- countdown (clock.py / timer.py) ---------------------------------------


func _seconds_remaining() -> int:
	if _time_left <= 0.0:
		return 0
	return int(_time_left) + 1


func _timer_reset() -> void:
	_time_left = INITIAL_SECONDS
	_timer_running = false
	_low_time = false


func _timer_stop() -> void:
	_timer_running = false
	Audio.stop_clock()


func _timer_start() -> void:
	_timer_running = true


func _update_timer(delta: float) -> void:
	if not _timer_running:
		return
	if not (Dev.enabled and Dev.unlimited_time):
		_time_left = maxf(0.0, _time_left - delta)
	var secs := _seconds_remaining()
	hud.set_timer(secs, _time_left)
	if secs > 0 and secs <= 3:
		Audio.play_clock()
		_low_time = true
	else:
		Audio.stop_clock()
		_low_time = false


func started() -> bool:
	if tutorial or completed:
		return map.loaded()
	return _timer_running


# --- main loop -------------------------------------------------------------


func _process(delta: float) -> void:
	_update_gauge(delta)
	steering.update()
	if _tries.replay or menus.visible or not game_active:
		return

	_update_timer(delta)

	if dead:
		if map.moving:  # a step the clock cut short still lands on its tile
			map.update_move(delta)
		player.update_at(map.get_player_position(), delta)
		if player.death_finished():
			finish_lose_life()
	elif started():
		_tries.tick(map, delta)
		move_player(delta)
		update_player(delta)
		_update_stats()
		var time_left := _seconds_remaining()
		set_time_message(time_left)
		if time_left < 1 and not dead and not tutorial:
			lose_life("timeout")
	elif map.loaded():
		loaded()


func loaded() -> void:
	if started():
		return
	player.update_at(map.get_player_position(), 0.0)
	player.show_player()
	if not tutorial:
		if not completed:
			# A drafting table level plays as level 1 but is its own map: 0 keeps
			# level 1's ghost and tries off it.
			_tries.begin(0 if custom != "" else level, player.outfit)
		_timer_start()
		hud.set_timer(_seconds_remaining(), _time_left)


## The tilt gauge shows while playing, on phones that tilt, unless turned off.
func _update_gauge(delta: float) -> void:
	gauge.visible = (
		game_active
		and not menus.visible
		and Save.tilt_gauge
		and not tilt.stick
		and (TiltInput.has_accelerometer() or show_gauge_anyway)
	)
	if not gauge.visible:
		return
	gauge.steer = tilt.get_vector()
	gauge.pace = pace(gauge.steer)
	gauge.near_player(player.position, delta)


## Tapping the gauge: the way the phone is held now becomes level.
func recentre() -> void:
	tilt.calibrate()
	_held_step = Vector2i.ZERO
	gauge.ripple()
	Haptics.feel("recentre")


## What steering vector `v` does, by the rule in _try_axis(): 0 MapMan stays
## put, 1 he walks, 2 he runs.
func pace(v: Vector2) -> int:
	var lean := maxf(absf(v.x), absf(v.y))
	var start: float = Dev.t("tilt_threshold")
	if _held_step != Vector2i.ZERO:
		start = minf(start, Dev.t("keep_threshold"))
	if lean <= start:
		return 0
	return 2 if lean > Dev.t("fast_threshold") else 1


func _update_stats() -> void:
	if tutorial:
		hud.set_tutorial_level(level, tutorial_levels.size())
	else:
		hud.set_level(level, levels.size())
	hud.set_score(score)
	hud.set_lives(lives)


func set_time_message(time_left: int) -> void:
	if tutorial or completed:
		hud.set_time_message("")
	elif time_left > 19 and started():
		hud.set_time_message(tr("GO!"))
	elif _low_time:
		hud.set_time_message(tr("HURRY UP!"))
	elif custom != "":
		hud.set_time_message("")
	elif time_left > 15 and started() and String(levels[level - 1].get("message", "")) != "":
		# Level messages are lowercase in the data; the sheets use capitals.
		hud.set_time_message(tr(String(levels[level - 1]["message"]).to_upper()))
	else:
		hud.set_time_message("")


## The field stays blue; the frame, the grid and the note change colour
## with the effect in force, worst first.
func set_background() -> void:
	var color := Blueprint.INK
	if not game_active:
		color = Blueprint.INK
	elif dead:
		color = DEATH_COLOR
	elif map.tiles_hidden:
		color = HIDDEN_COLOR
	elif reverse:
		color = REVERSE_COLOR
	elif vanish > 0:
		color = VANISH_COLOR
	elif stuck:
		color = STUCK_COLOR
	hud.set_state_color(color)
	_grid.color = Color(color, Blueprint.GRID.a if color == Blueprint.INK else 0.22)
	_grid.queue_redraw()


## The notes are English msgids that tr() translates (see i18n/catalog.json).
func set_controls_message() -> void:
	var shake := TiltInput.has_accelerometer()
	if _last_points >= 0.0:
		hud.show_effect("points")
		hud.set_controls_message(tr("BONUS POINTS"))
	elif _last_more_time >= 0.0:
		hud.show_effect("more_time")
		hud.set_controls_message(tr("EXTRA TIME"))
	elif _last_less_time >= 0.0:
		hud.show_effect("less_time")
		hud.set_controls_message(tr("TIME LOST"))
	elif _last_life >= 0.0:
		hud.show_effect("life")
		hud.set_controls_message(tr("EXTRA LIFE"))
	elif reverse and vanish > 0:
		var note := tr_n(
			"CONTROLS REVERSED &\nSEE YOU AGAIN IN %d MOVE",
			"CONTROLS REVERSED &\nSEE YOU AGAIN IN %d MOVES",
			vanish
		)
		hud.set_controls_message(note % vanish)
		hud.show_double_effect("reverse", "vanish")
	elif reverse and stuck:
		if shake:
			hud.set_controls_message(tr("STUCK & CONTROLS REVERSED. SHAKE TO RELEASE."))
		else:
			hud.set_controls_message(tr("STUCK & CONTROLS REVERSED. TAP TO RELEASE."))
		hud.show_double_effect("reverse", "sticky")
	elif reverse and _last_hide >= 0.0 and map.tiles_hidden:
		hud.set_controls_message(tr("CONTROLS REVERSED &\nTILES HIDDEN"))
		hud.show_double_effect("reverse", "hide")
	elif stuck:
		hud.set_controls_message(
			tr("STUCK, SHAKE TO RELEASE" if shake else "STUCK, TAP TO RELEASE")
		)
		hud.show_effect("sticky")
	elif reverse:
		hud.set_controls_message(tr("CONTROLS REVERSED"))
		hud.show_effect("reverse")
	elif vanish > 0:
		var note := tr_n("SEE YOU AGAIN IN %d MOVE", "SEE YOU AGAIN IN %d MOVES", vanish)
		hud.set_controls_message(note % vanish)
		hud.show_effect("vanish")
	elif _last_hide >= 0.0:
		if map.tiles_hidden:
			hud.show_effect("hide")
			hud.set_controls_message(tr("TILES HIDDEN"))
		else:
			hud.show_effect("unhide")
			hud.set_controls_message(tr("TILES UNHIDDEN"))
	else:
		hud.set_controls_message("")
		hud.clear_effect()


# --- movement (move_player / move_player_x / move_player_y) ----------------


func move_player(delta: float) -> void:
	if dead:
		return
	var now := _now()
	for name in ["_last_hide", "_last_points", "_last_more_time", "_last_less_time", "_last_life"]:
		if get(name) >= 0.0 and now - get(name) > FLASH_SECONDS:
			set(name, -1.0)

	if _calibrate_pending:
		_calibrate_pending = false
		tilt.calibrate()
		_held_step = Vector2i.ZERO

	if stuck and tilt.shook():
		stuck = false

	if completed:
		_update_ending(delta)

	if map.moving:
		map.update_move(delta)
		return

	tilt.update(delta)
	if completed and _ending_phase != EndingPhase.WAITING:
		# MapMan stops to face MapWoman, then they walk out together.
		if _ending_phase == EndingPhase.LEAVING:
			move(Vector2i.RIGHT, STOP_TIME)
			player.face_direction(Vector2i.RIGHT, true)
		return
	steer(tilt.get_vector(), started() and not stuck)


## Moves or turns MapMan for a steering vector (see TiltInput.get_vector).
func steer(v: Vector2, can_move: bool) -> void:
	var held := _held_step
	_held_step = Vector2i.ZERO
	var first_x := absf(v.x) > absf(v.y)
	var face := Callable(player, "face_idle")
	face = _try_axis(
		Vector2i.RIGHT if first_x else Vector2i.DOWN, v.x if first_x else v.y, can_move, face, held
	)
	if not map.moving and face.is_valid():
		face = _try_axis(
			Vector2i.DOWN if first_x else Vector2i.RIGHT,
			v.y if first_x else v.x,
			can_move,
			face,
			held
		)
	if face.is_valid():
		face.call()


## Returns the idle facing to use, or an invalid Callable once a move started.
## A lean already steering that way only has to stay above keep_threshold,
## so hand tremor around tilt_threshold doesn't make MapMan stutter.
func _try_axis(
	axis: Vector2i, value: float, can_move: bool, face: Callable, held: Vector2i
) -> Callable:
	var step := axis if value > 0.0 else -axis
	var threshold: float = Dev.t("tilt_threshold")
	if step == held:
		threshold = minf(threshold, Dev.t("keep_threshold"))
	if absf(value) <= threshold:
		return face
	var actual := -step if reverse else step
	if can_move and _guarded(actual):
		return face  # like a wall: the other axis may still move him
	var seconds := STOP_TIME * (0.5 if absf(value) > Dev.t("fast_threshold") else 1.0)
	if can_move:
		move(step, seconds)
	# Hold the way MapMan actually went, not a way a wall blocked.
	if map.moving or _held_step == Vector2i.ZERO:
		_held_step = step
	if map.moving:
		player.face_direction(actual, true)
		return Callable()
	return func(): player.face_direction(actual, false)


## The corner guard (assist tier ASSIST_MARKS): a step onto a death tile is
## only taken once MapMan has rested on his tile for guard_hold seconds, so
## the tilt that carried him along a row doesn't carry him off its end.
func _guarded(actual: Vector2i) -> bool:
	if not assists_on(ASSIST_MARKS):
		return false
	if not map.deaths.get(map.position_key + actual, false):
		return false
	return _now() - _landed_at < Dev.t("guard_hold")


func move(step: Vector2i, seconds: float) -> void:
	_start_move(-step if reverse else step, seconds)


## A move in screen directions, whatever the controls say.
func _start_move(actual: Vector2i, seconds: float) -> void:
	map.move(actual, seconds)
	if map.moving:
		_tries.step(actual, seconds)
		map.update_move(0.0)
		Audio.play_step()
		_moves += 1
		if vanish > 0:
			vanish -= 1


# --- tries, the replay and the best-run ghost ----------------------------------


## WATCH REPLAY: the level again, every try on it at once. The level clear
## waits, hidden, and comes back when the replay ends or is tapped away.
func _start_replay() -> void:
	if _tries.replay or not _tries.replayable(level):
		return
	menus.visible = false
	hud.visible = false
	player.vanish()
	map.load_level(_current_level_data(), _screen_size())
	_tries.play(map).finished.connect(_end_replay)


func _end_replay() -> void:
	if _tries.stop_replay():
		hud.visible = true
		menus.redraw()


# --- tile rules (update_player) --------------------------------------------


func update_player(delta: float) -> void:
	player.update_at(map.get_player_position(), delta)
	map.spike_cycle = Dev.t("spike_cycle")
	if map.update_spikes(delta):
		Audio.play("spikes")
	if map.moving:
		if not _was_moving and map.crumbles.get(map.moving_from(), false):
			Audio.play("crumble")  # the tile he just left falls away behind him
			map.crumble(map.moving_from())
		_was_moving = true
		return
	if _was_moving:
		_was_moving = false
		_landed_at = _now()
		_slide_step = map.last_step()
		player.land()
	if map.at_end():
		player.cheer()
		advance_level(map.is_checkpoint)
		return

	if map.on(map.reverses):
		Audio.play("reverse")
		reverse = not reverse
		map.clear(map.reverses)
		player.spin_around()

	if vanish > 0 and not dead:
		player.vanish()
	else:
		player.show_player()

	if map.on(map.vanishes):
		Audio.play("vanish")
		vanish = map.vanish_duration()
		map.clear(map.vanishes)
		player.vanish()

	if map.on(map.hides) or map.on(map.unhides):
		Audio.play("hide")
		if map.on(map.hides):
			map.clear(map.hides)
			map.hide_tiles()
		else:
			map.clear(map.unhides)
			map.unhide_tiles()
		_flash("_last_hide")

	if map.on(map.points):
		Audio.play("points")
		map.clear(map.points)
		map.float_text(FLOATS.star, Blueprint.GOLD)
		player.cheer()
		if not tutorial:
			stars += 1
		_flash("_last_points")

	if map.on(map.deaths) and not dead:
		map.unhide_tile_at(map.position_key)
		lose_life()

	# Spikes kill while up: stepping onto them, or standing there as they rise.
	if map.spikes_up_at(map.position_key) and not dead:
		lose_life()

	if map.on(map.lives):
		Audio.play("life")
		map.clear(map.lives)
		map.float_text(FLOATS.life, Blueprint.PINK)
		player.cheer()
		if not tutorial:
			lives += 1
		_flash("_last_life")

	if map.on(map.stickies):
		Audio.play("sticky")
		map.clear(map.stickies)
		stuck = true

	if map.on(map.more_times):
		map.clear(map.more_times)
		map.float_text(tr(FLOATS.more_time), Blueprint.INK)
		_time_left += 5.0
		_flash("_last_more_time")

	if map.on(map.less_times):
		map.clear(map.less_times)
		map.float_text(tr(FLOATS.less_time), Blueprint.PINK)
		_time_left = maxf(0.0, _time_left - 5.0)
		_flash("_last_less_time")

	# Ice: he slides on the way he came until a tile that isn't ice, or an
	# edge, stops him. Steering is ignored on the way (move_player() skips
	# it while a move is under way). Death and a sticky tile end the slide.
	if map.on(map.ices) and not dead and not stuck and _slide_step != Vector2i.ZERO:
		if map.walkable(map.position_key + _slide_step):
			if not _sliding:
				Audio.play("slide")
			_sliding = true
			_start_move(_slide_step, SLIDE_TIME)
			player.face_direction(_slide_step, true)
		else:
			_sliding = false
	else:
		_sliding = false

	set_background()
	set_controls_message()


## Start one status flash and cancel the others, as the original did.
func _flash(which: String) -> void:
	for name in ["_last_hide", "_last_points", "_last_more_time", "_last_less_time", "_last_life"]:
		set(name, -1.0)
	set(which, _now())


# --- the ending (completion.py) ------------------------------------------


func _start_ending() -> void:
	# MapWoman waits on the bottom path, four tiles in, like the original's (4, 1).
	# Playing as MapWoman (a look from the wardrobe), MapMan waits for her.
	_woman.art = "man" if player.outfit == "mapwoman" else "woman"
	_woman_key = Vector2i(4, completion_level["rows"].size() - 2)
	_ending_phase = EndingPhase.WAITING
	_ending_clock = 0.0
	_woman.face_idle()
	_vortex.restart()
	_hearts.restart()


func _hide_ending() -> void:
	_woman.vanish()
	_vortex.visible = false
	_hearts.visible = false


func _update_ending(delta: float) -> void:
	var woman_pos: Vector2 = map.tiles[_woman_key].position
	_vortex.position = map.ends[0].position
	_vortex.visible = true
	_vortex.advance(delta)
	if _woman.is_hidden and _ending_phase == EndingPhase.WAITING:
		_woman.show_player()
	match _ending_phase:
		EndingPhase.WAITING:
			var at := map.position_key
			if at.y == _woman_key.y and absi(at.x - _woman_key.x) <= 1:
				_ending_phase = EndingPhase.MEETING
				_ending_clock = 0.0
				player.face_right_idle()
				_woman.face_left_idle()
				_hearts.position = woman_pos + Vector2(-LevelMap.TILE_W * 0.5, -80.0)
				_hearts.visible = true
				Audio.pause_music(3.0)
				Audio.play("love")
			_woman.update_at(woman_pos, delta)
		EndingPhase.MEETING:
			_ending_clock += delta
			_hearts.advance(delta)
			_woman.update_at(woman_pos, delta)
			if _ending_clock >= MEETING_SECONDS:
				_ending_phase = EndingPhase.LEAVING
				_hearts.visible = false
				_woman.face_right()
		EndingPhase.LEAVING:
			# She walks a tile ahead of him, and steps into the vortex first.
			var pos := map.get_player_position() + Vector2(LevelMap.TILE_W, 0)
			_woman.update_at(pos, delta)
			if pos.x > _vortex.position.x:
				_woman.vanish()


# --- level flow ------------------------------------------------------------


func _current_level_data() -> Dictionary:
	if custom != "":
		return drafting.level
	if completed:
		return completion_level
	return tutorial_levels[level - 1] if tutorial else levels[level - 1]


func load_level() -> void:
	_timer_stop()
	_timer_reset()
	player.vanish()
	_hide_ending()
	var data := _current_level_data()
	map.load_level(data, _screen_size())
	if completed:
		hud.set_tutorial_text("")
		hud.set_timer(0, -1.0, false)
		hud.set_time_message("")
		_start_ending()
	elif tutorial:
		var touch := tilt.stick and data.has("description_touch")  # tilting lessons
		hud.set_tutorial_text(tr(data.get("description_touch" if touch else "description", "")))
		hud.set_timer(0, -1.0, false)
		hud.set_time_message("")
	else:
		hud.set_tutorial_text("")
		hud.set_timer(0, -1.0, true)
		hud.blank_timer()
		hud.set_time_message(tr("GET READY..."))
		if not practice and custom == "":
			Save.level_reached(level)
	_update_stats()


func reset_all(reset_stars := true) -> void:
	if reset_stars:
		stars = 0
	_moves = 0
	map.reset()
	dead = false
	reverse = false
	player.reset_pose()  # before stuck: a web that is gone needs no shaking off
	stuck = false
	map.clear(map.reverses)
	map.clear(map.hides)
	map.reset_hide()
	_timer_stop()
	_timer_reset()
	hud.clear_effect()
	hud.set_controls_message("")
	vanish = 0
	for name in ["_last_hide", "_last_points", "_last_more_time", "_last_less_time", "_last_life"]:
		set(name, -1.0)
	set_background()
	_update_stats()
	tilt.touch(false, Vector2.ZERO)
	tilt.stick_release()
	_calibrate_pending = true
	_landed_at = _now()
	_apply_assists()


# --- assists -----------------------------------------------------------------


## Lives lost on this level in the main game; the tutorial, practice and the
## ending never count, so they never get help.
func losses_here() -> int:
	if tutorial or practice or completed:
		return 0
	return losses.get(level, 0)


func assists_on(tier: int) -> bool:
	return losses_here() >= tier


## The help the next try gets, for the lost-life sheet: "", "marks", "route"
## or "skip".
func assist_name() -> String:
	if assists_on(ASSIST_SKIP):
		return "skip"
	if assists_on(ASSIST_ROUTE):
		return "route"
	if assists_on(ASSIST_MARKS):
		return "marks"
	return ""


## At the start of a try: mark the hidden death tiles and sketch the route,
## as far as the sheet's losses have earned.
func _apply_assists() -> void:
	map.set_marks(assists_on(ASSIST_MARKS))
	if assists_on(ASSIST_ROUTE):
		map.sketch_route(ROUTE_SKETCH_SECONDS)


## Give up on a sheet the assists offered to skip: on to the next one with no
## points, no best and no checkpoint, as if walked around.
func skip_level() -> void:
	if not assists_on(ASSIST_SKIP):
		return
	Dev.record(level, "skip", _time_left, _moves)
	menus.close()
	losses.erase(level)
	level += 1
	finish_advancing_level()
	# The next level is reached, so any look its number releases comes too.
	Save.sync_wardrobe()
	Save.save_all()


func advance_level(check_point: bool) -> void:
	_timer_stop()
	if completed:
		# Into the vortex: on to the completion scoring.
		Audio.play("end_level")
		_hide_ending()
		show_game_complete()
		return
	if custom != "":
		Audio.play("end_level")
		drafting.end(true)
		return
	if not tutorial and not practice:
		losses.erase(level)
	if not tutorial:
		var new_best := false
		var run := _tries.end("win", _time_left)
		if not (Dev.enabled and Dev.unlimited_time):  # a frozen clock isn't a best
			new_best = Save.record_best(level, _seconds_remaining(), stars)
			if run:
				Save.record_ghost(level, run)
		if practice:
			Audio.play("end_level")
			var note := tr("LEVEL %d: %ds LEFT, NEW BEST!" if new_best else "LEVEL %d: %ds LEFT")
			_end_practice(note % [level, _seconds_remaining()])
			return
		Dev.record(level, "win", _time_left, _moves)
	if check_point:
		Audio.pause_music(3.0)
		Audio.play("checkpoint")
	else:
		Audio.play("end_level")
	if tutorial:
		next_level()
		return
	# The first clear of every 5th level in the main game releases a look.
	var released := Wardrobe.released_at(level)
	if not Save.release(released):
		released = ""
	var time_bonus := _seconds_remaining() / 2
	end_of_level_points = POINTS_PER_LEVEL + time_bonus + stars
	var clock := _seconds_remaining()
	var last := level >= levels.size()
	_between = true
	var tries := _tries.list.size() if _tries.replayable(level) else 0
	menus.show_end_level(
		score, POINTS_PER_LEVEL, time_bonus, stars, check_point, level, clock, last, released, tries
	)


func next_level() -> void:
	_bank_level()
	finish_advancing_level()


## The cleared level's points join the score (saving a checkpoint on a
## checkpoint level), and the level after it is next.
func _bank_level() -> void:
	_between = false
	if not tutorial:
		score += end_of_level_points
		if map.is_checkpoint:
			Save.checkpoint_reached(level, score)
	level += 1


func finish_advancing_level() -> void:
	var count := tutorial_levels.size() if tutorial else levels.size()
	if level > count:
		if tutorial:
			# The tutorial runs straight on into level 1 of the real game.
			tutorial = false
			level = 1
			hud.show_stats(true)
		else:
			# Past the last level: the bonus map where MapWoman waits. Finishing
			# the game releases her into the wardrobe.
			completed = true
			_mark_completed()
			Save.release("mapwoman")
			Save.save_all()
			hud.show_stats(false)
	load_level()
	reset_all()


## The tutorial's lessons for this player: the Revision B ones (new tiles
## for the second playthrough, `rev_b` in tutorial.json) wait until the
## game has been finished once.
func lessons() -> Array:
	return tutorial_all.filter(
		func(l: Dictionary) -> bool: return not l.get("rev_b", false) or Save.has_completed
	)


## Finishing the game. The first time, the lessons it adds to the tutorial
## are news: the completion sheet and the main menu say so until it is played.
func _mark_completed() -> void:
	if not Save.has_completed and lessons().size() < tutorial_all.size():
		Save.new_lessons = true
	Save.has_completed = true
	tutorial_levels = lessons()


func show_game_complete() -> void:
	_timer_stop()
	map.unload()
	player.vanish()
	var lives_bonus := lives * LIFE_BONUS
	end_of_level_points = COMPLETION_BONUS + lives_bonus
	Audio.play_completion()
	menus.show_game_complete(score, COMPLETION_BONUS, lives_bonus, Save.new_lessons)


func new_game(start_level := 1, is_tutorial := false) -> void:
	if Save.first_play:
		Save.first_play = false
		Save.save_all()
	Audio.play_game()
	tutorial = is_tutorial
	if tutorial:
		tutorial_levels = lessons()
		if Save.new_lessons:  # the news has been read
			Save.new_lessons = false
			Save.save_all()
	completed = false
	practice = false
	_between = false
	_tries.clear()
	_tries.end("", _time_left)
	player.outfit = Save.worn
	score = 0
	level = start_level
	lives = INITIAL_LIVES
	game_active = true
	paused = false
	load_level()
	reset_all()
	hud.show_bar(true)
	hud.show_stats(not tutorial)
	if tutorial:
		hud.show_level(true)  # just the sheet number, no score or lives


## reason: "death" (a death tile) or "timeout" (the clock ran out).
func lose_life(reason := "death") -> void:
	_timer_stop()
	_tries.end(reason, _time_left)
	if not tutorial and not practice and custom == "":
		Dev.record(level, reason, _time_left, _moves)
		if not completed:
			losses[level] = losses.get(level, 0) + 1
	Audio.play("lose_life")
	_lose_reason = reason
	player.show_player()
	player.face_death()
	dead = true
	set_background()


func finish_lose_life() -> void:
	if practice or custom != "":
		# No lives in practice: straight back to the start of the level.
		load_level()
		reset_all()
		return
	if not tutorial and not (Dev.enabled and Dev.unlimited_lives):
		lives -= 1
	_update_stats()
	if lives < 1:
		game_over()
	elif not tutorial:
		menus.show_lose_life(lives, level, _lose_reason, assist_name())
	else:
		reset_all()


func game_over(show_score := true) -> void:
	hud.show_bar(false)
	hud.show_stats(false)
	map.unload()
	player.vanish()
	_hide_ending()
	_tries.end("", _time_left)
	completed = false
	practice = false
	custom = ""
	_between = false
	_timer_stop()
	game_active = false
	paused = false
	set_background()
	if show_score:
		Audio.play_game_over()
		var previous_best := Save.highscore
		var pb := Save.submit_score(score)
		menus.show_game_over(score, pb, Save.has_any_checkpoint(), previous_best)


# --- practice --------------------------------------------------------------


func show_practice_menu(page := -1, note := "") -> void:
	if page >= 0:
		_practice_page = page
	Audio.play_menu()
	menus.show_practice(_practice_page, Save.furthest_level, Save.bests, levels.size(), note)


func start_practice(n: int) -> void:
	# Practising first still leaves the first-play screen for "play from start".
	var first_play := Save.first_play
	new_game(n)
	if first_play:
		Save.first_play = true
		Save.save_all()
	practice = true
	hud.show_stats(false)
	hud.show_level(true)


func _end_practice(note := "") -> void:
	game_over(false)
	show_practice_menu(-1, note)


func show_start_menu() -> void:
	Audio.play_menu()
	var drafting := Save.drafting_open()
	menus.show_main(
		Save.highscore, Save.has_any_checkpoint(), levels.size(), drafting, Save.new_lessons
	)
	# A level link that came in during the main game.
	self.drafting.check_link()


func show_pause_menu() -> void:
	_timer_stop()
	paused = true
	# The final sheet after level 100 has no number and no clock.
	var clock := -1 if tutorial or completed else _seconds_remaining()
	if custom != "":
		DraftingSheet.build_pause(menus, drafting.pause_number())
	else:
		menus.show_pause(tutorial, 0 if completed else level, clock)


func _on_menu_action(act: String) -> void:
	if drafting.action(act):
		return
	match act:
		"play from start", "play", "new game", "play game":
			if Save.first_play and act == "play from start":
				menus.show_first_play()
			else:
				menus.close()
				new_game()
		"tutorial", "take tutorial":
			menus.close()
			new_game(1, true)
		"restart from checkpoint":
			menus.show_restart(Save.checkpoints.keys())
		"wardrobe":
			menus.show_wardrobe(level if _between else 0)
		"main menu":
			if menus.current == "wardrobe":
				# Looked at: nothing in it is new any more (the marks stay
				# while the sheet is open, through a tap that redraws it).
				Save.mark_seen()
			if game_active:
				game_over(false)
			show_start_menu()
		"confirm quit":
			menus.show_confirm_quit()
		"end game", "end tutorial":
			if practice:
				_end_practice()
			else:
				if _between:
					# Quitting from a level clear: its checkpoint is kept, and
					# the next level opens in practice.
					_bank_level()
					if level <= levels.size():
						Save.level_reached(level)
				game_over(false)
				show_start_menu()
		"practice":
			# Open on the page with the furthest level reached.
			var last_page := (levels.size() - 1) / Menus.PRACTICE_PAGE
			show_practice_menu(
				clampi((Save.furthest_level - 1) / Menus.PRACTICE_PAGE, 0, last_page)
			)
		"next level":
			menus.close()
			next_level()
		"replay":
			_start_replay()
		"clear wardrobe":
			menus.show_wardrobe(level)
		"back to clear":
			if menus.current == "wardrobe":
				Save.mark_seen()
			menus.reopen_end_level()
		"leave clear":
			# MAIN MENU on the level clear: the same question as quitting
			# from the pause; the level still counts if the game ends.
			menus.show_confirm_quit("back to clear")
		"try again":
			menus.close()
			reset_all(false)
		"skip sheet":
			skip_level()
		"unpause":
			menus.close()
			paused = false
			# The player may hold the phone differently after a pause.
			_calibrate_pending = true
			if not tutorial and started() == false and map.loaded():
				_timer_start()
		"completion done":
			score += end_of_level_points
			var pb := Save.submit_score(score)
			_mark_completed()
			Save.save_all()
			game_active = false
			hud.show_bar(false)
			hud.show_stats(false)
			set_background()
			# Her slip shows until the wardrobe has been looked at, so leaving
			# the ending before the vortex the first time doesn't lose it.
			var new_woman := Save.is_released("mapwoman") and "mapwoman" not in Save.seen
			menus.show_congratulations(score, pb, "mapwoman" if new_woman else "")
		_:
			if steering.handle(act) or OptionsActions.handle(act, menus):
				pass  # the Options, CONTROLS and language sheets
			elif act.begins_with("practice page "):
				show_practice_menu(int(act.get_slice(" ", 2)))
			elif act.begins_with("practice level "):
				menus.close()
				start_practice(int(act.get_slice(" ", 2)))
			elif act.begins_with("wear "):
				# From the wardrobe, or the slip on the level clear that released
				# it: he wears it from now on.
				if Save.wear(act.get_slice(" ", 1)):
					player.outfit = Save.worn
				if menus.current == "end_level":
					menus.redraw()
				else:
					menus.show_wardrobe(level if _between else 0)
			elif act.begins_with("L") and act.substr(1).is_valid_int():
				menus.close()
				new_game(int(act.substr(1)) + 1)


# --- input -----------------------------------------------------------------


func _can_pause() -> bool:
	return (
		game_active
		and not dead
		and not menus.visible
		and (tutorial or completed or (_timer_running and _seconds_remaining() <= 19))
	)


func _unhandled_input(event: InputEvent) -> void:
	if _tries.replay:
		return  # the replay takes its own taps
	if event.is_action_pressed("pause") and _can_pause():
		show_pause_menu()
		get_viewport().set_input_as_handled()
		return
	steering.input(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if game_active and not dead and not menus.visible and is_inside_tree():
			show_pause_menu()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and is_inside_tree():
		drafting.check_clipboard()
		drafting.check_link()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


## Android's back button or gesture: steps out one level, like other apps.
## (project.godot turns off quit_on_go_back so back doesn't just close the app.)
func go_back() -> void:
	if _tries.replay:
		_end_replay()
		return
	if intro:
		intro.advance()
		return
	if dev_panel and dev_panel.is_open():
		dev_panel.close()
		return
	if drafting.go_back():
		return
	match menus.current:
		"":
			if game_active and not dead:
				show_pause_menu()
		"pause":
			_on_menu_action("unpause")
		"confirm_quit":
			_on_menu_action(menus.confirm_back)
		"wardrobe":
			_on_menu_action("back to clear" if _between else "main menu")
		"options", "restart", "first_play", "game_over", "congratulations", "practice":
			_on_menu_action("main menu")
		"language", "controls":
			_on_menu_action("options")
		"main":
			get_tree().quit()
		# Tap-to-continue screens (life lost, level clear, completion scoring)
		# ignore back so a stray press can't skip or lose anything.
