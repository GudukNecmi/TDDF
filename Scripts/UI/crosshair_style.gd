class_name CrosshairStyle
extends Resource
## How one weapon's sight is drawn: the piece it is built from, where the four
## copies of it sit, and what colour they are.
##
## [b]The four pieces are one drawing.[/b] Every weapon's sight in the game is a
## single PNG - the revolver's bullet, the rifle's blade, the shotgun's corner -
## placed four times and turned a quarter turn each time, exactly as the concept
## art is assembled. Nothing is redrawn per arm and nothing is distorted, so the
## art the artist supplied is the art on screen.
##
## [b]Adding a weapon's sight is adding one of these to the crosshair's array.[/b]
## There is no weapon named anywhere in [Crosshair]: it looks up whichever style
## carries the id of the weapon that was built, so a fourth weapon is a resource
## and a PNG rather than a branch.
##
## The spacing is a range rather than a number because the sight opens with the
## distance from the player to the cursor - see [member closed_spacing] and
## [member open_spacing]. A revolver's range is deliberately almost nothing and a
## shotgun's is wide, which is the whole of "this weapon is loose at range" said
## visually.

## Which weapon this belongs to. Matched against [member WeaponDefinition.weapon_id],
## so it is the same name the catalogue, the selection screen and the ammunition
## already use.
@export var weapon_id: StringName = &"weapon"
## The one drawing the sight is built from. Placed four times.
@export var piece_texture: Texture2D
## Size one piece is drawn at, in pixels. The artwork is far larger than it wants
## to be on screen, so this is the dial that matters.
@export var piece_size := Vector2(26.0, 26.0)

@export_group("Placement")
## Whether the four copies sit on the diagonals rather than on the axes.
##
## Off puts them up, right, down and left - the cross the revolver and the rifle
## are drawn as. On puts them at the four corners, which is how the shotgun's
## bracket is assembled.
@export var diagonal: bool = false
## Extra turn applied to every piece, in degrees, on top of the quarter turn its
## own arm gets.
##
## [b]This is how a drawing is squared up without being redrawn.[/b] A piece drawn
## pointing up needs none; one drawn as a top-left corner needs whatever puts its
## corner outward. It is a whole-turn nudge, never a distortion.
@export var piece_rotation_offset_degrees: float = 0.0
## Whether each piece is turned to face out along its own arm. On is what a
## directional drawing - a bullet, a blade, a corner - wants. Off leaves every
## copy upright.
@export var rotate_with_arm: bool = true

@export_group("Spread")
## How far each piece sits from the middle with the cursor on the player, in
## pixels. The sight at rest.
@export var closed_spacing: float = 7.0
## How far it sits at [member spread_distance] and beyond. The difference between
## this and [member closed_spacing] is the whole of how loose the weapon reads.
@export var open_spacing: float = 16.0
## How far the cursor must be from the player, in world pixels, for the sight to
## be fully open. Beyond it nothing widens further.
@export var spread_distance: float = 620.0
## Shape of the opening between the two. 1 is a straight line; above 1 holds the
## sight closed near the player and opens it late, which is what a weapon that is
## only loose at real range wants.
@export_range(0.1, 6.0, 0.05) var spread_curve: float = 1.6
## How quickly the pieces slide to where the spread says they belong, in the usual
## exponential-smoothing units. High enough to feel immediate, low enough that a
## flick of the mouse does not snap them.
@export var spread_speed: float = 22.0

@export_group("Colour")
## What the sight is normally, before [member ready_colour] and
## [member not_ready_colour] below are blended over it. Kept as a fallback for
## a weapon that never answers [method CarriedWeapon.is_ready_to_fire] at all -
## every weapon in the game does, so this is not ordinarily seen - and for
## whatever share of the two firing colours below happens to be left over.
@export var normal_colour := Color(1.0, 0.66, 0.0)
## What it becomes while the weapon is charged. Only a weapon that has a charge
## ever shows it - see [RevolverSpin] - so for the others this is simply unused.
@export var charged_colour := Color(1.0, 0.11, 0.05)
## How quickly the sight crosses between the two, in the same smoothing units.
## Low, because the charge fading back is meant to be seen as a fade.
@export var charge_fade_speed: float = 6.0

@export_group("Readiness")
## What the sight is while the weapon could actually fire right now. Red by
## default - see [method CarriedWeapon.is_ready_to_fire], which is the one
## thing this is read against. Never the fire key having been pressed.
@export var ready_colour := Color(1.0, 0.12, 0.05)
## What the sight is while it could not - a spent shotgun waiting on the pump,
## an empty top chamber, a lever still down. Yellow by default.
@export var not_ready_colour := Color(1.0, 0.82, 0.05)
## How quickly the sight crosses between the two above, in the same smoothing
## units as [member charge_fade_speed]. High enough that pulling the trigger
## reads as an immediate colour change rather than a lingering fade.
@export var readiness_fade_speed: float = 16.0

@export_group("Outline")
## How far the outline is thrown out behind the sight, in pixels.
##
## [b]It is for reading the sight against the ground, not for restyling it.[/b] The
## desert is pale and busy and a yellow sight can vanish into it; a hairline of dark
## behind the artwork separates the two without the sight becoming a dark shape or
## its colour changing at all. One pixel is what this wants - much more and the
## outline starts being the thing the player sees. 0 turns it off.
@export var outline_thickness: float = 1.0
## What that hairline is. Near-black and slightly soft, so it reads as a shadow under
## the sight rather than as a second drawing around it.
@export var outline_colour := Color(0.0, 0.0, 0.0, 0.85)

@export_group("Ammo readout")
## Whether the count of what is actually in the weapon is drawn beside the sight.
## Off for a weapon whose magazine is not a number the player should be tracking at
## the crosshair - and for one that has no magazine to report.
@export var ammo_shown: bool = true
## Where that number sits relative to the middle of the sight, in pixels. Down and to
## the right, so it reads as hanging off the sight rather than as part of it, and so
## it never covers what is being aimed at.
@export var ammo_offset := Vector2(15.0, 9.0)
## How large it is drawn. Deliberately small: it is an indicator glanced at, not a
## readout, and the counter on the HUD is still where the player looks to actually
## count. A weapon whose magazine matters less can say less by saying it smaller.
@export var ammo_font_size: int = 20
## What colour it is. The weapon's own, so the number belongs to the sight it is
## beside; the alpha is what holds it back from competing with it.
@export var ammo_colour := Color(1.0, 0.66, 0.0, 0.9)

@export_group("Fire flash")
## What the sight is blown out to as the weapon fires, as a multiplier on
## whichever colour it is currently showing. The flash is the weapon's own colour
## turned up, never a different one.
@export var flash_gain: float = 2.4
## How long the flash lasts, in seconds. Tiny on purpose: it must be gone before
## the player has finished seeing it.
@export var flash_time: float = 0.06
## How much wider the sight is thrown as it flashes, in pixels. 0 flashes the
## colour alone.
@export var flash_kick: float = 4.0
