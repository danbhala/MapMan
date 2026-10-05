class_name DraftingTable
extends RefCounted
## The drafting table's side of the game flow, for main.gd: which draft is
## open, playing a draft or a friend's code (main.gd's `custom`), the way
## back afterwards, and a code found on the clipboard. DraftingSheet draws
## the sheets. Loads only with the game scene, so it may name Save.

## The draft being edited, or null.
var draft: Draft
## The level being played from the table, and where a received level goes
## back to: "drafting" or "main".
var level: Dictionary = {}
var back_to := "drafting"

## main.gd (untyped: it has no class_name).
var _game


func _init(game) -> void:
	_game = game


func show(note := "") -> void:
	Audio.play_menu()
	DraftingSheet.build(_game.menus, Save.all_drafts(), Save.received, note)


func open_draft(slot: int, signed_now := false) -> void:
	if draft == null or draft.slot != slot:
		draft = Save.all_drafts()[slot]
	DraftingSheet.build_editor(_game.menus, draft, signed_now)


## Play `level_data`: kind "draft" tests the draft being edited, "received"
## plays a friend's code.
func start(level_data: Dictionary, kind: String) -> void:
	# Like practice, this leaves the first-play screen for "play from start".
	var first_play := Save.first_play
	_game.custom = kind
	level = level_data
	_game.menus.close()
	_game.new_game(1)
	if first_play:
		Save.first_play = true
		Save.save_all()
	_game.hud.show_stats(false)
	_game.hud.show_level(false)


## Back from a draft or a received level; won: an exit was reached.
func end(won: bool) -> void:
	var kind: String = _game.custom
	var seconds: int = _game._seconds_remaining()
	_game.game_over(false)
	if kind == "draft":
		if won:
			draft.signed = true
			Save.store_draft(draft)
		open_draft(draft.slot, won)
		return
	var note := ""
	if won:
		note = _game.tr(DraftingSheet.TEXT.cleared) % seconds
	if back_to == "drafting" and Save.drafting_open():
		show(note)
	else:
		_game.show_start_menu()


## Play a code; returns why it can't be played ("bad", "newer") or "".
func play_code(code: String, back := "drafting") -> String:
	var got := LevelCode.decode(code)
	if got.has("newer"):
		return "newer"
	if not got.has("rows") or not _playable(got.rows):
		return "bad"
	Save.receive(code)
	back_to = back
	start(LevelCode.to_level(got), "received")
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
		"play found code":
			if play_code(Save.clipboard_seen, "main") != "":
				_game.show_start_menu()
		"test draft":
			if draft != null and draft.problem() == "":
				Save.store_draft(draft)
				start(draft.level(), "draft")
		"share draft":
			if draft != null and draft.signed:
				DraftingSheet.build_share(m, draft)
		"copy code":
			DisplayServer.clipboard_set(LevelCode.PREFIX + " " + draft.code())
			DraftingSheet.build_share(m, draft, true)
		"end custom":
			m.close()
			end(false)
		_:
			if act.begins_with("draft "):
				open_draft(int(act.get_slice(" ", 1)))
			elif act.begins_with("received "):
				var i := int(act.get_slice(" ", 1))
				if i < Save.received.size():
					play_code(Save.received[i])
			else:
				return false
	return true


## The back button on a drafting sheet; false if it isn't one.
func go_back() -> bool:
	match _game.menus.current:
		"drafting", "found_code":
			_game._on_menu_action("main menu")
		"editor", "enter_code":
			action("drafting table")
		"share":
			open_draft(draft.slot)
		_:
			return false
	return true
