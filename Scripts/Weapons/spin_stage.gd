class_name SpinStage
extends Resource
## One rung of the revolver's twirl: how long it has to be held for, what the shot
## it earns is worth, and how much harder the weapon is turning once it lands.
##
## [b]The stages are a list, not a ladder written into a script.[/b] [RevolverSpin]
## walks whatever array it is given in order and knows nothing about "two times" or
## "four times" - so a fourth rung, a different curve of speeds, or a weapon whose
## twirl only ever reaches one stage is an entry added or removed in the inspector.
## There is no threshold, no branch and no name here that a new entry would have to
## be added to.
##
## Every field is what that rung does the moment it is reached, and the array is
## expected to be in ascending [member hold_time] order.

## How long the weapon must have been spinning without a break, in seconds, for
## this rung to be reached. Measured from the start of the spin rather than from
## the previous rung, so the numbers read as the times the player actually feels.
@export var hold_time: float = 0.6

@export_group("What it earns")
## What a shot taken at this rung multiplies its damage by. Handed to
## [method Projectile.empower], so it rides on top of the round's own profile and
## falloff rather than replacing them - a bullet retuned later carries through.
@export var damage_multiplier: float = 2.0
## What the twirl's speed is multiplied by while this rung is held, against
## [member RevolverSpin.spin_speed_degrees].
##
## [b]It is the whole multiplier, not the step.[/b] A rung twice as fast as the
## base says 2 and the rung above it says 4 - what the player sees is the doubling,
## but each entry states its own speed outright so a stage can be retuned without
## every stage above it moving.
@export var spin_speed_multiplier: float = 2.0

@export_group("Camera")
## How hard the camera is kicked at the instant this rung is reached. Once, on the
## transition - the stage holding is not a reason to keep shaking.
@export var shake_strength: float = 6.0
## How long that kick lasts, in seconds.
@export var shake_duration: float = 0.14

@export_group("Sound")
## What the spin loop is played back at while this rung is held.
##
## [b]It is the pitch itself, not a step.[/b] The loop starts at
## [member RevolverSpin.spin_audio_base_pitch] and each rung states outright what it
## sounds like, exactly as [member spin_speed_multiplier] states its own speed - so a
## rung can be retuned without every rung above it moving, and the sound the player
## hears is always the rung they are actually on.
@export var audio_pitch: float = 1.5
## How long the loop takes to slide onto that pitch, in seconds. Short: the player
## should hear the weapon bite rather than hear a glissando.
@export var audio_pitch_time: float = 0.1

@export_group("Readout")
## What the multiplier readout says while this rung is held. The text, not a
## number, so a rung could read anything the art wants it to.
@export var label: String = "2x"
## How large that text is drawn, against the readout's own base size. The rungs
## grow as they climb so a fully wound revolver is unmistakable at a glance.
@export var label_scale: float = 1.0
