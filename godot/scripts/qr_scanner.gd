class_name QrScanner
extends Control
## The camera view on the scan sheet (DraftingSheet.build_scan): asks for
## the camera, shows what the back camera sees, and reads a QR code from it
## a few times a second with QrReader, off the main thread so the view keeps
## moving. Reports each new text it reads; the sheet decides what it is.

## A QR code was read: its text (each text once while the view is open).
signal read(text: String)
## What the camera is doing: "looking", "no_camera" or "no_permission".
signal status(kind: String)

const CAMERA_PERMISSION := "android.permission.CAMERA"
## Seconds between pictures read.
const EVERY := 0.2
## Seconds to wait for the phone to list its cameras.
const WAIT_FOR_CAMERAS := 3.0
## The picture size asked of the camera: enough for a code across a room,
## no more (QrReader shrinks pictures to 640 pixels anyway).
const WANT := Vector2i(1280, 720)
## Frames to wait before showing the view (the first can still be noise).
const SHOW_AFTER := 3
## Phones (Android) give the picture as brightness (Y, red-only on its own)
## and colour (CbCr) in two textures; this puts them back together, or
## shows the brightness as grey when there is no colour.
const YCBCR_SHADER := """
shader_type canvas_item;
uniform sampler2D cbcr : filter_linear;
uniform bool has_cbcr = false;
void fragment() {
	float y = texture(TEXTURE, UV).r;
	vec2 c = has_cbcr ? texture(cbcr, UV).rg - vec2(0.5) : vec2(0.0);
	COLOR = vec4(y + 1.402 * c.y, y - 0.344 * c.x - 0.714 * c.y, y + 1.772 * c.x, 1.0);
}
"""

var _view: TextureRect
var _feed: CameraFeed
## "permission", "cameras", "live" or "off".
var _state := ""
var _waited := 0.0
var _since := 0.0
var _task := -1
var _picture: Image
var _text := ""
var _last := ""
## Frames the camera has sent since it started.
var _frames := 0
## The camera was stopped for a trip to the background.
var _paused := false


func _ready() -> void:
	clip_contents = true
	_view = TextureRect.new()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Tests and screenshots run without a screen, and so without a camera.
	if DisplayServer.get_name() == "headless":
		_stop("no_camera")
		return
	if OS.get_name() == "Android" and not OS.request_permission(CAMERA_PERMISSION):
		_state = "permission"
		get_tree().on_request_permissions_result.connect(_on_permission)
		return
	_watch()


func _on_permission(permission: String, granted: bool) -> void:
	if _state != "permission" or not permission.ends_with("CAMERA"):
		return
	if granted:
		# The permission dialog is still closing: start the camera after it.
		_watch.call_deferred()
	else:
		_stop("no_permission")


func _watch() -> void:
	_state = "cameras"
	_waited = 0.0
	CameraServer.monitoring_feeds = true
	_start_feed()


## Start the back camera (or any), once the phone lists one.
func _start_feed() -> bool:
	var pick: CameraFeed
	for feed: CameraFeed in CameraServer.feeds():
		if pick == null or feed.get_position() == CameraFeed.FEED_BACK:
			pick = feed
	if pick == null:
		return false
	_feed = pick
	var formats := _feed.get_formats()
	var best := -1
	var best_gap := 1 << 30
	for i in formats.size():
		var f: Dictionary = formats[i]
		var gap := absi(int(f.get("width", 0)) * int(f.get("height", 0)) - WANT.x * WANT.y)
		if gap < best_gap:
			best_gap = gap
			best = i
	if best >= 0:
		_feed.set_format(best, {})
	_feed.feed_is_active = true
	var texture := CameraTexture.new()
	texture.camera_feed_id = _feed.get_id()
	_view.texture = texture
	# Hidden until the first picture: before it the texture holds whatever
	# was in that memory, a pattern of noise.
	_view.visible = false
	if _feed.has_signal("frame_changed") and not _feed.is_connected("frame_changed", _on_frame):
		_feed.connect("frame_changed", _on_frame)
	if _feed.get_datatype() == CameraFeed.FEED_YCBCR_SEP:
		var colour := CameraTexture.new()
		colour.camera_feed_id = _feed.get_id()
		colour.which_feed = CameraServer.FEED_CBCR_IMAGE
		_view.material = _ycbcr(colour)
	# The picture is shown as the camera gives it: feed_transform describes the
	# feed for 3D backgrounds, and following it turned the view upside down on
	# Android (a OnePlus 12).
	_state = "live"
	status.emit("looking")
	return true


func _process(delta: float) -> void:
	match _state:
		"cameras":
			_waited += delta
			if not _start_feed() and _waited > WAIT_FOR_CAMERAS:
				_stop("no_camera")
		"live":
			_poll(delta)


func _poll(delta: float) -> void:
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if _text != "" and _text != _last:
			_last = _text
			# The sheet may close on this, freeing the view.
			read.emit(_text)
			return
	_since += delta
	if _since < EVERY:
		return
	_since = 0.0
	var picture := _view.texture.get_image() if _view.texture else null
	if picture == null or picture.is_empty():
		return
	if picture.get_format() == Image.FORMAT_R8 and _view.material == null:
		_view.material = _ycbcr(null)
	if not _feed.has_signal("frame_changed"):
		_view.visible = true
	_picture = picture
	_task = WorkerThreadPool.add_task(_read_picture, false, "QR")


## Shows the view once a few real frames have come in.
func _on_frame() -> void:
	_frames += 1
	if _frames >= SHOW_AFTER:
		_view.set_deferred("visible", true)


func _ycbcr(colour: Texture2D) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = YCBCR_SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("cbcr", colour)
	m.set_shader_parameter("has_cbcr", colour != null)
	return m


## Android takes the camera away while the game is in the background:
## stopped and started again only around a real trip to the background:
## restarting a camera that is still opening (as the permission dialog
## closes) crashed the game.
func _notification(what: int) -> void:
	if _state != "live" or _feed == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED and _feed.feed_is_active:
		_feed.feed_is_active = false
		_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED and _paused:
		_paused = false
		_feed.feed_is_active = true


func _read_picture() -> void:
	_text = QrReader.read(_picture)


func _stop(kind: String) -> void:
	_state = "off"
	status.emit(kind)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	if _feed:
		if _feed.has_signal("frame_changed") and _feed.is_connected("frame_changed", _on_frame):
			_feed.disconnect("frame_changed", _on_frame)
		_feed.feed_is_active = false
	# The camera list stays watched: turning it off frees the feeds, which a
	# frame on its way to the closing view could still need.
	_state = "off"
