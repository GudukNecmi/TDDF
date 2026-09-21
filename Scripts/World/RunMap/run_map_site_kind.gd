class_name RunMapSiteKind
extends Resource
## What one kind of point on a run map looks like, and what it is called.
##
## [b]Adding a kind of place to the map is dropping one of these into a map's own
## [member RunMapView.site_kinds] array.[/b] Nothing in any script names a kind,
## branches on one or holds a threshold for one: the view looks the piece of art
## up by the handle the site carries and draws whatever it finds, so the twelve
## kinds the desert deals out - the two bandit points, the mini boss, the
## market, the saloon, the treasure, the event, the bounty, the deposit, the
## extraction, the sheriff outpost and the final boss - are twelve
## [code].tres[/code] files and no edit here. Which points get which is the
## matching [RunMapSitePlan] on the map's generator, not this resource. A site
## whose handle is not in the array falls back to the array's
## [member is_fallback] entry, so a half-authored map still draws.

## The handle sites carry - see [member RunMapSite.kind]. Matched exactly.
@export var kind: StringName = &"unknown"
## What the place is called, for the panel beside the map. Left empty the point
## is drawn without a name, which is right for a point whose contents have not
## been learned.
@export var display_name: String = ""
## The picture drawn at the point.
@export var icon: Texture2D
## The picture drawn once the piece has stood here - a camp struck through, a
## market already bought from. Optional: a kind left without one keeps
## [member icon] and is only dimmed, which is what a place worth going back to
## wants.
@export var visited_icon: Texture2D
## How big that picture is drawn, against its own pixel size. The boss is meant
## to read as bigger than an ordinary point from across the map.
@export_range(0.1, 4.0, 0.01) var icon_scale: float = 1.0
## Colour the picture is tinted. White leaves the art as authored.
@export var tint: Color = Color.WHITE
## Whether this entry is what an unrecognised handle is drawn as. The first entry
## with this set wins; a map with none draws nothing for a handle it does not
## know.
@export var is_fallback: bool = false
