class_name TroubleRewardDirector
extends Node
## What a finished search for trouble is worth, and everything between the last
## Danger and the player standing in the desert waiting on a horse.
##
## [b]It owns the ending, not the fighting.[/b] [DangerDirector] runs the Dangers and
## says when a search was [i]finished[/i] rather than merely ended - see
## [signal DangerDirector.search_finished], which a death deliberately never emits -
## and everything after that beat is here:
##
##   [codeblock]
##   STOP / Danger 10 cleared
##     -> a chest falls out of the sky and lands (camera shake, bounce)
##     -> the player walks to it and presses E: blood into their hands, items on the ground
##     -> a beat, and then the word that the country is quiet
##     -> RETURN TO CAMP
##     -> a few seconds of walking behind black
##     -> standing in the world, horse still away, "E - CALL HORSE" offered
##   [/codeblock]
##
## [b]Nothing here decides what a Danger is worth.[/b] That is [member tiers], an
## array of [TroubleRewardTier] resources matched against the deepest Danger
## actually beaten, so the ladder is three files in the inspector rather than a
## table in this script.
##
## [b]And nothing here is a new transition system.[/b] The walk home is the road's
## own screen with the man on foot - the same crossing a Danger is walked to,
## [method TravelLoading.play_titled] - and the word is the two-button screen the
## road asks gangs with, given one button. See [method TravelEventMenu.ask_notice].
##
## The camp is deliberately not touched by any of this. Where the waggon goes and
## when it comes back is [Camp]'s, and it comes back when the player calls it.

## Emitted as the chest is dropped, with what it holds.
signal reward_dropped(blood: int, items: int)
## Emitted once the chest has been taken.
signal reward_collected(blood: int, items: int)
## Emitted as the whole ending is over and the player is standing in the world
## again, free to call the horse.
signal trouble_closed()

## Group this joins, so anything - the camp, a test - can ask whether the ending is
## still playing out.
const GROUP := &"trouble_reward"

## The search this is the ending of. Left unresolved it is found by group, so the
## two need not be wired together in the scene.
@export var danger_path: NodePath = ^"../DangerDirector"
## Where the chest is instanced. The world's own container of loose things; left
## unresolved it goes under this node's parent, which is the world itself.
@export var container_path: NodePath = ^".."
## Group the player is found in, so the chest is dropped near them.
@export var body_group: StringName = &"player"

@export_group("The chest")
## What falls out of the sky. Without one, a finished search pays nothing and the
## ending is skipped entirely - which is the game exactly as it was before there
## were rewards.
@export var chest_scene: PackedScene
## Where it lands, relative to the player. Ahead of them and a little down the
## screen, so it comes down in view rather than on their head.
@export var drop_offset := Vector2(0.0, 190.0)
## How far the landing spot may wander from that, in pixels, so two searches do not
## drop their chest on exactly the same tuft of grass.
@export var drop_scatter: float = 90.0
## How long after the search ends the chest is dropped, in seconds - the beat the
## player is left looking at the last body before the sky opens.
@export var drop_delay: float = 1.0
## The rectangle the chest must land inside - the playable area. Left at nothing,
## the arena's own bounds are read off the spawner instead, which is where the size
## of the map already lives.
@export var drop_bounds := Rect2()
## How far inside those bounds it must land, in pixels, so a chest never comes down
## inside a wall.
@export var drop_inset: float = 200.0
## The world's own spawner, asked for the playable area when
## [member drop_bounds] is left empty - so the chest is bound by the same rectangle
## every enemy in the game is placed against rather than by a second copy of it.
@export var spawner_path: NodePath = ^"../EnemySpawner"

@export_group("What it holds")
## The reward ladder, one [TroubleRewardTier] per band of Dangers. The deepest
## Danger beaten picks the tier; a search deeper than every authored band is paid at
## the last one, so the table can never leave a finished search with nothing.
@export var tiers: Array[TroubleRewardTier] = []

@export_group("The word afterwards")
## How long after the chest is taken the message goes up, in seconds.
@export var notice_delay: float = 2.0
## What it says, and what the one button under it says.
@export var notice_text: String = "Buralarda belasını bulacak senden başka kimse kalmadı"
@export var notice_description: String = ""
@export var return_text: String = "RETURN TO CAMP"
## The screen it is asked on - the road's own two-button screen, given one button.
## Optional; without one the walk home follows the chest directly.
@export var notice_menu_path: NodePath = ^"../RunHUD/TravelEventMenu"

@export_group("The walk back")
## How long the player is walking for, in seconds.
@export var walk_time: float = 3.0
## What is written over the walk. [b]On foot and with no horse in it[/b] - see
## [method TravelLoading.play_titled] - because the animal is still away; that is
## the whole point of what happens next.
@export var walk_title: String = "WALKING BACK"
@export var walk_subtitle: String = "THE HORSE IS STILL OUT THERE"
## The crossing it is played on. Optional; without one the walk is the same length
## of plain black.
@export var loading_path: NodePath = ^"../RunHUD/TravelLoading"
## How long the screen takes to go black and to clear again.
@export var fade_out_time: float = 0.6
@export var fade_in_time: float = 0.6
## Gap between the button and the screen starting to go black, so the press is seen
## to land.
@export var start_delay: float = 0.15

## Which step of the ending is being played out. Only ever asked as a yes or no -
## see [method is_busy] - so it is a plain flag rather than an enum of its own.
var _busy: bool = false
var _chest: RewardChest
var _danger: DangerDirector


func _ready() -> void:
	add_to_group(GROUP)
	_wire_danger.call_deferred()


## The ending this world plays, or null when it has none.
static func get_active(from_node: Node) -> TroubleRewardDirector:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as TroubleRewardDirector


## Whether the ending is still playing out: a chest in the air, a chest standing
## uncollected, the word up, or the walk being made.
##
## [b]It is what keeps the horse from being called too early.[/b] The waggon asks
## this before it offers "E - CALL HORSE", so the player cannot whistle the animal in
## over their own reward. See [method Camp.can_call_horse].
func is_busy() -> bool:
	return _busy


## The chest currently standing, or null when there is none.
func get_chest() -> RewardChest:
	return _chest if _chest != null and is_instance_valid(_chest) else null


func _wire_danger() -> void:
	if not is_inside_tree():
		return
	_danger = get_node_or_null(danger_path) as DangerDirector
	if _danger == null:
		_danger = DangerDirector.get_active(self)
	if _danger == null:
		return
	if not _danger.search_finished.is_connected(_on_search_finished):
		_danger.search_finished.connect(_on_search_finished)


# --- The chest ------------------------------------------------------------------

## A search has been finished. The chest is owed from this moment; it is dropped a
## beat later so the last man is seen to fall first.
func _on_search_finished(_dangers_cleared: int, highest_danger: int) -> void:
	if _busy or chest_scene == null:
		return

	_busy = true
	var timer := get_tree().create_timer(maxf(drop_delay, 0.0), true, false, true)
	timer.timeout.connect(_drop_chest.bind(highest_danger))


## Which tier pays for [param danger]: the band that covers it, or the deepest
## authored band when the search went past the end of the ladder. Null only when
## nothing has been authored at all.
func find_tier(danger: int) -> TroubleRewardTier:
	var deepest: TroubleRewardTier = null
	for tier: TroubleRewardTier in tiers:
		if tier == null:
			continue
		if tier.covers(danger):
			return tier
		if deepest == null or tier.min_danger > deepest.min_danger:
			deepest = tier
	return deepest


func _drop_chest(highest_danger: int) -> void:
	if not is_inside_tree():
		return

	var tier := find_tier(highest_danger)
	if tier == null:
		# Nothing authored to pay with. The ending is abandoned rather than left half
		# played, so the player is free to call the horse immediately.
		_close()
		return

	var chest := chest_scene.instantiate() as RewardChest
	if chest == null:
		push_warning("TroubleRewardDirector: chest scene is not a RewardChest.")
		_close()
		return

	var container := get_node_or_null(container_path)
	if container == null:
		container = get_parent()
	container.add_child(chest)
	chest.global_position = _landing_spot()
	chest.reset_physics_interpolation()

	var blood := tier.roll_blood()
	chest.set_reward(blood, tier.item_count)
	chest.collected.connect(_on_chest_collected, CONNECT_ONE_SHOT)
	chest.drop()

	_chest = chest
	reward_dropped.emit(blood, tier.item_count)


## Where it comes down: near the player, scattered a little, and held inside the
## playable area so it can never land in a wall.
##
## The area is the spawner's own [member EnemySpawner.arena_bounds] unless one is
## given here - the same rectangle everything else in the world is placed against,
## so a chest is bound by the map's walls rather than by a second idea of them.
func _landing_spot() -> Vector2:
	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	var origin := Vector2.ZERO if body == null else body.global_position

	var point := origin + drop_offset
	if drop_scatter > 0.0:
		point += Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, drop_scatter)

	var area := _play_area()
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return point

	var room := area.grow(-maxf(drop_inset, 0.0))
	if room.size.x <= 0.0 or room.size.y <= 0.0:
		return area.get_center()
	return point.clamp(room.position, room.end)


func _play_area() -> Rect2:
	if drop_bounds.size.x > 0.0 and drop_bounds.size.y > 0.0:
		return drop_bounds
	var spawner := get_node_or_null(spawner_path) as EnemySpawner
	return Rect2() if spawner == null else spawner.arena_bounds


func _on_chest_collected(blood: int, items: int) -> void:
	_chest = null
	reward_collected.emit(blood, items)

	var timer := get_tree().create_timer(maxf(notice_delay, 0.0), true, false, true)
	timer.timeout.connect(_say_the_word)


# --- The word, and the walk home -------------------------------------------------

func _say_the_word() -> void:
	if not is_inside_tree():
		return

	var screen := get_node_or_null(notice_menu_path) as TravelEventMenu
	if screen == null:
		screen = TravelEventMenu.get_active(self)
	if screen == null:
		# Nowhere to say it. The walk home still happens, so a world without the screen
		# still ends its search properly.
		_walk_home()
		return

	screen.answered.connect(_on_notice_answered, CONNECT_ONE_SHOT)
	screen.ask_notice(notice_text, notice_description, return_text)


func _on_notice_answered(_accepted: bool) -> void:
	var timer := get_tree().create_timer(maxf(start_delay, 0.0), true, false, true)
	timer.timeout.connect(_walk_home)


## Behind the black, on foot. It is the same crossing a Danger is walked to, asked
## for other words, so there is one walking transition in the game rather than two.
func _walk_home() -> void:
	if not is_inside_tree():
		return

	var fade := ScreenFade.get_active(self)
	if fade == null:
		_walk()
		return
	fade.fade_out(maxf(fade_out_time, 0.0), _walk)


func _walk() -> void:
	if not is_inside_tree():
		return

	get_tree().paused = true
	var loading := get_node_or_null(loading_path)
	if loading == null:
		loading = TravelLoading.get_active(self)
	if loading != null and loading.has_method(&"play_titled"):
		loading.call(&"play_titled", walk_title, walk_subtitle, maxf(walk_time, 0.0001), true)

	var timer := get_tree().create_timer(maxf(walk_time, 0.0), true, false, true)
	timer.timeout.connect(_arrive)


## The walk is over. The world is handed back exactly as it was left - nothing has
## moved, nothing has been rebuilt - and the player is standing in it with the horse
## still away.
func _arrive() -> void:
	if not is_inside_tree():
		return

	var loading := get_node_or_null(loading_path)
	if loading == null:
		loading = TravelLoading.get_active(self)
	if loading != null and loading.has_method(&"stop"):
		loading.call(&"stop")

	get_tree().paused = false
	var fade := ScreenFade.get_active(self)
	if fade != null:
		fade.fade_in(maxf(fade_in_time, 0.0))

	_close()


## The ending is over. From here the waggon offers "E - CALL HORSE" again, because
## the only thing that was holding it off was [method is_busy].
func _close() -> void:
	if not _busy:
		return
	_busy = false
	_chest = null
	trouble_closed.emit()
