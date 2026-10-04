extends SceneTree
## WARDROBE DESIGN PROTOTYPE - measures how far each look reaches, in MapMan's
## units from the tile centre, across five poses (the README's size table).
##
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --audio-driver Dummy \
##       --script "$PWD/docs/wardrobe/prototype/extents.gd"

const S := 4.0
var fig_script: Script
var cat: Script


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var dir: String = (get_script() as Script).resource_path.get_base_dir()
	fig_script = load(dir.path_join("outfit_figure.gd"))
	cat = load(dir.path_join("catalogue.gd"))
	var origin := Vector2(240, 520)
	print("outfit, top, left, right (units; classic head top is 81 above the tile centre)")
	for item in cat.ITEMS + cat.BENCH:
		var box := Rect2()
		var first := true
		for pose in ["front", "walk_r", "walk_l", "cheer", "away"]:
			var vp := SubViewport.new()
			vp.size = Vector2i(480, 600)
			vp.transparent_bg = true
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(vp)
			var f: Node2D = fig_script.new()
			f.outfit = item[0]
			vp.add_child(f)
			f.position = origin
			f.scale = Vector2(S, S)
			f.visible = true
			f.is_hidden = false
			cat.pose(f, pose)
			if pose == "cheer":
				f._hop = 0.0  # the hop lifts everything alike; measure the outfit
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			var used := img.get_used_rect()
			var r := Rect2((Vector2(used.position) - origin) / S, Vector2(used.size) / S)
			box = r if first else box.merge(r)
			first = false
			vp.queue_free()
		print("%s, %.0f, %.0f, %.0f" % [item[0], -box.position.y, -box.position.x, box.end.x])
	quit()
