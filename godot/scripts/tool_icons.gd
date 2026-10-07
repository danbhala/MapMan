class_name ToolIcons
extends RefCounted
## The Toolbox's icons, drawn in the tile art's style (bold black strokes on
## the white tile, 96×69 like the @3x tiles) from SVG at the scale they are
## shown, so they stay crisp on every phone. Each is cached by id and scale.

const STROKE := 'stroke="black" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"'
const THIN := 'stroke="black" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"'
const MID := 'stroke="black" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"'
## The accents the tile art uses.
const PINK := "#ff9fb5"
const GOLD := "#ffd166"
const LILAC := "#c9a6ff"

static var _cache := {}


## The drawing inside the 96×69 tile for tool `id` ("lock" for a tool still
## locked, "fresh" for Fresh Sheet).
static func svg(id: String) -> String:
	var body := ""
	match id:
		"eraser":
			body = (
				'<g transform="rotate(-28 48 34)">'
				+ '<rect x="22" y="23" width="52" height="22" rx="5" fill="white" %s/>' % STROKE
				+ (
					'<path d="M22 28 Q22 23 27 23 L40 23 L40 45 L27 45 Q22 45 22 40 Z" fill="%s" %s/>'
					% [PINK, STROKE]
				)
				+ "</g>"
				+ '<path d="M10 52 L26 52 M16 60 L34 60" fill="none" %s/>' % THIN
			)
		"peek":
			body = (
				(
					'<path d="M38 46 Q30 38 30 30 A18 18 0 0 1 66 30 Q66 38 58 46 Z" fill="%s" %s/>'
					% [GOLD, STROKE]
				)
				+ '<path d="M39 52 L57 52 M42 59 L54 59" fill="none" %s/>' % STROKE
				+ '<path d="M14 26 L21 27 M82 26 L75 27 M22 9 L27 14 M74 9 L69 14" fill="none" %s/>' % THIN
			)
		"pin":
			body = (
				'<g transform="rotate(25 48 34)">'
				+ '<path d="M48 40 L48 64" fill="none" %s/>' % THIN
				+ (
					'<path d="M34 40 L62 40 L56 30 L56 16 L40 16 L40 30 Z" fill="%s" %s/>'
					% [PINK, STROKE]
				)
				+ '<path d="M36 10 L60 10" fill="none" stroke="black" stroke-width="8" stroke-linecap="round"/>'
				+ "</g>"
			)
		"hop":
			body = (
				'<path d="M16 54 Q48 2 78 50" fill="none" %s/>' % STROKE
				+ '<path d="M66 46 L79 52 L82 37" fill="none" %s/>' % STROKE
				+ '<circle cx="48" cy="56" r="7" fill="black"/>'
			)
		"hardhat":
			body = (
				'<path d="M24 44 Q24 14 48 14 Q72 14 72 44 Z" fill="%s" %s/>' % [GOLD, STROKE]
				+ '<path d="M14 46 L82 46" fill="none" stroke="black" stroke-width="9" stroke-linecap="round"/>'
				+ '<path d="M48 15 L48 30 M36 19 L38 30 M60 19 L58 30" fill="none" %s/>' % THIN
			)
		"revive":
			body = (
				(
					'<path d="M48 56 C26 42 26 26 37 22 C43 20 47 24 48 28 C49 24 53 20 59 22 C70 26 70 42 48 56 Z" fill="white" %s/>'
					% STROKE
				)
				+ '<path d="M18 40 A30 30 0 1 1 30 60" fill="none" %s/>' % MID
				+ '<path d="M12 33 L18 42 L27 36" fill="none" %s/>' % MID
			)
		"slow":
			body = (
				'<circle cx="48" cy="38" r="22" fill="white" %s/>' % STROKE
				+ '<path d="M48 16 A22 22 0 0 1 48 60 Z" fill="%s"/>' % LILAC
				+ '<circle cx="48" cy="38" r="22" fill="none" %s/>' % STROKE
				+ '<path d="M48 38 L48 24 M42 9 L54 9 M48 9 L48 16 M66 18 L70 14" fill="none" %s/>' % STROKE
			)
		"look":
			body = (
				'<path d="M12 36 Q48 2 84 36 Q48 70 12 36 Z" fill="white" %s/>' % STROKE
				+ '<circle cx="48" cy="36" r="12" fill="%s" %s/>' % [GOLD, STROKE]
				+ '<circle cx="48" cy="36" r="5" fill="black"/>'
			)
		"freeze":
			body = (
				'<circle cx="48" cy="38" r="22" fill="white" %s/>' % STROKE
				+ '<path d="M42 9 L54 9 M48 9 L48 16" fill="none" %s/>' % STROKE
				+ '<path d="M40 28 L40 48 M56 28 L56 48" fill="none" stroke="black" stroke-width="7" stroke-linecap="round"/>'
			)
		"fresh":
			body = (
				'<path d="M24 12 L62 12 L74 24 L74 62 L24 62 Z" fill="white" %s/>' % STROKE
				+ '<path d="M62 12 L62 24 L74 24" fill="none" %s/>' % THIN
				+ '<path d="M38 46 A12 12 0 1 0 38 32" fill="none" %s/>' % MID
				+ '<path d="M32 26 L37 33 L45 29" fill="none" %s/>' % MID
			)
		"lock":
			body = (
				'<rect x="32" y="30" width="32" height="26" rx="4" fill="white" %s/>' % STROKE
				+ '<path d="M38 30 L38 22 A10 10 0 0 1 58 22 L58 30" fill="none" %s/>' % STROKE
			)
	return (
		'<svg xmlns="http://www.w3.org/2000/svg" width="96" height="69" viewBox="0 0 96 69">'
		+ '<g transform="translate(48 29) scale(0.74) translate(-48 -36)">%s</g></svg>' % body
	)


## The icon as a texture, 96×69 pixels at scale 1.
static func texture(id: String, scale := 3.0) -> Texture2D:
	var key := "%s@%s" % [id, scale]
	if not _cache.has(key):
		var img := Image.new()
		img.load_svg_from_string(svg(id), scale)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## A tool's icon on a tile, `w` wide, as a child of `parent` at `pos`
## (its centre); faded to `alpha`.
static func tile(parent: Node, id: String, pos: Vector2, w: float, alpha := 1.0) -> Node2D:
	var n := Node2D.new()
	n.position = pos
	parent.add_child(n)
	var s := w / 96.0
	var t := Sprite2D.new()
	t.texture = load(LevelMap.TILE_DIR + "blank1.png")
	t.scale = Vector2(s, s)
	t.modulate.a = alpha
	n.add_child(t)
	var i := Sprite2D.new()
	i.texture = texture(id, 3.0)
	i.scale = Vector2(s / 3.0, s / 3.0)
	i.modulate.a = alpha
	n.add_child(i)
	return n
