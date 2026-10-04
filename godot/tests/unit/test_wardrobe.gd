extends GutTest
## The wardrobe (docs/wardrobe): the list of looks, what a save earns and
## keeps, and which clears release a look.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const OLD_SAVE := "user://test_wardrobe_old_save.cfg"
const TIER_ORDER := ["start", "common", "uncommon", "rare", "epic", "legendary", "special"]

var game


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Dev.enabled = false


func before_each() -> void:
	Save.worn = "classic"
	Save.released.clear()
	Save.seen.clear()
	Save.furthest_level = 1
	Save.has_completed = false
	Save.first_play = false


func after_each() -> void:
	Save.worn = "classic"
	Save.released.clear()
	Save.seen.clear()
	Save.furthest_level = 1
	Save.has_completed = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OLD_SAVE))


## A game of ten one-row levels.
func _game() -> void:
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	var levels := []
	for n in 10:
		(
			levels
			. append(
				{
					"number": n + 1,
					"rows": ["bw"],
					"loading": null,
					"delay": 0.0,
					"x_hides": 25,
					"checkpoint": false,
					"message": "",
				}
			)
		)
	game.levels = levels
	game.menus.close()


func _clear(level: int) -> void:
	game.new_game(level)
	game.map._load_elapsed = game.map._load_time
	game.advance_level(false)


func _save_file(values: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for section: String in values:
		for key: String in values[section]:
			cfg.set_value(section, key, values[section][key])
	cfg.save(OLD_SAVE)


# --- the list -------------------------------------------------------------------


func test_a_look_for_every_fifth_level_and_one_for_the_end() -> void:
	var levels := []
	for entry: Dictionary in Wardrobe.LOOKS:
		levels.append(entry.level)
	var expected := [0]
	for n in range(5, 101, 5):
		expected.append(n)
	expected.append(Wardrobe.THE_END)
	assert_eq(levels, expected, "Classic, then 5, 10 .. 100, then the end")


func test_ids_are_unique_and_known_to_the_outfits() -> void:
	var ids := Wardrobe.ids()
	for id in ids:
		assert_eq(ids.count(id), 1, "one look called " + id)
	assert_eq(ids[0], "classic")
	assert_eq(ids[-1], "mapwoman", "MapWoman comes last, for finishing")


func test_rarer_looks_come_later() -> void:
	var last := 0
	for entry: Dictionary in Wardrobe.LOOKS:
		var tier: int = TIER_ORDER.find(entry.tier)
		assert_gt(tier, -1, "%s has a known tier" % entry.id)
		assert_true(tier >= last, "%s is no commoner than the one before" % entry.id)
		last = tier
		assert_true(Wardrobe.TIERS.has(entry.tier))


func test_which_clear_releases_which_look() -> void:
	assert_eq(Wardrobe.released_at(5), "party_hat")
	assert_eq(Wardrobe.released_at(35), "cowboy")
	assert_eq(Wardrobe.released_at(100), "gold")
	assert_eq(Wardrobe.released_at(6), "", "only every 5th level")
	assert_eq(Wardrobe.released_at(0), "", "Classic isn't released by a level")
	assert_eq(Wardrobe.released_at(Wardrobe.THE_END), "", "MapWoman comes with the ending")


func test_what_progress_has_earned() -> void:
	assert_eq(Wardrobe.earned(1, false), ["classic"] as Array[String])
	var at_36 := Wardrobe.earned(36, false)
	assert_true("cowboy" in at_36, "level 35 is behind him")
	assert_false("hard_hat" in at_36)
	var at_100 := Wardrobe.earned(100, false)
	assert_false("gold" in at_100, "level 100 isn't cleared yet")
	assert_false("mapwoman" in at_100)
	assert_eq(Wardrobe.earned(100, true).size(), Wardrobe.LOOKS.size(), "finishing earns all")


# --- the save -------------------------------------------------------------------


func test_a_save_from_before_the_wardrobe_gets_what_it_earned() -> void:
	_save_file({"progress": {"furthest_level": 41, "has_completed": false}})
	Save.load_all(OLD_SAVE)
	var expected: Array[String] = [
		"party_hat",
		"signal_red",
		"bobble_hat",
		"racing_green",
		"shades",
		"blueprint",
		"cowboy",
		"hard_hat",
	]
	assert_eq(Save.released, expected, "every look up to level 40, in release order")
	assert_eq(Save.worn, "classic")
	assert_eq(Save.unseen(), expected.size(), "and all of them are NEW")


func test_a_finished_save_gets_every_look() -> void:
	_save_file({"progress": {"has_completed": true}})
	Save.load_all(OLD_SAVE)
	assert_eq(Save.released.size(), Wardrobe.LOOKS.size() - 1, "all but Classic, always there")
	assert_true(Save.is_released("gold"), "level 100 counts once the game is finished")
	assert_true(Save.is_released("mapwoman"))


func test_the_wardrobe_round_trips() -> void:
	_save_file(
		{
			"progress": {"furthest_level": 12},
			"wardrobe":
			{"worn": "signal_red", "released": ["party_hat", "signal_red"], "seen": ["party_hat"]},
		}
	)
	Save.load_all(OLD_SAVE)
	assert_eq(Save.worn, "signal_red")
	assert_eq(Save.released, ["party_hat", "signal_red"] as Array[String])
	assert_eq(Save.unseen(), 1)


func test_bad_entries_are_dropped_and_bad_wear_falls_back() -> void:
	_save_file(
		{
			"wardrobe":
			{"worn": "wizard", "released": ["cowboy", "cowboy", "jetpack", "classic", 7]},
		}
	)
	Save.load_all(OLD_SAVE)
	assert_eq(Save.released, ["cowboy"] as Array[String], "known looks, once each")
	assert_eq(Save.worn, "classic", "the wizard was never released")


func test_only_released_looks_can_be_worn() -> void:
	assert_false(Save.wear("wizard"))
	assert_eq(Save.worn, "classic")
	assert_true(Save.release("wizard"))
	assert_false(Save.release("wizard"), "released once")
	assert_false(Save.release("classic"), "always there")
	assert_false(Save.release("jetpack"))
	assert_true(Save.wear("wizard"))
	assert_eq(Save.worn, "wizard")
	assert_true(Save.wear("classic"), "Classic can always be worn again")


# --- releases in play -------------------------------------------------------------


func test_the_first_clear_of_a_5th_level_releases_its_look() -> void:
	_game()
	_clear(5)
	assert_eq(Save.released, ["party_hat"] as Array[String])
	assert_eq(game.menus.current, "end_level")


func test_clearing_it_again_releases_nothing_more() -> void:
	_game()
	_clear(5)
	_clear(5)
	assert_eq(Save.released, ["party_hat"] as Array[String])


func test_other_levels_release_nothing() -> void:
	_game()
	_clear(6)
	assert_eq(Save.released.size(), 0)


func test_practice_releases_nothing() -> void:
	_game()
	Save.furthest_level = 10
	game.start_practice(5)
	game.map._load_elapsed = game.map._load_time
	game.advance_level(false)
	assert_eq(Save.released.size(), 0, "looks come from the main game")


func test_the_tutorial_releases_nothing() -> void:
	_game()
	game.new_game(mini(5, game.tutorial_levels.size()), true)
	game.map._load_elapsed = game.map._load_time
	game.advance_level(false)
	assert_eq(Save.released.size(), 0)


func test_finishing_the_game_releases_mapwoman() -> void:
	_game()
	game.levels = [game.levels[0]]
	game.new_game(1)
	game.end_of_level_points = 0
	game.next_level()
	assert_true(game.completed)
	assert_true(Save.is_released("mapwoman"))
	assert_true(game._mapwoman_released, "so the last sheet can say so")


func test_a_new_game_wears_the_worn_look() -> void:
	_game()
	Save.release("cowboy")
	Save.wear("cowboy")
	game.new_game(1)
	assert_eq(game.player.outfit, "cowboy")


func test_wearing_from_the_wardrobe() -> void:
	_game()
	Save.release("shades")
	game._on_menu_action("wear shades")
	assert_eq(Save.worn, "shades")
	assert_eq(game.player.outfit, "shades")
	assert_eq(game.menus.current, "wardrobe")
	game._on_menu_action("wear wizard")
	assert_eq(Save.worn, "shades", "a look not released stays in the wardrobe")


func test_opening_the_wardrobe_sees_everything_in_it() -> void:
	_game()
	Save.release("party_hat")
	Save.release("signal_red")
	assert_eq(Save.unseen(), 2)
	game._on_menu_action("wardrobe")
	assert_eq(game.menus.current, "wardrobe")
	assert_eq(Save.unseen(), 0)
