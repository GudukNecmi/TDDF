class_name HorsePartMotion
extends Resource
## How one part of a horse moves through the gallop cycle - one entry of
## [member HorseRig.parts].
##
## [b]This is the whole of a part's animation, and it is data rather than
## code.[/b] [HorseRig] holds no list of body parts, no branch on a part's name
## and no number of its own for a head, a leg or a tail: it advances one phase
## and asks every entry of its array where that puts the node it points at. So
## a horse with two front legs, a saddle, a rider's bedroll or a mane that
## whips on its own is that horse's scene with more entries in the array - see
## the class doc of [HorseRig] - and never a second animation system, an
## [AnimationPlayer] per horse or a line added to a script.
##
## [b]It is written from the keyframe drawings, not invented.[/b] The reference
## sheet in [code]res://Assets/Horses/KeyFrames/[/code] is four poses of one
## stride: the front leg reaching, the legs gathering under the body, the rear
## leg driving back, and the suspension. What actually differs between those
## four drawings is how far each part has turned about its own joint and how
## far it has risen - which is exactly [member swing_degrees],
## [member phase_offset] and [member lift_pixels], read off a single stride
## clock rather than held as four separate pictures. That is what lets the same
## data play at any speed, blend down to a standing horse and loop without a
## seam.

## The node this entry poses, relative to the [HorseRig] itself - for example
## [code]^"Rig/FrontLeg"[/code]. Its own origin must sit on the joint it turns
## about; in the horses shipped so far that is done with
## [member Sprite2D.offset], so the artwork keeps the shared canvas it was
## drawn on and only the pivot moves.
@export var part_path: NodePath

@export_group("Swing")
## How far the part turns either way from its authored rest angle at a full
## gallop, in degrees. The single biggest thing a part does: a leg 550 source
## pixels long turning 26 degrees carries its hoof about 240 of them.
@export var swing_degrees: float = 0.0
## A constant turn added on top of the swing as the gallop blends in, in
## degrees - the part of a pose that does not oscillate. The tail streaming out
## behind and the neck reaching forward are this, not [member swing_degrees]:
## they are where the part [i]sits[/i] while running, and they fall back to the
## authored rest angle as the horse stops.
@export var swing_bias_degrees: float = 0.0
## Where in the stride this part reaches the top of its swing, in turns of the
## cycle - 0 and 1 are the same instant. The front leg leads at 0 and the rear
## leg answers half a stride later at 0.5; a tail or a head that trails its
## neck is a small offset past whatever it follows.
@export_range(0.0, 1.0) var phase_offset: float = 0.0
## How many times this part completes its own swing per stride. 1 for anything
## that swings once with the legs; 2 for something that answers on both beats,
## such as a body that rises and falls twice a stride.
@export_range(1, 4) var harmonic: int = 1

@export_group("Shift")
## How far the part rises and falls over the cycle, in the rig's own source
## pixels, in step with its swing. Small on every part of a horse - the legs
## are carried by their rotation, not by this - and mostly worth having on a
## body, a saddle or a load that should look like it is being thrown about.
@export var lift_pixels: float = 0.0
## How far the part slides along the horse's own length over the cycle, in
## source pixels. A quarter turn out of step with [member lift_pixels], so a
## part given both traces a small oval rather than a diagonal line.
@export var reach_pixels: float = 0.0

@export_group("Standing")
## How far the part turns either way while the horse is standing still, in
## degrees. Keep it tiny: this is a horse breathing and shifting its weight,
## not a gallop played slowly.
@export var idle_swing_degrees: float = 0.0
## How far the part rises and falls while standing still, in source pixels.
@export var idle_lift_pixels: float = 0.0
