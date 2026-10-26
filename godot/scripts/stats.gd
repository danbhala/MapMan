extends Node
## Play stats (docs/stats.md): anonymous level events sent to PostHog's EU
## cloud, only after the player says yes (StatsSheet asks once; Options >
## PRIVACY changes it). Nothing is queued or sent while the answer is no or
## not given, and saying no forgets the random install ID, so a later yes
## starts a new one.
##
## No name, account, advertising ID or device ID: each event carries the
## random install ID, a per-launch session, the build and the event's own
## numbers (level, mode, time left, the tile of a lost life).

## Where PostHog's EU cloud takes batches of events.
const HOST := "https://eu.i.posthog.com"
const PATH := "user://stats.cfg"
## The project's API key (PostHog "phc_..."; public by design: it can only
## send events). Empty turns the stats off entirely, question and all.
const KEY_SETTING := "mapman/stats/posthog_key"
## Ask again this long after a yes (the Irish DPC asks for consent to be
## refreshed at least every six months).
const REASK_SECONDS := 182 * 24 * 3600
const FLUSH_SECONDS := 30.0
const FLUSH_AT := 20  # events waiting before a batch goes early
const KEEP_AT_MOST := 300  # events kept while offline; the oldest go first

## "" not asked yet, "yes" or "no".
var answer := ""
## When the player last answered (Unix seconds).
var answered_at := 0
## The random install ID, while the answer is yes.
var install_id := ""
## Tests turn this off so they never write the phone's real files.
var persist := true
## Tests turn this off so nothing leaves the machine.
var send_on := true
## Events waiting to go: PostHog batch entries.
var queue: Array[Dictionary] = []

var key := ""
var _session := ""
var _http: HTTPRequest
var _sending := 0  # events in the batch on its way
var _clock := 0.0


func _ready() -> void:
	key = str(ProjectSettings.get_setting(KEY_SETTING, ""))
	_session = _random_hex(8)
	_load()
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_sent)
	# Tests and tools run headless: no stats, no question, nothing sent
	# (tests that need them set `key` themselves).
	if DisplayServer.get_name() == "headless":
		key = ""
		send_on = false
		persist = false
	event("app_open", _settings())


## The game has stats to send to (a key in project.godot).
func available() -> bool:
	return key != ""


## The player said yes.
func on() -> bool:
	return available() and answer == "yes"


## The question should be asked: never answered, or a yes that is due for
## refreshing.
func should_ask() -> bool:
	if not available():
		return false
	if answer == "":
		return true
	return answer == "yes" and _now() - answered_at > REASK_SECONDS


## The player's answer: true sends play stats from now on, false stops them
## and forgets the install ID and anything not yet sent.
func choose(yes: bool) -> void:
	answer = "yes" if yes else "no"
	answered_at = _now()
	if yes:
		if install_id == "":
			install_id = _uuid()
		_save()
		event("stats_on", _settings())
	else:
		install_id = ""
		queue.clear()
		_save()


## Queues one event; nothing happens unless the player said yes.
## name: snake_case, such as "level_clear"; props: its own numbers.
func event(name: String, props := {}) -> void:
	if not on():
		return
	var p := props.duplicate()
	p["$process_person_profile"] = false  # events only: no person profiles
	p["session"] = _session
	p["build"] = "dev" if OS.has_feature("dev") else "release"
	p["app_version"] = Dev.build_info.version
	p["commit"] = String(Dev.build_info.commit).left(7)
	p["platform"] = OS.get_name()
	(
		queue
		. append(
			{
				"event": name,
				"distinct_id": install_id,
				"properties": p,
				"timestamp": Time.get_datetime_string_from_system(true) + "Z",
			}
		)
	)
	while queue.size() > KEEP_AT_MOST:
		queue.pop_front()
	if queue.size() >= FLUSH_AT:
		flush()


## Sends what is waiting, one batch at a time.
func flush() -> void:
	if not on() or not send_on or _sending > 0 or queue.is_empty():
		return
	var body := JSON.stringify({"api_key": key, "batch": queue})
	var headers := ["Content-Type: application/json"]
	if _http.request(HOST + "/batch/", headers, HTTPClient.METHOD_POST, body) == OK:
		_sending = queue.size()


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= FLUSH_SECONDS:
		_clock = 0.0
		flush()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		# The phone may never bring the game back: keep what hasn't gone.
		_save()
		flush()


func _on_sent(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var sent := _sending
	_sending = 0
	# A refusal (4xx) would be refused again: drop the batch as if sent.
	if result == HTTPRequest.RESULT_SUCCESS and code < 500:
		queue = queue.slice(mini(sent, queue.size()))
		_save()


## What every level event says, for main.gd `g`: the sheet, the revision,
## how it is being played and the lives, plus `more` (times rounded to a tenth).
func of(g: Node, more := {}) -> Dictionary:
	var mode := "main"
	if g.tutorial:
		mode = "tutorial"
	elif g.custom != "":
		mode = "custom"
	elif g.practice:
		mode = "practice"
	var props := {"level": g.level, "mode": mode, "lives": g.lives, "lost_here": g.losses_here()}
	props["revision"] = "B" if Save.rev_b else "A"  # which game: levels.json or levels_b.json
	for k in more:
		props[k] = snappedf(more[k], 0.1) if more[k] is float else more[k]
	return props


## The settings worth knowing when choosing defaults.
func _settings() -> Dictionary:
	return {
		"controls": Save.controls,
		"tilt_sensitivity": Save.tilt_sensitivity,
		"language": Save.shown_locale(),
		"furthest_level": Save.furthest_level,
		"finished": Save.has_completed,
	}


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	answer = str(cfg.get_value("stats", "answer", ""))
	if answer not in ["", "yes", "no"]:
		answer = ""
	answered_at = int(cfg.get_value("stats", "answered_at", 0))
	install_id = str(cfg.get_value("stats", "install_id", "")) if answer == "yes" else ""
	if answer == "yes" and install_id == "":
		install_id = _uuid()
	queue.clear()
	if answer == "yes":
		for e in cfg.get_value("stats", "queue", []):
			if e is Dictionary:
				queue.append(e)


func _save() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "answer", answer)
	cfg.set_value("stats", "answered_at", answered_at)
	cfg.set_value("stats", "install_id", install_id)
	cfg.set_value("stats", "queue", queue)
	cfg.save(PATH)


func _now() -> int:
	return int(Time.get_unix_time_from_system())


static func _random_hex(bytes: int) -> String:
	return Crypto.new().generate_random_bytes(bytes).hex_encode()


## A random (version 4) UUID.
static func _uuid() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return (
		"%s-%s-%s-%s-%s"
		% [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20)]
	)
