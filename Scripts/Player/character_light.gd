class_name CharacterLight
extends PointLight2D
## The pool of light a character carries with them, with the three things worth
## tuning about it gathered into plain inspector values.
##
## A [PointLight2D] can already be tuned, but not in the terms anybody actually
## thinks in: how far the light reaches is buried in
## [member PointLight2D.texture_scale], which is a multiplier on the size of
## whatever gradient happens to be plugged in - change the texture and the same
## number means a different radius. [member light_radius] here is the reach in
## world pixels, and the scale is worked out from the texture that is actually
## there, so the number means the same thing whatever art the light is given.
##
## [member light_energy] is kept apart from [member Light2D.energy] on purpose.
## The energy on the node is what the light is burning at *right now*, and
## [AmbientLightDimmer] writes to it every frame as the world around the character
## gets brighter or darker. This is the authored strength that dimming is measured
## against, which the dimmer reads back through [method get_base_energy] - so
## turning the character's light down in the inspector works while the game is
## running, and the two components never fight over the same field.

## How strong the light is at full strength, before anything dims it. This is the
## dial for "how much light does the character give off".
@export_range(0.0, 4.0, 0.01) var light_energy: float = 0.4:
	set(value):
		light_energy = maxf(value, 0.0)
		_apply()
## How far the light reaches from the character, in world pixels. Measured
## against the light's own texture, so it stays true if the gradient is swapped.
@export_range(0.0, 800.0, 1.0) var light_radius: float = 150.0:
	set(value):
		light_radius = maxf(value, 0.0)
		_apply()
## Colour of the light. The alpha is ignored - how strong the light is is
## [member light_energy]'s business, so the two cannot disagree.
@export var light_colour := Color(0.86, 0.86, 1.0):
	set(value):
		light_colour = value
		_apply()


func _ready() -> void:
	_apply()


## The strength dimming is measured against, read by [AmbientLightDimmer] every
## frame rather than captured once - so this stays the authority on how bright the
## character's light is even while something else is scaling it.
func get_base_energy() -> float:
	return light_energy


func _apply() -> void:
	energy = light_energy
	color = Color(light_colour.r, light_colour.g, light_colour.b, 1.0)

	# texture_scale multiplies the texture's own size, and the texture is a disc
	# drawn to its full width, so its radius on screen is half of that.
	if texture == null:
		return
	var half_width := maxf(float(texture.get_width()) * 0.5, 0.001)
	texture_scale = light_radius / half_width
