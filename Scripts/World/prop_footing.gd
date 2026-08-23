@tool
class_name PropFooting
extends CollisionShape2D
## The solid part at the bottom of a piece of scenery: the poles a tent is pegged
## on, the foot of a stake driven into the ground.
##
## [b]A prop is not solid all the way up.[/b] A tent stands more than twice the
## height of a man, and a man walking behind one has to disappear behind it rather
## than stop dead at its roof. So what blocks him is a band along the very bottom
## of the artwork, and everything above that is picture only - which, with the
## props container y-sorted, is exactly the "walk behind it, cannot walk through
## it" the map wants.
##
##   [codeblock]
##     /\        <- picture only; the man passes behind it
##    /  \
##   /____\
##   [####]      <- height_units of solid, sitting on the prop's own base
##   [/codeblock]
##
## [b]It is stated in world units, not in pixels.[/b] One unit is
## [member pixels_per_unit] across, and the player is about two units tall - so
## "the lower 0.6 units are solid" is a sentence about the man rather than a number
## that only means something next to one particular drawing. Nothing here knows
## what a tent is: the same node is the foot of a stake, a crate or a rock at
## different numbers.
##
## [b]And it holds that size against the map's own scale.[/b] The scenery of a map
## is resized as a whole - see [PropScale] - which would otherwise shrink the solid
## band along with the picture and leave a shin-high tent blocking an ankle-high
## strip. With [member holds_world_size] on, the shape is built in local space
## divided by whatever scale the prop ended up at, so the band is
## [member height_units] of the world however large the map draws its scenery. Turn
## it off for a prop whose collision should shrink with its picture instead.
##
## The width is taken from the artwork by default - see [member width_fraction] -
## so a prop drawn wider is footed wider without a second number being kept in step
## with the first, and a set of drawings at different widths still each stand on
## their own base.

## How many world pixels one world unit is.
##
## [b]The player is about two units tall.[/b] That is the whole of what fixes the
## scale: the man is roughly 90 pixels from his boots to the crown of his hat, so a
## unit is half of that. It is a field rather than a constant because the character
## is the thing being measured against, and a later map or a later character can
## say so here rather than every prop's numbers having to be re-read.
@export var pixels_per_unit: float = 45.0:
	set(value):
		pixels_per_unit = maxf(value, 0.001)
		_apply()
## How tall the solid band is, in world units, measured up from the prop's base.
##
## 0.6 by default - a little under a third of the player's height, which is a thing
## to be stopped by rather than a wall.
@export var height_units: float = 0.6:
	set(value):
		height_units = maxf(value, 0.0)
		_apply()
## How wide it is, in world units. Left at nothing the artwork decides - see
## [member width_fraction] - which is what a set of drawings at different widths
## wants. Give it a number for a prop whose base is nothing like its picture: a
## stake is a hand's width of pole under a great deal of empty canvas.
@export var width_units: float = 0.0:
	set(value):
		width_units = maxf(value, 0.0)
		_apply()
## How much of the artwork's drawn width the base covers, when
## [member width_units] is left at nothing. 1 is the full width of the picture;
## lower pulls the solid part in from the edges, which is usually right, because
## the widest part of a drawing is rarely the part standing on the ground.
@export_range(0.0, 1.0, 0.01) var width_fraction: float = 0.8:
	set(value):
		width_fraction = clampf(value, 0.0, 1.0)
		_apply()
## Shifts the band from where the artwork put it, in world units. For a prop drawn
## off-centre on its canvas - a skull on a pole leaning to one side - without the
## artwork having to be redrawn or the prop node moved off its own position.
@export var offset_units := Vector2.ZERO:
	set(value):
		offset_units = value
		_apply()

@export_group("Measuring")
## The artwork the width is read from. Left unresolved, or pointed at something
## that is not a [PropArt], the width falls back to [member width_units] and then
## to nothing - so a footing on a prop with no picture is simply not solid rather
## than an error.
@export var art_path: NodePath = ^"../Art":
	set(value):
		art_path = value
		_apply()
## Whether the band keeps its size in the world whatever the map's [PropScale] is.
##
## On, which is what the numbers above mean: 0.6 units is 0.6 units on a map that
## draws its scenery at half size. Off authors the band at the prop's own scale
## instead, so it shrinks and grows with the picture - which is what a prop whose
## collision is really a property of its drawing wants.
@export var holds_world_size: bool = true:
	set(value):
		holds_world_size = value
		_apply()


func _ready() -> void:
	# After the artwork, which picks its picture in its own `_ready` - so the width
	# is measured against the drawing this instance actually ended up with rather
	# than against whichever one the scene was saved showing. Sibling order in the
	# scene is what guarantees it: the footing sits below the art.
	_apply()


## How tall the solid band is in world pixels, for a readout or a test.
func get_solid_height() -> float:
	return height_units * pixels_per_unit


## Builds the shape and stands it on the prop's base.
##
## The origin of a prop is the middle of the bottom edge of its artwork - see
## [PropArt] - so the band runs from there upwards, and nothing has to be told
## where the ground is.
func _apply() -> void:
	if not is_inside_tree():
		return

	var scale_out := 1.0
	if holds_world_size:
		# The prop has already been given the map's scale by whatever placed it, so
		# this is the number the world will actually draw it at. Dividing it back out
		# is what turns a world measurement into the local one the shape wants.
		scale_out = maxf(absf(global_scale.y), 0.001)

	var band := height_units * pixels_per_unit / scale_out
	var across := _width(scale_out)
	if band <= 0.0 or across <= 0.0:
		# Nothing to stand on. Left shapeless rather than given a zero-sized
		# rectangle, which Godot warns about every frame.
		shape = null
		return

	var box := shape as RectangleShape2D
	if box == null:
		# Its own rather than the scene's, so two props sharing a scene cannot end up
		# sharing one shape and resizing each other.
		box = RectangleShape2D.new()
		shape = box
	box.size = Vector2(across, band)

	var shift := offset_units * pixels_per_unit / scale_out
	position = Vector2(shift.x, -band * 0.5 + shift.y)


## How wide the band is, in the prop's own space: the number given, or the width of
## the drawing when none was.
func _width(scale_out: float) -> float:
	if width_units > 0.0:
		return width_units * pixels_per_unit / scale_out

	var art := get_node_or_null(art_path) as PropArt
	if art == null:
		return 0.0
	return art.get_content_size().x * width_fraction
