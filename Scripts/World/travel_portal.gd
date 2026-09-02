class_name TravelPortal
extends WorldMapLocation
## A Travel Portal - a fast-travel connector between two points of the World
## Map, dressed with [code]res://Scenes/World/ArenaPortal.tscn[/code]'s own
## artwork.
##
## [b]Built on [WorldMapLocation], not a second interaction system.[/b] Every
## World Map point of interest already goes through [WorldMapLocation] +
## [WorldMapLocationDirector] - one shared proximity timer instead of sixty
## independent ones, one shared prompt, the same fog-of-war and occlusion
## rules every camp and depot already follows. A portal is simply a
## [constant MapLocation.LocationType.TRAVEL_PORTAL] location like any other,
## never a copy of [ArenaPortal]'s own older reach-and-prompt loop.
## [method WorldMapLocation.try_interact] - inherited, unchanged - is what
## actually fires [signal WorldMapLocation.location_interacted]; this only
## listens for that same signal and hands the jump to
## [WorldMapTravelService].
##
## [b]The art is borrowed, not the behaviour.[/b] [member portal_art_path]
## points at an instance of [code]ArenaPortal.tscn[/code] with its own
## [code]arena_portal.gd[/code] script cleared on that one instance - see
## [code]TravelPortal.tscn[/code]'s own per-instance override - so its
## [code]Art[/code]/[code]Light[/code] nodes are exactly the "visually
## distinct map-travel entrance" the design asks for, kept alive here by
## [method _process] rather than by anything [code]arena_portal.gd[/code]
## would otherwise do (opening once a [WaveManager] that does not exist on
## the World Map goes quiet). [member WorldMapLocation.icon_path] - the
## inherited placeholder dot every location already draws - is left in
## place too, small and tinted [constant MapLocation.LocationType.TRAVEL_PORTAL]'s
## own colour, since it is what the World Map's own minimap actually reads.
##
## [b]No portal is its own destination's editor.[/b] [member destination]
## only ever names the paired [TravelPortal] this one sends a traveller to;
## building the desert's own chain of them - which portal answers to which -
## is entirely a matter of what each instance's [member destination] is
## pointed at in the World Map scene, never a branch in this file.

## The paired [TravelPortal] a traveller stepping into this one is sent to.
@export var destination: NodePath
## Where a traveller lands, relative to this portal's own position, when
## they arrive [i]through[/i] it - a little clear of the art itself, so
## arriving never stacks them on the portal's own icon or its light.
@export var arrival_offset: Vector2 = Vector2(0.0, 90.0)

@export_group("Art")
## The instanced [code]ArenaPortal.tscn[/code] this portal borrows its visual
## representation from - see the class doc.
@export var portal_art_path: NodePath = ^"PortalArt"
@export var art_path: NodePath = ^"PortalArt/Art"
@export var swirl_path: NodePath = ^"PortalArt/Art/Swirl"
@export var light_path: NodePath = ^"PortalArt/Light"
## How much the portal's art swells and settles as it idles, as a fraction.
@export var pulse_scale: float = 0.06
## Breaths per second.
@export var pulse_speed: float = 1.1
## Turns per second of the swirl - slow, the same unhurried turn
## [code]arena_portal.gd[/code] itself authors for a pool turning over rather
## than a fan.
@export var swirl_speed: float = 0.2
## The light's resting energy and how much it breathes along with the art,
## as a fraction of it.
@export var light_energy: float = 1.6
@export var light_pulse: float = 0.3

var _time: float = 0.0
@onready var _art: Node2D = get_node_or_null(art_path) as Node2D
@onready var _swirl: Node2D = get_node_or_null(swirl_path) as Node2D
@onready var _light: PointLight2D = get_node_or_null(light_path) as PointLight2D


func _ready() -> void:
	super()
	if not location_interacted.is_connected(_on_activated):
		location_interacted.connect(_on_activated)


func _process(delta: float) -> void:
	_time += delta
	if _swirl != null:
		_swirl.rotation += swirl_speed * TAU * delta
	var breath := 1.0 + sin(_time * pulse_speed * TAU) * pulse_scale
	if _art != null:
		_art.scale = Vector2.ONE * breath
	if _light != null:
		_light.energy = light_energy * (1.0 + sin(_time * pulse_speed * TAU) * light_pulse)


## The portal this one is paired with, or null when [member destination]
## points at nothing - which [WorldMapTravelService] reads as "this portal
## goes nowhere yet".
func get_destination() -> TravelPortal:
	return get_node_or_null(destination) as TravelPortal


## Where a traveller arriving [i]through[/i] this portal should be placed -
## see [member arrival_offset].
func get_arrival_position() -> Vector2:
	return global_position + arrival_offset


## Found by group and called by method presence, the same convention every
## other cross-system call in this codebase already follows (see
## [ArenaPortal]'s own [code]menu_path[/code]/[code]"open"[/code] pattern) -
## deliberately never a typed [WorldMapTravelService] reference here, since
## that class in turn needs to name [TravelPortal] itself; two scripts naming
## each other's [code]class_name[/code] is a circular dependency GDScript's
## own class registration cannot always resolve when both are pulled in by
## the same scene load, so neither file names the other's type at all.
func _on_activated() -> void:
	var service := get_tree().get_first_node_in_group(&"world_map_travel_service")
	if service != null and service.has_method(&"travel_through"):
		service.call(&"travel_through", self)
