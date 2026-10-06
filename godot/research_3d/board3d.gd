extends Node3D
## Research prototype: one real level from data/levels.json in 3D.
##
## Not part of the game. Run it as the main scene:
##   godot --path godot --resolution 1334x750 res://research_3d/board3d.tscn
## Environment:
##   CAM    table | iso | chase   (default table)
##   LEVEL  level number          (default 10)
##   SHOTS  directory: saves <cam>_<t>.png at the SHOT_AT times
##   SHOT_AT comma list of seconds (default "1.2,2.6,6.5,9.5")
##   END    seconds, then quit    (default 0 = run forever)
##
## The tiles are the game's own tile art laid flat on discs, MapMan is the
## game's own drawing (player.gd) rendered into a paper cut-out that always
## faces the camera, so nothing here redraws the original art.

const TILE_DIR := "res://assets/tiles/"
const FIELD := Color("#16407a")
const LIP := Color("#0c2a55")
const STEP_TIME := 0.3
const WALK_FROM := 3.0
const TILE_H := 0.1
const MAN_H := 2.2  # world units, feet to head (tiles are 1 apart)
const HIDERS := ["i", "@", "!", "+"]  # the tiles a hide tile hides

var cam_mode := "table"
var level_no := 10
var shots_dir := ""
var shot_at: Array[float] = []
var end_after := 0.0

var rows: Array = []
var tiles := {}  # Vector2i -> {type, node}
var start := Vector2i.ZERO
var exit_key := Vector2i.ZERO
var route: Array[Vector2i] = []
var centre := Vector3.ZERO
var board: Node3D
var cam: Camera3D
var man: Sprite3D
var player: Player
var man_vp: SubViewport
var foot_shadow: Sprite3D
var t := 0.0
var step_i := -1
var hidden_now := false
var tilt := Vector2.ZERO
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _textures := {}


func _ready() -> void:
	cam_mode = OS.get_environment("CAM") if OS.has_environment("CAM") else "table"
	if OS.has_environment("LEVEL"):
		level_no = int(OS.get_environment("LEVEL"))
	shots_dir = OS.get_environment("SHOTS")
	var at := OS.get_environment("SHOT_AT")
	for s in (at if at != "" else "1.2,2.6,6.5,9.5").split(","):
		shot_at.append(float(s))
	if OS.has_environment("END"):
		end_after = float(OS.get_environment("END"))
	seed(7)
	_load_level()
	_build_world()
	_build_tiles()
	_build_man()
	_plan_route()
	_place_camera(0.0, true)


# --- level -------------------------------------------------------------------


func _load_level() -> void:
	var f := FileAccess.open("res://data/levels.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	for l: Dictionary in data["levels"]:
		if int(l["number"]) == level_no:
			rows = l["rows"]
	for r in rows.size():
		var line: String = rows[r]
		for c in line.length():
			var ch := line[c]
			if ch == " " or ch == "-":
				continue
			var key := Vector2i(c, r)
			tiles[key] = {"type": ch}
			if ch == "b":
				start = key
			if ch.to_lower() in ["n", "s", "e", "w"]:
				exit_key = key
	var w := 0
	for line: String in rows:
		w = maxi(w, line.length())
	centre = Vector3((w - 1) * 0.5, 0.0, (rows.size() - 1) * 0.5)


func _bfs(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == to:
			var path: Array[Vector2i] = [cur]
			while cur != from:
				cur = prev[cur]
				path.push_front(cur)
			return path
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var n := cur + d
			if tiles.has(n) and not prev.has(n) and tiles[n]["type"] not in ["d", "!"]:
				prev[n] = cur
				queue.append(n)
	return []


## Start to exit, by way of the hide tile when there is one, so the tour
## shows the hidden tiles going out and MapMan walking them from memory.
func _plan_route() -> void:
	var hide := Vector2i(-1, -1)
	for k: Vector2i in tiles:
		if tiles[k]["type"] == "h":
			hide = k
	if hide.x >= 0:
		route = _bfs(start, hide)
		var rest := _bfs(hide, exit_key)
		rest.pop_front()
		route.append_array(rest)
	else:
		route = _bfs(start, exit_key)


# --- building ----------------------------------------------------------------


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = FIELD.darkened(0.35)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.82, 1.0)
	e.ambient_light_energy = 0.55
	e.fog_enabled = cam_mode == "chase"
	e.fog_light_color = FIELD.darkened(0.35)
	e.fog_density = 0.035
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, -28, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.55
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)

	board = Node3D.new()
	board.position = centre
	add_child(board)

	var paper := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
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
	ROUGHNESS = 0.95;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("field", FIELD)
	paper.material_override = mat
	paper.position = -centre + Vector3(centre.x, 0, centre.z)
	board.add_child(paper)
	paper.position = Vector3.ZERO

	cam = Camera3D.new()
	add_child(cam)


func _top_texture(file: String) -> Texture2D:
	if not _textures.has(file):
		var img: Image = (load(TILE_DIR + file) as Texture2D).get_image()
		img.decompress()
		# The art is a disc seen at an angle plus its own drop shadow; keep the
		# disc face (the top 59 of 69 px) and let the 3D disc be the shadow.
		var face := img.get_region(Rect2i(0, 0, 96, 59))
		_textures[file] = ImageTexture.create_from_image(face)
	return _textures[file]


func _build_tiles() -> void:
	var lip := StandardMaterial3D.new()
	lip.albedo_color = LIP
	lip.roughness = 0.8
	for key: Vector2i in tiles:
		var ty: String = tiles[key]["type"]
		var node := Node3D.new()
		node.position = Vector3(key.x, 0, key.y) - centre
		board.add_child(node)
		var size := 1.0
		if ty == "c":
			size = [0.84, 0.92, 1.0, 1.0][randi() % 4]
		node.scale = Vector3(size, 1, size)

		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.41
		cyl.bottom_radius = 0.43
		cyl.height = TILE_H
		cyl.radial_segments = 40
		disc.mesh = cyl
		disc.material_override = lip
		disc.position.y = TILE_H * 0.5
		node.add_child(disc)

		var face := Sprite3D.new()
		face.texture = _top_texture(LevelMap.texture_file(ty))
		face.axis = Vector3.AXIS_Y
		face.pixel_size = 0.84 / 96.0
		face.scale = Vector3(1, 96.0 / 59.0, 1)  # un-squash the drawn ellipse
		face.position.y = TILE_H + 0.002
		face.shaded = true
		face.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		face.modulate = Color(0.92, 0.95, 1.0)
		node.add_child(face)

		tiles[key]["node"] = node
		tiles[key]["home"] = node.position
		# Tiles arrive one after another, like the game's loading sweep.
		node.visible = false

	if tiles.has(exit_key) and _is_checkpoint():
		var flag := Node3D.new()
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.025
		pm.bottom_radius = 0.025
		pm.height = 1.0
		pole.mesh = pm
		pole.position.y = 0.6
		var white := StandardMaterial3D.new()
		white.albedo_color = Color.WHITE
		pole.material_override = white
		flag.add_child(pole)
		var cloth := MeshInstance3D.new()
		var pr := PrismMesh.new()
		pr.size = Vector3(0.3, 0.38, 0.02)
		cloth.mesh = pr
		cloth.rotation_degrees = Vector3(0, 0, -90)
		cloth.position = Vector3(0.19, 1.0, 0)
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color("#ffd166")
		cloth.material_override = gold
		flag.add_child(cloth)
		(tiles[exit_key]["node"] as Node3D).add_child(flag)


func _is_checkpoint() -> bool:
	var f := FileAccess.open("res://data/levels.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	for l: Dictionary in data["levels"]:
		if int(l["number"]) == level_no:
			return bool(l["checkpoint"])
	return false


func _build_man() -> void:
	man_vp = SubViewport.new()
	man_vp.size = Vector2i(240, 300)
	man_vp.transparent_bg = true
	man_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(man_vp)
	player = Player.new()
	player.scale = Vector2(2.8, 2.8)
	player.position = Vector2(120, 288)
	man_vp.add_child(player)
	player.vanish()

	man = Sprite3D.new()
	man.texture = man_vp.get_texture()
	man.billboard = (
		BaseMaterial3D.BILLBOARD_FIXED_Y if cam_mode == "chase" else BaseMaterial3D.BILLBOARD_ENABLED
	)
	man.pixel_size = MAN_H / (2.8 * 82.0)
	man.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	man.shaded = false
	man.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Pivot at his feet: the billboard turns about the node's origin, so the
	# picture is lifted by its offset and his feet stay planted on the tile.
	man.offset = Vector2(0, 150 - 12)
	man.visible = false
	board.add_child(man)

	# A soft contact shadow under his feet (the game has none; a 3D figure
	# floats without one).
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
	board.add_child(foot_shadow)

	# Hidden tiles: the one under his feet shows as a dashed outline, the
	# drafting convention for an edge you can't see (as the pencil marks do in
	# 2D). Only where he stands, so it gives nothing away ahead of him.
	var ring := _dashed_ring()
	for k: Vector2i in tiles:
		if tiles[k]["type"] not in HIDERS:
			continue
		var r := Sprite3D.new()
		r.texture = ring
		r.axis = Vector3.AXIS_Y
		r.pixel_size = 0.86 / 128.0
		r.shaded = false
		r.position = _tile_pos(k) + Vector3(0, 0.004, 0)
		r.modulate.a = 0.0
		board.add_child(r)
		tiles[k]["ring"] = r


func _dashed_ring() -> Texture2D:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for y in n:
		for x in n:
			var v := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5)
			var d := v.length() / (n * 0.5)
			var ang := fposmod(v.angle(), TAU) / TAU * 16.0
			if d > 0.86 and d < 0.97 and fposmod(ang, 1.0) < 0.6:
				img.set_pixel(x, y, Color(1, 1, 1, 0.85))
	return ImageTexture.create_from_image(img)


# --- the tour ----------------------------------------------------------------


func _tile_pos(k: Vector2i) -> Vector3:
	return Vector3(k.x, TILE_H, k.y) - centre


func _man_at(p: Vector3) -> void:
	man.position = p + Vector3(0, 0.01, 0)
	foot_shadow.position = p + Vector3(0, 0.006, 0)
	foot_shadow.visible = man.visible
	for k: Vector2i in tiles:
		if tiles[k].has("ring"):
			var r: Sprite3D = tiles[k]["ring"]
			var near := 1.0 - (Vector2(p.x, p.z) - Vector2(r.position.x, r.position.z)).length() / 0.75
			r.modulate.a = clampf(near, 0.0, 1.0) if hidden_now else 0.0


func _process(delta: float) -> void:
	t += delta
	_load_tiles()
	if t >= 1.8 and not man.visible:
		man.visible = true
		player.show_player()
		player.face_idle()
		_man_at(_tile_pos(start))
	_walk()
	player.tick(delta)
	_tilt_board(delta)
	_place_camera(delta, false)
	_shots()
	if end_after > 0.0 and t >= end_after:
		get_tree().quit()


func _load_tiles() -> void:
	for k: Vector2i in tiles:
		var tile: Dictionary = tiles[k]
		var node: Node3D = tile["node"]
		var d := absf(k.x - start.x) + absf(k.y - start.y)
		var at := 0.2 + d * 0.06
		if t >= at and not tile.get("loaded", false):
			tile["loaded"] = true
			node.visible = true
			node.position = tile["home"] + Vector3(0, 2.0, 0)
			var tw := create_tween()
			tw.tween_property(node, "position", tile["home"], 0.28)
			tw.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _walk() -> void:
	if t < WALK_FROM or route.is_empty():
		return
	var f := (t - WALK_FROM) / STEP_TIME
	var i := mini(int(f), route.size() - 1)
	var frac := clampf(f - i, 0.0, 1.0)
	if i >= route.size() - 1:
		if step_i != route.size() - 1:
			step_i = route.size() - 1
			player.face_idle()
			player.cheer()
		_man_at(_tile_pos(route.back()))
		tilt = Vector2.ZERO
		return
	var a := route[i]
	var b := route[i + 1]
	var dir := b - a
	if i != step_i:
		step_i = i
		player.face_direction(dir, true)
		_arrive(a)
	tilt = Vector2(dir)
	_man_at(_tile_pos(a).lerp(_tile_pos(b), frac))


## The tile rules this tour needs: hide and unhide.
func _arrive(k: Vector2i) -> void:
	var ty: String = tiles[k]["type"]
	if ty == "h" and not hidden_now:
		hidden_now = true
		_set_hidden(k, true)
	elif ty == "u" and hidden_now:
		hidden_now = false
		_set_hidden(k, false)


func _set_hidden(from: Vector2i, on: bool) -> void:
	for k: Vector2i in tiles:
		if tiles[k]["type"] not in HIDERS:
			continue
		var node: Node3D = tiles[k]["node"]
		var home: Vector3 = tiles[k]["home"]
		var delay := (absf(k.x - from.x) + absf(k.y - from.y)) * 0.03
		var tw := create_tween()
		tw.tween_interval(delay)
		if on:
			# Folds down into the paper.
			tw.tween_property(node, "position", home - Vector3(0, 0.25, 0), 0.25)
			tw.parallel().tween_property(node, "scale:x", 0.05, 0.25)
			tw.tween_callback(func() -> void: node.visible = false)
		else:
			node.visible = true
			tw.tween_property(node, "position", home, 0.25)
			tw.parallel().tween_property(node, "scale:x", 1.0, 0.25)


## Table view: the drafting table itself leans the way the phone is tilted.
func _tilt_board(delta: float) -> void:
	if cam_mode != "table":
		return
	var target := Vector3(deg_to_rad(4.0) * tilt.y, 0, -deg_to_rad(4.0) * tilt.x)
	board.rotation = board.rotation.lerp(target, minf(1.0, delta * 5.0))
	board.position = centre


func _place_camera(delta: float, snap: bool) -> void:
	var span := maxf(rows.size(), (centre.x + 0.5) * 2.0 * 0.56)
	var pos := Vector3.ZERO
	var look := centre
	match cam_mode:
		"iso":
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = span * 1.15
			var d := Vector3(1, 0, 1).normalized() * 20.0
			d.y = 20.0 * tan(deg_to_rad(35.264))
			pos = centre + d
			look = centre
		"chase":
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			cam.fov = 58.0
			var over := centre + Vector3(0, span * 1.5, span * 1.1)
			var m := man.position + centre
			var behind := m + Vector3(0, 3.0, 4.2)
			var k := clampf((t - 1.9) / 1.0, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			pos = over.lerp(behind, k)
			look = centre.lerp(m + Vector3(0, 0.6, -1.2), k)
		_:
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			cam.fov = 38.0
			pos = centre + Vector3(0, span * 1.6, span * 1.4)
			look = centre + Vector3(0, 0, -0.6)
	if snap or cam_mode != "chase":
		_cam_pos = pos
		_cam_look = look
	else:
		var s := minf(1.0, delta * 6.0)
		_cam_pos = _cam_pos.lerp(pos, s)
		_cam_look = _cam_look.lerp(look, s)
	cam.position = _cam_pos
	cam.look_at(_cam_look, Vector3.UP)


func _shots() -> void:
	if shots_dir == "" or shot_at.is_empty():
		return
	if t >= shot_at[0]:
		var s: float = shot_at.pop_front()
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%04.1f.png" % [shots_dir, cam_mode, s])
