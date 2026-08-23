class_name ScatterLayer
extends Resource
## One kind of thing strewn across a map: the cacti, the bushes, the bones.
##
## A layer is a set of interchangeable scenes and how many of them to place. It
## is a resource rather than a set of fields on [PropScatter] so that adding a
## kind of scenery to a map is adding an entry to an inspector array - there is
## no name, branch or threshold in any script that a new one would have to be
## added to, and a map can carry as many or as few layers as it likes.
##
## Note that variety *within* one kind - five drawings of cactus - is not a layer
## each. That belongs to the prop, in [member PropArt.textures]. A layer is a
## different thing with different rules: solid or not, slowing or not, its own
## size and its own density.

## Scenes placed for this layer, chosen between at random. Usually one, with the
## variety inside it in [member PropArt.textures]; several is for scenery that
## differs in more than its picture.
@export var scenes: Array[PackedScene] = []
## How many to place across the whole of the scatter's region.
@export var count: int = 60
## Whether this layer is placed at all. Off is how a map turns one kind of
## scenery off without losing its settings.
@export var enabled: bool = true

@export_group("Placement")
## Range each instance's whole scale is rolled from. Left at
## [constant Vector2.ONE] - which is what the desert uses - every prop keeps
## exactly the size its own scene was authored at and the scatter does not touch
## its scale at all, so the artwork reads at the size the concept drew it.
##
## Widening it rolls a size per instance instead. The scale is applied to the
## whole instance rather than to its artwork, so collision, touch area and shadow
## would grow with the picture rather than drifting off it.
@export var scale_range := Vector2.ONE
## How far apart two things in this layer are kept, in pixels. A preference
## rather than a guarantee - a crowded map still places them.
@export var min_separation: float = 120.0
## How far this layer's things are kept from things in *earlier* layers, in
## pixels. Bones and bushes want to be allowed near a cactus; a second cactus
## does not.
@export var min_separation_from_others: float = 40.0
## Placement attempts before the best position found so far is accepted.
@export var max_attempts: int = 12
