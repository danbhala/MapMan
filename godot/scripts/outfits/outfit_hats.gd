class_name OutfitHats
extends RefCounted
## Hats and helmets (docs/wardrobe), in the HAT layer. Every point goes
## through pen.t() (the hat_* calls), relative to the head's centre: the hat
## rides the head, and flies off and fades as he dies. The head's top is at
## y -15; keep within the size budget (test_outfits.gd).

const PINK := Color("#ff9fb5")
const GOLD := Color("#ffd166")


static func draw(pen: OutfitPen, id: String) -> void:
	match id:
		"party_hat":
			_party_hat(pen)


## A striped cone with a pom-pom, a little askew.
static func _party_hat(pen: OutfitPen) -> void:
	var base := Vector2(0, -12.0)
	var apex := base + Vector2(0, -25.0).rotated(-0.18)
	var l := base + Vector2(-9.6, 0)
	var r := base + Vector2(9.6, 0)
	pen.hat_poly(PackedVector2Array([l, apex, r]), PINK)
	for k: float in [0.12, 0.42, 0.7]:
		var band := PackedVector2Array(
			[
				l.lerp(apex, k),
				l.lerp(apex, k + 0.12),
				r.lerp(apex, k + 0.28),
				r.lerp(apex, k + 0.16)
			]
		)
		pen.hat_poly(band, GOLD)
	pen.hat_dot(apex, 3.8, Color.WHITE)
	for i in 6:
		pen.hat_dot(apex + Vector2.from_angle(TAU * i / 6.0) * 3.2, 1.6, Color.WHITE)
