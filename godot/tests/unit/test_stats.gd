extends GutTest
## Play stats (Stats, docs/stats.md): nothing is kept or sent without a yes,
## no forgets the ID, the question comes once (and again six months after a
## yes), and the game's level events carry what they say.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var game


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Stats.persist = false
	Stats.send_on = false


func before_each() -> void:
	Stats.key = "phc_test"
	Stats.answer = ""
	Stats.answered_at = 0
	Stats.install_id = ""
	Stats.queue.clear()


func after_each() -> void:
	Stats.key = ""
	Stats.answer = ""
	Stats.install_id = ""
	Stats.queue.clear()


func _names() -> Array:
	return Stats.queue.map(func(e: Dictionary) -> String: return e.event)


func test_nothing_is_queued_before_an_answer() -> void:
	Stats.event("level_start", {"level": 1})
	assert_eq(Stats.queue.size(), 0)
	assert_true(Stats.should_ask())


func test_no_key_means_no_question_and_no_stats() -> void:
	Stats.key = ""
	assert_false(Stats.should_ask())
	Stats.choose(true)
	Stats.event("level_start")
	assert_eq(Stats.queue.size(), 0)


func test_yes_starts_a_random_id_and_queues_events() -> void:
	Stats.choose(true)
	assert_false(Stats.should_ask())
	assert_eq(Stats.install_id.length(), 36)
	Stats.event("level_start", {"level": 3})
	var e: Dictionary = Stats.queue[-1]
	assert_eq(e.event, "level_start")
	assert_eq(e.distinct_id, Stats.install_id)
	assert_eq(e.properties.level, 3)
	assert_false(e.properties["$process_person_profile"], "no person profiles")


func test_no_forgets_the_id_and_what_was_waiting() -> void:
	Stats.choose(true)
	var first := Stats.install_id
	Stats.event("level_start")
	Stats.choose(false)
	assert_eq(Stats.install_id, "")
	assert_eq(Stats.queue.size(), 0)
	assert_false(Stats.should_ask(), "a no is not asked again")
	Stats.event("level_start")
	assert_eq(Stats.queue.size(), 0)
	Stats.choose(true)
	assert_ne(Stats.install_id, first, "a new yes is a new ID")


func test_a_yes_is_asked_again_after_six_months() -> void:
	Stats.choose(true)
	Stats.answered_at -= Stats.REASK_SECONDS + 1
	assert_true(Stats.should_ask())


func test_the_queue_keeps_only_the_newest_events_offline() -> void:
	Stats.choose(true)
	Stats.queue.clear()
	for i in Stats.KEEP_AT_MOST + 5:
		Stats.queue.append({"event": "x"})
	Stats.event("last")
	assert_eq(Stats.queue.size(), Stats.KEEP_AT_MOST)
	assert_eq(Stats.queue[-1].event, "last")


func test_the_question_comes_before_the_main_menu() -> void:
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	game.show_start_menu()
	assert_eq(game.menus.current, "stats_question")
	game._on_menu_action("stats no")
	assert_eq(Stats.answer, "no")
	assert_eq(game.menus.current, "main")


func test_privacy_sheet_turns_stats_on_and_off() -> void:
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	Stats.choose(false)
	game._on_menu_action("options")
	game._on_menu_action("privacy")
	assert_eq(game.menus.current, "privacy")
	game._on_menu_action("stats on")
	assert_true(Stats.on())
	game._on_menu_action("stats off")
	assert_false(Stats.on())


func test_a_level_sends_start_life_lost_and_clear() -> void:
	Stats.choose(true)
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	game.new_game(5)
	game.map._load_elapsed = game.map._load_time
	game.loaded()
	game.lose_life("death")
	game.advance_level(false)
	var names := _names()
	assert_has(names, "level_start")
	assert_has(names, "life_lost")
	assert_has(names, "level_clear")
	var lost: Dictionary = Stats.queue[names.find("life_lost")].properties
	assert_eq(lost.level, 5)
	assert_eq(lost.mode, "main")
	assert_eq(lost.reason, "death")
	assert_true(lost.has("x") and lost.has("y"), "where the life was lost")
