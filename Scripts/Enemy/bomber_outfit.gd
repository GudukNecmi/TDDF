class_name BomberOutfit
extends Resource
## One bomber's colours: the body it wears, the head it wears, and the head it is
## left with once the lamp on it has been smashed.
##
## The three are one resource rather than three parallel arrays because they are
## not independent - a grey hat belongs on a grey body, and the broken lamp has to
## be the same hat as the lit one it replaces. Keeping them together means a fourth
## colourway is one [code].tres[/code] file dropped into
## [member BomberAppearance.outfits] and nothing else, with no chance of the three
## lists drifting out of step.

## The body, worn on the bomber's [code]Visual/Body[/code] sprite.
@export var body: Texture2D
## The head, with its lamp lit, worn while the bomber is alive.
@export var head: Texture2D
## The same head with the lamp smashed, swapped in the moment the head comes off.
## Left unset the head simply keeps its lit artwork, which is what an outfit with
## no broken version authored should look like rather than a missing sprite.
@export var broken_head: Texture2D
