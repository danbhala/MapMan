extends Node2D
## Game controller. Port of the Game scene in map_man.py: level flow, the
## per-frame movement and tile rules, lives, score, timer and menus.

const POINTS_PER_LEVEL := 10
const INITIAL_LIVES := 3
const INITIAL_SECONDS := 20.0
const STOP_TIME := 14.0 / 60.0  # seconds to cross one tile on a gentle tilt
const FLASH_SECONDS := 2.0  # how long "Bonus Points" etc. stay in the bar
const COMPLETION_BONUS := 100
const LIFE_BONUS := 50

const BASE_BG := Color("#71c0e2")
const REVERSE_BG := Color("#e28c9b")
const VANISH_BG := Color("#d593e2")
const STUCK_BG := Color("#7ce2c0")
const DEATH_BG := Color("#aeaeae")
const HIDDEN_BG := Color("#b1aaea")

var levels: Array = []
var tutorial_levels: Array = []
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
var level := 1
var score := 0
var lives := INITIAL_LIVES
var stars := 0
var dead := false
var stuck := false
var reverse := false
var vanish := 0
var end_of_level_points := 0

var _bg: ColorRect
var _gradient: TextureRect

var _moves := 0  # moves made in this attempt at the level, for the play log
## The direction the player was last steering, so it only needs keep_threshold.
var _held_step := Vector2i.ZERO

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
	_bg.color = BASE_BG
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(_bg)
	_gradient = TextureRect.new()
	_gradient.texture = load("res://assets/background/gradient.png")
	_gradient.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gradient.stretch_mode = TextureRect.STRETCH_SCALE
	_gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(_gradient)

	map = LevelMap.new()
	add_child(map)
	player = Player.new()
	add_child(player)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	hud = Hud.new()
	hud_layer.add_child(hud)

	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	menus = Menus.new()
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


func _layout() -> void:
	var s := get_viewport_rect().size
	tilt.screen_size = s
	_gradient.position = Vector2.ZERO
	_gradient.size = Vector2(s.x, s.y - Hud.BAR_HEIGHT)


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
	if tutorial:
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
	tilt.calibrate()
	_held_step = Vector2i.ZERO
	player.update_at(map.get_player_position(), 0.0)
	player.show_player()
	if not tutorial:
		_timer_start()
		hud.set_timer(_seconds_remaining(), _time_left)


func _update_stats() -> void:
	hud.set_level(level, levels.size())
	hud.set_score(score)
	hud.set_lives(lives)


func set_time_message(time_left: int) -> void:
	if tutorial:
		hud.set_time_message("")
	elif time_left > 19 and started():
		hud.set_time_message("go!")
	elif _low_time:
		hud.set_time_message("hurry up!")
	elif time_left > 15 and String(levels[level - 1].get("message", "")) != "":
		hud.set_time_message(levels[level - 1]["message"])
	else:
		hud.set_time_message("")


func set_background() -> void:
	if not game_active:
		_bg.color = BASE_BG
	elif map.tiles_hidden:
		_bg.color = HIDDEN_BG
	elif dead:
		_bg.color = DEATH_BG
	elif reverse:
		_bg.color = REVERSE_BG
	elif vanish > 0:
		_bg.color = VANISH_BG
	elif stuck:
		_bg.color = STUCK_BG
	else:
		_bg.color = BASE_BG


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

	if stuck and tilt.shook():
		stuck = false

	if map.moving:
		map.update_move(delta)
		return

	tilt.update(delta)
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
	if _held_step == Vector2i.ZERO:
		_held_step = step
	var seconds := STOP_TIME * (0.5 if absf(value) > Dev.t("fast_threshold") else 1.0)
	if can_move:
		move(step, seconds)
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
		return
	if map.at_end():
		advance_level(map.is_checkpoint)
		return

	if map.on(map.reverses):
		Audio.play("reverse")
		reverse = not reverse
		map.clear(map.reverses)

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
		if not tutorial:
			stars += 1
		_flash("_last_points")

	if map.on(map.deaths) and not dead:
		map.unhide_tile_at(map.position_key)
		lose_life()

	if map.on(map.lives):
		Audio.play("life")
		map.clear(map.lives)
		if not tutorial:
			lives += 1
		_flash("_last_life")

	if map.on(map.stickies):
		Audio.play("sticky")
		map.clear(map.stickies)
		stuck = true

	if map.on(map.more_times):
		map.clear(map.more_times)
		_time_left += 5.0
		_flash("_last_more_time")

	if map.on(map.less_times):
		map.clear(map.less_times)
		_time_left = maxf(0.0, _time_left - 5.0)
		_flash("_last_less_time")

	set_background()
	set_controls_message()


## Start one status flash and cancel the others, as the original did.
func _flash(which: String) -> void:
	for name in ["_last_hide", "_last_points", "_last_more_time", "_last_less_time", "_last_life"]:
		set(name, -1.0)
	set(which, _now())


# --- level flow ------------------------------------------------------------


func _current_level_data() -> Dictionary:
	return tutorial_levels[level - 1] if tutorial else levels[level - 1]


func load_level() -> void:
	_timer_stop()
	_timer_reset()
	player.vanish()
	var data := _current_level_data()
	map.load_level(data, _screen_size())
	if tutorial:
		hud.set_tutorial_text(data.get("description", ""))
		hud.set_timer(0, -1.0, false)
		hud.set_time_message("")
	else:
		hud.set_tutorial_text("")
		hud.set_timer(0, -1.0, true)
		hud.blank_timer()
		hud.set_time_message("get ready...")
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


func advance_level(check_point: bool) -> void:
	_timer_stop()
	if not tutorial:
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
	menus.show_end_level(score, POINTS_PER_LEVEL, time_bonus, stars, check_point)


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
			show_game_complete()
			return
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
	score = 0
	level = start_level
	lives = INITIAL_LIVES
	game_active = true
	paused = false
	load_level()
	reset_all()
	hud.show_bar(true)
	hud.show_stats(not tutorial)


## reason: "death" (a death tile) or "timeout" (the clock ran out).
func lose_life(reason := "death") -> void:
	_timer_stop()
	if not tutorial:
		Dev.record(level, reason, _time_left, _moves)
	Audio.play("lose_life")
	player.show_player()
	player.face_death()
	dead = true
	set_background()


func finish_lose_life() -> void:
	if not tutorial and not (Dev.enabled and Dev.unlimited_lives):
		lives -= 1
	_update_stats()
	if lives < 1:
		game_over()
	elif not tutorial:
		menus.show_lose_life(lives)
	else:
		reset_all()


func game_over(show_score := true) -> void:
	hud.show_bar(false)
	hud.show_stats(false)
	map.unload()
	player.vanish()
	_timer_stop()
	game_active = false
	paused = false
	set_background()
	if show_score:
		Audio.play_game_over()
		var pb := Save.submit_score(score)
		menus.show_game_over(score, pb, Save.has_any_checkpoint())


# --- dev menu ----------------------------------------------------------------


## Start a normal game at any level (dev menu).
func dev_go_to_level(n: int) -> void:
	menus.close()
	new_game(clampi(n, 1, levels.size()))


## Move on to the next level without finishing this one (dev menu).
func dev_skip_level() -> void:
	if not game_active:
		return
	menus.close()
	end_of_level_points = 0
	next_level()


# --- menus -----------------------------------------------------------------


func show_start_menu() -> void:
	Audio.play_menu()
	menus.show_main(Save.highscore, Save.has_any_checkpoint())


func show_pause_menu() -> void:
	_timer_stop()
	paused = true
	menus.show_pause(tutorial)


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
		"main menu":
			if game_active:
				game_over(false)
			show_start_menu()
		"confirm quit":
			menus.show_confirm_quit()
		"end game", "end tutorial":
			game_over(false)
			show_start_menu()
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
			tilt.calibrate()
			_held_step = Vector2i.ZERO
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
			if act.begins_with("L") and act.substr(1).is_valid_int():
				menus.close()
				new_game(int(act.substr(1)) + 1)


# --- input -----------------------------------------------------------------


func _can_pause() -> bool:
	return (
		game_active
		and not dead
		and not menus.visible
		and (tutorial or (_timer_running and _seconds_remaining() <= 19))
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
