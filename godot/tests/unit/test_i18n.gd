extends GutTest
## Languages: every string a player can see is in i18n/catalog.json, every
## language translates all of them, every character has a bundled glyph, and
## every sheet still fits its boxes in every language.

const MAIN_SCENE := preload("res://scenes/main.tscn")
## TEXT entries that are numbers, symbols or format scaffolding, not words.
const UNTRANSLATED := [
	"001",
	"000",
	"001-B",
	"001-C",
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
const PLURAL_SAMPLES := [0, 1, 2, 3, 5, 11, 21, 25, 100]

var catalog: Dictionary
var msgids := {}
var game


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Dev.enabled = false
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/catalog.json"))
	for entry in catalog.strings:
		msgids[entry.id] = entry


func before_each() -> void:
	Save.reduce_motion = true
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	game.menus.close()


func after_each() -> void:
	Save.reduce_motion = false
	Save.set_locale("")


func _has_letters(text: String) -> bool:
	for ch in text:
		if ch.to_upper() != ch.to_lower():
			return true
	return false


# --- the catalog -----------------------------------------------------------


func test_every_menu_and_hud_string_is_in_the_catalog() -> void:
	for table in [Menus.TEXT, Hud.TEXT]:
		for key in table:
			var value = table[key]
			var texts: Array = value if value is Array else [value]
			for text in texts:
				if _has_letters(text) and text not in UNTRANSLATED:
					assert_true(msgids.has(text), "catalog has %s: %s" % [key, text])


func test_every_tr_call_in_the_scripts_is_in_the_catalog() -> void:
	var literal := RegEx.create_from_string('\\btr(?:_n)?\\(\\s*"((?:[^"\\\\]|\\\\.)*)"')
	var count := 0
	for script in ["main.gd", "hud.gd", "menus.gd", "level_map.gd"]:
		var source := FileAccess.get_file_as_string("res://scripts/" + script)
		for m in literal.search_all(source):
			var text: String = m.get_string(1).c_unescape()
			count += 1
			assert_true(msgids.has(text), "%s: catalog has %s" % [script, text])
	assert_gt(count, 20, "the game-loop notes go through tr()")


func test_data_text_is_in_the_catalog() -> void:
	var tutorial: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/tutorial.json")
	)
	for level in tutorial.levels:
		assert_true(msgids.has(level.description), "tutorial lesson: " + level.description)
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
		var texts: Array = [catalog.locales[locale].name]
		for entry in catalog.strings:
			if entry.has("plural"):
				for n in PLURAL_SAMPLES:
					texts.append(t.get_plural_message(entry.id, entry.plural, n))
			else:
				texts.append(t.get_message(entry.id))
		var missing := {}
		for text in texts:
			for ch in text:
				if ch != "\n" and not font.has_char(ch.unicode_at(0)):
					missing[ch] = true
		assert_eq(missing.keys(), [], "%s: characters without a glyph" % locale)


# --- the sheets ----------------------------------------------------------------


func _open_every_sheet(check: Callable) -> void:
	var m = game.menus
	var sheets := [
		func(): m.show_main(1842, true, 100),
		func(): m.show_first_play(),
		func(): m.show_options(),
		func(): m.show_language(),
		func(): m.show_pause(false, 35, 12),
		func(): m.show_pause(true),
		func(): m.show_confirm_quit(),
		func(): m.show_lose_life(2, 35),
		func(): m.show_lose_life(15, 35, "timeout"),
		func(): m.show_game_over(1842, true, true, 1790),
		func(): m.show_restart([10, 30]),
		func(): m.show_practice(1, 25, {21: {"time": 9, "stars": 1}}, 100),
		func(): m.show_end_level(1842, 10, 7, 2, true, 35, 14),
		func(): m.show_congratulations(2042, true),
		func(): m.show_game_complete(1842, 100, 100),
	]
	for open_sheet in sheets:
		open_sheet.call()
		check.call(m.current)


func _check_fit(locale: String, sheet: String) -> void:
	for b in game.menus.find_children("*", "Button", true, false):
		var need: float = b.get_minimum_size().x
		assert_true(
			need <= b.size.x + 0.5,
			"%s %s: button '%s' needs %d of %d" % [locale, sheet, b.text, need, b.size.x]
		)
	for l in game.menus.find_children("*", "Label", true, false):
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.size.x > 0.0 and l.text != "":
			var need: float = l.get_minimum_size().x
			assert_true(
				need <= l.size.x + 0.5,
				"%s %s: label '%s' needs %d of %d" % [locale, sheet, l.text, need, l.size.x]
			)


func test_every_sheet_fits_in_every_language() -> void:
	var locales: Array = catalog.locales.keys()
	locales.append("en")
	for locale in locales:
		Save.set_locale(locale)
		_open_every_sheet(_check_fit.bind(locale))


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
