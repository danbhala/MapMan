class_name DraftingTable
extends RefCounted
## The drafting table's side of the game flow, for main.gd: which draft is
## open, playing a draft or a friend's code (main.gd's `custom`), the way
## back afterwards, and a code found on the clipboard. DraftingSheet draws
## the sheets. Loads only with the game scene, so it may name Save.

## The draft being edited, or null.
var draft: Draft
## The level being played from the table, its code, and where it goes back
## to: "drafting", "main", "card" (its level card) or "editor" (a draft's test).
var level: Dictionary = {}
var code := ""
var back_to := "drafting"
## The level card open (or to go back to): "draft" with the draft slot
## `card_slot`, or "received" with the code `card_code`.
var card_kind := ""
var card_slot := 0
var card_code := ""

## main.gd (untyped: it has no class_name).
var _game
## The last level link the game was opened with, so it plays once.
var _link := ""
## The code on the share sheet, and its number and way back.
var _shared := ""
var _share_args := ["", "drafting table"]


func _init(game) -> void:
	_game = game


func show(note := "") -> void:
	Audio.play_menu()
	DraftingSheet.build(_game.menus, Save.all_drafts(), Save.received, note)


func open_draft(slot: int, signed_now := false) -> void:
	if draft == null or draft.slot != slot:
		draft = Save.all_drafts()[slot]
	DraftingSheet.build_editor(_game.menus, draft, signed_now)


## A cell of the table was tapped: an empty draft opens in the editor, any
## other level shows its card.
func open_cell(kind: String, index: int) -> void:
	if kind == "draft":
		var d: Draft = Save.all_drafts()[index]
		if d.is_empty():
			open_draft(index)
			return
		draft = d
		card_slot = index
	else:
		if index >= Save.received.size():
			return
		card_code = Save.received[index]
	card_kind = kind
	show_card()


## The open level card, as a Card; null if its level has gone.
func card() -> LevelCard.Card:
	var c := LevelCard.Card.new()
	if card_kind == "draft":
		if draft == null or draft.slot != card_slot:
			draft = Save.all_drafts()[card_slot]
		if draft.is_empty():
			return null
		c.draft = draft
		c.number = DraftingSheet.TEXT.draft_cell % (card_slot + 1)
		c.title = _game.tr(DraftingSheet.TEXT.draft_title) % (card_slot + 1)
		var status: String = DraftingSheet.TEXT.signed if draft.signed else DraftingSheet.TEXT.draft
		c.kind_line = "%s · %s" % [c.title, _game.tr(status)]
		c.name = draft.name
		c.source = _game.tr(LevelCard.TEXT.made_by_you)
		c.can_play = draft.problem() == ""
		c.can_share = draft.signed
		c.stats = Save.level_stat(draft.code()) if draft.code() != "" else {}
		c.edit = "edit"
	else:
		var index := Save.received.find(card_code)
		if index < 0:
			return null
		var got := LevelCode.decode(card_code)
		c.draft = Draft.from_level(0, LevelCode.to_level(got))
		c.number = DraftingSheet.TEXT.received_cell % (index + 1)
		c.title = _game.tr(LevelCard.TEXT.received_title) % (index + 1)
		c.kind_line = c.title
		c.name = Save.received_name(card_code)
		c.source = _game.tr(LevelCard.TEXT.from_friend)
		c.stats = Save.level_stat(card_code)
		c.edit = "remix"
		c.can_edit = _free_slot() >= 0
		if not c.can_edit:
			c.source = _game.tr(LevelCard.TEXT.no_slot)
	c.replay = _game._tries.replayable(0, _card_level_code())
	return c


## The level card again (after a try, a replay, a rename); the table if its
## level has gone. note: a line about the last try.
func show_card(note := "") -> void:
	var c := card()
	if c == null:
		show()
		return
	c.note = note
	Audio.play_menu()
	LevelCard.build(_game.menus, c)


## The code the open card's level plays as (a draft's changes with it).
func _card_level_code() -> String:
	if card_kind == "draft":
		return LevelCode.clean(draft.code()) if draft != null else ""
	return LevelCode.clean(card_code)


## The first empty draft slot, or -1.
func _free_slot() -> int:
	var drafts := Save.all_drafts()
	for i in drafts.size():
		if drafts[i].is_empty():
			return i
	return -1


## Play `level_data` (code `level_code`): kind "draft" tests the draft being
## edited, "received" plays a friend's code.
func start(level_data: Dictionary, kind: String, level_code: String) -> void:
	# Like practice, this leaves the first-play screen for "play from start".
	var first_play := Save.first_play
	_game.custom = kind
	level = level_data
	code = LevelCode.clean(level_code)
	_game.menus.close()
	_game.new_game(1)
	if first_play:
		Save.first_play = true
		Save.save_all()
	_game.hud.show_stats(false)
	_game.hud.show_level(false)


## Back from a draft or a received level; won: an exit was reached, which
## goes on the level's record (Save.level_won()).
func end(won: bool) -> void:
	var kind: String = _game.custom
	var seconds: int = _game._seconds_remaining()
	var best := false
	if won:
		var run: RunRecord = _game._tries.end("win", _game._time_left)
		if not (Dev.enabled and Dev.unlimited_time):  # a frozen clock isn't a best
			best = Save.level_won(code, seconds, run)
	_game.game_over(false)
	var note := ""
	if won:
		var line: String = LevelCard.TEXT.new_best if best else DraftingSheet.TEXT.cleared
		note = _game.tr(line) % seconds
	if kind == "draft":
		if won:
			draft.signed = true
			Save.store_draft(draft)
		if back_to == "card":
			show_card(note)
		else:
			open_draft(draft.slot, won)
		return
	if back_to == "card":
		show_card(note)
	elif back_to == "drafting" and Save.drafting_open():
		show(note)
	else:
		_game.show_start_menu()


## Play a code; returns why it can't be played ("bad", "newer") or "".
## One played from its level card stays where it is on the table.
func play_code(text: String, back := "drafting") -> String:
	var got := LevelCode.decode(text)
	if got.has("newer"):
		return "newer"
	if not got.has("rows") or not _playable(got.rows):
		return "bad"
	if back != "card":
		Save.receive(text)
	back_to = back
	start(LevelCode.to_level(got), "received", text)
	return ""


## A level needs a start tile and an exit to be played.
func _playable(rows: Array) -> bool:
	var text := "".join(rows)
	if text.count("b") != 1:
		return false
	for e in ["n", "e", "s", "w"]:
		if text.contains(e):
			return true
	return false


## A level code someone copied (from a chat, or a QR code read by the
## phone's camera) is offered once, as the game opens on the main menu.
func check_clipboard() -> void:
	var m: Menus = _game.menus
	if m.current != "main" or not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		return
	var code := LevelCode.find(DisplayServer.clipboard_get())
	if code == "" or code == Save.clipboard_seen or code in Save.received:
		return
	Save.clipboard_seen = code
	Save.save_all()
	DraftingSheet.build_found(m, code)


## A level link opens the game (the phone's camera, a chat): the level plays
## at once, from wherever the player is, but never in the middle of the main
## game, which keeps it for the main menu. `link` is for tests.
func check_link(link := "") -> void:
	if link == "":
		link = launch_link()
	if link == "" or link == _link or LevelCode.find(link) == "":
		return
	if _game.intro != null or (_game.game_active and _game.custom == ""):
		return
	_link = link
	if _game.custom != "":
		_game.menus.close()
		_game.game_over(false)
	play_code(link, "main")


## The link Android opened the game with (the intent's data), or "".
static func launch_link() -> String:
	if not Engine.has_singleton("AndroidRuntime"):
		return ""
	var activity = Engine.get_singleton("AndroidRuntime").getActivity()
	var intent = activity.getIntent() if activity else null
	var data = intent.getData() if intent else null
	return str(data.toString()) if data else ""


## The pause sheet's number while playing from the table.
func pause_number() -> String:
	if _game.custom == "draft":
		return "D%d" % (draft.slot + 1)
	return "R" if _game.custom == "received" else ""


## Handle a menu action of the drafting sheets; false if it isn't one.
func action(act: String) -> bool:
	var m: Menus = _game.menus
	match act:
		"drafting table":
			if m.current == "editor" and draft != null:
				Save.store_draft(draft)
				# Back from editing a level that has a card: to its card.
				if card_kind == "draft" and card_slot == draft.slot and not draft.is_empty():
					show_card()
					return true
			card_kind = ""
			show()
		"enter code":
			DraftingSheet.build_code_entry(m, "")
		"paste code":
			var pasted := DisplayServer.clipboard_get().strip_edges().left(200)
			DraftingSheet.build_code_entry(m, pasted)
		"play code":
			var text := m.code_input.text if m.code_input else ""
			var why := play_code(text)
			if why != "":
				DraftingSheet.build_code_entry(m, text, why)
		"scan code":
			DraftingSheet.build_scan(m)
		"play found code":
			if play_code(Save.clipboard_seen, "main") != "":
				_game.show_start_menu()
		"test draft":
			if draft != null and draft.problem() == "":
				Save.store_draft(draft)
				back_to = "editor"
				start(draft.level(), "draft", draft.code())
		"share draft":
			if draft != null and draft.signed:
				_share(
					draft.code(),
					DraftingSheet.TEXT.share_number % (draft.slot + 1),
					"draft %d" % draft.slot
				)
		"copy code":
			DisplayServer.clipboard_set(LevelCode.link(_shared))
			_share(_shared, _share_args[0], _share_args[1], true)
		"end custom":
			m.close()
			end(false)
		_:
			if act.begins_with("draft "):
				var slot := int(act.get_slice(" ", 1))
				if m.current == "share":
					open_draft(slot)  # BACK TO THE DRAFT
				else:
					open_cell("draft", slot)
			elif act.begins_with("received "):
				open_cell("received", int(act.get_slice(" ", 1)))
			elif act == "card" or act.begins_with("card "):
				card_action(act)
			elif act.begins_with("scanned "):
				var why := play_code(act.substr(8))
				if why != "":
					DraftingSheet.scan_status(m, "newer" if why == "newer" else "not_a_level")
			else:
				return false
	return true


## A level card's actions (LevelCard): "card" shows it again.
func card_action(act: String) -> void:
	var m: Menus = _game.menus
	var c := card()
	if c == null:
		show()
		return
	match act:
		"card":
			show_card()
		"card play":
			if card_kind == "draft":
				if draft.problem() == "":
					back_to = "card"
					start(draft.level(), "draft", draft.code())
			else:
				play_code(card_code, "card")
		"card edit":
			open_draft(card_slot)
		"card remix":
			var slot := _free_slot()
			if slot < 0:
				return
			var d := Draft.from_level(slot, c.draft.level())
			d.name = c.name
			Save.store_draft(d)
			draft = d
			card_kind = "draft"
			card_slot = slot
			open_draft(slot)
		"card share":
			if c.can_share:
				var code_now := _card_level_code()
				_share(code_now, c.number + "-S", "card")
		"card replay":
			var title: String = (
				_game.tr(LevelCard.TEXT.replay_title) % (c.name if c.name != "" else c.title)
			)
			_replay(c.draft.level(), _card_level_code(), title)
		"card rename":
			LevelCard.build_rename(m, c)
		"card rename save":
			var name := Draft.tidy_name(m.code_input.text if m.code_input else "")
			if card_kind == "draft":
				draft.name = name
				Save.store_draft(draft)
			else:
				Save.name_received(card_code, name)
			show_card()
		"card delete":
			var question: String = (
				_game.tr(LevelCard.TEXT.delete_draft) % (card_slot + 1)
				if card_kind == "draft"
				else _game.tr(LevelCard.TEXT.delete_received) % (Save.received.find(card_code) + 1)
			)
			LevelCard.build_delete(m, c, question)
		"card delete yes":
			if card_kind == "draft":
				Save.delete_draft(card_slot)
				draft = null
			else:
				Save.delete_received(Save.received.find(card_code))
			card_kind = ""
			show()


## A try at the level playing begins: it counts on the level's record.
## Returns its code, the key to its tries and ghost ("" in the main game).
func begin_try() -> String:
	if _game.custom == "":
		return ""
	Save.level_tried(code)
	return code


## A replay ended; true if it was a card's (main.gd's _end_replay()), which
## comes back.
func replay_ended() -> bool:
	if _game.game_active:
		return false
	_game.map.unload()
	show_card()
	return true


## WATCH REPLAY on a card: every try at the level `data` (code `level_code`)
## since the game opened, over the card, which comes back when it ends.
func _replay(data: Dictionary, level_code: String, title: String) -> void:
	var tries: Tries = _game._tries
	if tries.replay or not tries.replayable(0, level_code):
		return
	_game.menus.visible = false
	_game.hud.visible = false
	_game.map.load_level(data, _game._screen_size())
	tries.play(_game.map, title).finished.connect(_game._end_replay)


## The share sheet of `share_code`, numbered `number`; its way back reports `back_act`.
func _share(share_code: String, number: String, back_act: String, copied := false) -> void:
	_shared = LevelCode.pretty(share_code)
	_share_args = [number, back_act]
	var back: String = (
		_game.tr(DraftingSheet.TEXT.back_to_draft)
		if back_act.begins_with("draft")
		else _game.tr(LevelCard.TEXT.back_to_level)
	)
	DraftingSheet.build_share(_game.menus, _shared, number, back, back_act, copied)


## The back button on a drafting sheet; false if it isn't one.
func go_back() -> bool:
	match _game.menus.current:
		"drafting", "found_code":
			_game._on_menu_action("main menu")
		"editor", "enter_code", "scan":
			action("drafting table")
		"card":
			card_kind = ""
			show()
		"card_delete", "card_rename":
			show_card()
		"share":
			action(_share_args[1])
		_:
			return false
	return true
