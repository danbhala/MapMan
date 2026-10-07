extends Node3D
## Research prototype: "flip to 3D". Not part of the game.
##
## The sheet starts seen from the 2D game's own angle (a near-orthographic
## camera, tiles foreshortened like the 2D ovals) and looks impossible: the
## exit is across a gap. Flipping to 3D swings the camera round with a dolly
## zoom, and the raised tiles pop up out of the paper like a pop-up book:
## steps up, a walkway over the gap, steps down. MapMan climbs them.
##
## Run it as the main scene:
##   godot --path godot --resolution 1334x750 res://research_3d/popup3d.tscn
## Environment: SHOTS dir + SHOT_AT "1,2,3", END seconds, POSE (finale).

const TILE_DIR := "res://assets/tiles/"
const FIELD := Color("#16407a")
const LIP := Color("#0c2a55")
const TILE_H := 0.1
const MAN_H := 2.2
const STEP_TIME := 0.3
const STEP := 0.35  # one stair, in tile widths

## The level: [column, row, height in stairs, tile type]. Height 0 is the
## paper; anything above it is folded flat (and unseen) until the flip.
const LEVEL := [
	[0, 5, 0, "b"],
	[1, 5, 0, "c"],
	[2, 5, 0, "c"],
	[3, 5, 0, "c"],
	[3, 4, 1, "c"],
	[3, 3, 2, "c"],
	[3, 2, 3, "c"],
	[4, 2, 3, "c"],
	[5, 2, 3, "c"],
	[6, 2, 3, "p"],
	[7, 2, 3, "c"],
	[8, 2, 3, "c"],
	[9, 2, 3, "c"],
	[9, 3, 2, "c"],
	[9, 4, 1, "c"],
	[9, 5, 0, "c"],
	[10, 5, 0, "c"],
	[11, 5, 0, "e"],
]

## Timeline (seconds).
const T_MAN := 1.4
const T_WALK := 1.8
const T_FLIP := 3.9
const FLIP_TIME := 1.7
const T_ON := 6.0

## The two cameras: the 2D game's angle, and the 3D one.
const FLAT := {"fov": 3.0, "pitch": 41.0, "yaw": 0.0}
const DEEP := {"fov": 40.0, "pitch": 47.0, "yaw": -26.0}
const POSES := ["spin", "lean", "stretch", "star", "wiggle"]

var tiles := {}  # Vector2i -> {type, h, node, stalk}
var route: Array[Vector2i] = []
var centre := Vector3(5.5, 0.5, 3.6)
var cam: Camera3D
var man: Sprite3D
var foot_shadow: Sprite3D
var player: Player
var t := 0.0
var flip := 0.0  # 0 = the 2D angle, 1 = 3D
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
	for s in (at if at != "" else "3.5,5.0,7.5,9.5").split(","):
		shot_at.append(float(s))
	if OS.has_environment("END"):
		end_after = float(OS.get_environment("END"))
	seed(3)
	_build_world()
	_build_tiles()
	_build_man()
	route = [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5)]
	for k in [
		Vector2i(3, 4),
		Vector2i(3, 3),
		Vector2i(3, 2),
		Vector2i(4, 2),
		Vector2i(5, 2),
		Vector2i(6, 2),
		Vector2i(7, 2),
		Vector2i(8, 2),
		Vector2i(9, 2),
		Vector2i(9, 3),
		Vector2i(9, 4),
		Vector2i(9, 5),
		Vector2i(10, 5),
		Vector2i(11, 5)
	]:
		route.append(k)
	_place_camera()


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
	var pencil := StandardMaterial3D.new()
	pencil.albedo_color = Color(1, 1, 1, 0.75)
	pencil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pencil.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for row: Array in LEVEL:
		var key := Vector2i(row[0], row[1])
		var h: float = row[2] * STEP
		var ty: String = row[3]
		var node := Node3D.new()
		node.position = Vector3(key.x, h, key.y)
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
		node.visible = false
		var stalk: MeshInstance3D = null
		if h > 0.0:
			# A pencil-thin column down to the paper, like a pop-up's tab.
			stalk = MeshInstance3D.new()
			var sm := CylinderMesh.new()
			sm.top_radius = 0.035
			sm.bottom_radius = 0.035
			sm.height = 1.0
			stalk.mesh = sm
			stalk.material_override = pencil
			stalk.position = Vector3(key.x, 0.0, key.y)
			stalk.scale = Vector3(1, 0.001, 1)
			stalk.visible = false
			add_child(stalk)
		tiles[key] = {"type": ty, "h": h, "node": node, "stalk": stalk}
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
	flag.position = Vector3(11.62, 0, 4.9)
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


func _top(k: Vector2i) -> Vector3:
	return Vector3(k.x, tiles[k]["h"] + TILE_H, k.y)


func _man_at(p: Vector3) -> void:
	man.position = p + Vector3(0, 0.01, 0)
	foot_shadow.position = p + Vector3(0, 0.006, 0)
	foot_shadow.visible = man.visible


func _process(delta: float) -> void:
	t += delta
	_pop_ground()
	if t >= T_MAN and not man.visible:
		man.visible = true
		player.show_player()
		player.face_idle()
		_man_at(_top(route[0]))
	_walk()
	_flip()
	_finale()
	player.tick(delta)
	_place_camera()
	_shots()
	if end_after > 0.0 and t >= end_after:
		get_tree().quit()


func _pop_ground() -> void:
	for k: Vector2i in tiles:
		var tile: Dictionary = tiles[k]
		if tile["h"] > 0.0 or tile.get("in", false):
			continue
		if t >= 0.2 + k.x * 0.06:
			tile["in"] = true
			var node: Node3D = tile["node"]
			var home := node.position
			node.visible = true
			node.position = home + Vector3(0, 2.0, 0)
			var tw := create_tween()
			tw.tween_property(node, "position", home, 0.28)
			tw.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			if k == Vector2i(11, 5):
				get_node("Flag").visible = true


## The flip: a dolly zoom from the 2D game's angle to 3D, and the raised
## tiles unfold out of the paper, nearest the camera's turn first.
func _flip() -> void:
	if t < T_FLIP:
		return
	var k := clampf((t - T_FLIP) / FLIP_TIME, 0.0, 1.0)
	flip = k * k * (3.0 - 2.0 * k)
	for key: Vector2i in tiles:
		var tile: Dictionary = tiles[key]
		if tile["h"] <= 0.0 or tile.get("in", false):
			continue
		var order := absf(key.x - 3) + absf(key.y - 5)
		if t >= T_FLIP + 0.45 + order * 0.07:
			tile["in"] = true
			var node: Node3D = tile["node"]
			var stalk: MeshInstance3D = tile["stalk"]
			var h: float = tile["h"]
			node.visible = true
			node.position.y = 0.0
			node.scale = Vector3(1, 1, 0.05)
			stalk.visible = true
			var tw := create_tween().set_parallel()
			tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(node, "position:y", h, 0.45)
			tw.tween_property(node, "scale:z", 1.0, 0.45)
			tw.tween_property(stalk, "scale:y", h, 0.45)
			tw.tween_property(stalk, "position:y", h * 0.5, 0.45)


func _walk() -> void:
	if t < T_WALK:
		return
	# Three steps to the edge, a stop at the gap, then on after the flip.
	var steps := (t - T_WALK) / STEP_TIME
	if t >= T_ON:
		steps = 3.0 + (t - T_ON) / STEP_TIME
	else:
		steps = minf(steps, 3.0)
	var i := mini(int(steps), route.size() - 1)
	var frac := clampf(steps - i, 0.0, 1.0)
	if i >= route.size() - 1:
		if step_i != route.size() - 1:
			step_i = route.size() - 1
			player.face_idle()
			_start_finale()
		_man_at(_top(route.back()))
		return
	if i == 3 and t < T_ON:
		# Stuck at the gap: he looks across it, then back at us.
		if step_i != 3:
			step_i = 3
			player.face_direction(Vector2i.RIGHT, false)
			get_tree().create_timer(0.9).timeout.connect(player.face_idle)
		_man_at(_top(route[3]))
		return
	var a := route[i]
	var b := route[i + 1]
	if i != step_i:
		step_i = i
		player.face_direction(b - a, true)
	_man_at(_top(a).lerp(_top(b), frac))


func _place_camera() -> void:
	var fov: float = lerpf(FLAT["fov"], DEEP["fov"], flip)
	var pitch := deg_to_rad(lerpf(FLAT["pitch"], DEEP["pitch"], flip))
	var yaw := deg_to_rad(lerpf(FLAT["yaw"], DEEP["yaw"], flip))
	# Dolly zoom: keep the sheet the same size on screen while the lens
	# widens, so the flat 2D look bends into depth.
	var half := 4.1
	var dist := half / tan(deg_to_rad(fov) * 0.5)
	var look := centre
	var m := man.position
	if finale_t >= 0.0:
		var f := clampf((t - finale_t) / 1.1, 0.0, 1.0)
		f = f * f * (3.0 - 2.0 * f)
		look = look.lerp(m + Vector3(0, 1.05, 0), f)
		dist = lerpf(dist, 5.0, f)
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	cam.fov = fov
	cam.near = maxf(0.05, dist * 0.02)
	cam.position = look + dir * dist
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
		get_viewport().get_texture().get_image().save_png("%s/popup_%04.1f.png" % [shots_dir, s])
