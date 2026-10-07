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
	Save.new_lessons = false


func after_each() -> void:
	Save.worn = "classic"
	Save.released.clear()
	Save.seen.clear()
	Save.furthest_level = 1
	Save.has_completed = false
	Save.rev_b = false
	Save.track_b = Save.Track.new()
	Blueprint.revise(false)
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
		# A misspelt id in a part file would quietly draw as Classic.
		if id != "classic" and id != "mapwoman":
			assert_true(_outfits_know(id), id + ": the outfits colour or draw it")
	assert_eq(ids[0], "classic")
	assert_eq(Wardrobe.LOOKS[-1].id, "mapwoman", "MapWoman comes last of his, for finishing")
	assert_eq(ids.size(), Wardrobe.LOOKS.size() + Wardrobe.HERS.size(), "then hers")


## Whether the outfits do anything for a look: its own colours, or a part in
## some layer, drawn with a measuring pen on the pose a Player leaves in it.
func _outfits_know(id: String) -> bool:
	if not Outfits.palette(id).is_empty():
		return true
	var p := Player.new()
	p.outfit = id
	p.measure()
	var pen: OutfitPen = p._pen
	pen.begin(p, true)
	pen.set_frame(Vector2.ZERO, 0.0, Vector2.ONE)
	for layer in Outfits.Layer.values():
		Outfits.draw(pen, layer, id)
	var drawn := pen.bounds.has_area()
	drawn = Outfits.head_shape(pen, id, Color.WHITE) or drawn
	drawn = Outfits.eyes(pen, id, Color.WHITE) or drawn
	p.free()
	return drawn


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


# --- her wardrobe -------------------------------------------------------------------


func test_she_has_a_look_for_every_fifth_sheet_of_revision_b() -> void:
	var levels := []
	for entry: Dictionary in Wardrobe.HERS:
		levels.append(entry.level)
		assert_true(Wardrobe.is_hers(entry.id), entry.id + " is hers")
		assert_false(Outfits.palette(entry.id).is_empty() and not _outfits_know(entry.id))
	var expected := []
	for n in range(5, 101, 5):
		expected.append(n)
	assert_eq(levels, expected, "5, 10 .. 100")
	var last := 0
	for entry: Dictionary in Wardrobe.HERS:
		var tier: int = TIER_ORDER.find(entry.tier)
		assert_gt(tier, -1, "%s has a known tier" % entry.id)
		assert_true(tier >= last, "%s is no commoner than the one before" % entry.id)
		last = tier
	assert_true(Wardrobe.is_hers("mapwoman"))
	assert_false(Wardrobe.is_hers("cowboy"))
	assert_eq(Wardrobe.her_list()[0].id, "mapwoman", "her page starts with her")
	assert_eq(Wardrobe.her_list().size(), Wardrobe.HERS.size() + 1)


func test_which_revision_b_clear_releases_which_look_of_hers() -> void:
	assert_eq(Wardrobe.released_at(5, true), "sky_blue")
	assert_eq(Wardrobe.released_at(100, true), "platinum")
	assert_eq(Wardrobe.released_at(6, true), "", "only every 5th sheet")
	assert_eq(Wardrobe.released_at(5, false), "party_hat", "the first game releases his")


func test_what_revision_b_progress_has_earned() -> void:
	assert_eq(Wardrobe.earned_hers(1).size(), 0)
	var at_31 := Wardrobe.earned_hers(31)
	assert_true("footballer" in at_31, "sheet 30 is behind her")
	assert_false("chef" in at_31)
	assert_false("platinum" in Wardrobe.earned_hers(100), "sheet 100 isn't cleared yet")


func test_a_save_with_revision_b_progress_gets_her_looks() -> void:
	_save_file({"progress": {"has_completed": true}, "rev_b": {"furthest_level": 21}})
	Save.load_all(OLD_SAVE)
	assert_true(Save.is_released("mapwoman"))
	for id in ["sky_blue", "beret", "headband", "sunflower"]:
		assert_true(Save.is_released(id), id + " came with sheet 20")
	assert_false(Save.is_released("goggles"), "sheet 25 isn't cleared yet")
	assert_eq(Save.released.size(), Wardrobe.LOOKS.size() - 1 + 4)


func test_the_first_clear_of_a_5th_sheet_of_revision_b_releases_her_look() -> void:
	_game()
	Save.has_completed = true
	Save.release("mapwoman")
	game.revision_b.start(5)
	game.map._load_elapsed = game.map._load_time
	game.advance_level(false)
	assert_true(Save.is_released("sky_blue"), "her look, not his")
	assert_false(Save.is_released("party_hat"))
	assert_eq(game.menus.current, "end_level")
	game.advance_level(false)
	assert_eq(Save.released, ["mapwoman", "sky_blue"] as Array[String], "released once")


func test_the_first_game_releases_nothing_of_hers() -> void:
	_game()
	_clear(5)
	assert_false(Save.is_released("sky_blue"))


func test_wearing_one_of_hers_makes_the_player_her() -> void:
	_game()
	Save.release("mapwoman")
	Save.release("chef")
	game._on_menu_action("wear chef")
	assert_eq(game.player.outfit, "chef")
	assert_eq(game.menus.current, "wardrobe")
	assert_true(_on_her_page(), "and the wardrobe stays on her page")
	# The player is her in it: MapMan waits at the end, as when she is worn.
	game.menus.close()
	game.levels = [game.levels[0]]
	game.new_game(1)
	game.end_of_level_points = 0
	game.next_level()
	assert_eq(game._woman.art, "man", "MapMan waits for her")


func test_her_page_opens_once_she_has_joined() -> void:
	_game()
	game._on_menu_action("wardrobe")
	assert_null(_button(tr("MAPWOMAN >")), "no page of hers before the game is finished")
	assert_false(_on_her_page())
	Save.release("mapwoman")
	game._on_menu_action("wardrobe")
	assert_not_null(_button(tr("MAPWOMAN >")))
	game._on_menu_action("her wardrobe")
	assert_eq(game.menus.current, "wardrobe")
	assert_true(_on_her_page())
	assert_not_null(_button(tr("<  MAPMAN")))
	assert_null(_button(tr("MAPWOMAN >")))
	game._on_menu_action("his wardrobe")
	assert_false(_on_her_page())
	# Worn, she opens the wardrobe on her page.
	Save.wear("mapwoman")
	game._on_menu_action("wardrobe")
	assert_true(_on_her_page())


func test_the_main_menu_counts_her_looks_once_she_has_joined() -> void:
	_game()
	game.show_start_menu()
	assert_not_null(_label("1/%d" % Wardrobe.LOOKS.size()))
	Save.release("mapwoman")
	Save.release("sky_blue")
	game.show_start_menu()
	assert_not_null(_label("3/%d" % (Wardrobe.LOOKS.size() + Wardrobe.HERS.size())))


## Whether the wardrobe open now is her page, by its heading.
func _on_her_page() -> bool:
	return game.menus._header.text.ends_with(tr("MAPWOMAN'S WARDROBE"))


## A label on the sheet open now (a closed sheet is still in the tree until
## the end of the frame).
func _label(text: String) -> Label:
	for l in game.menus._panel.find_children("*", "Label", true, false):
		if l.text == text or l.text.ends_with(text):
			return l
	return null


func _button(text: String) -> Button:
	for b in game.menus._panel.find_children("*", "Button", true, false):
		if b.text == text:
			return b
	return null


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
	Save.furthest_level = 12
	Save.release("party_hat")
	Save.release("signal_red")
	Save.wear("signal_red")
	Save.seen.assign(["party_hat"])
	# Written the way the game writes it, into a file of the test's own.
	Save.persist = true
	Save.save_all(OLD_SAVE)
	Save.persist = false
	Save.worn = "classic"
	Save.released.clear()
	Save.seen.clear()
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
	game._on_menu_action("completion done")
	assert_eq(game.menus.current, "congratulations")
	var texts := []
	for l in game.menus.find_children("*", "Label", true, false):
		texts.append(l.text)
	assert_has(texts, tr("MAPWOMAN JOINS THE WARDROBE"), "and the last sheet says so")


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


func test_leaving_the_wardrobe_has_seen_everything_in_it() -> void:
	_game()
	Save.release("party_hat")
	Save.release("signal_red")
	assert_eq(Save.unseen(), 2)
	game._on_menu_action("wardrobe")
	assert_eq(game.menus.current, "wardrobe")
	game._on_menu_action("wear party_hat")
	assert_eq(Save.unseen(), 2, "still marked new while the sheet is open")
	game._on_menu_action("main menu")
	assert_eq(Save.unseen(), 0, "seen once the sheet is left")
