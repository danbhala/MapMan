class_name BackButton
extends RefCounted
## Android's back button or gesture, for main.gd: steps out one level, like
## other apps. (project.godot turns off quit_on_go_back so back doesn't just
## close the app.)


static func press(g: Node) -> void:
	if g._tries.replay:
		g._end_replay()
		return
	if g.intro:
		g.intro.advance()
		return
	if g.dev_panel and g.dev_panel.is_open():
		g.dev_panel.close()
		return
	if g.drafting.go_back():
		return
	match g.menus.current:
		"":
			if g.game_active and not g.dead:
				g.show_pause_menu()
		"pause":
			g._on_menu_action("unpause")
		"confirm_quit":
			g._on_menu_action(g.menus.confirm_back)
		"wardrobe":
			g._on_menu_action("back to clear" if g._between else "main menu")
		"options", "restart", "first_play", "game_over", "congratulations", "practice":
			g._on_menu_action("main menu")
		"language", "controls", "privacy":
			g._on_menu_action("options")
		"main":
			g.get_tree().quit()
		# Tap-to-continue screens (life lost, level clear, completion scoring)
		# and the play stats question ignore back so a stray press can't
		# skip, lose or answer anything.
