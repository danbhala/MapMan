extends Node
## Ads (docs/ads.md): rewarded ads the player chooses (KEEP GOING when the
## last life is lost, DOUBLE IT on the level clear) and a full-screen ad on
## NEXT, now and then, through Google AdMob (addons/admob, reached only through
## scripts/ads_admob.gd). Levels 1 to 10, the tutorial, practice, the drafting
## table and replays never show an ad, and there are no banners.
##
## With no connection, no consent, ads switched off or no ad loaded, the
## buttons simply aren't offered and NEXT goes straight on: the game never
## waits on an ad.

## An ad became ready (a sheet offering one may want to redraw).
signal changed

## Levels up to this one never show an ad of any kind.
const FREE_LEVELS := 10
## At most one full-screen ad per this many level clears past FREE_LEVELS...
const CLEARS_PER_INTERSTITIAL := 3
## ...and never sooner than this after any ad, rewarded ones included.
const MIN_GAP_MS := 180_000

## Google's test ad units, for every dev build: AdMob suspends accounts whose
## own ads get tapped by their developers.
const TEST_UNITS := {
	"keep_going": "ca-app-pub-3940256099942544/5224354917",
	"double_it": "ca-app-pub-3940256099942544/5224354917",
	"level_clear": "ca-app-pub-3940256099942544/1033173712",
}
## MapMan's own ad units (AdMob > Apps > MapMan > Ad units); its app ID is in
## project.godot (admob/general/android/app_id).
const UNITS := {
	"keep_going": "ca-app-pub-4967250367903621/4253994178",
	"double_it": "ca-app-pub-4967250367903621/8173147179",
	"level_clear": "ca-app-pub-4967250367903621/6815658465",
}

## The DEV menu's switches: no ads at all, and the full-screen ad on every
## clear past level 10 (to try it without playing three levels).
var off := false
var every_clear := false
## Tests and screenshots: every rewarded ad is ready and rewards at once,
## with no plugin and no network.
var fake := false

## The AdMob side (scripts/ads_admob.gd), loaded only on a phone so tests and
## the desktop never touch the plugin.
var _admob: RefCounted
var _clears := 0  # clears past FREE_LEVELS since the last full-screen ad
var _last_ad_ms := -MIN_GAP_MS
var _showing := false


## Whether this build can show ads at all: only on a phone.
func supported() -> bool:
	return fake or OS.get_name() in ["Android", "iOS"]


## The ad unit for `key`: Google's test unit in a dev build.
func unit(key: String) -> String:
	return TEST_UNITS[key] if Dev.enabled else UNITS[key]


## At launch: Google's consent form where the law asks for one (the EU and
## UK), then the SDK, then the ads load in the background.
func start() -> void:
	if _admob or fake or not supported():
		return
	_admob = load("res://scripts/ads_admob.gd").new(self)
	_admob.start()


## Whether a rewarded ad (`key`: "keep_going" or "double_it") can be offered.
func rewarded_ready(key: String) -> bool:
	if off or _showing:
		return false
	return fake or (_admob != null and _admob.has(key))


## Plays the rewarded ad `key`; `done` gets true once the player has earned
## the reward, after the ad closes. An ad that fails to play still rewards:
## the player asked for it in good faith.
func show_rewarded(key: String, done: Callable) -> void:
	if not rewarded_ready(key):
		done.call(false)
		return
	if fake:
		_last_ad_ms = Time.get_ticks_msec()
		done.call(true)
		return
	_showing = true
	_admob.show_rewarded(
		key,
		func(earned: bool) -> void:
			_showing = false
			_last_ad_ms = Time.get_ticks_msec()
			done.call(earned)
	)


## Counts a clear of `level` in the main game towards the next full-screen ad.
func note_clear(level: int) -> void:
	if level > FREE_LEVELS:
		_clears += 1


## Whether NEXT after clearing `level` should show the full-screen ad first.
func interstitial_due(level: int) -> bool:
	if off or _showing or level <= FREE_LEVELS:
		return false
	if not (fake or (_admob != null and _admob.has("level_clear"))):
		return false
	if every_clear:
		return true
	if _clears < CLEARS_PER_INTERSTITIAL:
		return false
	return Time.get_ticks_msec() - _last_ad_ms >= MIN_GAP_MS


## Shows the full-screen ad, then `done` (at once if there is none to show).
func show_interstitial(done: Callable) -> void:
	_clears = 0
	_last_ad_ms = Time.get_ticks_msec()
	if fake or _admob == null or not _admob.has("level_clear"):
		done.call()
		return
	_showing = true
	_admob.show_interstitial(
		func() -> void:
			_showing = false
			_last_ad_ms = Time.get_ticks_msec()
			done.call()
	)


## Options' AD PRIVACY row: Google requires a way back to the consent form
## wherever it was shown.
func privacy_options_required() -> bool:
	if fake:
		return true
	return _admob != null and _admob.privacy_options_required()


func show_privacy_options() -> void:
	if _admob:
		_admob.show_privacy_options()


## DEV: forget the consent answer, so the form asks again on the next launch.
func reset_consent() -> void:
	if _admob:
		_admob.reset_consent()


## Tests: back to a fresh launch.
func reset() -> void:
	off = false
	every_clear = false
	_clears = 0
	_last_ad_ms = -MIN_GAP_MS
	_showing = false


## DEV: switching ads off drops the loaded ones; on again loads them.
func set_off(on: bool) -> void:
	off = on
	if _admob and off:
		_admob.drop_all()
	elif _admob:
		_admob.load_all()
	changed.emit()
