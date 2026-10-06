extends TiltInput
## A hand for the portrait video (tools/portrait_tour.gd): the tilt the tour
## sets in `lean`, as the gauge reads a real phone. Loaded with load() once the
## game runs, so this script may name TiltInput (and so Dev).

## The tilt the tour is giving, in screen terms (TiltInput units, g).
var lean := Vector2.ZERO


func get_vector() -> Vector2:
	if stick:
		return super.get_vector()
	return lean
