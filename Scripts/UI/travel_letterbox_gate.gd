extends Node
## Keeps [TravelLetterbox] framed for as long as the player is standing on the
## World Map, and clears it again the moment they leave it - the "permanent
## while travelling, gone everywhere else" half of the letterbox's state
## rules. Built the same way [code]world_map_hud_gate.gd[/code] and
## [code]world_map_visibility_gate.gd[/code] already gate their own piece of
## the World Map's HUD: by asking the World Map's own [WorldZone] whether the
## player is inside it, rather than a mechanism of its own.
##
## [b]It listens rather than polls.[/b] [signal WorldZone.player_entered] and
## [signal WorldZone.player_exited] already fire exactly on the crossing this
## cares about, so there is nothing to gain from re-reading
## [method WorldZone.is_player_inside] every frame the way a purely visual gate
## does - the letterbox only ever needs to react once, on the frame the player
## actually crosses the line.
##
## [b]It never touches the bars while a scripted transition owns them.[/b]
## [method TravelLetterbox.is_transitioning] is asked before every call this
## makes. Without that guard, the World Map → Arena hand-off - which moves the
## player clean out of the World Map's own [WorldZone] rectangle before
## [method TravelLetterbox.play_destination_reveal] has even begun - would read
## as "the player left the World Map" and snap the bars away out from under a
## loading screen [WorldMapCombatBridge] is deliberately still holding up. The
## scripted sequence is always left to finish what it started; this gate only
## ever picks the bars back up once nothing else is driving them.
##
## [b]A destination that never moves the player out of the World Map's
## rectangle will not see this gate bring the bars back on its own[/b] - there
## is no exit-then-entry crossing for it to react to, since
## [signal WorldZone.player_exited] and [signal WorldZone.player_entered] only
## ever fire on an actual crossing. [WorldMapCombatBridge] never hits this,
## because opening and closing a fight always relocates the player into and
## back out of the Arena; a future destination built to stay put - a Tavern or
## a Market menu opened in place, say - should call
## [method TravelLetterbox.show_letterbox] itself when it closes, the same way
## it would have called [method TravelLetterbox.play_loading_transition] and
## [method TravelLetterbox.play_destination_reveal] to open.

## The World Map's own [WorldZone].
@export var zone_id: StringName = &"world_map"
## The letterbox this gates. Defaults to this node's own parent, the ordinary
## case - the gate sitting as a child of the bars it controls, the same
## arrangement [code]world_map_hud_gate.gd[/code] uses for its own target.
@export var letterbox_path: NodePath = ^".."

var _letterbox: TravelLetterbox
var _zone: WorldZone


func _ready() -> void:
	_letterbox = get_node_or_null(letterbox_path) as TravelLetterbox
	# Deferred so this still finds the World Map's own [WorldZone] whatever
	# order the world's nodes happen to ready in - the same reason
	# [WorldMapDestination] defers its own lookup of the player's [Teleporter].
	call_deferred(&"_wire_zone")


func _wire_zone() -> void:
	_zone = WorldZone.get_by_id(self, zone_id)
	if _zone == null:
		return
	if not _zone.player_entered.is_connected(_on_player_entered):
		_zone.player_entered.connect(_on_player_entered)
	if not _zone.player_exited.is_connected(_on_player_exited):
		_zone.player_exited.connect(_on_player_exited)
	# The player may already be standing in the zone by the time this wires
	# up - a run that opens straight onto the World Map, say - in which case
	# neither signal will ever fire for a crossing that already happened.
	if _zone.is_player_inside():
		_on_player_entered()


func _on_player_entered() -> void:
	if _letterbox == null or _letterbox.is_transitioning():
		return
	_letterbox.show_letterbox()


func _on_player_exited() -> void:
	if _letterbox == null or _letterbox.is_transitioning():
		return
	_letterbox.hide_letterbox()
