class_name Camp
extends ArenaPortal
## The tent that goes up when the round ends: where the player patches themselves
## up, buys shells, and decides whether to ride out again, travel, or go home.
##
## [b]It is the round-end portal, wearing different clothes.[/b] It extends
## [ArenaPortal] rather than reimplementing it, so everything about [i]when[/i] the
## way out of a round appears is unchanged and lives in one place: the clock
## stopping, the arena emptying, the beat afterwards, the growing, the region the
## thing is allowed to appear in and the reach test against the player. A camp is
## an arena portal that looks like a tent and opens the [CampMenu] instead of the
## shop.
##
## [b]Holding rather than tapping is not this file's doing either.[/b] Making camp
## is meant to be a decision - the menu behind it ends the round one way or the
## other - so it costs a moment of standing still rather than a keypress that
## could be an accident on the way past. That is [member ArenaPortal.hold_seconds],
## set to 0.9 on the camp's own scene: the mechanism lives on the portal so that
## the [HorseCart] at the far end of a travel map can be held in exactly the same
## way, drawn by exactly the same [CampPrompt], without a second copy of it
## existing.
##
## What is left here is only what makes a camp a camp: the group the HUD's prompt
## and the travel systems find it by, and nothing else.

## Emitted as the player sets out looking for trouble, and again when that search is
## called off. [b]Nothing listens yet[/b] - the encounter itself belongs to the danger
## system - so these are the seam that system will be hung off rather than anything
## this file acts on.
signal trouble_search_started
signal trouble_search_ended
## Emitted when the player calls the horse back - the moment the key is pressed, not
## the moment anything arrives. The animal is still minutes away at this point; see
## [signal horse_arrived].
signal horse_called
## Emitted as the waggon comes to a stop beside the player and this becomes the camp
## again. [b]This is the end of a search for trouble[/b]: the horse is back, the
## waggon is standing somewhere new, and everything the camp does works again.
signal horse_arrived

## Group the camp joins, so the HUD's prompt can find it without a path across the
## scene - the camp is in the world and the prompt is on the HUD.
const CAMP_GROUP := &"camp"

@export_group("Search for trouble")
## What the hint in the corner says while the waggon is standing where the player left
## it and can simply be used.
@export var camp_prompt_text: String = "Hold \"E\" at the wagon"
## What it says once the player has gone looking for trouble and the waggon has to be
## sent for - see [method call_horse].
##
## [b]That one is a tap rather than a hold[/b], because calling the horse is not a
## decision being weighed the way making camp is - there is nothing else to do at that
## point. See [method uses_hold].
@export var call_horse_prompt_text: String = "E - CALL HORSE"
## Whether the waggon goes with the horse. On, it is taken off the field for as long
## as the animal is away, which is what makes calling it back an arrival rather than
## a switch being flicked on something that was standing there the whole time.
@export var hides_while_away: bool = true
## Whether the horse can be called from anywhere while it is away, rather than only
## from where the waggon used to stand.
##
## [b]On, and it has to be.[/b] The waggon is not there to walk up to - it left with
## the horse - so the key that calls it cannot be tied to a circle round a thing that
## is not on the field. Off restores the older behaviour, where the player had to
## return to the spot to whistle.
@export var call_from_anywhere: bool = true

@export_group("Coming back")
## How long the horse takes to arrive once it has been called, in seconds: the
## shortest wait and the longest, rolled per call.
@export var call_delay_range := Vector2(3.0, 6.0)
## How far off the side of the map it comes in from, in pixels. Comfortably beyond
## the edge of the view, so it is seen to arrive rather than to appear.
@export var arrival_distance: float = 1500.0
## How long the ride in takes, in seconds.
@export var arrival_time: float = 2.4
## How far beside the player it stops, in pixels, and how far up or down the screen
## - so it parks alongside them rather than on top of them.
@export var park_gap: float = 210.0
@export var park_lift: float = 40.0
## The waggon's own sprite, flipped to face the way it is travelling. Optional.
@export var cart_sprite_path: NodePath = ^"Art/Cart"

## Whether the player is out looking for trouble. Set by [CampMenu].
var _searching: bool = false
## Whether the waggon has to be sent for before it can be used again.
var _horse_away: bool = false
## Whether the horse has been called and is on its way. The waggon is neither usable
## nor callable while this is true, which is what stops a second whistle stacking two
## arrivals.
var _calling: bool = false
var _arrival_tween: Tween


func _ready() -> void:
	super()
	add_to_group(CAMP_GROUP)


## The camp the HUD should follow. Null means this world has none - a map with no
## camp in it, or one being looked at in the editor - which every caller reads as
## "there is nothing to prompt for".
static func get_active_camp(from_node: Node) -> Camp:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(CAMP_GROUP) as Camp


## Whether a journey is under way - the horse sent for, the road being ridden, or
## an ambush or gang being dealt with.
##
## The camp is asked this rather than told, because a journey is not a thing that
## happens to the camp: it is a state of the run, and [TravelDirector] is where it
## is already kept. A world with no director in it has no journeys to be in the
## middle of.
func is_journey_under_way() -> bool:
	var director := TravelDirector.get_active(self)
	return director != null and director.is_journey_under_way()


## Whether the player is asleep at this camp.
##
## The camp is asked this rather than told, exactly as it is about a journey: a night
## is not a thing that happens to the waggon, it is a state of the run, and
## [SleepDirector] is where it is already kept. A world with no sleep system in it has
## no nights to be in the middle of.
func is_sleeping() -> bool:
	var director := SleepDirector.get_active(self)
	return director != null and director.is_sleeping()


## [b]The camp cannot be used while the player is travelling, nor while they are
## asleep beside it.[/b]
##
## The road is not a separate world - an ambush is fought in the arena the player
## rode out of, with the camp still standing in it - so without this the player
## could walk back to the tent mid-journey and make camp again in the middle of a
## fight, or press TRAVEL on a ride that is already happening.
##
## It is done by refusing the [i]reach[/i] rather than by refusing the menu, and
## that covers everything at once: [ArenaPortal] drives its hold, its key and its
## prompt off this one answer, so the "hold E" hint drops away as the journey
## starts, the hold cannot build, and neither a tap nor [method ArenaPortal.use]
## can open anything. Coming off the road restores all of it with nothing to
## remember to put back.
func is_in_reach(body: Node2D) -> bool:
	# The night is refused here rather than on the menu, and that is what makes HEAL,
	# AMMO, WEAPONS, TRAVEL and TROUBLE unreachable while the player is lying down:
	# they are all buttons on a panel that cannot be opened, because [ArenaPortal]
	# drives its hold, its key and its prompt off this one answer. Getting up restores
	# every one of them with nothing to remember to put back.
	if is_journey_under_way() or is_sleeping():
		return false

	# While the horse is away the key is not "use the waggon" but "send for it", and
	# there is no waggon standing there to walk up to - so the reach is the whole map
	# rather than a circle round an empty patch of desert. It is still refused while
	# the search itself is unfinished, which is what keeps the player from whistling
	# the animal in over their own Danger or their own reward.
	if _horse_away and call_from_anywhere:
		if _calling or not can_call_horse():
			return false
		return is_open() and body != null and body.is_in_group(body_group)

	return super(body)


## The same refusal, made again at the point of use.
##
## [b]It is not redundant.[/b] The reach above is a live test, but the portal acts
## on a [i]cached[/i] answer that is only refreshed from
## [method Node._process] - and a frozen tree does not run it, so a journey that
## begins while the player is standing at the tent leaves that cache reading "in
## reach" for as long as the world stays paused. Gating the reach alone would still
## let anything calling this directly open the camp mid-ride.
func use() -> void:
	if is_journey_under_way() or is_sleeping():
		return
	# The one key does whichever of its two jobs the waggon's state calls for. While the
	# horse is away there is no camp to open at all - see [method call_horse].
	if _horse_away:
		call_horse()
		return
	super()


# --- Searching for trouble ------------------------------------------------------

## Whether the player is out looking for trouble.
func is_searching_for_trouble() -> bool:
	return _searching


## Sets the player looking for trouble, and reports whether the search actually began.
##
## [b]It starts a state and nothing else.[/b] There are no danger waves, no chest and
## no move of the waggon in this milestone - what the search does is send the horse
## away, so that the way back to the camp is the player calling it, and announce itself
## for the system that will later hang the encounter off [signal trouble_search_started].
##
## Refused while a journey is under way, for the same reason the camp itself is: the
## player cannot be riding somewhere and looking for trouble at once.
func begin_trouble_search() -> bool:
	if _searching or is_journey_under_way():
		return false

	_searching = true
	_horse_away = true
	# The waggon leaves with the animal. Nothing about where it stood is remembered,
	# because it does not come back there - it comes back to wherever the player is
	# standing when they call it. See [method call_horse].
	if hides_while_away:
		visible = false
	trouble_search_started.emit()
	return true


## Calls the search off without the horse having been sent for. What a later system
## does when a search cannot be run at all; nothing in the game calls it yet.
func end_trouble_search() -> void:
	if not _searching:
		return
	_searching = false
	trouble_search_ended.emit()


# --- Calling the horse ----------------------------------------------------------

## Whether the waggon has to be sent for before it can be used.
func is_horse_call_pending() -> bool:
	return _horse_away


## Whether the horse can be sent for right now.
##
## [b]Not while there is still trouble to finish.[/b] A search that is still running,
## and the ending that follows it - the chest falling, the chest standing
## uncollected, the walk back - all hold the whistle off, so the animal cannot be
## called in over the player's own reward. Both are asked of the systems that own
## them rather than mirrored here, and a world with neither simply always allows it.
func can_call_horse() -> bool:
	if not _horse_away or _calling:
		return false

	var danger := DangerDirector.get_active(self)
	if danger != null and danger.is_running():
		return false

	var reward := TroubleRewardDirector.get_active(self)
	if reward != null and reward.is_busy():
		return false

	return true


## Whether the horse is on its way in.
func is_horse_arriving() -> bool:
	return _calling


## Sends for the horse, and reports whether one was sent for.
##
## [b]It is the whistle, not the arrival.[/b] The animal is somewhere out in the
## country: it takes between the two ends of [member call_delay_range] to reach the
## player, comes in from whichever side the roll picked, and only when it has pulled
## up beside them is the camp handed back - see [method _arrive]. Until then the
## waggon is neither usable nor callable again.
func call_horse() -> bool:
	if not can_call_horse():
		return false

	_calling = true
	horse_called.emit()

	var low := minf(call_delay_range.x, call_delay_range.y)
	var high := maxf(call_delay_range.x, call_delay_range.y)
	var wait := randf_range(maxf(low, 0.0), maxf(high, 0.0))
	# Process-always and in real time, so the wait still passes through anything that
	# freezes the world or slows it down while the player stands about.
	var timer := get_tree().create_timer(maxf(wait, 0.0), true, false, true)
	timer.timeout.connect(_ride_in)
	return true


## The waggon comes in from one side or the other and pulls up alongside the player.
##
## [b]There is no horse node and no horse artwork.[/b] The waggon [i]is[/i] the
## placeholder - it is the same [code]horse_cart[/code] sprite the travel screen
## draws and the same node that has always been the camp - so nothing new is drawn
## and nothing has to be handed over when the real animal is made: the arrival is a
## position being driven, and the thing being driven is already the camp.
func _ride_in() -> void:
	if not is_inside_tree() or not _calling:
		return

	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	if body == null:
		# Nobody to pull up beside. The waggon is simply handed back where it stands,
		# so a world with no player can never be left without a camp.
		_arrive()
		return

	var side := 1.0 if randf() < 0.5 else -1.0
	var park := _park_spot(body, side)

	global_position = park + Vector2(side * maxf(arrival_distance, 0.0), 0.0)
	visible = true
	# Physics interpolation is on project-wide; without this the waggon is smeared in
	# from wherever it was standing before it was put out on the edge of the map.
	reset_physics_interpolation()
	_face_travel(side)

	if _arrival_tween != null and _arrival_tween.is_running():
		_arrival_tween.kill()
	_arrival_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_arrival_tween.tween_property(self, "global_position", park, maxf(arrival_time, 0.0001))
	_arrival_tween.tween_callback(_arrive)


## Where it pulls up: alongside the player, on the side it came in from.
##
## The spot is held inside [member ArenaPortal.open_region] - the same rectangle that
## decides where the camp may open in the first place - but [b]only when the player is
## themselves inside it[/b]. Somebody standing outside the arena entirely, which a
## death out looking for trouble leaves them, would otherwise have their waggon
## clamped to the far edge of a map they are not on; beside them is the right answer
## everywhere, and the clamp is only there to keep it out of the walls.
func _park_spot(body: Node2D, side: float) -> Vector2:
	var park := body.global_position + Vector2(side * park_gap, park_lift)
	if _has_region() and open_region.has_point(body.global_position):
		return _clamped_to_region(park)
	return park


## Which way the waggon is pointing as it comes in. The sprite's own flip, so it is
## one property rather than a second set of artwork.
## [param side] is the side it came in from, so it is travelling the other way. The
## artwork is drawn facing left - the horse is at the left of the cart - so a waggon
## coming in from the left, and therefore travelling right, is the flipped one.
func _face_travel(side: float) -> void:
	var sprite := get_node_or_null(cart_sprite_path) as Sprite2D
	if sprite != null:
		sprite.flip_h = side < 0.0


## It has stopped. [b]This spot is the camp now[/b] - the waggon was not moved back to
## where it used to be, it was driven to where the player is standing - and with it
## the whole of the trouble state goes: the search is over, the horse is home, and
## every camp action works again.
func _arrive() -> void:
	_calling = false
	_horse_away = false
	visible = true

	if _searching:
		_searching = false
		trouble_search_ended.emit()

	horse_arrived.emit()


## Calling the horse is a tap; making camp is still a hold. The hold belongs to the
## decision rather than to the key, and there is no decision in sending for the waggon.
func uses_hold() -> bool:
	if _horse_away:
		return false
	return super()


## What the hint in the corner should say, which depends on which of its two jobs the
## key is currently doing. Read by [CampPrompt], so the two can never disagree.
func get_prompt_text() -> String:
	return call_horse_prompt_text if _horse_away else camp_prompt_text
