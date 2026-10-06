class_name AdOffers
extends RefCounted
## The ads' side of the game flow, for main.gd (docs/ads.md): KEEP GOING when
## the last life goes, DOUBLE IT on the level clear and, now and then, a
## full-screen ad on NEXT. Ads (scripts/ads.gd) says what is loaded and plays
## them. Loads only with the game scene, so it may name Ads and Audio.

## KEEP GOING is spent for this game (one more life, once per game).
var kept_going := false

## main.gd (untyped: it has no class_name).
var _game


func _init(game) -> void:
	_game = game


## The menu actions this flow handles; false for any other.
func action(act: String) -> bool:
	match act:
		"next level":
			if Ads.interstitial_due(_game.level):
				# Over the level clear, before the next sheet.
				Ads.show_interstitial(_game._on_menu_action.bind("next level now"))
			else:
				_game._on_menu_action("next level now")
		"keep going":
			_keep_going()
		"give up":
			_game.game_over()
		"double it":
			_double_it()
		"ad privacy":
			Ads.show_privacy_options()
		_:
			return false
	return true


## KEEP GOING is on offer when the last life goes: once per game, in the
## main game past the free levels, with a rewarded ad ready.
func can_keep_going() -> bool:
	var g = _game
	if g.tutorial or g.practice or g.completed or g.custom != "" or kept_going:
		return false
	return g.level > Ads.FREE_LEVELS and Ads.rewarded_ready("keep_going")


## The last life is gone: KEEP GOING or END THE GAME where it is on offer,
## otherwise game over.
func last_life_lost() -> void:
	if can_keep_going():
		offer_keep_going()
	else:
		_game.game_over()


func offer_keep_going() -> void:
	_game.menus.show_lose_life(0, _game.level, _game._lose_reason, "", true)


## The ad, then one more life on the same sheet. Closed early, the offer
## stands while an ad is ready; otherwise the game is over.
func _keep_going() -> void:
	Ads.show_rewarded(
		"keep_going",
		func(earned: bool) -> void:
			if earned:
				kept_going = true
				_game.lives = 1
				_game._update_stats()
				_game.menus.close()
				_game.reset_all(false)
			elif can_keep_going():
				offer_keep_going()
			else:
				_game.game_over()
	)


## The level clear of `level` in the main game: counts towards the next
## full-screen ad, and gives Menus.show_end_level's `more`: the tries the
## replay would show and, unless a release slip takes its place, DOUBLE IT
## on offer (-1).
func on_clear(level: int, released: String) -> Dictionary:
	Ads.note_clear(level)
	var tries: Tries = _game._tries
	var more := {"tries": tries.list.size() if tries.replayable(level) else 0}
	if released == "" and level > Ads.FREE_LEVELS and Ads.rewarded_ready("double_it"):
		more.double = -1
	return more


## After the ad, the sheet's points count twice.
func _double_it() -> void:
	Ads.show_rewarded(
		"double_it",
		func(earned: bool) -> void:
			if earned and _game._between:
				var extra: int = _game.end_of_level_points
				_game.end_of_level_points += extra
				_game.menus.doubled_end_level(extra)
				Audio.play("star")
	)
