extends SceneTree
## Every menu sheet and HUD state in every language, saved as pictures and
## checked for text that overflows its box, is clipped, overlaps other text
## or leaves the screen. Run it through tools/i18n_shots.sh, or directly:
##
##   xvfb-run godot --path godot --rendering-driver opengl3 --resolution 1334x750 \
##       --fixed-fps 60 --audio-driver Dummy --script res://tools/i18n_shots.gd \
##       -- --out=/tmp/mapman-i18n [--locales=ar,ja] [--boxes]
##
## Writes <out>/<locale>/<screen>.png and <out>/report.txt; exits 1 on problems.
## --boxes outlines every text's measured box on the pictures. The rules are
## in tools/layout_check.gd, which tests/unit/test_i18n.gd also runs.

const LayoutCheck := preload("res://tools/layout_check.gd")

var out_dir := "user://i18n_shots"
var only: PackedStringArray = []
var boxes := false
var game
var problems: PackedStringArray = []
var screens := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.split("=")[1]
		elif arg.begins_with("--locales="):
			only = arg.split("=")[1].split(",")
		elif arg == "--boxes":
			boxes = true
	DirAccess.make_dir_recursive_absolute(out_dir)
	run.call_deferred()


func frames(n := 1) -> void:
	for i in n:
		await process_frame


# --- the checks ----------------------------------------------------------------


## The area text may use: inside the drawing frame.
func _bounds() -> Rect2:
	return root.get_visible_rect().grow(-Blueprint.INSET)


## Outline every text's box on the picture, to see what the check sees.
func _draw_boxes(img: Image) -> void:
	var scale := Vector2(img.get_size()) / root.get_visible_rect().size
	for c in LayoutCheck.texts(game.menus) + LayoutCheck.texts(game.hud):
		var box := LayoutCheck.text_box(c)
		var r := Rect2i((box.position * scale).floor(), (box.size * scale).ceil())
		for x in range(r.position.x, r.end.x):
			img.set_pixel(x, r.position.y, Blueprint.PINK)
			img.set_pixel(x, r.end.y - 1, Blueprint.PINK)
		for y in range(r.position.y, r.end.y):
			img.set_pixel(r.position.x, y, Blueprint.PINK)
			img.set_pixel(r.end.x - 1, y, Blueprint.PINK)


func shot(locale: String, name: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if boxes:
		_draw_boxes(img)
	var dir := out_dir.path_join(locale)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))
	for p in LayoutCheck.problems([game.menus, game.hud], _bounds()):
		problems.append("%s/%s: %s" % [locale, name, p])
	screens += 1


# --- the screens ------------------------------------------------------------------


func _loaded() -> void:
	game.map._load_elapsed = game.map._load_time
	game.loaded()


func sheets(locale: String) -> void:
	var m = game.menus
	game.game_over(false)
	m.show_main(1842, true, 100)
	await shot(locale, "01_main")
	m.show_first_play()
	await shot(locale, "02_first_run")
	m.show_options()
	await shot(locale, "03_options")
	m.show_language()
	await shot(locale, "04_language")
	# As a phone in this language shows them before any choice is made.
	var save = root.get_node("Save")
	save.locale = ""
	save.use_locale(locale)
	m.show_options()
	await shot(locale, "05_options_phone")
	m.show_language()
	await shot(locale, "06_language_phone")
	save.set_locale(locale)
	m.show_pause(false, 35, 12)
	await shot(locale, "07_pause")
	m.show_pause(true)
	await shot(locale, "08_pause_tutorial")
	m.show_confirm_quit()
	await shot(locale, "09_confirm")
	m.show_lose_life(2, 35)
	await shot(locale, "10_lose_life")
	m.show_lose_life(15, 35, "timeout")
	await shot(locale, "11_lose_life_timeout")
	m.show_game_over(1842, true, true, 1790)
	await shot(locale, "12_game_over")
	m.show_restart([10, 30])
	await shot(locale, "13_checkpoints")
	m.show_practice(1, 25, {21: {"time": 9, "stars": 1}, 22: {"time": 12, "stars": 0}}, 100)
	await shot(locale, "14_practice")
	m.show_end_level(1842, 10, 7, 2, true, 35, 14)
	await shot(locale, "15_level_clear")
	m.show_end_level(1842, 10, 7, 0, false, 100, 14, true)
	await shot(locale, "16_last_level_clear")
	m.show_congratulations(2042, true)
	await shot(locale, "17_congratulations")
	m.show_game_complete(1842, 100, 100)
	await shot(locale, "18_completion")
	m.close()


func hud_states(locale: String) -> void:
	game.menus.close()
	game.new_game(10)
	_loaded()
	await shot(locale, "19_playing")
	game.reverse = true
	game.vanish = 3
	game.set_background()
	game.set_controls_message()
	await shot(locale, "20_reversed_vanished")
	game.vanish = 0
	game.stuck = true
	game.set_background()
	game.set_controls_message()
	await shot(locale, "21_stuck_reversed")
	game.reverse = false
	game.stuck = false
	game.map.hide_tiles()
	game._flash("_last_hide")
	game.set_background()
	game.set_controls_message()
	await shot(locale, "22_tiles_hidden")
	game.map.unhide_tiles()
	game._flash("_last_points")
	game.set_background()
	game.set_controls_message()
	await shot(locale, "23_bonus_points")
	game.game_over(false)
	# The longest lesson, with an effect's note up in the header strip.
	game.new_game(6, true)
	_loaded()
	game.reverse = true
	game.set_background()
	game.set_controls_message()
	await shot(locale, "24_tutorial")
	game.game_over(false)
	game.menus.close()


func run() -> void:
	seed(20261004)
	var save = root.get_node("Save")
	save.persist = false
	save.reduce_motion = true  # sheets settle at once
	var dev = root.get_node("Dev")
	dev.enabled = false
	dev.persist = false
	save.highscore = 0
	save.first_play = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(5)

	var catalog: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://i18n/catalog.json")
	)
	var locales: PackedStringArray = ["en"]
	locales.append_array(catalog.locales.keys())
	if not only.is_empty():
		locales = only
	for locale in locales:
		save.set_locale(locale)
		await sheets(locale)
		await hud_states(locale)
	save.set_locale("")

	var report := FileAccess.open(out_dir.path_join("report.txt"), FileAccess.WRITE)
	report.store_line("%d screens in %d languages" % [screens, locales.size()])
	for p in problems:
		report.store_line(p)
	report.close()
	if problems.is_empty():
		print("I18N SHOTS OK: %d screens in %d languages" % [screens, locales.size()])
		quit(0)
	else:
		print("I18N SHOTS: %d problems\n- " % problems.size() + "\n- ".join(problems))
		quit(1)
