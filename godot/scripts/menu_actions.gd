class_name MenuActions
extends RefCounted
## The menus' actions (the strings the sheets' buttons report, see menus.gd)
## carried out on main.gd, which hands them here from `_on_menu_action()`
## once the drafting table and Revision B have had their pick. Loads only
## with the game scene, so it may name Save.


## `game` is main.gd (untyped: it has no class_name).
static func handle(game, act: String) -> void:
	match act:
		"play from start", "play", "new game", "play game":
			if Save.first_play and act == "play from start":
				game.menus.show_first_play()
			else:
				game.menus.close()
				game.new_game()
		"tutorial", "take tutorial":
			game.menus.close()
			game.new_game(1, true)
		"restart from checkpoint":
			game.menus.show_restart(Save.checkpoints.keys())
		"wardrobe":
			game.menus.show_wardrobe(game.level if game._between else 0)
		"main menu":
			if game.menus.current == "wardrobe":
				# Looked at: nothing in it is new any more (the marks stay
				# while the sheet is open, through a tap that redraws it).
				Save.mark_seen()
			if game.game_active:
				_stat_quit(game)
				game.game_over(false)
			game.show_start_menu()
		"confirm quit":
			game.menus.show_confirm_quit()
		"end game", "end tutorial":
			if game.game_active:
				_stat_quit(game)
			_end_game(game)
		"practice":
			# Open on the page with the furthest level reached.
			var last_page: int = (game.levels.size() - 1) / Menus.PRACTICE_PAGE
			game.show_practice_menu(
				clampi((Save.furthest_level - 1) / Menus.PRACTICE_PAGE, 0, last_page)
			)
		"next level":
			game.menus.close()
			game.next_level()
		"replay":
			Stats.event("replay_watched", Stats.of(game))
			game._start_replay()
		"clear wardrobe":
			game.menus.show_wardrobe(game.level)
		"back to clear":
			if game.menus.current == "wardrobe":
				Save.mark_seen()
			game.menus.reopen_end_level()
		"leave clear":
			# MAIN MENU on the level clear: the same question as quitting
			# from the pause; the level still counts if the game ends.
			game.menus.show_confirm_quit("back to clear")
		"try again":
			game.menus.close()
			game.reset_all(false)
		"skip sheet":
			game.skip_level()
		"unpause":
			game.menus.close()
			game.paused = false
			# The player may hold the phone differently after a pause.
			game._calibrate_pending = true
			if not game.tutorial and game.started() == false and game.map.loaded():
				game._timer_start()
		"completion done":
			_completion_done(game)
		_:
			_prefixed(game, act)


## Quitting from the pause sheet, or a level clear.
static func _end_game(game) -> void:
	if game.practice:
		game._end_practice()
		return
	if game._between:
		# Quitting from a level clear: its checkpoint is kept, and the next
		# level opens in practice.
		game._bank_level()
		if game.level <= game.levels.size():
			Save.level_reached(game.level)
	game.game_over(false)
	game.show_start_menu()


## The final inspection is in: the congratulations sheet, with her slip the
## first time, and the stamp that releases Revision B (or approves it).
static func _completion_done(game) -> void:
	game.score += game.end_of_level_points
	var pb: bool = Save.submit_score(game.score)
	game._mark_completed()
	Save.save_all()
	game.game_active = false
	game.hud.show_bar(false)
	game.hud.show_stats(false)
	game.set_background()
	# Her slip shows until the wardrobe has been looked at, so leaving the
	# ending before the vortex the first time doesn't lose it.
	var new_woman := Save.is_released("mapwoman") and "mapwoman" not in Save.seen
	var stamp := "approved" if Save.rev_b else "released" if game._first_finish else ""
	game.menus.show_congratulations(game.score, pb, "mapwoman" if new_woman else "", stamp)


## Actions with an argument after a prefix.
static func _prefixed(game, act: String) -> void:
	if game.steering.handle(act) or OptionsActions.handle(act, game.menus):
		pass  # the Options, CONTROLS and language sheets
	elif StatsSheet.handle(act, game.menus):
		pass  # the play stats question and the PRIVACY sheet
	elif act.begins_with("practice page "):
		game.show_practice_menu(int(act.get_slice(" ", 2)))
	elif act.begins_with("practice level "):
		game.menus.close()
		game.start_practice(int(act.get_slice(" ", 2)))
	elif act.begins_with("wear "):
		# From the wardrobe, or the slip on the level clear that released it:
		# he wears it from now on.
		if Save.wear(act.get_slice(" ", 1)):
			game.player.outfit = Save.worn
			Stats.event("look_worn", {"look": Save.worn})
		if game.menus.current == "end_level":
			game.menus.redraw()
		else:
			game.menus.show_wardrobe(game.level if game._between else 0)
	elif act.begins_with("L") and act.substr(1).is_valid_int():
		game.menus.close()
		game.new_game(int(act.substr(1)) + 1)


## Play stats (Stats): leaving a game for the menu, mid-level or from a level
## clear.
static func _stat_quit(game) -> void:
	var more := {"after_clear": game._between, "time_left": game._time_left}
	Stats.event("quit", Stats.of(game, more))
