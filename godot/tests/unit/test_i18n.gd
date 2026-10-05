extends GutTest
## Languages: every string a player can see is in i18n/catalog.json, every
## language translates all of them, every character has a bundled glyph, and
## every sheet still fits its boxes in every language.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const LayoutCheck := preload("res://tools/layout_check.gd")
## TEXT entries that are numbers, symbols or format scaffolding, not words.
const UNTRANSLATED := [
	"001",
	"000",
	"001-B",
	"001-C",
	"001-D",
	"001-E",
	"%d/%d",
	"END",
	"CP",
	"100",
	"P-%02d",
	"[X]",
	"[ ]",
	"+%d",
	"—",
	"<  P-%02d",
	"P-%02d  >",
	"DEV",
	"%s, %s",
	"★ %d",
	"♥ %d",
	"T-0:%02d"
]
## Plural n values that reach every form of every language's rule.
const PLURAL_SAMPLES := [0, 1, 2, 3, 5, 7, 11, 21, 25, 100]

var catalog: Dictionary
var msgids := {}
## The plural forms, which only show up as the second half of a pair.
var plurals := {}
var game


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Dev.enabled = false
	# The phone's screen, not the 64 px square headless Godot starts with:
	# the sheets are laid out in it.
	get_tree().root.size = Vector2i(1334, 750)
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/catalog.json"))
	for entry in catalog.strings:
		msgids[entry.id] = entry
		if entry.has("plural"):
			plurals[entry.plural] = entry


func before_each() -> void:
	Save.reduce_motion = true
	_pin_wardrobe("classic", [])
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	game.menus.close()
	# The main menu it opened on its own is gone once a frame has passed.
	await get_tree().process_frame


func after_each() -> void:
	Save.reduce_motion = false
	Save.set_locale("")
	_pin_wardrobe("classic", [])


## The wardrobe with `released` in it, the last of them not seen yet (NEW on
## the main menu), and `worn` on.
func _pin_wardrobe(worn: String, released: Array) -> void:
	Save.released.assign(released)
	Save.seen.assign(released.slice(0, maxi(released.size() - 1, 0)))
	Save.worn = worn


func _has_letters(text: String) -> bool:
	for ch in text:
		if ch.to_upper() != ch.to_lower():
			return true
	return false


# --- the catalog -----------------------------------------------------------


func test_every_menu_and_hud_string_is_in_the_catalog() -> void:
	for table in [Menus.TEXT, Hud.TEXT, WardrobeSheet.TEXT, Intro.TEXT, ControlsSheet.TEXT]:
		for key in table:
			var value = table[key]
			var texts: Array = value if value is Array else [value]
			for text in texts:
				if _has_letters(text) and text not in UNTRANSLATED:
					var known: bool = msgids.has(text) or plurals.has(text)
					assert_true(known, "catalog has %s: %s" % [key, text])


func test_every_tr_call_in_the_scripts_is_in_the_catalog() -> void:
	var literal := RegEx.create_from_string('\\btr(?:_n)?\\(\\s*"((?:[^"\\\\]|\\\\.)*)"')
	var count := 0
	for script in ["main.gd", "hud.gd", "menus.gd", "wardrobe_sheet.gd", "level_map.gd"]:
		var source := FileAccess.get_file_as_string("res://scripts/" + script)
		for m in literal.search_all(source):
			var text: String = m.get_string(1).c_unescape()
			count += 1
			assert_true(msgids.has(text), "%s: catalog has %s" % [script, text])
	assert_gt(count, 10, "the game-loop notes go through tr()")


func test_every_look_and_tier_name_is_in_the_catalog() -> void:
	for look in Wardrobe.LOOKS:
		assert_true(msgids.has(look.name), "catalog has the look %s" % look.name)
	for tier in Wardrobe.TIERS:
		var name: String = Wardrobe.TIERS[tier]
		if name != "":
			assert_true(msgids.has(name), "catalog has the tier %s" % name)


func test_data_text_is_in_the_catalog() -> void:
	var tutorial: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/tutorial.json")
	)
	for level in tutorial.levels:
		assert_true(msgids.has(level.description), "tutorial lesson: " + level.description)
		var touch: String = level.get("description_touch", "")
		if touch != "":
			assert_true(msgids.has(touch), "tutorial lesson, touch: " + touch)
	var levels: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/levels.json")
	)
	for level in levels.levels:
		var message := String(level.get("message", ""))
		if message != "":
			assert_true(msgids.has(message.to_upper()), "level message: " + message)


func test_language_sheet_matches_the_catalog() -> void:
	var codes: Array = catalog.locales.keys()
	for entry in Menus.LANGUAGES:
		if entry[0] == "en":
			continue
		assert_has(codes, entry[0])
		assert_eq(entry[1], catalog.locales[entry[0]].name)
	assert_eq(Menus.LANGUAGES.size(), codes.size() + 1, "every language, plus English")


# --- the translations ---------------------------------------------------------


func test_every_language_translates_every_string() -> void:
	for locale in catalog.locales:
		var t := TranslationServer.get_translation_object(locale)
		assert_not_null(t, "a translation is loaded for " + locale)
		if t == null:
			continue
		for entry in catalog.strings:
			if entry.has("plural"):
				for n in PLURAL_SAMPLES:
					var form := t.get_plural_message(entry.id, entry.plural, n)
					assert_ne(form, "", "%s: %s for n=%d" % [locale, entry.id, n])
			else:
				assert_ne(t.get_message(entry.id), "", "%s: %s" % [locale, entry.id])


func test_translations_keep_their_placeholders() -> void:
	var holder := RegEx.create_from_string("%0?\\d*[ds]")
	for locale in catalog.locales:
		var t := TranslationServer.get_translation_object(locale)
		if t == null:
			continue
		for entry in catalog.strings:
			var wanted := []
			for m in holder.search_all(entry.id):
				wanted.append(m.get_string())
			var forms := []
			if entry.has("plural"):
				for n in PLURAL_SAMPLES:
					forms.append(t.get_plural_message(entry.id, entry.plural, n))
			else:
				forms.append(t.get_message(entry.id))
			for form in forms:
				var got := []
				for m in holder.search_all(form):
					got.append(m.get_string())
				assert_eq(got, wanted, "%s: placeholders of %s" % [locale, entry.id])


func test_every_character_has_a_bundled_glyph() -> void:
	var font := Blueprint.mono(500)
	for locale in catalog.locales:
		var t := TranslationServer.get_translation_object(locale)
		if t == null:
			continue
		var texts: Array[String] = [catalog.locales[locale].name]
		for entry in catalog.strings:
			if entry.has("plural"):
				for n in PLURAL_SAMPLES:
					texts.append(String(t.get_plural_message(entry.id, entry.plural, n)))
			else:
				texts.append(String(t.get_message(entry.id)))
		var missing := {}
		for text in texts:
			for ch in text:
				if ch != "\n" and not font.has_char(ch.unicode_at(0)):
					missing[ch] = true
		assert_eq(missing.keys(), [], "%s: characters without a glyph" % locale)


# --- the sheets ----------------------------------------------------------------


## The look whose name and tier take the most room in the language on screen,
## of those a level releases: the longest release slip, and the longest name
## over MapMan on the wardrobe sheet.
func _longest_look() -> String:
	var font := Blueprint.mono(800)
	var longest := ""
	var widest := 0.0
	for look in Wardrobe.LOOKS:
		if look.level == 0 or look.level == Wardrobe.THE_END:
			continue
		var text: String = tr(look.name) + "  ·  " + tr(Wardrobe.TIERS[look.tier])
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		if w > widest:
			widest = w
			longest = look.id
	return longest


## Sheet 001-D with `worn` on: its name and details over him.
func _wardrobe_sheet(worn: String) -> void:
	Save.worn = worn
	game.menus.show_wardrobe()


## Sheet 001-E steering by touch: the tilt rows greyed out, TILT ONLY.
func _controls_by_touch(m) -> void:
	Save.controls = "touch"
	m.show_controls()
	Save.controls = "tilt"


func _open_every_sheet(check: Callable) -> void:
	var m = game.menus
	# Part way through: the first ten looks, the longest and MapWoman released.
	var longest := _longest_look()
	var released: Array = Wardrobe.ids().slice(1, 11)
	for id in [longest, "mapwoman"]:
		if id not in released:
			released.append(id)
	_pin_wardrobe(longest, released)
	var sheets := [
		func(): m.show_main(1842, true, 100),
		func(): m.show_main(1842, true, 100, true),
		func(): m.show_first_play(),
		func(): m.show_options(),
		func(): m.show_language(),
		func(): m.show_controls(),
		_controls_by_touch.bind(m),
		func(): m.show_pause(false, 35, 12),
		func(): m.show_pause(true),
		func(): m.show_confirm_quit(),
		func(): m.show_lose_life(2, 35),
		func(): m.show_lose_life(15, 35, "timeout"),
		func(): m.show_lose_life(1, 35, "death", "marks"),
		func(): m.show_lose_life(1, 35, "timeout", "skip"),
		func(): m.show_game_over(1842, true, true, 1790),
		func(): m.show_restart([10, 30]),
		func(): m.show_practice(1, 25, {21: {"time": 9, "stars": 1}}, 100),
		func(): m.show_end_level(1842, 10, 7, 2, true, 35, 14),
		func(): m.show_end_level(1842, 10, 7, 2, true, 35, 14, false, longest),
		func(): m.show_wardrobe(36),
		func(): m.show_congratulations(2042, true),
		func(): m.show_congratulations(2042, true, "mapwoman"),
		func(): m.show_game_complete(1842, 100, 100),
		func(): m.show_game_complete(1842, 100, 100, true),
		_wardrobe_sheet.bind(longest),
		_wardrobe_sheet.bind("mapwoman"),
		_wardrobe_sheet.bind("classic"),
	]
	for open_sheet in sheets:
		open_sheet.call()
		check.call(m.current)
		# Let the sheet's nodes go before the next one, or they pile up.
		m.close()
		await get_tree().process_frame


## The area text may use: inside the drawing frame.
func _bounds() -> Rect2:
	return game.menus.get_viewport_rect().grow(-Blueprint.INSET)


func _check_fit(locale: String, sheet: String) -> void:
	var found := LayoutCheck.problems([game.menus], _bounds())
	assert_eq(found.size(), 0, "%s %s: %s" % [locale, sheet, "; ".join(found)])


func test_every_sheet_fits_in_every_language() -> void:
	var locales: Array = catalog.locales.keys()
	locales.append("en")
	for locale in locales:
		Save.set_locale(locale)
		await _open_every_sheet(_check_fit.bind(locale))


## The HUD while playing: a level, every effect's note, and a tutorial lesson.
func _play_every_hud_state(check: Callable) -> void:
	game.new_game(10)
	game.map._load_elapsed = game.map._load_time
	game.loaded()
	check.call("playing")
	game.reverse = true
	game.vanish = 3
	game.set_controls_message()
	check.call("reversed and vanished")
	game.vanish = 0
	game.stuck = true
	game.set_controls_message()
	check.call("stuck and reversed")
	game.reverse = false
	game.stuck = false
	game.map.hide_tiles()
	game._flash("_last_hide")
	game.set_controls_message()
	check.call("tiles hidden")
	game.map.unhide_tiles()
	game._flash("_last_points")
	game.set_controls_message()
	check.call("bonus points")
	game.game_over(false)
	game.new_game(6, true)
	game.map._load_elapsed = game.map._load_time
	game.loaded()
	game.reverse = true
	game.set_controls_message()
	check.call("tutorial")
	game.game_over(false)


func _check_hud(locale: String, state: String) -> void:
	var found := LayoutCheck.problems([game.hud], _bounds())
	assert_eq(found.size(), 0, "%s %s: %s" % [locale, state, "; ".join(found)])


## Before any choice is made the options value and the marked box read
## "phone's language", translated: the longest state of those two sheets.
func test_following_the_phone_lays_out_in_every_language() -> void:
	var locales: Array = catalog.locales.keys()
	locales.append("en")
	for locale in locales:
		Save.locale = ""
		Save.use_locale(locale)
		var m = game.menus
		for open_sheet in [func(): m.show_options(), func(): m.show_language()]:
			open_sheet.call()
			_check_fit(locale + " (phone)", m.current)
			m.close()
			await get_tree().process_frame


func test_the_hud_lays_out_in_every_language() -> void:
	var locales: Array = catalog.locales.keys()
	locales.append("en")
	for locale in locales:
		Save.set_locale(locale)
		_play_every_hud_state(_check_hud.bind(locale))


func test_hud_notes_fit_in_two_lines_in_every_language() -> void:
	game.levels = [{"rows": ["bcw"], "delay": 0.0}]
	game.new_game(1)
	var locales: Array = catalog.locales.keys()
	locales.append("en")
	for locale in locales:
		Save.set_locale(locale)
		for entry in catalog.strings:
			if entry.max > 36 or not entry.id == entry.id.to_upper():
				continue  # only the short capitals go in the bar
			var text: String = (
				tr_n(entry.id, entry.plural, 3) % 3 if entry.has("plural") else tr(entry.id)
			)
			if "%" in text:
				continue
			game.hud.set_controls_message(text)
			assert_true(
				game.hud.note_label.get_line_count() <= 2,
				"%s: '%s' takes %d lines" % [locale, text, game.hud.note_label.get_line_count()]
			)
