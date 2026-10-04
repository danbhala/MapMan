extends SceneTree
## Draws the App Store icon: MapMan on the blue grid in a white frame, in the
## Blueprint look, 1024×1024 and opaque (App Store Connect refuses a build
## whose icon has an alpha channel). The iOS export presets point at the PNG.
##
##   xvfb-run -a godot --path godot --rendering-driver opengl3 \
##       --script res://tools/app_icon.gd [-- out.png]
##
## Needs a display (rendering), so xvfb-run on a headless machine.

const SIZE := 1024
const OUT := "res://assets/icon/app_icon_1024.png"
## Drawing units to icon pixels: the field and MapMan at seven times game size.
const SCALE := 7.0
## The frame sits inside iOS's rounded-corner mask (about 0.22 of the size).
const FRAME_INSET := 64.0
const FRAME_RADIUS := 168.0
const FRAME_WIDTH := 12.0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var out := OUT
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]

	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var field := ColorRect.new()
	field.color = Blueprint.FIELD
	field.size = Vector2(SIZE, SIZE)
	vp.add_child(field)

	# The grid lines up with the icon's centre, so MapMan stands on a crossing.
	var sheet := Node2D.new()
	sheet.scale = Vector2(SCALE, SCALE)
	var units := SIZE / SCALE
	var shift := fmod(units / 2.0, Blueprint.GRID_STEP)
	sheet.position = Vector2(shift - Blueprint.GRID_STEP, shift - Blueprint.GRID_STEP) * SCALE
	vp.add_child(sheet)
	var g := Blueprint.grid(sheet, Vector2(units, units) + Vector2.ONE * Blueprint.GRID_STEP * 2.0)
	g.color = Color(1, 1, 1, 0.16)

	var frame := Line2D.new()
	frame.points = _rounded_box(FRAME_INSET, SIZE - FRAME_INSET, FRAME_RADIUS)
	frame.width = FRAME_WIDTH
	frame.default_color = Blueprint.INK
	frame.joint_mode = Line2D.LINE_JOINT_ROUND
	frame.antialiased = true
	vp.add_child(frame)

	var man := Player.new()
	vp.add_child(man)
	man.scale = Vector2(SCALE, SCALE)
	# Feet a little below the middle, head well above it: the figure is about
	# 80 units tall, so this centres it optically.
	man.position = Vector2(SIZE / 2.0, SIZE / 2.0 + 40.0 * SCALE)
	man.show_player()
	man.modulate.a = 1.0
	man.look = Vector2(0.0, 0.25)
	man.auto_look = false
	man.queue_redraw()

	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var err := img.save_png(out)
	print("app icon: %s (%s)" % [ProjectSettings.globalize_path(out), error_string(err)])
	quit(0 if err == OK else 1)


func _rounded_box(lo: float, hi: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [
		[Vector2(hi - r, lo + r), -PI / 2.0],
		[Vector2(hi - r, hi - r), 0.0],
		[Vector2(lo + r, hi - r), PI / 2.0],
		[Vector2(lo + r, lo + r), PI],
	]
	for c: Array in corners:
		for k in 13:
			var a: float = c[1] + PI / 2.0 * k / 12.0
			pts.append(c[0] + Vector2(cos(a), sin(a)) * r)
	pts.append(pts[0])
	return pts
