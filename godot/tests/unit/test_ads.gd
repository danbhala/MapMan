extends GutTest
## Ads (docs/ads.md): KEEP GOING once per game, DOUBLE IT on the level clear,
## the full-screen ad on NEXT now and then, and none of it on levels 1 to 10.
## Ads.fake stands in for AdMob: every ad is ready and rewards at once.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const LEVELS := 20

var game


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Dev.enabled = false


func before_each() -> void:
	Ads.fake = true
	Ads.reset()
	Save.reduce_motion = true
	Save.worn = "classic"
	Save.released.clear()
	Save.seen.clear()
	Save.checkpoints.clear()
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	var levels := []
	for n in LEVELS:
		levels.append({"number": n + 1, "rows": ["bw"], "checkpoint": false, "message": ""})
	game.levels = levels
	game.menus.close()


func after_each() -> void:
	Ads.fake = false
	Ads.reset()
	Save.reduce_motion = false
	Save.released.clear()
	Save.seen.clear()
	Save.checkpoints.clear()


func _start(level: int) -> void:
	game.new_game(level)
	game.map._load_elapsed = game.map._load_time
	game.loaded()


## Clear `level` of a fresh game: its level clear is up.
func _clear(level: int) -> void:
	_start(level)
	game.advance_level(false)
	assert_eq(game.menus.current, "end_level")


func _lose_last_life() -> void:
	game.lives = 1
	game.lose_life()
	game.finish_lose_life()


# --- KEEP GOING -----------------------------------------------------------


func test_keep_going_gives_one_life_back_on_the_same_sheet() -> void:
	_start(15)
	_lose_last_life()
	assert_eq(game.menus.current, "lose_life", "offered instead of game over")
	assert_true(game.game_active)
	game._on_menu_action("keep going")
	assert_eq(game.lives, 1)
	assert_eq(game.level, 15)
	assert_eq(game.menus.current, "")
	assert_true(game.game_active)


func test_keep_going_is_once_per_game() -> void:
	_start(15)
	_lose_last_life()
	game._on_menu_action("keep going")
	_lose_last_life()
	assert_false(game.game_active, "the second time, the game is over")
	_start(15)
	_lose_last_life()
	assert_eq(game.menus.current, "lose_life", "a new game offers it again")


func test_end_the_game_ends_it() -> void:
	_start(15)
	_lose_last_life()
	game._on_menu_action("give up")
	assert_false(game.game_active)


func test_no_keep_going_on_the_free_levels() -> void:
	_start(Ads.FREE_LEVELS)
	_lose_last_life()
	assert_false(game.game_active)


func test_no_keep_going_with_ads_off_or_no_ad() -> void:
	Ads.off = true
	_start(15)
	_lose_last_life()
	assert_false(game.game_active)


# --- DOUBLE IT ------------------------------------------------------------


func test_double_it_doubles_the_sheets_points() -> void:
	_clear(16)  # 15 releases a look, whose slip takes DOUBLE IT's place
	var before: int = game.end_of_level_points
	assert_eq(game.menus._clear_args[9].get("double"), -1, "on offer")
	game._on_menu_action("double it")
	assert_eq(game.end_of_level_points, before * 2)
	assert_eq(game.menus._clear_args[9].get("double"), before, "spent")
	assert_eq(game.menus.current, "end_level")
	var score: int = game.score
	game._on_menu_action("next level")
	assert_eq(game.score, score + before * 2, "both halves banked")


func test_no_double_it_on_the_free_levels() -> void:
	_clear(Ads.FREE_LEVELS)
	assert_false(game.menus._clear_args[9].has("double"))


# --- the full-screen ad ---------------------------------------------------


func test_full_screen_ad_pacing() -> void:
	assert_false(Ads.interstitial_due(Ads.FREE_LEVELS + 1), "no clears yet")
	for n in Ads.CLEARS_PER_INTERSTITIAL:
		Ads.note_clear(Ads.FREE_LEVELS + 1 + n)
	assert_true(Ads.interstitial_due(14))
	assert_false(Ads.interstitial_due(Ads.FREE_LEVELS), "never on a free level")
	Ads.show_interstitial(func() -> void: pass)
	for n in Ads.CLEARS_PER_INTERSTITIAL:
		Ads.note_clear(20)
	assert_false(Ads.interstitial_due(20), "not within minutes of the last ad")


func test_a_rewarded_ad_holds_off_the_full_screen_one() -> void:
	for n in Ads.CLEARS_PER_INTERSTITIAL:
		Ads.note_clear(15)
	Ads.show_rewarded("double_it", func(_earned: bool) -> void: pass)
	assert_false(Ads.interstitial_due(15))


func test_free_level_clears_do_not_count() -> void:
	for n in 10:
		Ads.note_clear(n + 1)
	assert_false(Ads.interstitial_due(Ads.FREE_LEVELS + 1))


func test_next_still_goes_on_after_the_full_screen_ad() -> void:
	Ads.every_clear = true
	_clear(15)
	game._on_menu_action("next level")
	assert_eq(game.level, 16)
	assert_eq(game.menus.current, "")


func test_ads_off_means_no_full_screen_ad() -> void:
	Ads.every_clear = true
	Ads.set_off(true)
	assert_false(Ads.interstitial_due(15))
	assert_false(Ads.rewarded_ready("keep_going"))
