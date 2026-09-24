class_name RunMapExtractionNode
extends Node
## The run map's EXTRACTION points: arriving on one ends the run and goes home.
##
## [b]Another listener on [signal RunMapDirector.site_reached], built like the
## others.[/b] [RunMapBanditNode], [RunMapBountyBossNode] and [RunMapSaloonNode]
## each hear an arrival and deal with their own kind of point; this one hears an
## arrival on an EXTRACTION point and knows nothing else about the map.
##
## [b]It is not a second extraction.[/b] Everything that extracting actually is -
## the Blood settlement into [code]BloodBank[/code], the bounty rewards and
## penalties, the secured horse and depot Blood, clearing what was carried, and
## the journey to the Base - is [WorldMapExtractionService]'s, and this only
## tells it that the player has reached an Extraction, through
## [method WorldMapExtractionService.extract]. The service standing beside this
## in the run map scene is configured for a scene with no player body - see its
## [code]Run Map[/code] group.
##
## [b]The map's choices are closed as the run ends.[/b] [RunMapDirector] opens
## them again straight after announcing the arrival, so the close is deferred to
## land after it, exactly as [RunMapSaloonNode] does, and nothing is left live
## on the board while the curtain comes down on it.

## Emitted the instant an Extraction point has been handed to the service and
## the service accepted it.
signal extraction_reached(site: RunMapSite)

@export_group("Wiring")
@export var director_path: NodePath = ^"../RunMapDirector"
@export var view_path: NodePath = ^"../RunMapView"
## The extraction service this hands the arrival to.
@export var service_path: NodePath = ^"../WorldMapExtractionService"

@export_group("Which points extract")
## Every handle this node answers. An array, so a second kind of way out is an
## entry here and no edit to this file.
@export var kinds: Array[StringName] = [&"extraction"]

var _director: RunMapDirector
var _view: RunMapView


func _ready() -> void:
	_director = get_node_or_null(director_path) as RunMapDirector
	_view = get_node_or_null(view_path) as RunMapView
	if _director != null and not _director.site_reached.is_connected(_on_site_reached):
		_director.site_reached.connect(_on_site_reached)


## Whether [param kind] is one this node answers.
func answers(kind: StringName) -> bool:
	return kinds.has(kind)


func _on_site_reached(site: RunMapSite) -> void:
	if site == null or not answers(site.kind):
		return
	var service := get_node_or_null(service_path) as WorldMapExtractionService
	if service == null:
		push_warning("RunMapExtractionNode: no extraction service at '%s'." % service_path)
		return
	if not service.extract():
		return
	if _view != null:
		_view.set_picking.call_deferred(false)
	extraction_reached.emit(site)
