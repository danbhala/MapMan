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
		_watch()
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
	_turn_view()
	_state = "live"
	status.emit("looking")
	return true


## Show the picture the right way up: the feed says how its pictures sit.
func _turn_view() -> void:
	var t := _feed.feed_transform
	if absf(t.x.x) >= absf(t.x.y):
		_view.flip_h = t.x.x < 0.0
		_view.flip_v = t.y.y < 0.0


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
	_picture = picture
	_task = WorkerThreadPool.add_task(_read_picture, false, "QR")


## Android takes the camera away while the game is in the background.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and _state == "live" and _feed:
		_feed.feed_is_active = false
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
		_feed.feed_is_active = false
	if _state != "":
		CameraServer.monitoring_feeds = false
	_state = "off"
