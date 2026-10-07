extends GutTest
## The Toolbox: the star bank a cleared sheet pays into, the tree of tools
## bought from it, Fresh Sheet, the belt, and each tool at work on a sheet
## (scripts/toolbox.gd, the rules in docs/toolbox.md).

const MAIN_SCENE := preload("res://scenes/main.tscn")

var game


func before_all() -> void:
	Save.persist = false  # never touch the player's real progress
	Dev.persist = false
	Dev.enabled = false


func before_each() -> void:
	Save.reduce_motion = true
	Save.fx_on = false
	Save.bank = 0
	Save.tools = {}
	Save.belt = []
	Save.banked = {}
	Save.fresh_sheet = false
	Save.has_completed = false
	Save.furthest_level = 1
	Save.rev_b = false


func after_each() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "shake"]:
		Input.action_release(action)
	Engine.time_scale = 1.0


## A one-row level: the player starts on "b" (column 0) and walks right.
func _start(row: String, extra_rows: Array = [], loading = null) -> void:
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	var rows: Array = extra_rows.duplicate()
	rows.append(row)
	game.levels = [
		{
			"number": 1,
			"rows": rows,
			"loading": loading,
			"delay": 0.0,
			"x_hides": 25,
			"checkpoint": false,
			"message": "",
		}
	]
	game.menus.close()
	game.new_game(1)
	game.map._load_elapsed = game.map._load_time  # skip the appear animation
	game.loaded()


## `id` owned at `tier` and on the belt, as a bought tool is.
func _own(id: String, tier := 1) -> void:
	Save.tools[id] = tier
	if id not in Save.belt:
		Save.belt.append(id)


## Put MapMan on column x of the bottom row and apply that tile's rule.
func _step_on(x: int) -> void:
	var row: int = game.map.start_position.y
	game.map.position_key = Vector2i(x, row)
	game.update_player(0.0)


## A tap (press and release) on the field at the tile in column x.
func _tap_tile(x: int) -> void:
	var tile = game.map.tiles[Vector2i(x, game.map.start_position.y)]
	var at: Vector2 = game.map.global_position + tile.position
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		assert_true(game.toolbox.field_tap(e), "the tap went to the tool")


# --- the bank -----------------------------------------------------------------


func test_a_sheet_pays_its_stars_once() -> void:
	var paid := Toolbox.bank_sheet(Save, "A35", 2, true)
	assert_eq(paid, {"tiles": 2, "clear": 1, "quick": 1, "total": 4})
	assert_eq(Save.bank, 4)
	paid = Toolbox.bank_sheet(Save, "A35", 3, false)
	assert_eq(paid.total, 1, "only the third star tile is new")
	assert_eq(Save.bank, 5)
	paid = Toolbox.bank_sheet(Save, "A35", 3, true)
	assert_eq(paid.total, 0, "the quick star was paid on the first clear")
	assert_eq(Toolbox.bank_sheet(Save, "B35", 0, false).total, 1, "Revision B's sheet is its own")


func test_the_bank_never_comes_from_practice_or_the_tutorial() -> void:
	_start("bcw")
	game.practice = true
	assert_true(game.toolbox.enabled(), "tools work in practice")
	game.practice = false
	game.tutorial = true
	assert_false(game.toolbox.enabled(), "no tools in the tutorial")
	game.tutorial = false
	game.custom = "draft"
	assert_false(game.toolbox.enabled(), "a drafting table level is played as drawn")
	game.custom = ""
	assert_true(game.toolbox.enabled())


func test_the_tree_costs_more_than_the_sheets_pay() -> void:
	assert_eq(Toolbox.tree_price(), 1455)
	assert_eq(Toolbox.TOOLS.size(), 9)
	for tool in Toolbox.TOOLS:
		assert_eq(tool.tiers.size(), Toolbox.TIERS, tool.id + " has three tiers")
		for t in Toolbox.TIERS - 1:
			assert_gt(tool.tiers[t + 1].price, tool.tiers[t].price, tool.id + " tiers cost more")


# --- buying ---------------------------------------------------------------------


func test_tools_are_bought_tier_by_tier_from_the_bank() -> void:
	Save.bank = 20
	assert_true(Toolbox.buy(Save, "eraser"))
	assert_eq(Save.tool_tier("eraser"), 1)
	assert_eq(Save.bank, 5, "tier I of the Eraser cost 15")
	assert_false(Toolbox.buy(Save, "eraser"), "tier II costs 30: too dear")
	assert_eq(Save.tool_tier("eraser"), 1)
	Save.bank = 30
	assert_true(Toolbox.buy(Save, "eraser"))
	assert_eq(Save.tool_tier("eraser"), 2)
	assert_eq(Toolbox.spent_stars(Save), 45)
	assert_eq(Toolbox.still_needed(Save), 1455 - 45)


func test_a_tool_opens_once_the_one_above_it_is_owned() -> void:
	Save.bank = 500
	assert_false(Toolbox.unlocked("peek", Save), "the Light Table waits on the Eraser")
	assert_false(Toolbox.buy(Save, "peek"))
	assert_true(Toolbox.buy(Save, "eraser"))
	assert_true(Toolbox.unlocked("peek", Save))
	assert_true(Toolbox.buy(Save, "peek"))
	assert_true(Toolbox.unlocked("pin", Save), "and the Push Pin on the Light Table")
	assert_true(Toolbox.unlocked("hop", Save), "each branch starts open")
	assert_true(Toolbox.unlocked("slow", Save))
	assert_eq(Toolbox.above("pin"), "peek")
	assert_eq(Toolbox.above("eraser"), "")


func test_fresh_sheet_takes_every_star_back() -> void:
	Save.bank = 100
	assert_true(Toolbox.buy(Save, "eraser"))
	assert_true(Toolbox.buy(Save, "hop"))
	assert_true(Toolbox.set_on_belt(Save, "eraser", true))
	assert_false(Toolbox.refund(Save), "Fresh Sheet is not owned yet")
	assert_true(Toolbox.buy_fresh_sheet(Save))
	assert_eq(Save.bank, 100 - 15 - 15 - Toolbox.FRESH_SHEET_PRICE)
	assert_false(Toolbox.buy_fresh_sheet(Save), "it is bought once")
	assert_true(Toolbox.refund(Save))
	assert_eq(Save.bank, 100 - Toolbox.FRESH_SHEET_PRICE, "the tools' stars came back, not its own")
	assert_eq(Save.tools, {})
	assert_eq(Save.belt, [] as Array[String])
	assert_true(Save.fresh_sheet, "and it is still owned")
	assert_false(Toolbox.refund(Save), "nothing to take back now")


# --- the belt -------------------------------------------------------------------


func test_the_belt_holds_two_tools_then_three_at_sheet_fifty() -> void:
	Save.bank = 500
	for id in ["eraser", "hop", "slow"]:
		assert_true(Toolbox.buy(Save, id))
	assert_eq(Toolbox.belt_slots(Save), 2)
	assert_true(Toolbox.set_on_belt(Save, "eraser", true))
	assert_true(Toolbox.set_on_belt(Save, "hop", true))
	assert_false(Toolbox.set_on_belt(Save, "slow", true), "the belt is full")
	assert_false(Toolbox.set_on_belt(Save, "freeze", true), "a tool not owned can't go on")
	Save.furthest_level = 50
	assert_eq(Toolbox.belt_slots(Save), 3)
	assert_true(Toolbox.set_on_belt(Save, "slow", true))
	assert_eq(Save.belt, ["eraser", "hop", "slow"] as Array[String])
	assert_true(Toolbox.set_on_belt(Save, "hop", false))
	assert_eq(Save.belt, ["eraser", "slow"] as Array[String])
	Save.furthest_level = 1
	Save.rev_b = true
	assert_eq(Toolbox.belt_slots(Save), 2, "Revision B's own progress doesn't count")
	Save.rev_b = false


func test_the_belt_shows_only_on_a_sheet_with_tools() -> void:
	_start("bccw")
	assert_false(game.toolbox.showing(), "nothing on the belt")
	_own("eraser")
	assert_true(game.toolbox.showing())
	assert_eq(game.toolbox.belt(), ["eraser"] as Array[String])
	game.toolbox.update_belt()
	assert_true(game.belt.visible)
	assert_eq(game.hud.belt_room, ToolBelt.room(1))
	game.tutorial = true
	assert_false(game.toolbox.showing(), "not in the tutorial")
	game.toolbox.update_belt()
	assert_false(game.belt.visible)
	assert_eq(game.hud.belt_room, 0.0)


# --- the hand -------------------------------------------------------------------


func test_eraser_rubs_out_a_skull_then_recharges() -> void:
	_start("bcdcw")
	_own("eraser")
	assert_true(game.toolbox.ready("eraser"))
	game.toolbox.use("eraser")
	assert_eq(game.toolbox.armed(), "eraser", "a tap on the button arms it")
	_tap_tile(2)
	assert_eq(game.toolbox.armed(), "")
	assert_false(game.map.deaths[Vector2i(2, 0)], "the skull is gone")
	_step_on(2)
	assert_false(game.dead, "and the tile is safe")
	assert_false(game.toolbox.ready("eraser"), "it recharges")
	assert_almost_eq(game.toolbox.cooling("eraser"), 1.0, 0.01)
	game.toolbox.update(6.0)
	assert_true(game.toolbox.ready("eraser"), "6 s at tier I")


func test_eraser_finds_a_hidden_skull_and_wastes_on_a_plain_tile() -> void:
	_start("bcdcw", [], ["  *  "])  # the skull starts hidden
	_own("eraser")
	assert_true(game.map.deaths[Vector2i(2, 0)])
	assert_true(game.map.tiles[Vector2i(2, 0)].start_hidden)
	game.toolbox.use("eraser")
	_tap_tile(2)
	assert_false(game.map.deaths[Vector2i(2, 0)], "a hidden skull is rubbed out too")
	game.toolbox.update(10.0)
	game.toolbox.use("eraser")
	_tap_tile(1)
	assert_false(game.toolbox.ready("eraser"), "a plain tile still spends the use")
	game.toolbox.update(10.0)
	game.toolbox.use("eraser")
	game.toolbox.use("eraser")
	assert_eq(game.toolbox.armed(), "", "a second tap puts it away")
	assert_true(game.toolbox.ready("eraser"))


func test_a_tap_with_nothing_armed_still_pauses() -> void:
	_start("bcw")
	_own("eraser")
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	assert_false(game.toolbox.field_tap(e), "the field keeps its tap")


func test_light_table_shows_the_hidden_tiles_once_a_try() -> void:
	_start("bcdcw", [], ["  *  "])
	_own("eraser")
	_own("peek", 2)
	game.toolbox.use("peek")
	assert_true(game.toolbox.peeking())
	assert_almost_eq(game.toolbox.running("peek"), 1.0, 0.01)
	game.toolbox.update(0.5)
	assert_true(game.toolbox.peeking(), "1 s at tier II")
	game.toolbox.update(0.6)
	assert_false(game.toolbox.peeking())
	assert_true(game.toolbox.used_up("peek"), "once a try")
	assert_false(game.toolbox.ready("peek"))
	game.toolbox.begin_try()
	assert_true(game.toolbox.ready("peek"), "the next try has another")


func test_push_pin_holds_spikes_down_and_a_crumble_tile_whole() -> void:
	_start("b^kcw")
	_own("eraser")
	_own("peek")
	_own("pin")
	game.map.spike_time = 0.8 * game.map.spike_cycle
	game.map.update_spikes(0.0)
	assert_eq(game.map.spike_state(Vector2i(1, 0)), 2, "spikes up")
	game.toolbox.use("pin")
	_tap_tile(1)
	assert_eq(game.map.spike_state(Vector2i(1, 0)), 0, "pinned down")
	_step_on(1)
	assert_false(game.dead)
	game.toolbox.update(3.5)
	assert_eq(game.map.spike_state(Vector2i(1, 0)), 2, "3 s at tier I, then they rise again")
	game.toolbox.update(10.0)
	game.toolbox.use("pin")
	_tap_tile(2)
	game.map.crumble(Vector2i(2, 0))
	assert_true(game.map.crumbles[Vector2i(2, 0)], "a pinned crumble tile holds")
	game.toolbox.update(3.5)
	game.map.crumble(Vector2i(2, 0))
	assert_false(game.map.crumbles[Vector2i(2, 0)], "and breaks once the pin is out")


# --- the feet -------------------------------------------------------------------


func test_hop_clears_the_next_tile_the_way_he_faces() -> void:
	_start("bcdcw")
	_own("hop")
	game.player.face_direction(Vector2i.RIGHT, true)
	game.toolbox.use("hop")
	assert_true(game.map.hopping(), "over the skull")
	assert_gt(game.toolbox.hop_lift(), -1.0)
	game.map.update_move(10.0)
	assert_eq(game.map.position_key, Vector2i(2, 0), "landed past the next tile")
	assert_false(game.toolbox.ready("hop"), "recharging")
	game.toolbox.update(8.0)
	assert_true(game.toolbox.ready("hop"))


func test_hop_needs_a_tile_to_land_on() -> void:
	_start("bcw")
	_own("hop", 3)
	game.player.face_direction(Vector2i.RIGHT, true)
	game.toolbox.use("hop")
	assert_false(game.map.moving, "two tiles on from the start is off the sheet")
	assert_true(game.toolbox.ready("hop"), "nothing spent")
	game.player.face_direction(Vector2i.LEFT, true)
	game.toolbox.use("hop")
	assert_false(game.map.moving, "no tile to the left either")


func test_hard_hat_takes_the_first_skull_on_a_sheet() -> void:
	_start("bcdcdw")
	_own("hardhat")
	_step_on(2)
	assert_false(game.dead, "the hat took the hit")
	assert_true(game.toolbox.used_up("hardhat"))
	game.update_player(0.0)
	assert_false(game.dead, "standing on the tile stays safe")
	_step_on(4)
	assert_true(game.dead, "the second skull gets him")


func test_hard_hat_covers_spikes_from_tier_two() -> void:
	_start("b^cw")
	_own("hardhat")
	game.map.spike_time = 0.8 * game.map.spike_cycle
	game.map.update_spikes(0.0)
	_step_on(1)
	assert_true(game.dead, "tier I is skulls only")
	_start("b^cw")
	_own("hardhat", 2)
	game.map.spike_time = 0.8 * game.map.spike_cycle
	game.map.update_spikes(0.0)
	_step_on(1)
	assert_false(game.dead, "tier II takes the spikes")


func test_hard_hat_is_back_on_the_next_sheet_not_the_next_try() -> void:
	_start("bcdw")
	_own("hardhat")
	_step_on(2)
	game.toolbox.begin_try()
	assert_true(game.toolbox.used_up("hardhat"), "once a sheet")
	game.toolbox.begin_sheet()
	assert_false(game.toolbox.used_up("hardhat"))


func test_second_draft_stands_him_up_on_the_same_sheet_once_a_game() -> void:
	_start("bcdw")
	_own("revive")
	game.lives = 1
	_step_on(2)
	assert_true(game.dead)
	game.finish_lose_life()
	assert_eq(game.lives, 1, "back up with a life")
	assert_true(game.game_active, "the game goes on")
	assert_eq(game.menus.current, "", "no game over sheet")
	assert_eq(game._time_left, 8.0, "8 s at tier I")
	assert_true(game.toolbox.used_up("revive"), "once a game")
	game.toolbox.begin_sheet()
	assert_true(game.toolbox.used_up("revive"), "a new sheet doesn't bring it back")
	game.toolbox.begin_game()
	assert_false(game.toolbox.used_up("revive"))


func test_game_over_without_a_second_draft() -> void:
	_start("bcdw")
	game.lives = 1
	_step_on(2)
	game.finish_lose_life()
	assert_false(game.game_active)


# --- the clock ------------------------------------------------------------------


func test_slow_mo_halves_the_clock_and_holds_through_a_pause() -> void:
	_start("bccw")
	_own("slow")
	game.toolbox.use("slow")
	assert_eq(Engine.time_scale, Toolbox.SLOW_SCALE)
	assert_true(game.toolbox.slowing())
	game.toolbox.update(0.5)  # half a second of slowed time: one real second
	assert_almost_eq(game.toolbox.running("slow"), 0.5, 0.01, "2 s at tier I, by the wall clock")
	game.toolbox.suspend()
	assert_eq(Engine.time_scale, 1.0, "the pause sheet runs at full speed")
	assert_false(game.toolbox.slowing())
	game.toolbox.resume()
	assert_eq(Engine.time_scale, Toolbox.SLOW_SCALE)
	game.toolbox.update(0.6)
	assert_eq(Engine.time_scale, 1.0, "over")
	assert_true(game.toolbox.used_up("slow"), "once a try")
	game.toolbox.stop()
	assert_eq(Engine.time_scale, 1.0)


func test_stop_clock_holds_the_countdown_while_he_walks() -> void:
	_start("bccw")
	_own("freeze")
	var before: float = game._time_left
	game.toolbox.use("freeze")
	assert_true(game.toolbox.clock_stopped())
	game._update_timer(1.0)
	assert_eq(game._time_left, before, "the clock stands still")
	game.toolbox.update(2.1)
	assert_false(game.toolbox.clock_stopped(), "2 s at tier I")
	game._update_timer(1.0)
	assert_lt(game._time_left, before, "and runs again")
	assert_true(game.toolbox.used_up("freeze"), "once a sheet")
	game.toolbox.begin_try()
	assert_true(game.toolbox.used_up("freeze"))


func test_first_look_holds_the_clock_until_a_lean_or_a_tap() -> void:
	_start("bccw")
	_own("slow")
	_own("look")
	game.toolbox.begin_try()
	assert_true(game.toolbox.look_update(0.0), "the look holds the clock")
	assert_true(game.toolbox.looking())
	assert_true(game.toolbox.look_update(1.0))
	assert_true(game.toolbox.look_update(0.5), "2 s at tier I, not over yet")
	assert_false(game.toolbox.look_update(0.6))
	assert_false(game.toolbox.looking())
	assert_false(game.toolbox.look_update(1.0), "and stays over")
	game.toolbox.begin_try()
	assert_true(game.toolbox.look_update(0.0), "every try has a look")
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	assert_true(game.toolbox.field_tap(e), "a tap ends it")
	assert_false(game.toolbox.looking())


func test_tools_do_nothing_off_the_belt_or_on_a_pause() -> void:
	_start("bcdw")
	Save.tools["eraser"] = 2
	assert_eq(game.toolbox.tier("eraser"), 0, "owned but not carried")
	assert_false(game.toolbox.ready("eraser"))
	_own("eraser", 2)
	game.paused = true
	game.toolbox.use("eraser")
	assert_eq(game.toolbox.armed(), "", "nothing arms on a pause")
	game.paused = false


# --- the sheet ------------------------------------------------------------------


func test_the_toolbox_opens_from_the_menu_pause_and_level_clear() -> void:
	_start("bccw")
	game.menus.action.connect(func(a: String): game._on_menu_action(a))
	Save.furthest_level = 11
	game.menus.show_main(0, false)
	game.menus.action.emit("toolbox")
	assert_eq(game.menus.current, "toolbox")
	assert_eq(game.toolbox.from, "main")
	game.menus.action.emit("toolbox back")
	assert_eq(game.menus.current, "main")
	game.show_pause_menu()
	game.menus.action.emit("toolbox pause")
	assert_eq(game.menus.current, "toolbox")
	assert_eq(game.toolbox.from, "pause")
	game.menus.action.emit("toolbox back")
	assert_eq(game.menus.current, "pause")


func test_the_sheet_buys_belts_and_refunds() -> void:
	_start("bccw")
	Save.furthest_level = 11
	Save.bank = 100
	game.toolbox.from = "main"
	assert_true(game.toolbox.action("tool hop"))
	assert_eq(game.toolbox.selected, "hop")
	assert_true(game.toolbox.action("buy hop"))
	assert_eq(Save.tool_tier("hop"), 1)
	assert_true(Save.on_belt("hop"), "a new tool goes straight on the belt")
	assert_true(game.toolbox.action("belt hop"))
	assert_false(Save.on_belt("hop"))
	assert_true(game.toolbox.action("fresh sheet"))
	assert_true(Save.fresh_sheet, "bought")
	assert_eq(Save.bank, 100 - 15 - 40)
	assert_true(game.toolbox.action("fresh sheet"))
	assert_eq(Save.bank, 100 - 40, "the hop's stars came back")
	assert_eq(Save.tools, {})
	assert_false(game.toolbox.action("wardrobe"), "not the toolbox's")


func test_fresh_sheet_waits_until_the_sheet_is_over() -> void:
	_start("bccw")
	Save.bank = 100
	Save.fresh_sheet = true
	Save.tools["hop"] = 1
	game.toolbox.from = "pause"
	assert_true(game.toolbox.action("fresh sheet"))
	assert_eq(Save.tools, {"hop": 1}, "mid-sheet the tools stay")
	game.toolbox.from = "clear"
	assert_true(game.toolbox.action("fresh sheet"))
	assert_eq(Save.tools, {}, "between sheets they go")


func test_a_cleared_sheet_pays_the_bank_and_the_clear_says_so() -> void:
	_start("bc@w")
	Save.furthest_level = 11
	game.stars = 1
	game._time_left = 15.0
	game.advance_level(false)
	assert_eq(Save.bank, 3, "a star tile, the clear and the quick star")
	assert_eq(Save.banked["A1"].tiles, 1)
	assert_eq(game.menus.current, "end_level")
