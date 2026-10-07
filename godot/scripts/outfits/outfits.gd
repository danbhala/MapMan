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
## body and the legs), head_glow; bow (MapWoman's, else the body's). Every
## look keeps a dark mass and a light one, so he reads on the blue paper and
## on a white tile (test_outfits.gd).
const PALETTES := {
	"signal_red": {"body": Color("#e0453a")},
	"racing_green": {"body": Color("#1f7a4f")},
	"blueprint":
	{
		"body": Blueprint.FIELD,
		"head": Blueprint.FIELD,
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
	# MapWoman's (docs/wardrobe, "Her wardrobe").
	"sky_blue": {"body": Color("#5fb3e8"), "legs": Color("#1d5c8a"), "bow": Color("#1d5c8a")},
	"sunflower": {"body": Color("#f2c230"), "legs": Color("#2f5d34")},
	"footballer": {"body": Color("#f2f5f9"), "legs": Color("#1b263b"), "outline": Color("#2c3e50")},
	"chef": {"body": Color("#f6f6f6"), "legs": Color("#2b2b2b"), "outline": Color("#4a4a4a")},
	"firefighter": {"body": Color("#f9c74f"), "legs": Color("#1b263b")},
	"detective": {"body": Color("#8a7a5a"), "legs": Color("#4a3f2e")},
	"storm":
	{
		"body": Color("#111a2e"),
		"eyes": Color("#ffd60a"),
		"glow": Color("#ffd60a"),
		"head_glow": Color("#ffd60a"),
	},
	"surgeon": {"body": Color("#2a9d8f"), "legs": Color("#1b6b62")},
	"mechanic": {"body": Color("#3e6db3"), "legs": Color("#3e6db3")},
	"beekeeper":
	{
		"body": Color("#f4f1e8"),
		"legs": Color("#f4f1e8"),
		"outline": Color("#6b6b5e"),
		"leg_outline": Color("#6b6b5e"),
	},
	"rock_star": {"body": Color("#1b1b22"), "legs": Color("#b5171f"), "outline": Color("#c0c6d0")},
	"sea_captain":
	{
		"body": Color("#1f3b73"),
		"legs": Color("#eef2f7"),
		"outline": Color("#d4a017"),
		"leg_outline": Color("#34495e"),
	},
	"knight": {"body": Color("#a9b4c2"), "legs": Color("#6b7685"), "outline": Color("#4b5563")},
	"aviator": {"body": Color("#8c6a3f"), "legs": Color("#4a3a26")},
	"disco":
	{
		"body": Color("#c9ced6"),
		"head": Color("#e6e9ee"),
		"eyes": Color("#3a2d6b"),
		"legs": Color("#3a2d6b"),
		"outline": Color("#5b6270"),
		"head_outline": Color("#8a93a3"),
		"bow": Color("#5b6270"),
	},
	"dragon": {"body": Color("#2e8b57"), "legs": Color("#1f5e3a")},
	"platinum":
	{
		"body": Color("#d8dde3"),
		"head": Color("#eef1f4"),
		"eyes": Color("#4a5563"),
		"outline": Color("#6b7785"),
		"leg_outline": Color("#6b7785"),
		"head_outline": Color("#9aa3ae"),
		"bow": Color("#9aa3ae"),
	},
}
## Looks with something on the back (a cape, a rolled map). It hangs behind
## him, and covers his back when he walks away.
const BACKS := ["superhero", "explorer", "mechanic", "rock_star", "aviator", "dragon"]
## MapWoman's looks that take the place of her bow: a hat, a hood, hair.
const BARE_HEAD := [
	"beret",
	"headband",
	"chef",
	"firefighter",
	"detective",
	"surgeon",
	"mechanic",
	"beekeeper",
	"rock_star",
	"sea_captain",
	"knight",
	"aviator",
	"dragon",
]


## The colours a look changes ({} for plain MapMan).
static func palette(id: String) -> Dictionary:
	return PALETTES.get(id, {})


static func has_back(id: String) -> bool:
	return id in BACKS


## Whether a look of hers leaves off MapWoman's bow (something else is on
## her head).
static func hides_bow(id: String) -> bool:
	return id in BARE_HEAD


## The parts of look `id` in `layer`.
static func draw(pen: OutfitPen, layer: Layer, id: String) -> void:
	if id == "classic":
		return  # the common case: nothing to look up
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
	return id != "classic" and OutfitFaces.head_shape(pen, id, colour)


## Draws the eyes when the look changes them, and says so; otherwise Player
## draws the classic eyes.
static func eyes(pen: OutfitPen, id: String, colour: Color) -> bool:
	return id != "classic" and OutfitFaces.eyes(pen, id, colour)
