extends GutTest
## The Blueprint look: the vector MapMan's dials, the reduce-motion switch,
## the HUD's state colour and the map's fold and float animations.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var game


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Dev.enabled = false
	Save.set_locale("en")  # the English these tests read, whatever the machine's


func after_all() -> void:
	Save.set_locale("")


func before_each() -> void:
	Save.reduce_motion = false
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	game.menus.close()


func after_each() -> void:
	Save.reduce_motion = false


func _start(row: String) -> void:
	game.levels = [{"rows": [row], "delay": 0.0}]
	game.new_game(1)
	game.map._load_elapsed = game.map._load_time
	game.loaded()


func _step_on(x: int) -> void:
	game.map.position_key = Vector2i(x, 0)
	game.update_player(0.0)


# --- MapMan ---------------------------------------------------------------


func test_death_plays_out_then_finishes() -> void:
	_start("bdcw")
	_step_on(1)
	assert_true(game.dead)
	assert_false(game.player.death_finished(), "the animation takes time")
	game.player.update_at(Vector2.ZERO, Player.DEATH_SECONDS)
	assert_true(game.player.death_finished())


func test_new_attempt_resets_his_pose() -> void:
	_start("bdcw")
	_step_on(1)
	game.player.dead = 1.0
	game.player.web = 1.0
	game.reset_all()
	assert_eq(game.player.dead, 0.0, "back on his feet")
	assert_eq(game.player.web, 0.0, "and free of cobweb")
	assert_false(game.player.death_finished())


func test_sticky_tile_webs_him_and_a_shake_frees_him() -> void:
	Save.reduce_motion = true  # instant, so the values can be read at once
	_start("bycw")
	_step_on(1)
	assert_true(game.stuck)
	assert_eq(game.player.web, 1.0, "wrapped in cobweb")
	game.stuck = false
	assert_eq(game.player.web, 0.0, "shaken off")


func test_stuck_again_soon_after_a_shake_still_webs_him() -> void:
	_start("bycyw")
	_step_on(1)
	game.stuck = false  # the shake-off starts playing
	await wait_seconds(0.1)
	_step_on(3)
	assert_true(game.stuck)
	await wait_seconds(0.7)
	assert_almost_eq(game.player.web, 1.0, 0.01, "wrapped again, old shake-off stopped")
	assert_eq(game.player.shake_off, 0.0)


func test_timeout_mid_step_lands_before_dying() -> void:
	_start("bccw")
	game.move(Vector2i.RIGHT, 0.2)
	assert_true(game.map.moving)
	game.lose_life("timeout")
	game._process(0.5)  # a dead frame still finishes the step
	assert_false(game.map.moving)
	assert_eq(game.map.position_key, Vector2i(1, 0), "died on a tile, not between two")


func test_death_colour_beats_hidden_tiles() -> void:
	_start("bhdw")
	_step_on(1)
	assert_true(game.map.tiles_hidden)
	assert_eq(game.hud.frame.default_color, Blueprint.MINT)
	_step_on(2)
	assert_true(game.dead)
	assert_eq(game.hud.frame.default_color, Blueprint.PINK)


func test_vanish_note_counts_moves_in_the_singular() -> void:
	_start("b1cw")
	_step_on(1)
	assert_eq(game.vanish, 1)
	assert_eq(game.hud.note_label.text, "SEE YOU AGAIN IN 1 MOVE")


func test_checkpoint_flag_stands_on_the_exit() -> void:
	game.levels = [{"rows": ["bcw"], "delay": 0.0, "checkpoint": true}]
	game.new_game(1)
	assert_not_null(game.map.checkpoint_flag)
	var exit_pos: Vector2 = game.map.tiles[Vector2i(2, 0)].position
	assert_eq(game.map.checkpoint_flag.position, exit_pos - Vector2(0, LevelMap.TILE_H / 2.0))


func test_map_sits_between_the_strips() -> void:
	_start("bcw")
	var y: float = game.map.tiles[Vector2i(0, 0)].position.y
	assert_almost_eq(y, LevelMap.CENTRE_Y, 0.001, "a one-row map sits on the band's centre")


func test_facing_flips_him_for_left() -> void:
	Save.reduce_motion = true
	_start("bccw")
	game.player.face_left()
	assert_eq(game.player.flip, -1.0)
	game.player.face_right_idle()
	assert_eq(game.player.flip, 1.0)
	assert_eq(game.player.walking, 0.0)


func test_vanish_hides_him_completely() -> void:
	_start("b3cw")
	_step_on(1)
	assert_true(game.player.is_hidden)
	assert_false(game.player.visible, "nothing of him is drawn")


func test_mapwoman_wears_the_bow() -> void:
	assert_eq(game._woman.art, "woman")
	assert_eq(game.player.art, "man")


# --- motion -----------------------------------------------------------------


func test_reduce_motion_switch() -> void:
	assert_true(Blueprint.motion())
	Save.reduce_motion = true
	assert_false(Blueprint.motion())


func test_reduce_motion_is_saved_with_the_options() -> void:
	game._on_menu_action("options")
	game._on_menu_action("reduce motion on")
	assert_true(Save.reduce_motion)
	assert_eq(game.menus.current, "options", "stays on the options sheet")
	game._on_menu_action("reduce motion off")
	assert_false(Save.reduce_motion)
	# And it survives the trip through the save file.
	var path := "user://test_reduce_motion.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("options", "reduce_motion", true)
	cfg.save(path)
	Save.load_all(path)
	assert_true(Save.reduce_motion, "read back from the options section")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_stamp_slams_only_with_motion() -> void:
	var still := Blueprint.stamp(game, "PASSED", Vector2.ZERO, Blueprint.GOLD, false)
	assert_eq(still.scale, Vector2.ONE)
	var slam := Blueprint.stamp(game, "PASSED", Vector2.ZERO, Blueprint.GOLD, true)
	assert_gt(slam.scale.x, 1.0, "starts large and drops onto the sheet")
	Save.reduce_motion = true
	var quiet := Blueprint.stamp(game, "PASSED", Vector2.ZERO, Blueprint.GOLD, true)
	assert_eq(quiet.scale, Vector2.ONE, "no slam with reduced motion")


func test_delayed_stamp_waits_before_it_slams() -> void:
	var late := Blueprint.stamp(game, "REWORK", Vector2.ZERO, Blueprint.PINK, true, 0.45)
	await wait_seconds(0.2)
	assert_eq(late.modulate.a, 0.0, "still in the air at 0.2 s")
	assert_gt(late.scale.x, 2.0)
	await wait_seconds(0.6)
	assert_almost_eq(late.modulate.a, 1.0, 0.01, "down by 0.8 s")
	assert_almost_eq(late.scale.x, 1.0, 0.01)


func test_truncated_line_keeps_a_share_of_its_length() -> void:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)])
	assert_eq(Blueprint.truncated(pts, 0.5), PackedVector2Array([Vector2(0, 0), Vector2(10, 0)]))
	assert_eq(
		Blueprint.truncated(pts, 0.75),
		PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 5)])
	)
	assert_eq(Blueprint.truncated(pts, 1.0), pts)


# --- the map ------------------------------------------------------------------


func _sprites() -> int:
	var n := 0
	for child in game.map.get_children():
		if child is Sprite2D:
			n += 1
	return n


func test_hiding_tiles_folds_stand_ins_away() -> void:
	_start("bhiiw")
	var before := _sprites()
	_step_on(1)
	assert_true(game.map.tiles_hidden)
	assert_false(game.map.tiles[Vector2i(2, 0)].sprite.visible, "hidden at once")
	assert_eq(_sprites(), before + 2, "a folding stand-in for each hidden tile")


func test_hiding_tiles_is_instant_with_reduced_motion() -> void:
	Save.reduce_motion = true
	_start("bhiiw")
	var before := _sprites()
	_step_on(1)
	assert_eq(_sprites(), before, "no stand-ins")


func test_collecting_floats_a_note() -> void:
	_start("bpcw")
	_step_on(1)
	var notes: Array = game.map.find_children("*", "Label", false, false)
	assert_eq(notes.size(), 1)
	assert_eq(notes[0].text, "+1 ★")


# --- the HUD --------------------------------------------------------------------


func test_frame_takes_the_effect_colour() -> void:
	_start("brcw")
	assert_eq(game.hud.frame.default_color, Blueprint.INK)
	_step_on(1)
	assert_true(game.reverse)
	assert_eq(game.hud.frame.default_color, Blueprint.PINK)
	game.reset_all()
	assert_eq(game.hud.frame.default_color, Blueprint.INK)


func test_header_shows_sheet_score_and_lives() -> void:
	_start("bcw")
	game._update_stats()
	assert_eq(game.hud.level_label.text, "SHEET 001 / 1")
	assert_eq(game.hud.score_label.text, "★ 0")
	assert_eq(game.hud.lives_label.text, "♥ 3")


func test_countdown_reads_as_a_dimension() -> void:
	_start("bcw")
	game.hud.set_timer(12, 11.5)
	assert_eq(game.hud.timer_label.text, "T-0:12")
	assert_almost_eq(game.hud.timer_line.share, 11.5 / Hud.TIMER_SPAN, 0.001)


func test_tutorial_fills_the_header_and_bar() -> void:
	game.tutorial_levels = [{"rows": ["brw"], "description": "Tilt to move.\nThen go."}]
	game.new_game(1, true)
	game._update_stats()
	assert_true(game.hud.level_label.visible)
	assert_eq(game.hud.level_label.text, "TUTORIAL 1 / 1")
	assert_false(game.hud.score_label.visible)
	assert_eq(game.hud.tutorial_label.text, "Tilt to move. Then go.", "one wrapped paragraph")
	# An effect's note goes up into the header, not over the lesson.
	game.map._load_elapsed = game.map._load_time
	game.loaded()
	_step_on(1)
	assert_true(game.reverse)
	assert_eq(game.hud.header_note.text, "CONTROLS REVERSED")
	assert_eq(game.hud.note_label.text, "")
	assert_eq(game.hud.effect_single.modulate.a, 0.0, "no icon in the bar during the lesson")


func test_lives_row_caps_its_discs() -> void:
	game.menus.show_lose_life(15, 7)
	var labels: Array = game.menus._panel.find_children("*", "Label", true, false)
	var texts := []
	for l in labels:
		texts.append(l.text)
	assert_has(texts, "+9", "six discs, then the rest as a number")


func test_final_sheet_pause_has_no_level() -> void:
	game.completed = true
	game.level = 101
	game.game_active = true
	game.show_pause_menu()
	var labels: Array = game.menus.find_children("*", "Label", true, false)
	var header := ""
	for l in labels:
		if String(l.text).begins_with("MAPMAN"):
			header = l.text
	assert_string_contains(header, "SHEET END-A")
