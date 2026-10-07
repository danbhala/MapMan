extends Node3D
## Research prototype: a FEZ-style turn. Not part of the game.
##
## The sheet is seen from a fixed angle, square on, without perspective, so
## two tiles that are far apart in depth and height can land on the same
## spot on the screen. What MapMan can step to is decided by the screen,
## not by where tiles really are. Turn the sheet a quarter turn and a far,
## raised ledge lines up with the path: a bridge that only exists from
## that side.
##
## Run it as the main scene:
##   godot --path godot --resolution 1334x750 res://research_3d/fez3d.tscn
## Environment: FEZ_LEVEL bridge|circle, SHOTS dir + SHOT_AT "1,2,3", END
## seconds, POSE (finale).

const TILE_DIR := "res://assets/tiles/"
const FIELD := Color("#16407a")
const LIP := Color("#0c2a55")
const TILE_H := 0.1
const MAN_H := 2.2
const STEP_TIME := 0.3
## The camera looks down at 45 degrees, so one step of height moves a tile
## one row up the screen, exactly as one tile further away does.
const PITCH := 45.0
const STEP := 1.0

## Levels: [column x, height, depth z, type], in walking order (the tour
## walks them in this order). "o" is a turn tile: stepping onto it turns the
## sheet a quarter turn clockwise, once. FEZ_LEVEL picks one.
const LEVELS := {
	# From the front the ledge floats off to the right; seen from the right
	# side it sits exactly in the gap.
	"bridge":
	[
		[0, 0, 5, "b"],
		[1, 0, 5, "c"],
		[2, 0, 5, "c"],
		[3, 0, 5, "o"],
		[5, 1, 5, "c"],
		[6, 1, 5, "p"],
		[7, 1, 5, "c"],
		[8, 1, 5, "c"],
		[8, 0, 5, "e"],
	],
	# Full Circle: the flag is in the same screen cell as the start. Three
	# turns and a climb of four bring him back to where he began, four
	# steps up. Checked by turn_solver.py: one way through, 24 steps.
	"circle":
	[
		[0, 0, 0, "b"],
		[1, 0, 0, "c"],
		[2, 0, 0, "c"],
		[3, 0, 0, "o"],
		[4, 1, -1, "c"],
		[5, 2, -2, "p"],
		[6, 3, -3, "c"],
		[7, 4, -4, "o"],
		[7, 4, -5, "c"],
		[6, 4, -5, "c"],
		[5, 4, -5, "c"],
		[4, 4, -5, "p"],
		[3, 4, -5, "c"],
		[2, 4, -5, "c"],
		[1, 4, -5, "c"],
		[0, 4, -5, "o"],
		[0, 4, -4, "c"],
		[0, 4, -3, "c"],
		[0, 4, -2, "p"],
		[0, 4, -1, "c"],
		[0, 4, 0, "c"],
		[0, 4, 1, "c"],
		[0, 4, 2, "c"],
		[0, 4, 3, "c"],
		[0, 4, 4, "e"],
	],
}
const T_MAN := 1.4
const T_WALK := 1.8
const TURN_TIME := 0.7  # quick: a flick of the wrist, not a slow pan
const POSES := ["spin", "lean", "stretch", "star", "wiggle"]

var level: Array = []
var plan: Array = []  # the tour: {at, until, kind, a, b, from, to}
var exit_key := Vector3i.ZERO
var return_at := 0.0  # when the sheet starts coming back round after the finale
var size := 9.0
var tiles := {}  # Vector3i (x, h, z) -> {type, node}
var route: Array[Vector3i] = []
var centre := Vector3.ZERO
var cam: Camera3D
var man: Sprite3D
var foot_shadow: Sprite3D
var player: Player
var t := 0.0
var yaw := 0.0  # the view: 0 = from the front, 90 = from the right
var step_i := -1
var finale_t := -1.0
var pose := ""
var shots_dir := ""
var shot_at: Array[float] = []
var end_after := 0.0
var _jumps := 0
var _posed := false
var _confetti_done := false
var _textures := {}


func _ready() -> void:
	shots_dir = OS.get_environment("SHOTS")
	var at := OS.get_environment("SHOT_AT")
	for s in (at if at != "" else "3.3,5.0,6.0,8.0").split(","):
		shot_at.append(float(s))
	if OS.has_environment("END"):
		end_after = float(OS.get_environment("END"))
	seed(3)
	var name := OS.get_environment("FEZ_LEVEL")
	level = LEVELS[name if LEVELS.has(name) else "bridge"]
	for row: Array in level:
		route.append(Vector3i(row[0], row[1], row[2]))
		if row[3] == "e":
			exit_key = route.back()
	var lo := Vector3(route[0])
	var hi := lo
	for k in route:
		lo = lo.min(Vector3(k))
		hi = hi.max(Vector3(k))
	centre = (lo + hi) * 0.5
	centre.y = (lo.y + hi.y) * 0.5 * STEP + 0.6
	size = maxf(9.0, (hi - lo).length() * 0.9)
	_build_world()
	_build_tiles()
	_build_man()
	_plan_tour()
	_place_camera()


## The tour: a step per tile, a pause and a turn on each turn tile, a long
## look at the gap before the first turn.
func _plan_tour() -> void:
	var at := T_WALK
	var y := 0.0
	for i in route.size():
		if i > 0:
			plan.append({"at": at, "until": at + STEP_TIME, "kind": "step", "a": i - 1, "b": i})
			at += STEP_TIME
		if tiles[route[i]]["type"] == "o":
			var pause := 1.6 if i < 4 else 0.5
			plan.append({"at": at, "until": at + pause, "kind": "look", "a": i})
			at += pause
			plan.append(
				{
					"at": at,
					"until": at + TURN_TIME,
					"kind": "turn",
					"from": y,
					"to": y + 90.0,
					"a": i
				}
			)
			y += 90.0
			at += TURN_TIME + 0.3
	plan.append({"at": at, "until": at + 3.4, "kind": "finale", "a": route.size() - 1})
	at += 3.4
	# Then the sheet comes round to the front again, to show where he is.
	return_at = at
	while y < 360.0:
		plan.append(
			{
				"at": at,
				"until": at + TURN_TIME,
				"kind": "turn",
				"from": y,
				"to": y + 90.0,
				"a": route.size() - 1
			}
		)
		y += 90.0
		at += TURN_TIME + 0.2


# --- building ----------------------------------------------------------------


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = FIELD
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.82, 1.0)
	e.ambient_light_energy = 0.55
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, -28, 0)
	sun.light_energy = 0.9
	add_child(sun)

	var paper := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	paper.mesh = plane
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded;
uniform vec3 field : source_color;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float line(float v, float w) {
	float d = abs(fract(v) - 0.5);
	return 1.0 - smoothstep(w, w + fwidth(v) * 1.2, 0.5 - d);
}
void fragment() {
	vec2 p = wp.xz + 0.5;
	float minor = max(line(p.x, 0.012), line(p.y, 0.012));
	float major = max(line(p.x / 5.0, 0.004), line(p.y / 5.0, 0.004));
	vec3 c = field;
	c = mix(c, vec3(1.0), minor * 0.10);
	c = mix(c, vec3(1.0), major * 0.20);
	ALBEDO = c;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("field", FIELD)
	paper.material_override = mat
	add_child(paper)

	cam = Camera3D.new()
	cam.far = 1000.0
	add_child(cam)


func _top_texture(file: String) -> Texture2D:
	if not _textures.has(file):
		var img: Image = (load(TILE_DIR + file) as Texture2D).get_image()
		img.decompress()
		_textures[file] = ImageTexture.create_from_image(img.get_region(Rect2i(0, 0, 96, 59)))
	return _textures[file]


func _build_tiles() -> void:
	var lip := StandardMaterial3D.new()
	lip.albedo_color = LIP
	for row: Array in level:
		var key := Vector3i(row[0], row[1], row[2])
		var h: float = row[1] * STEP
		var ty: String = row[3]
		var node := Node3D.new()
		node.position = Vector3(key.x, h, key.z)
		add_child(node)
		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.41
		cyl.bottom_radius = 0.43
		cyl.height = TILE_H
		disc.mesh = cyl
		disc.material_override = lip
		disc.position.y = TILE_H * 0.5
		node.add_child(disc)
		var face := Sprite3D.new()
		face.texture = _top_texture(LevelMap.texture_file(ty))
		face.axis = Vector3.AXIS_Y
		face.pixel_size = 0.84 / 96.0
		face.scale = Vector3(1, 1, 96.0 / 59.0)  # un-squash the ellipse
		face.position.y = TILE_H + 0.002
		face.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		face.modulate = Color(0.92, 0.95, 1.0)
		node.add_child(face)
		if ty == "o":
			var arrow := Label3D.new()
			arrow.text = "\u21bb"
			arrow.font_size = 160
			arrow.pixel_size = 0.0032
			arrow.modulate = LIP
			arrow.outline_size = 0
			arrow.rotation_degrees = Vector3(-90, 0, 0)
			arrow.position.y = TILE_H + 0.004
			node.add_child(arrow)
		node.visible = false
		tiles[key] = {"type": ty, "h": h, "node": node}
	# The flag on the exit, beside the tile.
	var flag := Node3D.new()
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.025
	pm.bottom_radius = 0.025
	pm.height = 1.1
	pole.mesh = pm
	pole.position.y = 0.55
	var white := StandardMaterial3D.new()
	white.albedo_color = Color.WHITE
	pole.material_override = white
	flag.add_child(pole)
	var cloth := MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = Vector3(0.3, 0.38, 0.02)
	cloth.mesh = pr
	cloth.rotation_degrees = Vector3(0, 0, -90)
	cloth.position = Vector3(0.19, 0.95, 0)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("#ffd166")
	cloth.material_override = gold
	flag.add_child(cloth)
	flag.position = Vector3(exit_key.x + 0.62, exit_key.y * STEP, exit_key.z - 0.1)
	flag.visible = false
	flag.name = "Flag"
	add_child(flag)


func _build_man() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(360, 400)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	player = Player.new()
	player.scale = Vector2(2.8, 2.8)
	player.position = Vector2(180, 388)
	vp.add_child(player)
	player.vanish()
	man = Sprite3D.new()
	man.texture = vp.get_texture()
	man.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	man.pixel_size = MAN_H / (2.8 * 82.0)
	man.offset = Vector2(0, 200 - 12)  # pivot at his feet
	man.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	man.shaded = false
	man.no_depth_test = true  # always in front, as in FEZ: the screen is the truth
	man.render_priority = 10
	man.visible = false
	add_child(man)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.06, 0.15, 0.55))
	grad.set_color(1, Color(0.02, 0.06, 0.15, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	foot_shadow = Sprite3D.new()
	foot_shadow.texture = gt
	foot_shadow.axis = Vector3.AXIS_Y
	foot_shadow.pixel_size = 0.62 / 64.0
	foot_shadow.scale = Vector3(1.0, 0.62, 1.0)
	foot_shadow.shaded = false
	foot_shadow.visible = false
	add_child(foot_shadow)


# --- the tour ----------------------------------------------------------------


func _top(k: Vector3i) -> Vector3:
	return Vector3(k.x, tiles[k]["h"] + TILE_H, k.z)


func _man_at(p: Vector3) -> void:
	man.position = p + Vector3(0, 0.01, 0)
	foot_shadow.position = p + Vector3(0, 0.006, 0)
	foot_shadow.visible = man.visible


func _process(delta: float) -> void:
	t += delta
	_pop_in()
	if t >= T_MAN and not man.visible:
		man.visible = true
		player.show_player()
		player.face_idle()
		_man_at(_top(route[0]))
	_play()
	_finale()
	player.tick(delta)
	_place_camera()
	_shots()
	if end_after > 0.0 and t >= end_after:
		get_tree().quit()


func _pop_in() -> void:
	for k: Vector3i in tiles:
		var tile: Dictionary = tiles[k]
		if tile.get("in", false):
			continue
		if t >= 0.2 + (k.x + k.z - route[0].z) * 0.05:
			tile["in"] = true
			var node: Node3D = tile["node"]
			var home := node.position
			node.visible = true
			node.position = home + Vector3(0, 2.0, 0)
			var tw := create_tween()
			tw.tween_property(node, "position", home, 0.28)
			tw.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			if k == exit_key:
				get_node("Flag").visible = true


## Plays the tour. The turn: the sheet swings a quarter turn. Nothing
## moves; what is next to what changes, because that is decided by where
## the tiles land on the screen, not where they are.
func _play() -> void:
	for item: Dictionary in plan:
		if t < item["at"]:
			continue
		var k := clampf((t - item["at"]) / (item["until"] - item["at"]), 0.0, 1.0)
		match item["kind"]:
			"step":
				var a: Vector3i = route[item["a"]]
				var b: Vector3i = route[item["b"]]
				if step_i != item["b"]:
					step_i = item["b"]
					var d := b - a
					# Facing is on the screen: from the side, along x is down.
					var y := deg_to_rad(yaw)
					var sx := roundf(d.x * cos(y) - d.z * sin(y))
					var sy := roundf(d.z * cos(y) + d.x * sin(y))
					player.face_direction(Vector2i(int(sx), int(sy)), true)
				# From tile to tile along the screen, however far apart they are.
				_man_at(_top(a).lerp(_top(b), k))
			"look":
				# On a turn tile: he looks across the gap, then back at us.
				if item.get("done", false):
					continue
				if k < 0.5:
					if not item.get("looked", false):
						item["looked"] = true
						player.face_direction(Vector2i.RIGHT, false)
				else:
					item["done"] = true
					player.face_idle()
				_man_at(_top(route[item["a"]]))
			"turn":
				var e := k * k * (3.0 - 2.0 * k)
				yaw = lerpf(item["from"], item["to"], e)
				if not item.get("spent", false) and k > 0.0:
					item["spent"] = true
					_spend(route[item["a"]])
			"finale":
				if finale_t < 0.0:
					player.face_idle()
					_start_finale()


## A used turn tile: its arrow fades to a dot.
func _spend(k: Vector3i) -> void:
	var node: Node3D = tiles[k]["node"]
	for c in node.get_children():
		if c is Label3D:
			create_tween().tween_property(c, "modulate:a", 0.25, 0.4)


func _place_camera() -> void:
	var pitch := deg_to_rad(PITCH)
	var y := deg_to_rad(yaw)
	var look := centre
	var sz := size
	if finale_t >= 0.0:
		var f := clampf((t - finale_t) / 1.1, 0.0, 1.0)
		if t >= return_at:
			f = 1.0 - clampf((t - return_at) / 1.0, 0.0, 1.0)  # back out for the reveal
		f = f * f * (3.0 - 2.0 * f)
		look = look.lerp(man.position + Vector3(0, 1.05, 0), f)
		sz = lerpf(size, 5.5, f)
	var dir := Vector3(sin(y) * cos(pitch), sin(pitch), cos(y) * cos(pitch))
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = sz
	cam.position = look + dir * 40.0
	cam.look_at(look, Vector3.UP)


# --- the finale (as in board3d.gd) -------------------------------------------


func _start_finale() -> void:
	finale_t = t
	pose = OS.get_environment("POSE")
	if pose not in POSES:
		randomize()
		pose = POSES[randi() % POSES.size()]


func _finale() -> void:
	if finale_t < 0.0:
		return
	var f := t - finale_t
	player.happy = 1.0
	if _jumps < 3 and f >= 0.15 + _jumps * 0.5:
		_jumps += 1
		player.jump()
	if not _confetti_done and f >= 0.35:
		_confetti_done = true
		_confetti(man.position + Vector3(0, MAN_H + 0.3, 0))
		_confetti(man.position + Vector3(0.25, 1.25, 0.05))
	if f < 1.75:
		return
	var p := f - 1.75
	match pose:
		"spin":
			if not _posed:
				_posed = true
				player.spin_around()
				get_tree().create_timer(0.5).timeout.connect(player.spin_around)
		"lean":
			player.rotation = lerpf(player.rotation, -0.32, 0.15)
		"stretch":
			player.scale = player.scale.lerp(Vector2(2.8 * 0.86, 2.8 * 1.22), 0.2)
		"star":
			if not _posed:
				_posed = true
				player.spin_around()
				player._jump = 0.0
				player.jump()
		"wiggle":
			player.rotation = sin(p * 11.0) * 0.22
			player.flip = 1.0 if sin(p * 5.5) > 0.0 else -1.0
			player.squash = absf(sin(p * 11.0)) * 0.35


func _confetti(at: Vector3) -> void:
	var c := CPUParticles3D.new()
	c.one_shot = true
	c.explosiveness = 0.92
	c.amount = 90
	c.lifetime = 3.2
	c.position = at
	c.direction = Vector3(0, 1, 0)
	c.spread = 75.0
	c.initial_velocity_min = 2.6
	c.initial_velocity_max = 4.6
	c.gravity = Vector3(0, -3.2, 0)
	c.damping_min = 1.2
	c.damping_max = 2.2
	c.angle_max = 360.0
	c.angular_velocity_min = -540.0
	c.angular_velocity_max = 540.0
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	g.colors = PackedColorArray(
		[Color("#ff9fb5"), Color("#ffd166"), Color("#c9a6ff"), Color("#8be0c8"), Color.WHITE]
	)
	c.color_initial_ramp = g
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	c.mesh = quad
	add_child(c)
	c.emitting = true


func _shots() -> void:
	if shots_dir == "" or shot_at.is_empty():
		return
	if t >= shot_at[0]:
		var s: float = shot_at.pop_front()
		get_viewport().get_texture().get_image().save_png("%s/fez_%04.1f.png" % [shots_dir, s])
