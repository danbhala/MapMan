extends Node2D
## Game controller. Port of the Game scene in map_man.py: level flow, the
## per-frame movement and tile rules, lives, score, timer and menus.

## The ending: MapMan walks up to MapWoman, they meet, then walk out together.
enum EndingPhase { WAITING, MEETING, LEAVING }

const POINTS_PER_LEVEL := 10
const INITIAL_LIVES := 3
const INITIAL_SECONDS := 20.0
const STOP_TIME := 14.0 / 60.0  # seconds to cross one tile on a gentle tilt
const FLASH_SECONDS := 2.0  # how long "Bonus Points" etc. stay in the bar
const COMPLETION_BONUS := 100
const LIFE_BONUS := 50
const MEETING_SECONDS := 1.0  # how long MapMan and MapWoman stand facing

## The frame, grid and notes take an effect's colour while it is on.
const REVERSE_COLOR := Blueprint.PINK
const VANISH_COLOR := Blueprint.LILAC
const STUCK_COLOR := Blueprint.GOLD
const DEATH_COLOR := Blueprint.PINK
const HIDDEN_COLOR := Blueprint.MINT

var levels: Array = []
var tutorial_levels: Array = []
var completion_level: Dictionary = {}
var check_point_levels: Array = []

var map: LevelMap
var player: Player
var hud: Hud
var menus: Menus
var tilt := TiltInput.new()
var dev_panel: DevPanel

# game state (names follow the original)
var game_active := false
var paused := false
var tutorial := false
## Playing the bonus map after the last level, where MapWoman waits.
var completed := false
## Practising one level from the practice menu: no lives, score or checkpoints.
var practice := false
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

var _bg: ColorRect
var _grid: Blueprint.Grid
var _was_moving := false
var _lose_reason := "death"

var _moves := 0  # moves made in this attempt at the level, for the play log
## The direction the player was last steering, so it only needs keep_threshold.
var _held_step := Vector2i.ZERO

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

	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	menus = Menus.new()
	menus.tilt = tilt
	menu_layer.add_child(menus)
	menus.action.connect(_on_menu_action)

	get_viewport().size_changed.connect(_layout)
	_layout()
	if Dev.enabled:
		dev_panel = DevPanel.new(self)
		add_child(dev_panel)

	hud.show_bar(false)
	hud.show_stats(false)
	show_start_menu()


func _load_data() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	levels = data["levels"]
	check_point_levels = data["check_points"]
	tutorial_levels = (
		JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial.json"))["levels"]
	)
	completion_level = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/completion.json")
	)


func _layout() -> void:
	var s := get_viewport_rect().size
	tilt.screen_size = s
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
	if menus.visible or not game_active:
		return

	_update_timer(delta)

	if dead:
		player.update_at(map.get_player_position(), delta)
		if player.death_finished():
			finish_lose_life()
	elif started():
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
		_timer_start()
		hud.set_timer(_seconds_remaining(), _time_left)


func _update_stats() -> void:
	if tutorial:
		hud.set_level_text("TUTORIAL %d / %d" % [level, tutorial_levels.size()])
	else:
		hud.set_level(level, levels.size())
	hud.set_score(score)
	hud.set_lives(lives)


func set_time_message(time_left: int) -> void:
	if tutorial or completed:
		hud.set_time_message("")
	elif time_left > 19 and started():
		hud.set_time_message("go!")
	elif _low_time:
		hud.set_time_message("hurry up!")
	elif time_left > 15 and String(levels[level - 1].get("message", "")) != "":
		hud.set_time_message(levels[level - 1]["message"])
	else:
		hud.set_time_message("")


## The field stays blue; the frame, the grid and the note change colour
## with the effect in force, worst first.
func set_background() -> void:
	var color := Blueprint.INK
	if not game_active:
		color = Blueprint.INK
	elif map.tiles_hidden:
		color = HIDDEN_COLOR
	elif dead:
		color = DEATH_COLOR
	elif reverse:
		color = REVERSE_COLOR
	elif vanish > 0:
		color = VANISH_COLOR
	elif stuck:
		color = STUCK_COLOR
	hud.set_state_color(color)
	_grid.color = Color(color, Blueprint.GRID.a if color == Blueprint.INK else 0.22)
	_grid.queue_redraw()


func set_controls_message() -> void:
	var shake_word := (
		"shake" if TiltInput.has_accelerometer() or not tilt.touch_steering_enabled() else "tap"
	)
	if _last_points >= 0.0:
		hud.show_effect("points")
		hud.set_controls_message("Bonus Points", 20)
	elif _last_more_time >= 0.0:
		hud.show_effect("more_time")
		hud.set_controls_message("Extra Time", 20)
	elif _last_less_time >= 0.0:
		hud.show_effect("less_time")
		hud.set_controls_message("Time Lost", 20)
	elif _last_life >= 0.0:
		hud.show_effect("life")
		hud.set_controls_message("Extra Life", 20)
	elif reverse and vanish > 0:
		hud.set_controls_message("Controls reversed &\nsee you again in %d moves" % vanish, 18)
		hud.show_double_effect("reverse", "vanish")
	elif reverse and stuck:
		hud.set_controls_message(
			"Stuck, & controls reversed. %s to release." % shake_word.capitalize(), 18
		)
		hud.show_double_effect("reverse", "sticky")
	elif reverse and _last_hide >= 0.0 and map.tiles_hidden:
		hud.set_controls_message("Controls reversed &\nand tiles hidden", 18)
		hud.show_double_effect("reverse", "hide")
	elif stuck:
		hud.set_controls_message("Stuck, %s to release" % shake_word, 20)
		hud.show_effect("sticky")
	elif reverse:
		hud.set_controls_message("Controls reversed", 20)
		hud.show_effect("reverse")
	elif vanish > 0:
		hud.set_controls_message("See you again in %d moves" % vanish, 18)
		hud.show_effect("vanish")
	elif _last_hide >= 0.0:
		if map.tiles_hidden:
			hud.show_effect("hide")
			hud.set_controls_message("Tiles hidden", 20)
		else:
			hud.show_effect("unhide")
			hud.set_controls_message("Tiles unhidden", 20)
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
	var seconds := STOP_TIME * (0.5 if absf(value) > Dev.t("fast_threshold") else 1.0)
	if can_move:
		move(step, seconds)
	# Hold the way MapMan actually went, not a way a wall blocked.
	if map.moving or _held_step == Vector2i.ZERO:
		_held_step = step
	var actual := -step if reverse else step
	if map.moving:
		player.face_direction(actual, true)
		return Callable()
	return func(): player.face_direction(actual, false)


func move(step: Vector2i, seconds: float) -> void:
	map.move(-step if reverse else step, seconds)
	if map.moving:
		map.update_move(0.0)
		Audio.play_step()
		_moves += 1
		if vanish > 0:
			vanish -= 1


# --- tile rules (update_player) --------------------------------------------


func update_player(delta: float) -> void:
	player.update_at(map.get_player_position(), delta)
	if map.moving:
		_was_moving = true
		return
	if _was_moving:
		_was_moving = false
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
		map.float_text("+1 ★", Blueprint.GOLD)
		player.cheer()
		if not tutorial:
			stars += 1
		_flash("_last_points")

	if map.on(map.deaths) and not dead:
		map.unhide_tile_at(map.position_key)
		lose_life()

	if map.on(map.lives):
		Audio.play("life")
		map.clear(map.lives)
		map.float_text("+1 ♥", Blueprint.PINK)
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
		map.float_text("+5 S", Blueprint.INK)
		_time_left += 5.0
		_flash("_last_more_time")

	if map.on(map.less_times):
		map.clear(map.less_times)
		map.float_text("−5 S", Blueprint.PINK)
		_time_left = maxf(0.0, _time_left - 5.0)
		_flash("_last_less_time")

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
		hud.set_tutorial_text(data.get("description", ""))
		hud.set_timer(0, -1.0, false)
		hud.set_time_message("")
	else:
		hud.set_tutorial_text("")
		hud.set_timer(0, -1.0, true)
		hud.blank_timer()
		hud.set_time_message("get ready...")
		if not practice:
			Save.level_reached(level)
	_update_stats()


func reset_all(reset_stars := true) -> void:
	if reset_stars:
		stars = 0
	_moves = 0
	map.reset()
	dead = false
	reverse = false
	stuck = false
	map.clear(map.reverses)
	map.clear(map.hides)
	map.reset_hide()
	player.reset_pose()
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
	_calibrate_pending = true


func advance_level(check_point: bool) -> void:
	_timer_stop()
	if completed:
		# Into the vortex: on to the completion scoring.
		Audio.play("end_level")
		_hide_ending()
		show_game_complete()
		return
	if not tutorial:
		var new_best := false
		if not (Dev.enabled and Dev.unlimited_time):  # a frozen clock isn't a best
			new_best = Save.record_best(level, _seconds_remaining(), stars)
		if practice:
			Audio.play("end_level")
			_end_practice(
				(
					"level %d: %ds left%s"
					% [level, _seconds_remaining(), ", new best!" if new_best else ""]
				)
			)
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
	var time_bonus := _seconds_remaining() / 2
	end_of_level_points = POINTS_PER_LEVEL + time_bonus + stars
	menus.show_end_level(
		score, POINTS_PER_LEVEL, time_bonus, stars, check_point, level, _seconds_remaining()
	)


func next_level() -> void:
	if not tutorial:
		score += end_of_level_points
		if map.is_checkpoint:
			Save.checkpoint_reached(level, score)
	level += 1
	finish_advancing_level()


func finish_advancing_level() -> void:
	var count := tutorial_levels.size() if tutorial else levels.size()
	if level > count:
		if tutorial:
			# The tutorial runs straight on into level 1 of the real game.
			tutorial = false
			level = 1
			hud.show_stats(true)
		else:
			# Past the last level: the bonus map where MapWoman waits.
			completed = true
			Save.has_completed = true
			Save.save_all()
			hud.show_stats(false)
	load_level()
	reset_all()


func show_game_complete() -> void:
	_timer_stop()
	map.unload()
	player.vanish()
	var lives_bonus := lives * LIFE_BONUS
	end_of_level_points = COMPLETION_BONUS + lives_bonus
	Audio.play_completion()
	menus.show_game_complete(score, COMPLETION_BONUS, lives_bonus)


func new_game(start_level := 1, is_tutorial := false) -> void:
	if Save.first_play:
		Save.first_play = false
		Save.save_all()
	Audio.play_game()
	tutorial = is_tutorial
	completed = false
	practice = false
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
	if not tutorial and not practice:
		Dev.record(level, reason, _time_left, _moves)
	Audio.play("lose_life")
	_lose_reason = reason
	player.show_player()
	player.face_death()
	dead = true
	set_background()


func finish_lose_life() -> void:
	if practice:
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
		menus.show_lose_life(lives, level, _lose_reason)
	else:
		reset_all()


func game_over(show_score := true) -> void:
	hud.show_bar(false)
	hud.show_stats(false)
	map.unload()
	player.vanish()
	_hide_ending()
	completed = false
	practice = false
	_timer_stop()
	game_active = false
	paused = false
	set_background()
	if show_score:
		Audio.play_game_over()
		var previous_best := Save.highscore
		var pb := Save.submit_score(score)
		menus.show_game_over(score, pb, Save.has_any_checkpoint(), previous_best)


# --- dev menu ----------------------------------------------------------------


## Start a normal game at any level (dev menu).
func dev_go_to_level(n: int) -> void:
	menus.close()
	new_game(clampi(n, 1, levels.size()))


## Move on to the next level without finishing this one (dev menu).
func dev_skip_level() -> void:
	if not game_active:
		return
	if practice:
		# Skipping never saves checkpoints or unlocks levels from practice.
		_end_practice()
		return
	menus.close()
	end_of_level_points = 0
	next_level()


# --- menus -----------------------------------------------------------------

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
	menus.show_main(Save.highscore, Save.has_any_checkpoint(), levels.size())


func show_pause_menu() -> void:
	_timer_stop()
	paused = true
	menus.show_pause(tutorial, level, -1 if tutorial or completed else _seconds_remaining())


func _on_menu_action(act: String) -> void:
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
		"options":
			menus.show_options()
		"music on", "music off":
			Audio.set_music_enabled(act == "music on")
			menus.show_options()
		"fx on", "fx off":
			Audio.set_fx_enabled(act == "fx on")
			menus.show_options()
		"vibration on", "vibration off":
			Save.vibration_on = act == "vibration on"
			Save.save_all()
			Haptics.feel("toggle")
			menus.show_options()
		"reduce motion on", "reduce motion off":
			Save.reduce_motion = act == "reduce motion on"
			Save.save_all()
			menus.show_options()
		"main menu":
			if game_active:
				game_over(false)
			show_start_menu()
		"confirm quit":
			menus.show_confirm_quit()
		"end game", "end tutorial":
			if practice:
				_end_practice()
			else:
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
		"try again":
			menus.close()
			reset_all(false)
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
			Save.has_completed = true
			Save.save_all()
			game_active = false
			hud.show_bar(false)
			hud.show_stats(false)
			set_background()
			menus.show_congratulations(score, pb)
		_:
			if act.begins_with("practice page "):
				show_practice_menu(int(act.get_slice(" ", 2)))
			elif act.begins_with("practice level "):
				menus.close()
				start_practice(int(act.get_slice(" ", 2)))
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
	if event.is_action_pressed("pause") and _can_pause():
		show_pause_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not game_active or menus.visible:
			return
		if tilt.touch_steering_enabled():
			# No accelerometer: hold towards an edge to steer (the original's
			# tilt simulator). A fresh tap also frees MapMan from a sticky tile.
			tilt.touch(event.pressed, event.position)
			if event.pressed and stuck:
				stuck = false
		elif not event.pressed and _can_pause():
			show_pause_menu()
	elif event is InputEventMouseMotion and tilt.touch_steering_enabled():
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			tilt.touch(true, event.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if game_active and not dead and not menus.visible and is_inside_tree():
			show_pause_menu()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


## Android's back button or gesture: steps out one level, like other apps.
## (project.godot turns off quit_on_go_back so back doesn't just close the app.)
func go_back() -> void:
	if dev_panel and dev_panel.is_open():
		dev_panel.close()
		return
	match menus.current:
		"":
			if game_active and not dead:
				show_pause_menu()
		"pause", "confirm_quit":
			_on_menu_action("unpause")
		"options", "restart", "first_play", "game_over", "congratulations", "practice":
			_on_menu_action("main menu")
		"main":
			get_tree().quit()
		# Tap-to-continue screens (life lost, level clear, completion scoring)
		# ignore back so a stray press can't skip or lose anything.
