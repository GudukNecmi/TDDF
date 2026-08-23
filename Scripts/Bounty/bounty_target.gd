class_name BountyTarget
extends Resource
## Who the bounty is on: the outlaw whose face is on the poster.
##
## Deliberately only an identity. There is no health, no attack, no scene to
## spawn and no difficulty here, because none of that has been decided yet -
## this milestone builds the board, not the fight. When mini bosses arrive, what
## they are gets added to this resource and every poster already printing a name
## and a face keeps working, because the poster only ever asks for those two.
##
## The roster is an inspector array on [BountySettings], so a new outlaw is a
## [code].tres[/code] file rather than an entry in a script.

## The handle the rest of the game keys off. Never shown.
@export var target_id: StringName = &"target"
## The name on the poster.
@export var display_name: String = "OUTLAW"
## The line under the name - what they are wanted for. Flavour, and the thing
## that makes five posters read as five different people rather than five copies.
@export var crime: String = "MURDER"
## The face. A placeholder silhouette for now; the real artwork drops in here
## without anything else changing.
@export var portrait: Texture2D
