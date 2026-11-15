class_name Motion
extends RefCounted
## The phone's motion sensors, wherever the game runs.
##
## In the app this is Godot's own Input. In a phone's browser (the web
## version) Godot reads no sensors, so web/motion.js, in the page's head,
## listens to the browser's devicemotion events and keeps the latest reading
## in window.mapmanMotion, already turned to Godot's terms: in m/s², pointing
## at the ground, rotated to the screen (+x right edge, +y top edge, +z out of
## the screen).

static var _js: JavaScriptObject


## True on a phone or tablet, app or browser.
static func on_phone() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


## Gravity, pointing at the ground; zero if there is no sensor (yet).
static func gravity() -> Vector3:
	if not OS.has_feature("web"):
		return Input.get_gravity()
	return _read("g")


## Gravity plus the shakes; zero if there is no sensor (yet).
static func accelerometer() -> Vector3:
	if not OS.has_feature("web"):
		return Input.get_accelerometer()
	return _read("a")


static func _read(which: String) -> Vector3:
	if _js == null:
		_js = JavaScriptBridge.get_interface("mapmanMotion")
		if _js == null:
			return Vector3.ZERO
	return Vector3(
		float(_js.get(which + "x")), float(_js.get(which + "y")), float(_js.get(which + "z"))
	)
