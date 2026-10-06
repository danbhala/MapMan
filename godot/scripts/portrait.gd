class_name Portrait
extends RefCounted
## The portrait prototype (research/portrait, not on master): the game held
## upright. The switch is the project's orientation (display/window/handheld/
## orientation = portrait). Upright, the screen is 375 wide, too narrow for the
## widest sheets (17 columns of 32), so the map is turned a quarter turn
## anticlockwise: a sheet's columns run up the screen and its rows across.
## The tiles and MapMan stay upright. Main still thinks in the map's own
## directions; screen_dir() and grid_vector() turn them at the edges.
## Under the field is the control deck (PortraitDeck): the thumb's place.

## The deck under the field, inside the frame.
const DECK_HEIGHT := 140.0
## The map sits this much below the field's middle: MapMan stands up from
## his tile, so the top row needs room for his head under the countdown.
const MAP_DROP := 18.0
## Hud.HEADER_HEIGHT + Hud.BAR_HEIGHT: named here, not through Hud, so the
## --script tools that load LevelMap don't pull in the autoloads Hud names.
const TOP_STRIPS := 28.0 + 44.0


static func on() -> bool:
	return int(ProjectSettings.get_setting("display/window/handheld/orientation", 0)) == 1


## The map direction `g` (column, row) as a screen direction.
static func screen_dir(g: Vector2i) -> Vector2i:
	if not on():
		return g
	return Vector2i(g.y, -g.x)


## A screen steering vector in the map's own directions.
static func grid_vector(v: Vector2) -> Vector2:
	if not on():
		return v
	return Vector2(-v.y, v.x)


## The field between the header (with the countdown bar under it) and the deck.
static func field_rect(screen: Vector2) -> Rect2:
	var inner := Blueprint.INSET + 1.0
	var top := inner + TOP_STRIPS
	var bottom := screen.y - inner - DECK_HEIGHT
	return Rect2(inner, top, screen.x - 2.0 * inner, bottom - top)


static func deck_rect(screen: Vector2) -> Rect2:
	var inner := Blueprint.INSET + 1.0
	return Rect2(inner, screen.y - inner - DECK_HEIGHT, screen.x - 2.0 * inner, DECK_HEIGHT)
