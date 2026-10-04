class_name Outfits
extends RefCounted
## The looks MapMan can wear (docs/wardrobe): their colours, and the parts
## each layer of him draws. Player draws the figure and calls draw() once per
## layer; the parts live in outfit_backs.gd, outfit_bodies.gd,
## outfit_faces.gd and outfit_hats.gd. An id with nothing here, "classic"
## among them, is plain MapMan.

## The layers, back to front. Dying, BODY and NECK draw over HEAD and FACE
## (he is swallowed whole) and the HAT flies off.
enum Layer { BACK, LEGS, BODY, NECK, HEAD, FACE, HAT, FRONT }

## Colour roles a look changes. body, head, eyes; legs (else the body's);
## outline (round the body), leg_outline, head_outline; glow (a halo round the
## body and the legs), head_glow. Every look keeps a dark mass and a light
## one, so he reads on the blue paper and on a white tile (test_outfits.gd).
const PALETTES := {
	"signal_red": {"body": Color("#e0453a")},
	"racing_green": {"body": Color("#1f7a4f")},
	"blueprint":
	{
		"body": Color("#16407a"),
		"head": Color("#16407a"),
		"eyes": Color.WHITE,
		"outline": Color.WHITE,
		"head_outline": Color.WHITE,
		"leg_outline": Color.WHITE,
	},
	"hard_hat": {"body": Color("#ff7a1a"), "legs": Color("#1b263b")},
	"neon":
	{
		"body": Color("#0b1020"),
		"eyes": Color("#f72585"),
		"glow": Color("#4cc9f0"),
		"head_glow": Color("#f72585"),
	},
	"doctor": {"body": Color("#f2f5f9"), "legs": Color("#178f82"), "outline": Color("#2c3e50")},
	"explorer": {"body": Color("#8c7248"), "legs": Color("#6b5636")},
	"astronaut":
	{
		"body": Color("#eef2f7"),
		"legs": Color("#eef2f7"),
		"outline": Color("#34495e"),
		"leg_outline": Color("#34495e"),
	},
	"pumpkin": {"head": Color("#f4831f")},
	"skeleton": {"head": Color("#efe8d6")},
	"robot": {"body": Color("#6c7a89"), "head": Color("#a9b4c2"), "legs": Color("#3d4652")},
	"superhero": {"body": Color("#d62828"), "eyes": Color.WHITE},
	"wizard": {"body": Color("#9d4edd")},
	"gold":
	{
		"body": Color("#d9a521"),
		"head": Color("#f2cd5c"),
		"eyes": Color("#6b4a06"),
		"outline": Color("#8a6512"),
		"leg_outline": Color("#8a6512"),
		"head_outline": Color("#b8860b"),
	},
}
## Looks with something on the back (a cape, a rolled map). It hangs behind
## him, and covers his back when he walks away.
const BACKS := ["superhero", "explorer"]


## The colours a look changes ({} for plain MapMan).
static func palette(id: String) -> Dictionary:
	return PALETTES.get(id, {})


static func has_back(id: String) -> bool:
	return id in BACKS


## The parts of look `id` in `layer`.
static func draw(pen: OutfitPen, layer: Layer, id: String) -> void:
	match layer:
		Layer.BACK, Layer.FRONT:
			OutfitBacks.draw(pen, layer, id)
		Layer.LEGS, Layer.BODY, Layer.NECK:
			OutfitBodies.draw(pen, layer, id)
		Layer.HEAD, Layer.FACE:
			OutfitFaces.draw(pen, layer, id)
		Layer.HAT:
			OutfitHats.draw(pen, id)


## Draws the head when the look changes its shape, and says so; otherwise
## Player draws the round head.
static func head_shape(pen: OutfitPen, id: String, colour: Color) -> bool:
	return OutfitFaces.head_shape(pen, id, colour)


## Draws the eyes when the look changes them, and says so; otherwise Player
## draws the classic eyes.
static func eyes(pen: OutfitPen, id: String, colour: Color) -> bool:
	return OutfitFaces.eyes(pen, id, colour)
