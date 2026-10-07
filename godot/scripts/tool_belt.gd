class_name ToolBelt
extends Control
## The tool belt (the Toolbox) at the left end of the HUD's bottom bar: a
## round button per tool carried, drawn like the tilt gauge, with the tool's
## icon on a tile. A white ring sweeps round while it recharges, a coloured
## ring drains while its effect runs, and it fades once the sheet has had
## its uses. Taps stop here, so they never pause the game.

const RADIUS := 19.0
## Room each button takes along the bar.
const PITCH := Toolbox.BELT_PITCH
const FADED := 0.35
## The ring colour of each effect that runs for a while.
const RING := {"slow": Blueprint.LILAC, "freeze": Blueprint.GOLD, "peek": Blueprint.MINT}

var toolbox: Toolbox
var _buttons: Array[ToolButton] = []


func _init(box: Toolbox) -> void:
	toolbox = box
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


## Sits over the bar's left end, `hud` giving the bar's place.
func place(hud: Hud) -> void:
	position = hud.bar.global_position
	size = Vector2(PITCH * 3.0 + 8.0, Hud.BAR_HEIGHT)


## The width the belt takes in the bar for `count` tools (Hud.belt_room).
static func room(count: int) -> float:
	return PITCH * count + 8.0 if count > 0 else 0.0


## The buttons for the tools on the belt now, in its order.
func refresh(ids: Array[String]) -> void:
	var same := ids.size() == _buttons.size()
	if same:
		for i in ids.size():
			same = same and _buttons[i].id == ids[i]
	if same:
		return
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	for i in ids.size():
		var b := ToolButton.new(ids[i], toolbox)
		b.position = Vector2(8.0 + PITCH * i, (Hud.BAR_HEIGHT - RADIUS * 2.0) / 2.0)
		add_child(b)
		_buttons.append(b)


func _process(_delta: float) -> void:
	if not visible:
		return
	for b in _buttons:
		b.queue_redraw()


## One tool's button: a disc with its icon, and the rings.
class ToolButton:
	extends Control
	var id: String
	var toolbox: Toolbox

	func _init(tool_id: String, box: Toolbox) -> void:
		id = tool_id
		toolbox = box
		size = Vector2.ONE * RADIUS * 2.0
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		accessibility_name = TranslationServer.translate(Toolbox.tool(id).name)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			# Both halves of the tap stop here: a release on the field pauses.
			accept_event()
			if event.pressed:
				toolbox.use(id)

	func _has_point(point: Vector2) -> bool:
		return point.distance_to(size / 2.0) <= RADIUS + 4.0

	func _draw() -> void:
		var c := size / 2.0
		var ready := toolbox.ready(id) or toolbox.running(id) > 0.0
		var spent := toolbox.used_up(id)
		var mod := Color(1, 1, 1, FADED if spent else 1.0)
		draw_circle(c, RADIUS, Color(0, 0, 0, 0.5))
		var w := RADIUS * 1.55
		var rect := Rect2(c + Vector2(-w / 2.0, -w * 0.36 - 1.0), Vector2(w, w * 0.72))
		var tile_tex: Texture2D = load(LevelMap.TILE_DIR + "blank1.png")
		draw_texture_rect(tile_tex, rect, false, mod)
		draw_texture_rect(ToolIcons.texture(id, 2.0), rect, false, mod)
		draw_arc(c, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 1.2, true)
		var cool := toolbox.cooling(id)
		if cool > 0.0:
			var to := -PI / 2.0 + TAU * (1.0 - cool)
			draw_arc(c, RADIUS, -PI / 2.0, to, 48, Color(1, 1, 1, 0.9), 2.5, true)
		var run := toolbox.running(id)
		if run > 0.0:
			var ring: Color = RING.get(id, Blueprint.GOLD)
			draw_arc(c, RADIUS, -PI / 2.0, -PI / 2.0 + TAU * run, 48, ring, 3.0, true)
		if toolbox.armed() == id:
			draw_arc(c, RADIUS + 2.5, 0, TAU, 48, Blueprint.GOLD, 2.0, true)
		elif not ready and not spent and cool == 0.0:
			draw_arc(c, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.2), 1.0, true)
