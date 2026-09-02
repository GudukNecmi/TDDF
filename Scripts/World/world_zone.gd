class_name WorldZone
extends Node2D
## A rectangle of the world that plays by its own rules.
##
## The arena and the base are not separate scenes - they are two places a couple
## of thousand pixels apart in the same one - so "being in the base" is not a
## state anything can be told about, it is a position. This node is that fact
## written down once: a rectangle, and what is true inside it.
##
## Everything a zone changes is *asked for* rather than done to somebody. The
## world's ambient [CanvasModulate] is blended towards [member ambient_colour],
## the shared [CameraController] is handed a resting zoom multiplier through its
## own [method CameraController.set_zoom_multiplier], and anything that cares
## whether the player should be armed or patched up reads the flags below off
## whichever zone reports them inside it. None of those systems know this class
## exists, and a world with no zones behaves exactly as it did before there were
## any.
##
## Both the darkness and the camera are eased rather than switched, so crossing
## into the base is a place closing in and going dark rather than a cut. The
## ambient light is only written to while the blend is actually somewhere between
## the two colours, which is what keeps a zone from holding the world's darkness
## hostage the whole time the player is nowhere near it.

## Emitted as the player crosses into the zone.
signal player_entered
## Emitted as they leave it.
signal player_exited

## Group every zone joins, so [method get_zone_for] can find them all without
## anything being wired to any of them.
const GROUP := &"world_zone"

## What this place is. Never shown to the player - it is the handle a system uses
## to ask for one particular zone.
@export var zone_id: StringName = &"zone"
## The zone's rectangle, in this node's own local space.
@export var region := Rect2(-1150.0, -1470.0, 2300.0, 1850.0)
## Only bodies in this group can be in a zone.
@export var body_group: StringName = &"player"

@export_group("Atmosphere")
## Whether the zone touches the world's ambient light at all.
@export var affects_ambient: bool = true
## Group the world's ambient [CanvasModulate] is found in. One node lights the
## whole canvas, so the zone borrows it rather than adding a second one - two
## would simply cancel each other out.
@export var ambient_group: StringName = &"ambient_modulate"
## The zone's own dim, atmospheric colour - what the ambient light is mixed
## down towards while the player is in here. Darker than the world's own
## colour makes the zone darker.
##
## This dims the *unlit* world only: every light inside the zone is untouched, so
## the torches, the pit and the player's own lamp keep their brightness and the
## place reads as lit by them rather than as a screen turned down.
@export var ambient_colour := Color(0.06, 0.055, 0.09)
## How much of the current day colour's own hue and brightness still reaches
## the zone once the player is fully inside it, 0 to 1. 0 replaces the day
## outright with [member ambient_colour] and never moves again regardless of
## the hour - which is what used to leave a moody interior's own atmosphere
## disagreeing with the HUD's reading of the hour the instant the blend had
## landed. 1 lets the day back through entirely and the zone stops darkening
## the room at all. The low default keeps the room reading as the same dim,
## authored place at every hour while still letting dawn, noon and night
## visibly tint it differently, exactly the way [SunController]'s own shadows
## never stop moving just because a room is dim.
@export_range(0.0, 1.0) var ambient_day_influence: float = 0.35
## How quickly the ambient light crosses between the two colours.
@export var ambient_blend_speed: float = 2.2
## Whether the colour the zone blends *away* from is asked of the map's
## [DayCycleDirector] every frame rather than captured off the [CanvasModulate]
## the first time the player walks in.
##
## This is what keeps the world's darkness and the time of day the HUD is showing
## the same thing. Capturing the colour meant the zone took a snapshot of whatever
## was on the modulate at that instant - which could be another zone's blend, or
## the colour the scene was authored with before the hour had been applied - and
## then held the whole world to that snapshot for the rest of the visit, leaving
## the darkness on one hour while the readout said another.
##
## Off falls back to the captured colour, for a zone in a world with no day cycle
## to ask.
@export var ambient_follows_day_cycle: bool = true
## Whether this zone shows [DayCycleDirector]'s own continuous blend of the
## current hour - [method DayCycleDirector.get_world_time_ambient_colour] -
## for as long as the player stands in it, instead of blending towards
## [member ambient_colour] on the way in and away from it on the way out.
##
## This is what the World Map's own zone wants and no other zone does: the
## base and the tutorial map are places whose own darkness the day does not
## reach, so they still blend to their one authored colour, but the World Map
## is the day itself and had nothing continuously repainting it before this -
## [DayCycleDirector] only ever wrote its ambient once, as the world loaded,
## or when the old round-based clock announced a stage change, so the map's
## own hour kept turning underneath a colour that had stopped following it.
@export var follows_world_time: bool = false
## The continuous clock read while [member follows_world_time] is on - the
## same [code]WorldClock[/code] autoload [SunController] already follows.
@export var world_time_path: NodePath = ^"/root/WorldClock"

@export_group("Camera")
## Whether the zone moves the camera's resting zoom.
@export var affects_camera: bool = true
## Where the camera rests while the player is in here, as a multiplier on the
## camera's authored zoom. Above 1 is closer: 1.3 is 30% closer than the arena.
## Every camera effect - shake, the shotgun's punch, the teleport - still rides
## on top of it untouched.
@export var camera_zoom_multiplier: float = 1.3

@export_group("Rules")
## Whether weapons are put away in here. Read by [PlayerLoadout]; this node never
## touches a weapon itself.
@export var holster_weapons: bool = true
## Whether arriving here patches the player up. Read by [ZoneHealer]; this node
## never touches a health pool itself.
@export var heals_player: bool = true
## Whether enemies are allowed here at all. Read by [ZoneEnemyGuard], which stops
## the run's spawning and finishes off anything standing when the player crosses
## in, and removes any enemy that gets inside the rectangle afterwards. This node
## never touches an enemy itself.
@export var bars_enemies: bool = true
## Whether a weapon in here is inert - read by [CarriedWeapon], which simply
## never dispatches an input event to its own [method CarriedWeapon._weapon_input]
## while it is true. Distinct from [member holster_weapons]: that puts the
## weapon away at the belt, and a presentation that wants it visibly carried -
## the World Map, riding rather than fighting - can leave it drawn and still
## have this refuse to fire it. [GameCursor] reads the same flag to decide
## whether the pointer belongs up instead of the sight, for the same reason it
## already gives the pointer to an unarmed player: a sight for a gun that
## cannot fire is exactly that same lie.
@export var blocks_weapon_fire: bool = false

var _inside: bool = false
var _amount: float = 0.0
var _outside_colour := Color.WHITE
var _captured_outside: bool = false
var _ambient: CanvasModulate


func _ready() -> void:
	add_to_group(GROUP)


## The zone [param body] is standing in, or null when it is in none of them -
## which every caller reads as "the ordinary rules apply".
static func get_zone_for(from_node: Node, body: Node2D) -> WorldZone:
	if from_node == null or not from_node.is_inside_tree() or body == null:
		return null

	for node: Node in from_node.get_tree().get_nodes_in_group(GROUP):
		var zone := node as WorldZone
		if zone != null and zone.is_inside(body):
			return zone
	return null


## The zone with [param wanted], wherever the player happens to be.
static func get_by_id(from_node: Node, wanted: StringName) -> WorldZone:
	if from_node == null or not from_node.is_inside_tree():
		return null

	for node: Node in from_node.get_tree().get_nodes_in_group(GROUP):
		var zone := node as WorldZone
		if zone != null and zone.zone_id == wanted:
			return zone
	return null


## The zone's rectangle in world space.
func get_world_region() -> Rect2:
	return Rect2(global_position + region.position, region.size)


## Whether [param body] is standing in here. Anything not in [member body_group]
## never is, so an effect that wandered across the map cannot claim the zone.
func is_inside(body: Node2D) -> bool:
	if body == null or not body.is_in_group(body_group):
		return false
	return get_world_region().has_point(body.global_position)


## True while the player is in here.
func is_player_inside() -> bool:
	return _inside


func _process(delta: float) -> void:
	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	var inside := is_inside(body)
	if inside != _inside:
		_inside = inside
		_push_camera()
		if _inside:
			player_entered.emit()
		else:
			player_exited.emit()

	_blend_ambient(delta)


## The camera is pushed on the crossing rather than every frame, so two zones can
## never end up arguing over it frame by frame and whatever else has taken the
## camera - a death crawling in on the body - keeps it until the player actually
## walks somewhere else.
func _push_camera() -> void:
	if not affects_camera:
		return
	var camera := CameraController.get_active(self)
	if camera == null:
		return
	camera.set_zoom_multiplier(camera_zoom_multiplier if _inside else 1.0)


## Eased towards the zone's colour while the player is in it and back out again
## when they leave. The write is skipped entirely once the blend has landed back
## on nothing, so a zone the player is nowhere near stops touching the world's
## light rather than reasserting the same colour forever.
##
## [b]Also skipped outright while [DayCycleDirector] is holding the ambient
## for something else[/b] - a World Map fight in progress, say. Without this a
## zone only just left keeps easing its own blend down for a couple of seconds
## after the player has gone, and every one of those frames writes straight
## over whatever combat forced onto the same [CanvasModulate] - the zone and
## the fight both think they are the only thing touching it, and only one of
## them is right while the fight holds. [method DayCycleDirector.is_ambient_overridden]
## is the one question that settles who currently is.
func _blend_ambient(delta: float) -> void:
	if not affects_ambient:
		return
	if _ambient_is_held_elsewhere():
		return

	if follows_world_time and _inside:
		_apply_world_time_ambient()
		return

	var goal := 1.0 if _inside else 0.0
	var previous := _amount
	_amount = lerpf(_amount, goal, 1.0 - exp(-maxf(ambient_blend_speed, 0.01) * delta))
	if goal <= 0.0 and _amount < 0.001:
		_amount = 0.0
	if _amount <= 0.0 and previous <= 0.0:
		return

	var ambient := _get_ambient()
	if ambient == null:
		return

	var outside := _get_outside_colour(ambient)
	var target := ambient_colour.lerp(outside, ambient_day_influence)
	ambient.color = outside.lerp(target, _amount)


## The colour outside this zone - what the world looks like when the player is not
## standing in here.
##
## Asked of the map's clock every frame, so it is always the hour actually being
## played and there is no second copy of the time of day kept here to drift out of
## step with the one the HUD reads. A map with no day cycle falls back to the
## colour the [CanvasModulate] was authored with, captured once before the zone has
## touched it - which is what the zone always did.
func _get_outside_colour(ambient: CanvasModulate) -> Color:
	if not _captured_outside:
		_outside_colour = ambient.color
		_captured_outside = true

	if not ambient_follows_day_cycle:
		return _outside_colour

	var day := DayCycleDirector.get_active(self)
	return _outside_colour if day == null else day.get_ambient_colour(_outside_colour)


## Writes [DayCycleDirector]'s own continuous blend of the current hour
## straight onto the shared ambient [CanvasModulate] - see
## [member follows_world_time]. Called every frame the player stands in a
## zone marked for it, so the World Map's darkness turns with
## [WorldTimeManager] exactly as [SunController]'s own shadows already do,
## rather than sitting wherever [DayCycleDirector] last wrote it.
##
## A map with no [DayCycleDirector], or a clock that cannot be found, leaves
## the [CanvasModulate] exactly as it already was - the same "nothing to add"
## every other lookup in this class falls back to.
func _apply_world_time_ambient() -> void:
	var day := DayCycleDirector.get_active(self)
	if day == null:
		return
	var ambient := _get_ambient()
	if ambient == null:
		return
	var clock := get_node_or_null(world_time_path)
	ambient.color = day.get_world_time_ambient_colour(clock, ambient.color)


## Whether something else has claimed the shared ambient [CanvasModulate]
## outright right now. A map with no [DayCycleDirector] at all reads this as
## "no", exactly as [method _get_outside_colour] already falls back when one
## is missing.
func _ambient_is_held_elsewhere() -> bool:
	var day := DayCycleDirector.get_active(self)
	return day != null and day.is_ambient_overridden()


## Looked up lazily and re-looked-up if it goes away, the same way [BloodField]
## and [CameraController] are found - the modulate may enter the tree after this.
func _get_ambient() -> CanvasModulate:
	if _ambient == null or not is_instance_valid(_ambient):
		_ambient = get_tree().get_first_node_in_group(ambient_group) as CanvasModulate
	return _ambient
