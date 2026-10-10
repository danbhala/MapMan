class_name Toolbox
extends RefCounted
## The Toolbox (docs/toolbox.md): nine tools in three branches, bought a tier
## at a time with the stars in the bank, two of them carried on the belt. The
## table of tools and the rules of buying are static; an instance is the
## tools in play for main.gd: their recharges, uses and effects on the sheet
## being played, the belt's taps, and the Toolbox sheet's actions. Loads only
## with the game scene, so it may name Save and Audio.

## Tiers each tool has, and what Fresh Sheet costs (bought once).
const TIERS := 3
const FRESH_SHEET_PRICE := 40
## The belt: two tools, a third from this sheet on.
const BELT_SLOTS := 2
const THIRD_SLOT_LEVEL := 50
## Slow-mo: the game's speed, and the music's pitch (a tape slowing).
const SLOW_SCALE := 0.5
const SLOW_PITCH := 0.72
## Push Pin recharges this long; the Eraser rubs out a tile this close to a tap.
const PIN_RECHARGE := 10.0
const TAP_REACH := 18.0
## The belt's buttons are this far apart in the bar, from its left edge.
const BELT_PITCH := 44.0
## A hop's arc height, in pixels, and the after-images Slow-mo trails.
const HOP_HEIGHT := 30.0
const TRAIL := 2
const TRAIL_LAG := 5  # frames behind the one before

## The branches, in order, each a name and a line under it (msgids).
const BRANCHES := [
	["YOUR HAND", "you help him"],
	["HIS FEET", "he gets moves"],
	["THE CLOCK", "time bends"],
]
## Every tool, in branch order: three to a branch, each unlocked by tier I of
## the one above it. `kind`: "tap" (a belt button to tap), "tile" (tap the
## button, then a tile), "auto" (works by itself, no button). `limit`: how
## often it works ("recharge", "try", "sheet", "game"). Each tier is its
## price in stars and its strength: seconds ("s"), tiles ("tiles") or uses
## ("uses"); a recharge in seconds where that changes by tier.
const TOOLS := [
	{
		"id": "eraser",
		"name": "ERASER",
		"blurb": "Tap a skull to rub it out, even one you can't see.",
		"branch": 0,
		"kind": "tile",
		"limit": "recharge",
		"tiers": [{"price": 15, "s": 6.0}, {"price": 30, "s": 5.0}, {"price": 60, "s": 4.0}],
	},
	{
		"id": "peek",
		"name": "LIGHT TABLE",
		"blurb": "The hidden tiles show through the paper for a moment.",
		"branch": 0,
		"kind": "tap",
		"limit": "try",
		"tiers": [{"price": 30, "s": 0.5}, {"price": 60, "s": 1.0}, {"price": 100, "s": 1.5}],
	},
	{
		"id": "pin",
		"name": "PUSH PIN",
		"blurb": "Tap spikes or a crumble tile to pin it: it stays put.",
		"branch": 0,
		"kind": "tile",
		"limit": "recharge",
		"tiers": [{"price": 25, "s": 3.0}, {"price": 50, "s": 5.0}, {"price": 90, "s": 8.0}],
	},
	{
		"id": "hop",
		"name": "HOP",
		"blurb": "He hops over the next tile the way he's facing.",
		"branch": 1,
		"kind": "tap",
		"limit": "recharge",
		"tiers":
		[
			{"price": 15, "tiles": 1, "recharge": 8.0},
			{"price": 30, "tiles": 1, "recharge": 5.0},
			{"price": 60, "tiles": 2, "recharge": 5.0},
		],
	},
	{
		"id": "hardhat",
		"name": "HARD HAT",
		"blurb": "The first skull on a sheet doesn't get him.",
		"branch": 1,
		"kind": "auto",
		"limit": "sheet",
		"tiers": [{"price": 30, "uses": 1}, {"price": 50, "uses": 1}, {"price": 100, "uses": 2}],
	},
	{
		"id": "revive",
		"name": "SECOND DRAFT",
		"blurb": "Out of lives, he gets back up on the same sheet.",
		"branch": 1,
		"kind": "auto",
		"limit": "game",
		"tiers":
		[
			{"price": 40, "s": 8.0, "uses": 1},
			{"price": 70, "s": 15.0, "uses": 1},
			{"price": 120, "s": 15.0, "uses": 2},
		],
	},
	{
		"id": "slow",
		"name": "SLOW-MO",
		"blurb": "Everything at half speed for a few seconds, music too.",
		"branch": 2,
		"kind": "tap",
		"limit": "try",
		"tiers": [{"price": 15, "s": 2.0}, {"price": 35, "s": 4.0}, {"price": 70, "s": 6.0}],
	},
	{
		"id": "look",
		"name": "FIRST LOOK",
		"blurb": "The clock waits while you take in the sheet.",
		"branch": 2,
		"kind": "auto",
		"limit": "try",
		"tiers": [{"price": 20, "s": 2.0}, {"price": 40, "s": 3.0}, {"price": 80, "s": 4.0}],
	},
	{
		"id": "freeze",
		"name": "STOP CLOCK",
		"blurb": "The countdown stops while he keeps walking.",
		"branch": 2,
		"kind": "tap",
		"limit": "sheet",
		"tiers": [{"price": 40, "s": 2.0}, {"price": 70, "s": 3.0}, {"price": 110, "s": 5.0}],
	},
]
## What each tool's tiers say on the sheet (msgids; %s is the strength).
const TIER_TEXT := {
	"eraser": "RECHARGES IN %s S",
	"peek": "%s S LOOK",
	"pin": "PINNED %s S",
	"hop": ["1 TILE, %s S RECHARGE", "2 TILES, %s S RECHARGE"],
	"hardhat": ["SKULL, ONCE A SHEET", "SKULL OR SPIKES, ONCE", "SKULL OR SPIKES, TWICE"],
	"revive": ["BACK UP WITH %s S", "BACK UP WITH %s S", "TWICE A GAME, %s S"],
	"slow": "%s S AT HALF SPEED",
	"look": "%s S LOOK",
	"freeze": "CLOCK STOPS %s S",
}

# --- the table ---------------------------------------------------------------------

## The sheet the Toolbox was opened from ("main", "pause" or "clear"), for
## the way back, and the tool its card shows.
var from := "main"
var selected := "eraser"

## main.gd (untyped: it has no class_name).
var _game
## Seconds of recharge left (id -> seconds), uses so far (id -> count,
## cleared by the tool's limit), and effects still running (id -> seconds).
var _cool := {}
var _uses := {}
var _active := {}
## A "tile" tool waiting for a tap on the sheet.
var _armed := ""
## Pinned tiles (key -> seconds left).
var _pinned := {}
## The tile the Hard Hat took a hit on: no death while he stands there.
var _hat_tile := Vector2i(-99, -99)
var _hat_on := false
## First Look: seconds of looking left, and whether this try's is still to come.
var _look_left := 0.0
var _look_pending := false
## Slow-mo put on hold by a pause: seconds to resume with.
var _slow_held := 0.0
## The after-images behind him in Slow-mo, and where he has been.
var _trail: Array[Player] = []
var _trail_parent: Node
var _trail_pos: Array[Vector2] = []
## Draws the pins and the Light Table's view on the map.
var _marks: ToolMarks


static func tool(id: String) -> Dictionary:
	for t in TOOLS:
		if t.id == id:
			return t
	return {}


static func is_tool(id: String) -> bool:
	return not tool(id).is_empty()


## The tools of branch `b`, top first.
static func branch_tools(b: int) -> Array:
	return TOOLS.filter(func(t: Dictionary) -> bool: return t.branch == b)


## The tool above `id` in its branch, whose tier I unlocks it; "" at the top.
static func above(id: String) -> String:
	var t := tool(id)
	var branch := branch_tools(t.branch)
	var i := branch.find(t)
	return branch[i - 1].id if i > 0 else ""


## Whether tool `id` can be bought: it is the top of its branch, or the tool
## above it is owned.
static func unlocked(id: String, save) -> bool:
	var up := above(id)
	return up == "" or save.tool_tier(up) > 0


## What the next tier of `id` costs when `owned` is the tier owned; -1 at
## the top tier.
static func next_price(id: String, owned: int) -> int:
	var t := tool(id)
	if t.is_empty() or owned >= TIERS:
		return -1
	return int(t.tiers[owned].price)


## What tier `tier` (1..3) of `id` costs.
static func price(id: String, tier: int) -> int:
	return int(tool(id).tiers[tier - 1].price)


## The strength of tier `tier` (1..3) of `id`: its "s", "tiles" or "uses".
static func strength(id: String, tier: int, what: String) -> float:
	var t := tool(id)
	if t.is_empty() or tier < 1:
		return 0.0
	return float(t.tiers[mini(tier, TIERS) - 1].get(what, 0))


## What a tier is worth, as the sheet says it (translated).
static func tier_text(id: String, tier: int) -> String:
	var t := tool(id)
	var spec: Dictionary = t.tiers[tier - 1]
	var msg = TIER_TEXT[id]
	if msg is Array:
		# One line per tier, or (Hop) per tiles cleared.
		msg = msg[tier - 1] if msg.size() == TIERS else msg[int(spec.get("tiles", 1)) - 1]
	var text: String = TranslationServer.translate(msg)
	var s: String = ""
	if spec.has("recharge"):
		s = _figure(spec.recharge)
	elif spec.has("s"):
		s = _figure(spec.s)
	return text % s if "%s" in text else text


## "6", "1.5" or "½" for a figure in seconds.
static func _figure(v: float) -> String:
	if is_equal_approx(v, 0.5):
		return "½"
	if is_equal_approx(v, floorf(v)):
		return str(int(v))
	return "%.1f" % v


## Stars spent on tools so far (what Fresh Sheet gives back).
static func spent_stars(save) -> int:
	var total := 0
	for t in TOOLS:
		for tier in save.tool_tier(t.id):
			total += int(t.tiers[tier].price)
	return total


## What every tool at every tier costs together.
static func tree_price() -> int:
	var total := 0
	for t in TOOLS:
		for spec in t.tiers:
			total += int(spec.price)
	return total


## Stars still needed to own everything, from the bank and what is owned.
static func still_needed(save) -> int:
	return maxi(tree_price() - spent_stars(save) - save.bank, 0)


## The belt's slots: a third once sheet THIRD_SLOT_LEVEL is reached.
static func belt_slots(save) -> int:
	if save.track_a.furthest_level >= THIRD_SLOT_LEVEL or save.has_completed:
		return BELT_SLOTS + 1
	return BELT_SLOTS


## The sheet's name in the bank: "A35", or "B35" in Revision B.
static func sheet_key(level: int, rev_b := false) -> String:
	return ("B%d" if rev_b else "A%d") % level


# --- the bank and the shop (on a Save) ---------------------------------------------


## The stars a cleared sheet pays into the bank: its star tiles beyond any
## it has paid before, its clear star the first time, and its quick star the
## first time it is cleared with `quick` true. `key` names the sheet ("A35").
## Returns what was paid: {"tiles", "clear", "quick", "total"}.
static func bank_sheet(save, key: String, star_tiles: int, quick: bool) -> Dictionary:
	var b: Dictionary = save.banked.get(key, {"tiles": 0, "clear": false, "quick": false})
	var paid := {"tiles": maxi(star_tiles - int(b.tiles), 0), "clear": 0, "quick": 0}
	if not b.clear:
		paid.clear = 1
	if quick and not b.quick:
		paid.quick = 1
	paid["total"] = paid.tiles + paid.clear + paid.quick
	b.tiles = maxi(int(b.tiles), star_tiles)
	b.clear = true
	b.quick = bool(b.quick) or quick
	save.banked[key] = b
	if paid.total > 0:
		save.bank += paid.total
	save.save_all()
	return paid


## The next tier of tool `id` is bought, if the save.bank can pay for it and the
## tool above it in its branch is owned; true if it was.
static func buy(save, id: String) -> bool:
	var price := next_price(id, save.tool_tier(id))
	if price < 0 or price > save.bank or not unlocked(id, save):
		return false
	save.bank -= price
	save.tools[id] = save.tool_tier(id) + 1
	save.save_all()
	return true


## Fresh Sheet is bought once, for its price; true if it was just now.
static func buy_fresh_sheet(save) -> bool:
	if save.fresh_sheet or save.bank < FRESH_SHEET_PRICE:
		return false
	save.bank -= FRESH_SHEET_PRICE
	save.fresh_sheet = true
	save.save_all()
	return true


## Fresh Sheet: every star spent on save.tools comes back to the save.bank, and the
## save.tools and the save.belt are cleared; true if there was anything to take back.
static func refund(save) -> bool:
	if not save.fresh_sheet:
		return false
	var refund := spent_stars(save)
	if refund == 0:
		return false
	save.bank += refund
	save.tools.clear()
	save.belt.clear()
	save.save_all()
	return true


## Puts an owned tool on the save.belt, or takes it off; false when there is no
## room, or it isn't owned.
static func set_on_belt(save, id: String, on: bool) -> bool:
	if on:
		if save.tool_tier(id) == 0 or id in save.belt:
			return false
		if save.belt.size() >= belt_slots(save):
			return false
		save.belt.append(id)
	else:
		if id not in save.belt:
			return false
		save.belt.erase(id)
	save.save_all()
	return true


# --- in play --------------------------------------------------------------------------


func _init(game) -> void:
	_game = game


## The tier of `id` in play: on the belt, when tools apply to the sheet.
func tier(id: String) -> int:
	if not enabled():
		return 0
	return Save.tool_tier(id) if id in Save.belt else 0


## Tools work in the main game and practice, not the tutorial, the ending or
## a drafting table level (a friend's sheet is played as drawn).
func enabled() -> bool:
	return not _game.tutorial and not _game.completed and _game.custom == ""


## Whether the belt shows now: a tool on it, on a sheet tools apply to.
func showing() -> bool:
	return enabled() and _game.game_active and not Save.belt.is_empty()


## The tools on the belt, in its order.
func belt() -> Array[String]:
	var out: Array[String] = []
	for id in Save.belt:
		if Save.tool_tier(id) > 0:
			out.append(id)
	return out


## A new sheet: every count and effect starts afresh.
func begin_sheet() -> void:
	for id in _uses.keys():
		if tool(id).limit != "game":
			_uses.erase(id)
	begin_try()


## A new try at the sheet: recharges, once-a-try tools and effects restart;
## what a sheet or a game allows carries on.
func begin_try() -> void:
	for id in _uses.keys():
		if tool(id).limit in ["try", "recharge"]:
			_uses.erase(id)
	_cool.clear()
	_pinned.clear()
	_armed = ""
	_hat_on = false
	_end_slow()
	_end_peek()
	_look_pending = tier("look") > 0
	_look_left = 0.0
	if _marks:
		_marks.queue_redraw()


## A new game: everything, the once-a-game tools included.
func begin_game() -> void:
	_uses.clear()
	begin_try()


## The sheet just cleared pays into the star bank: its star tiles the first
## time each is picked up, its clear star, and its quick star with
## main.gd's QUICK_SECONDS or more left. What the level clear says of it:
## {"paid", "bank"}, or {} while the Toolbox is still closed.
func bank_stars() -> Dictionary:
	var g = _game
	var key := sheet_key(g.level, Save.rev_b)
	var paid := bank_sheet(Save, key, g.stars, g._seconds_remaining() >= g.QUICK_SECONDS)
	if not Save.toolbox_open():
		return {}
	return {"paid": paid.total, "bank": Save.bank}


## The tool belt shows beside the gauge while a sheet with tools is played.
func update_belt() -> void:
	var g = _game
	var belt: ToolBelt = g.belt
	belt.visible = showing() and not g.menus.visible and g.hud.visible and g._tries.replay == null
	var ids: Array[String] = []
	if showing():
		ids = self.belt()
	belt.refresh(ids)
	var room := ToolBelt.room(ids.size())
	if room != g.hud.belt_room:
		g.hud.belt_room = room
		g.hud.layout()


## The sheet is over (cleared, lost, or left): no effect outlives it.
func stop() -> void:
	_armed = ""
	_end_slow()
	_end_peek()
	_pinned.clear()
	_look_left = 0.0
	_look_pending = false
	_hat_on = false


## Each frame the sheet is being played, `delta` of game time.
func update(delta: float) -> void:
	for id in _cool.keys():
		_cool[id] = maxf(_cool[id] - delta, 0.0)
		if _cool[id] == 0.0:
			_cool.erase(id)
	for key in _pinned.keys():
		_pinned[key] -= delta
		if _pinned[key] <= 0.0:
			_pinned.erase(key)
			_game.map.pinned.erase(key)
			if _marks:
				_marks.queue_redraw()
	# Slow-mo runs on the clock on the wall, not the slowed one.
	var real := delta / maxf(Engine.time_scale, 0.01)
	for id in _active.keys():
		_active[id] -= real if id == "slow" else delta
		if _active[id] <= 0.0:
			_active.erase(id)
			match id:
				"slow":
					_end_slow()
				"peek":
					_end_peek()
	if _active.has("slow"):
		_follow_trail()
	# The Hard Hat's tile is safe only while he stands on it.
	if _hat_on and _game.map.position_key != _hat_tile and not _game.map.moving:
		_hat_on = false


## How much of a tool's recharge is still to run, 0..1, for the belt.
func cooling(id: String) -> float:
	if not _cool.has(id):
		return 0.0
	var full := _recharge(id)
	return clampf(_cool[id] / full, 0.0, 1.0) if full > 0.0 else 0.0


## How much of a tool's effect is still running, 0..1, for the belt.
func running(id: String) -> float:
	if not _active.has(id):
		return 0.0
	var full := strength(id, tier(id), "s")
	return clampf(_active[id] / full, 0.0, 1.0) if full > 0.0 else 0.0


## Whether a tool can be used now: owned, charged and not spent.
func ready(id: String) -> bool:
	if tier(id) == 0 or _cool.has(id) or _active.has(id):
		return false
	return not used_up(id)


## A tool's uses on this try, sheet or game are gone.
func used_up(id: String) -> bool:
	var t := tool(id)
	var allowed := int(strength(id, tier(id), "uses"))
	if allowed == 0:
		allowed = 1
	return t.limit != "recharge" and int(_uses.get(id, 0)) >= allowed


func armed() -> String:
	return _armed


## Whether the sheet is being played right now (tools work only then).
func _playing() -> bool:
	var g = _game
	return g.game_active and not g.menus.visible and not g.dead and g.started() and not g.paused


## A tap on the belt button of `id`: the tool is used, or armed for a tile.
func use(id: String) -> void:
	if not _playing() or not ready(id):
		if _armed == id:
			_armed = ""
		Audio.play("tool_no")
		return
	var t := tool(id)
	if t.kind == "tile":
		_armed = "" if _armed == id else id
		Audio.play("tool_arm" if _armed != "" else "tool_no")
		return
	match id:
		"hop":
			if not _hop():
				Audio.play("tool_no")
				return
		"slow":
			_start_slow()
		"peek":
			_start_peek()
		"freeze":
			_active["freeze"] = strength("freeze", tier("freeze"), "s")
			_game.hud.show_effect("freeze")
	_used(id)


## The tool has been used: it counts, and starts recharging.
func _used(id: String) -> void:
	_uses[id] = int(_uses.get(id, 0)) + 1
	var full := _recharge(id)
	if full > 0.0:
		_cool[id] = full
	Audio.play("tool")


func _recharge(id: String) -> float:
	match id:
		"pin":
			return PIN_RECHARGE
		"eraser":
			return strength(id, tier(id), "s")
		"hop":
			return strength(id, tier(id), "recharge")
	return 0.0


## A tap on the field while a "tile" tool is armed: the tile under it gets
## the tool, or the tap disarms it. True when the tap was taken (never a
## pause). During First Look any tap ends the look.
func field_tap(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return false
	if looking():
		if not event.pressed:
			_look_left = 0.0
			_game.hud.set_look(0, 0.0)
			_game.hud.set_time_message("")
		return true
	if _armed == "":
		return false
	if event.pressed:
		return true
	var key := _tile_at(event.position)
	var id := _armed
	_armed = ""
	if key == Vector2i(-99, -99):
		return true  # off the sheet: put away
	match id:
		"eraser":
			_erase(key)
		"pin":
			_pin(key)
	_used(id)
	return true


## The tile under a screen position, or (-99, -99) when none is near.
func _tile_at(pos: Vector2) -> Vector2i:
	var map: LevelMap = _game.map
	var local := pos - map.global_position
	var best := Vector2i(-99, -99)
	var best_d := TAP_REACH
	for key in map.tiles:
		var tile: LevelMap.Tile = map.tiles[key]
		if tile.blank:
			continue
		var d := local.distance_to(tile.position)
		if d < best_d:
			best_d = d
			best = key
	return best


# --- the hand -----------------------------------------------------------------------


## The Eraser on `key`: a skull there, seen or not, is rubbed out until the
## next try. Any other tile just wastes the eraser.
func _erase(key: Vector2i) -> void:
	var map: LevelMap = _game.map
	if not map.deaths.get(key, false):
		Audio.play("tool_no")
		return
	map.erase_tile(key)
	Audio.play("erase")
	if _marks:
		_marks.rubbed(map.tiles[key].position)


## The Push Pin on `key`: spikes stay down and a crumble tile holds for the
## tier's seconds.
func _pin(key: Vector2i) -> void:
	var map: LevelMap = _game.map
	if not (map.spikes.has(key) or map.crumbles.get(key, false)):
		Audio.play("tool_no")
		return
	var seconds := strength("pin", tier("pin"), "s")
	_pinned[key] = seconds
	map.pinned[key] = true
	map.update_spikes(0.0)
	Audio.play("pin")
	if _marks:
		_marks.queue_redraw()


## Whether `key` is pinned right now, for the map's marks.
func pinned(key: Vector2i) -> bool:
	return _pinned.has(key)


func _start_peek() -> void:
	_active["peek"] = strength("peek", tier("peek"), "s")
	_game.hud.show_effect("peek")
	if _marks:
		_marks.peeking = true
		_marks.queue_redraw()


func _end_peek() -> void:
	_active.erase("peek")
	if _marks and _marks.peeking:
		_marks.peeking = false
		_marks.queue_redraw()
		_game.hud.clear_effect()


func peeking() -> bool:
	return _active.has("peek")


# --- the feet -----------------------------------------------------------------------


## Hop: over the next tile (two at tier III) the way he faces, landing on a
## real tile. False when there is nowhere to land.
func _hop() -> bool:
	var map: LevelMap = _game.map
	if map.moving or _game.stuck:
		return false
	var dir: Vector2i = _game.player.facing()
	if dir == Vector2i.ZERO:
		dir = map.last_step().sign()
	if dir == Vector2i.ZERO:
		return false
	var tiles := int(strength("hop", tier("hop"), "tiles"))
	var target := map.position_key + dir * (tiles + 1)
	if not map.walkable(target):
		return false
	var seconds: float = _game.STOP_TIME * 0.5 * (tiles + 1)
	map.hop(dir, tiles + 1, seconds)
	# The try records the hop as that many quick steps, so its replay and
	# ghost cross the tiles he hopped over on foot.
	for i in tiles + 1:
		_game._tries.step(dir, seconds / (tiles + 1))
	map.update_move(0.0)
	_game.player.face_direction(dir, true)
	_game._moves += 1
	if _game.vanish > 0:
		_game.vanish -= 1
	Audio.play("hop")
	return true


## How high he is off the sheet mid-hop (0 on the ground).
func hop_lift() -> float:
	var map: LevelMap = _game.map
	if not map.hopping():
		return 0.0
	return sin(map.move_share() * PI) * HOP_HEIGHT


## He stepped onto a deadly tile (`what`: "death" or "spikes"): the Hard Hat
## takes the hit if it is on and still has one, and the skull stays showing;
## true if it did.
func hat_saves(key: Vector2i, what: String) -> bool:
	if _hat_on and key == _hat_tile:
		return true
	var t := tier("hardhat")
	if t == 0 or used_up("hardhat"):
		return false
	if what == "spikes" and t < 2:
		return false
	_uses["hardhat"] = int(_uses.get("hardhat", 0)) + 1
	_hat_on = true
	_hat_tile = key
	_game.map.float_text(TranslationServer.translate("HARD HAT!"), Blueprint.GOLD)
	_game.player.cheer()
	Audio.play("hardhat")
	return true


## Out of lives: Second Draft stands him back up on the same sheet with its
## tier's seconds on the clock, once a game (twice at tier III); false when
## there is no draft left.
func revive() -> bool:
	if tier("revive") == 0 or used_up("revive"):
		return false
	_uses["revive"] = int(_uses.get("revive", 0)) + 1
	var g = _game
	g.lives = 1
	g._update_stats()
	g.reset_all(false)
	g._time_left = strength("revive", tier("revive"), "s")
	g.map.float_text(TranslationServer.translate("SECOND DRAFT"), Blueprint.GOLD)
	Audio.play("revive")
	return true


# --- the clock ----------------------------------------------------------------------


func _start_slow() -> void:
	_active["slow"] = strength("slow", tier("slow"), "s")
	Engine.time_scale = SLOW_SCALE
	Audio.slow_music(SLOW_PITCH)
	_game.hud.show_effect("slow")
	_trail_pos.clear()
	_make_trail()
	for p in _trail:
		p.outfit = _game.player.outfit
		p.visible = false


func _end_slow() -> void:
	if not _active.has("slow") and _slow_held == 0.0 and Engine.time_scale == 1.0:
		return
	_active.erase("slow")
	_slow_held = 0.0
	Engine.time_scale = 1.0
	Audio.slow_music(1.0)
	for p in _trail:
		p.vanish()
	_game.hud.clear_effect()


func slowing() -> bool:
	return _active.has("slow")


## A pause holds Slow-mo (the sheets run at full speed) and unpausing lets
## it run on.
func suspend() -> void:
	if _active.has("slow"):
		_slow_held = _active["slow"]
		_active.erase("slow")
		Engine.time_scale = 1.0
		Audio.slow_music(1.0)


func resume() -> void:
	if _slow_held > 0.0:
		_active["slow"] = _slow_held
		_slow_held = 0.0
		Engine.time_scale = SLOW_SCALE
		Audio.slow_music(SLOW_PITCH)


## Stop Clock: the countdown stands still.
func clock_stopped() -> bool:
	return _active.has("freeze")


## First Look: whether the clock is waiting for the player to look.
func looking() -> bool:
	return _look_left > 0.0


## Called each frame the sheet has loaded and the clock hasn't started: runs
## First Look when a try has one. True while the look holds the clock.
func look_update(delta: float) -> bool:
	if _look_pending:
		_look_pending = false
		if tier("look") > 0 and not _game.paused:
			_look_left = strength("look", tier("look"), "s")
			# The way the phone is held now is level: only a lean from here ends it.
			_game.tilt.calibrate()
			_game.player.update_at(_game.map.get_player_position(), 0.0)
			_game.player.show_player()
			_game.hud.set_time_message(TranslationServer.translate("FIRST LOOK"))
	if _look_left <= 0.0:
		return false
	_look_left -= delta
	# A lean ends the look early: the player has seen enough.
	_game.tilt.update(delta)
	if _game.tilt.get_vector().length() > Dev.t("tilt_threshold"):
		_look_left = 0.0
	_game.hud.set_look(ceili(_look_left), _look_left)
	if _look_left <= 0.0:
		_game.hud.set_look(0, 0.0)
		_game.hud.set_time_message("")
		return false
	return true


# --- Slow-mo's after-images ------------------------------------------------------------


## The two faint copies of him that trail behind in Slow-mo, on the field.
## They are only made the first time Slow-mo runs: a Player draws on the
## random numbers, and the sheets' loading must stay the same without one.
func make_trail(parent: Node) -> void:
	_trail_parent = parent


func _make_trail() -> void:
	if not _trail.is_empty():
		return
	for i in TRAIL:
		var p := Player.new()
		p.z_index = 9
		p.auto_look = false
		_trail_parent.add_child(p)
		p.vanish()
		_trail.append(p)


func _follow_trail() -> void:
	var player: Player = _game.player
	_trail_pos.append(player.position)
	while _trail_pos.size() > TRAIL * TRAIL_LAG + 1:
		_trail_pos.pop_front()
	for i in _trail.size():
		var back := (i + 1) * TRAIL_LAG
		var p := _trail[i]
		if _trail_pos.size() <= back or player.is_hidden:
			p.visible = false
			continue
		if not p.visible:
			p.reset_pose()
			p.is_hidden = false
			p.visible = true
		p.flip = player.flip
		p.look = player.look
		p.walking = player.walking
		p.side_on = player.side_on
		p.position = _trail_pos[_trail_pos.size() - 1 - back]
		p.modulate = Color(1, 1, 1, 0.4 - 0.15 * i)
		p.queue_redraw()


# --- the map's marks -----------------------------------------------------------------


## Pins and the Light Table's view, drawn over the map. Made again with
## each sheet, since the map's children go with its tiles.
func mark_map() -> void:
	_marks = ToolMarks.new(self, _game.map)
	_marks.z_index = 4
	_game.map.add_child(_marks)


## The pins over pinned tiles, the hidden tiles showing faintly through the
## paper while the Light Table is on, and the crumbs of a rubbed-out skull.
class ToolMarks:
	extends Node2D
	const CRUMB_SECONDS := 0.8
	var toolbox: Toolbox
	var map: LevelMap
	var peeking := false
	var _crumbs: Array = []  # [position, seconds left]

	func _init(box: Toolbox, on_map: LevelMap) -> void:
		toolbox = box
		map = on_map

	func _process(delta: float) -> void:
		if peeking or not _crumbs.is_empty():
			for c in _crumbs:
				c[1] -= delta
			_crumbs = _crumbs.filter(func(c: Array) -> bool: return c[1] > 0.0)
			queue_redraw()

	func rubbed(at: Vector2) -> void:
		_crumbs.append([at, CRUMB_SECONDS])
		queue_redraw()

	func _draw() -> void:
		if peeking:
			for key in map.tiles:
				var tile: LevelMap.Tile = map.tiles[key]
				if tile.sprite == null or tile.sprite.visible or map.broken.has(key):
					continue
				var tex := tile.sprite.texture
				var size := tex.get_size() * LevelMap.ASSET_SCALE
				draw_texture_rect(
					tex, Rect2(tile.position - size / 2.0, size), false, Color(1, 1, 1, 0.4)
				)
		var pin := ToolIcons.texture("pin", 2.0)
		for key in map.pinned:
			var tile: LevelMap.Tile = map.tiles.get(key)
			if tile == null:
				continue
			var size := pin.get_size() * 0.18
			var at := tile.position + Vector2(6.0, -16.0)
			draw_texture_rect(pin, Rect2(at - size / 2.0, size), false)
		for c in _crumbs:
			var share: float = c[1] / CRUMB_SECONDS
			var at: Vector2 = c[0]
			draw_arc(at, 20.0 - 6.0 * share, 0, TAU, 32, Color(1, 1, 1, 0.8 * share), 1.4, true)
			for p in [
				Vector2(-14, 9), Vector2(-9, 12), Vector2(12, 10), Vector2(16, 6), Vector2(-17, 4)
			]:
				draw_circle(at + p * (1.4 - 0.4 * share), 1.6, Color(ToolIcons.PINK, share))


# --- the sheet's actions ---------------------------------------------------------------


## Menu actions of the Toolbox's: "toolbox" (open it from the main menu or a
## level clear), "toolbox pause" (from the pause sheet), "tool <id>" (show a
## tool's card), "buy <id>", "belt <id>" (on or off the belt), "fresh sheet"
## (buy it, then take every star back) and "toolbox back". True if `act`
## was one.
func action(act: String) -> bool:
	var menus: Menus = _game.menus
	match act:
		"toolbox", "toolbox pause":
			from = "pause" if act == "toolbox pause" else ("clear" if _game._between else "main")
			if not Save.toolbox_open():
				return true
			_show()
		"toolbox back":
			match from:
				"pause":
					_game.show_pause_menu()
				"clear":
					menus.reopen_end_level()
				_:
					_game.show_start_menu()
		"fresh sheet":
			if not Save.fresh_sheet:
				if Toolbox.buy_fresh_sheet(Save):
					Audio.play("stamp")
			elif from == "pause":
				pass  # only between sheets: the belt stays as it is mid-sheet
			elif Toolbox.refund(Save):
				Audio.play("fresh")
			_show()
		_:
			if act.begins_with("tool "):
				var id := act.get_slice(" ", 1)
				if is_tool(id):
					selected = id
				_show()
			elif act.begins_with("buy "):
				if Toolbox.buy(Save, act.get_slice(" ", 1)):
					Audio.play("buy")
					_auto_belt(act.get_slice(" ", 1))
				_show()
			elif act.begins_with("belt "):
				var id := act.get_slice(" ", 1)
				if Toolbox.set_on_belt(Save, id, not Save.on_belt(id)):
					Audio.play("toggle")
				_show()
			else:
				return false
	return true


## A tool just bought goes on the belt when there is room.
func _auto_belt(id: String) -> void:
	if Save.tool_tier(id) == 1 and Save.belt.size() < belt_slots(Save):
		Toolbox.set_on_belt(Save, id, true)


func _show() -> void:
	ToolboxSheet.build(_game.menus, self)
