class_name BlackPowder
extends Resource
## A shot that leaves a cloud of blood-tinted smoke behind it - the part behind the
## shotgun's Legendary BLACK POWDER.
##
## [b]It adds no enemy AI of its own.[/b] The weapon only decides when a shot is a
## smoke shot - see [member cooldown] - and drops [member smoke_scene] where its
## holder stands. What the smoke does to the fight is the holder's [PlayerStealth],
## which reads the numbers below off the cloud the player is hiding in and steers the
## enemies through the one destination hook they already have for going somewhere
## other than the player - see [code]begin_investigation()[/code] in
## [code]enemy.gd[/code].
##
## A weapon reads it off [member WeaponStats.black_powder] - put there by a
## [WeaponLegendary] - and every value is read at the moment it is needed, so
## retuning it in the Inspector is felt on the next shot or the next frame.

@export_group("Cooldown")
## Seconds between two smoke shots. The first shot once this has run out makes the
## smoke; a shot before then is an ordinary shot and leaves the wait as it was.
@export var cooldown: float = 6.0

@export_group("Smoke")
## The cloud left where the holder fired from - see [BlackPowderSmoke].
@export var smoke_scene: PackedScene
## Radius of the cloud, in pixels. The player hides while inside it.
@export var smoke_radius: float = 150.0
## Radius, in pixels, inside which the player counts as hidden - a little wider than
## the smoke drawn, so standing near its soft edge still hides them. Only where the
## player hides; the cloud is drawn from [member smoke_radius] whatever this is.
@export var stealth_radius: float = 190.0
## Seconds the cloud lasts from the shot until it has gone - its thinning out at the
## end included.
@export var smoke_duration: float = 4.5
## How far behind the holder, in pixels, the cloud's middle is set down - straight
## back from where the shot was aimed, so the player stands in its front half. Keep
## it under [member stealth_radius] or the player starts outside their own smoke.
@export var smoke_back_offset: float = 100.0

@export_group("Perception")
## How close, in pixels, an enemy has to be to make out a player hidden in the smoke.
## Only enemies this close find them; everyone else goes on what they last knew.
@export var close_detection_radius: float = 80.0
## Seconds between two marks of a nearby enemy making out the hidden player.
@export var detection_mark_interval: float = 0.3
## How far, in pixels, a shot fired from inside the smoke is heard. Below 0 it is
## heard by every enemy in the fight.
@export var hearing_radius: float = -1.0

@export_group("Search")
## What an enemy's walk is multiplied by while it goes to look at a place rather
## than at the player.
@export_range(0.0, 2.0, 0.01) var investigate_speed_multiplier: float = 0.85
## How far, in pixels, from the place it was sent to an enemy wanders while it looks
## round, once it has got there.
@export var search_radius: float = 60.0
## How close, in pixels, counts as having reached where it was going.
@export var arrive_distance: float = 14.0

@export_group("HUD")
## What the readout in the corner calls it.
@export var hud_name: String = "BLACK POWDER"
## Shown after the name once the next shot will make smoke.
@export var ready_text: String = "READY"
## Shown after the name while it is waiting, with the seconds left.
@export var cooldown_format: String = "%.1f"


## Where the cloud of a shot fired from [param holder_position] along [param aim]
## goes: [member smoke_back_offset] straight back from the aim.
func smoke_point(holder_position: Vector2, aim: Vector2) -> Vector2:
	if aim.is_zero_approx():
		return holder_position
	return holder_position - aim.normalized() * smoke_back_offset


## The readout for [param time_left] seconds still to wait.
func label_for(time_left: float) -> String:
	if time_left <= 0.0:
		return "%s  %s" % [hud_name, ready_text]
	return "%s  %s" % [hud_name, cooldown_format % time_left]


## Drops a cloud at [param point] under [param container] and hands it back, or null
## with no [member smoke_scene].
func release(container: Node, point: Vector2) -> Node2D:
	if smoke_scene == null or container == null:
		return null
	var cloud := smoke_scene.instantiate() as Node2D
	if cloud == null:
		return null
	if cloud.has_method(&"configure"):
		cloud.call(&"configure", self)
	container.add_child(cloud)
	cloud.global_position = point
	return cloud
