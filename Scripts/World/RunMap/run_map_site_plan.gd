class_name RunMapSitePlan
extends Resource
## What one kind of place is worth on a run map: how many of it a run gets, and
## how much room it wants around it.
##
## [b]This is the whole of the node distribution, and it is data.[/b] One of
## these per kind of place goes into a map's own
## [member RunMapGenerator.site_plans], and the generator reads nothing else to
## decide what is where: it takes the guaranteed counts, fills the rest of the
## map by [member weight], and places each one by the spacing rules below.
## Adding a thirteenth kind of place to the desert is a [code].tres[/code] here
## and a matching [RunMapSiteKind] for the art - no threshold, branch or name in
## any script.
##
## [b]A count is either promised or drawn.[/b] [member exact_count] promises a
## number outright - the one final boss, the three bounties - and takes no part
## in the weighted draw. Everything else promises [member min_count] and then
## competes for whatever the map has left over, up to [member max_count]. That
## split is what makes a run vary without ever coming out short of the places a
## run needs.

## The handle written onto the sites this plan claims - matched against
## [member RunMapSiteKind.kind] for the art, and against whatever node event
## answers arrivals there. See [member RunMapSite.kind].
@export var kind: StringName = &""

@export_group("How many")
## An exact number of this kind, whatever size the map came out. -1 - the
## default - leaves the count to [member min_count], [member max_count] and
## [member weight] below. [b]This is the whole of "exactly three bounties".[/b]
@export var exact_count: int = -1
## The fewest of this kind a run is guaranteed, placed before the map is filled.
## Ignored when [member exact_count] is set.
@export var min_count: int = 0
## The most of this kind a run may have. -1 is no cap, which is what the common
## filler kinds want. A cap is what keeps a kind appearing regularly without
## appearing excessively.
@export var max_count: int = -1
## This kind's share of whatever the map has left after every guarantee is met.
## Relative to every other plan's, so doubling one number halves everyone else's
## share rather than meaning anything on its own. 0 takes no part in the fill, so
## a kind with a guarantee and no weight appears exactly as often as it is
## promised and never more.
@export var weight: float = 0.0
## Whether this plan takes the northernmost point on the map rather than being
## placed among the rest. [b]The final boss, and nothing else[/b] - the point at
## the far end of the map is one site and the first plan flagged here claims it.
@export var claims_northernmost: bool = false

@export_group("Where")
## Which spacing band this kind shares. Two points whose plans name the same
## group prefer to sit [member RunMapGenerator.spacing_target] apart - neither
## side by side nor at opposite ends of the map. Left empty the kind is placed
## freely, which is what the common filler kinds want.
@export var spacing_group: StringName = &""
## Whether this kind counts as a high-value place for the anti-clustering rule,
## so several of them cannot land in the same small corner of the map even when
## their plans name different [member spacing_group]s. See
## [member RunMapGenerator.cluster_radius].
@export var is_special: bool = false
## Which stretch of the map this kind may appear in, as a fraction of the way
## from the start to the boss - (0, 1) is anywhere, (0.3, 1) keeps a kind out of
## the opening rows. A band no point falls inside is ignored rather than
## enforced, so a short map still places everything it promised.
@export var row_band: Vector2 = Vector2(0.0, 1.0)
