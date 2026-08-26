class_name RunSessionState
extends Node
## Whether the player is out on a run, and which map they chose for it.
##
## The class and the singleton are named apart on purpose, exactly as
## [BloodWallet], [RoundCounter] and [DayClock] are: a [code]class_name[/code]
## matching an autoload's name shadows it and refuses to compile. Reach the live
## one as [code]RunSession[/code]; the type is [RunSessionState] where a
## reference has to be statically typed.
##
## It is an autoload for the same reason the round counter is. The world is one
## scene holding both the base and the arena, and going on a run rebuilds that
## scene - so "the player picked the desert and is heading out" has to survive
## [method SceneTree.reload_current_scene] or the rebuilt world would have no way
## of knowing whether it was meant to open in the base or in the middle of a
## fight. An autoload is the only thing a reload does not touch.
##
## What it holds is deliberately just handles - which map, which region, which
## weapon. Everything about what those *are* - a map's name and title card, a
## region's label and description - lives in a [MapDefinition] or a [MapRegion]
## resource in the inspector, so adding the forest later is a resource and not an
## edit here.
##
## [b]Where and when a run is happening is answered from here.[/b] Three questions
## make up a run's destination and this is the one place all three can be asked:
## [method get_map_id], [method get_region_id] and [method get_time_id]. The first
## two are chosen by the player before setting out and stored here; the third is
## chosen too - see [method choose_time] - but is deliberately [i]not[/i] stored,
## because the game already had somewhere to keep the hour. Picking a time moves
## [DayClock] and nothing else, and the hour is read back off that clock, so the
## screen the player picked on, the darkness of the world, the icon on the HUD and
## the round intro's title card are four views of one number rather than four
## copies of it. Keeping all three questions answerable here means a later system -
## one placing a target on a map, say - asks the run where and when it is and gets
## a straight answer, without having to know that two of those came from a menu
## and one came from a clock.

## Emitted when a map is chosen and the player sets out.
signal run_began(map_id: StringName)
## Emitted when the session is put back to sitting in the base.
signal run_ended()
## Emitted when the player picks what they are taking with them.
signal weapon_chosen(weapon_id: StringName)
## Emitted when the player picks which part of the map they are heading into.
signal region_chosen(region_id: StringName)
## Emitted when the player picks what hour they are riding out at. The day cycle
## has already been moved to it by the time this arrives.
signal time_chosen(time_id: StringName)
## Emitted when the player marks somewhere on the map as where they are heading
## next. Nobody has moved yet - see [method set_destination_region].
signal destination_chosen(region_id: StringName)
## Emitted as the player sends for the horse to ride to the region they marked.
## Nothing has moved and no world has been rebuilt; the travel screen is what
## comes next.
signal travel_started(region_id: StringName)
## Emitted once a journey has been made: the destination is now the region, and
## the clock has already been moved by [param days] stages.
signal travel_finished(region_id: StringName, days: int)

## Id of the map being played, or empty while the player is at home in the base
## with no run under way.
var _map_id: StringName = &""
## Id of the weapon in the player's hands, or empty when they have not chosen one
## and the roster's default stands.
##
## It lives here for exactly the reason the map does: the world is rebuilt on the
## way out to a run, and an autoload is the only thing a
## [method SceneTree.reload_current_scene] does not touch - so the weapon picked
## in the base is still the weapon being carried once the arena has been built.
## [b]It deliberately survives the run ending[/b], because what the player is
## carrying is not a fact about one run: walking back into the base with the rifle
## should leave the rifle in their hands until they choose otherwise.
var _weapon_id: StringName = &""
## Which part of that map the run is happening in, or empty before the player has
## been asked.
##
## [b]It is cleared whenever a map is chosen[/b] - see [method begin] - because a
## region only means anything relative to the map that owns it, and the desert's C
## is not a town's C. That is what stops a stale letter from a previous run leaking
## into the next one and sending a later system looking for a place that is not on
## this map.
var _region_id: StringName = &""
## Where the player has said they are going next, or empty when they have not been
## asked - which reads as staying where they are. Cleared whenever the region
## itself is chosen, so arriving somewhere never leaves a destination standing
## that the player has already reached.
var _destination_region_id: StringName = &""
## Whether a journey between two regions is under way: the horse has been sent for
## and the ride has not been made yet.
##
## It lives here rather than on [TravelDirector] for the same reason the map and
## the region do - it must outlive the world being rebuilt. The rebuild happens at
## the *end* of a journey, and this is what is cleared as part of making the
## arrival, so a world can never come back still believing somebody is on the road.
## See [method begin_travel].
var _travelling: bool = false
## The animal the player owns, or null while they have never been given one -
## which every caller reads as "whatever the travel screen offers as its default".
##
## [b]Nothing sets this yet.[/b] It is the seam a stable or a base upgrade hangs
## off: handing the player a faster [Horse] is one call to [method set_horse], and
## the travel screen grows the shorter journeys on its own because the durations
## it offers are the horse's own answer. It survives a rebuild for the same reason
## the weapon does - what you own is not a fact about one round.
var _horse: Horse
## Where the catalogue of maps is read from, so a run can be asked which
## [MapDefinition] it is on and, through it, which region and which hour.
##
## A path rather than a resource because an autoload script has no scene and so no
## inspector to drop one into - the same arrangement [BountyLedger] uses for its
## settings. It is loaded once, on the first question that needs it.
@export var map_catalog_path: String = "res://Resources/Maps/map_catalog.tres"
## The day cycle, asked what hour the run is at. Left as the default it is the
## [code]DayCycle[/code] autoload.
@export var day_clock_path: NodePath = ^"/root/DayCycle"
## The carried health, forgotten whenever a run begins or ends - see [RunVitals].
## Setting out is always at full health and coming home always arrives whole; only
## the rounds inside one run carry their wounds forward.
@export var vitals_path: NodePath = ^"/root/Vitals"

## Whether the player still has a resupply owed to them for this run.
##
## [b]Kitting out happens once per run, not once per round.[/b] Every round is a
## world being built, so a resupply hung off that would refill the pouches between
## rounds for nothing and make the camp's ammunition worthless. This is set when a
## run begins and taken by the first world that asks - see
## [method take_outfit] and [member WorldBoot.resupply_on_run].
var _outfit_owed: bool = false

## Whether the next world to be built is one the player rode into, rather than one
## they simply started the next round in.
##
## [b]It is here for exactly the reason the outfit is.[/b] A journey ends by
## rebuilding the world, and the arrival - standing where the region says arrivals
## stand, and whatever is waiting there - has to happen in the world that comes
## back, which is not the world the ride was made in. An autoload is the only thing
## a [method SceneTree.reload_current_scene] does not touch, so the fact that a ride
## just ended is remembered here and taken by the first world that asks. See
## [method take_arrival] and [RegionArrival].
var _arrival_owed: bool = false

## Whether this session is a Free Run rather than the story.
##
## [b]It is a property of the session for the same reason the map is.[/b] A Free
## Run outlives every world it builds - the loop is one Trouble after another and
## each of them rebuilds nothing but the fight - so the one thing that must not be
## forgotten is what kind of game this is. An autoload is the only thing a
## [method SceneTree.reload_current_scene] leaves standing, so it is remembered
## here and read by whoever is deciding what a freshly built world is for.
##
## [b]Nothing about the story is conditional on it.[/b] It is asked in exactly two
## places - [WorldBoot], deciding whether the round belongs to the wave manager or
## to the search, and [DangerDirector], deciding whether a search has a bottom to
## it - and both of those refuse to it exactly as they refuse to a boss or an
## arrival. A story run never sets it and so never sees either question.
var _free_run: bool = false

var _catalog: MapCatalog


## True once a map has been chosen. The world reads this on the way up to decide
## whether it is building a base to stand around in or an arena to fight in.
func is_running() -> bool:
	return _map_id != &""


## Which map, or empty when there is no run. Read by the round intro to find the
## right title card, and by anything later that needs to build a particular map.
func get_map_id() -> StringName:
	return _map_id


## Which weapon the player is carrying, or empty when they have never chosen. A
## caller reads that as "whatever the roster offers first" - see
## [method WeaponCatalog.get_default] - so there is no weapon named here as a
## fallback.
func get_weapon_id() -> StringName:
	return _weapon_id


## Notes what the player picked. Called by the weapon selection screen; the
## world's [WeaponMount] reads it when the arena is built and puts that weapon in
## their hands.
func choose_weapon(weapon_id: StringName) -> void:
	if weapon_id == &"" or weapon_id == _weapon_id:
		return
	_weapon_id = weapon_id
	weapon_chosen.emit(_weapon_id)


## Which part of the map the run is in, or empty when the player has not been
## asked. The companion to [method get_map_id], and what a later system placing a
## target on the map reads to decide whether this is the run it was waiting for.
func get_region_id() -> StringName:
	return _region_id


## Notes which region the player picked. Called by the region selection screen,
## which is raised once a map has been chosen - so this is always set against a
## map, never on its own.
##
## Refuses an empty id: "nowhere" is not a choice the player can make, and the run
## must not set out with the question half answered.
func choose_region(region_id: StringName) -> void:
	if region_id == &"" or region_id == _region_id:
		return
	_region_id = region_id
	# Arriving somewhere clears the intention to go there, so the camp opens
	# offering the next round rather than a ride the player has already taken.
	_destination_region_id = &""
	region_chosen.emit(_region_id)


## Where the player has said they are heading next, which is [b]not[/b] where they
## are. Empty falls back to the region they are standing in, so a run that has
## never been asked reads as staying put.
##
## The two are deliberately separate. Marking somewhere on the camp's map is a
## decision, not a journey: the camp reads this to know whether its button should
## say NEXT ROUND or TRAVEL, and only arriving - which is the travel milestone's
## business - makes a destination into a location.
func get_destination_region() -> StringName:
	return _destination_region_id if _destination_region_id != &"" else _region_id


## Marks where the player intends to go next. Nothing moves, and the region they
## are currently in is untouched.
func set_destination_region(region_id: StringName) -> void:
	if region_id == _destination_region_id:
		return
	_destination_region_id = region_id
	destination_chosen.emit(get_destination_region())


## Whether the marked destination is somewhere other than where the player is
## standing. What decides whether the camp offers a round or a ride.
func has_travel_pending() -> bool:
	var destination := get_destination_region()
	return destination != &"" and destination != _region_id


## Makes the marked destination the region the run is now in, and reports whether
## anything moved.
##
## Arriving is what turns a destination into a location, and it goes through
## [method choose_region], so there is still exactly one place the run's region is
## written. Called by [method complete_travel] at the end of a journey.
func arrive_at_destination() -> bool:
	if not has_travel_pending():
		return false
	choose_region(get_destination_region())
	_destination_region_id = &""
	# The one place a destination becomes a location, and therefore the one place
	# an arrival can be noted. It is owed rather than acted on here, because the
	# world it happens in has not been built yet.
	_arrival_owed = true
	return true


# --- Travel -------------------------------------------------------------------

## Whether a journey is under way, asked by [TravelDirector] - and by the world it
## builds in, to put back a journey that was interrupted rather than finished.
func is_travelling() -> bool:
	return _travelling


## Sets out for whatever region has been marked, and reports whether there was
## anywhere to set out for.
##
## [b]It only records the decision.[/b] Nothing is moved and no world is rebuilt -
## the ride itself is [TravelDirector]'s, and it happens where the player is
## standing. Refusing a second call while one is under way is what stops the camp
## beginning two journeys.
func begin_travel() -> bool:
	if _travelling or not has_travel_pending():
		return false
	_travelling = true
	travel_started.emit(get_destination_region())
	return true


## Gives up on a journey without having made it, leaving the destination marked.
## What backing out of the travel screen does, so pressing TRAVEL is never a
## commitment - and what a world coming up mid-journey uses to clear a ride that
## was interrupted rather than finished.
func abandon_travel() -> void:
	if not _travelling:
		return
	_travelling = false


## Completes a journey of [param days] stages: the clock is moved on, the marked
## destination becomes the region, and the road is left behind.
##
## The two halves are deliberately in this order. The hour is advanced first, so
## anything listening for the arrival is looking at a session whose clock has
## already moved - there is never a frame in which the player has arrived but the
## day has not passed.
##
## Reports whether the player actually went anywhere. A journey with no
## destination left to reach still clears the travel state, so a world can never
## come back as a road nobody is on.
func complete_travel(days: int) -> bool:
	if not _travelling:
		return false
	_travelling = false

	advance_days(days)
	var moved := arrive_at_destination()
	travel_finished.emit(_region_id, days)
	return moved


## Moves the day on by [param days] of this map's stages, and reports whether the
## clock actually moved.
##
## [b]It owns no notion of time.[/b] How many stages a day is divided into is the
## map's answer and where the session is in them is [DayClock]'s, so all this does
## is put the two together - which is what keeps the world's darkness, the HUD's
## icon and the hour's name reading one number after a journey exactly as they do
## after a round.
func advance_days(days: int) -> bool:
	if days <= 0:
		return false

	var map := get_map()
	if map == null or map.day_stages.is_empty():
		return false

	var clock := get_node_or_null(day_clock_path)
	if clock == null or not clock.has_method(&"advance_stages"):
		return false

	clock.call(&"advance_stages", days, map.day_stages.size())
	return true


## The animal the player travels on. Null means they have never been given one,
## which the travel screen reads as "offer the horse I was authored with" - so
## there is no starting horse named anywhere in code.
func get_horse() -> Horse:
	return _horse


## Hands the player a horse. Nothing calls it yet; it is what a stable or a base
## upgrade will call, and every shorter journey that horse allows appears on the
## travel screen without anything else being changed.
func set_horse(horse: Horse) -> void:
	if horse == _horse:
		return
	_horse = horse


## Whether the run has been given everywhere it needs: a map, and a part of it.
## What the portal checks before it lets the transition begin.
func has_destination() -> bool:
	return _map_id != &"" and _region_id != &""


## The map this run is on, as the resource rather than the handle - for anything
## that needs its regions, its hours or its name. Null when no map is chosen or
## the catalogue cannot be read.
func get_map() -> MapDefinition:
	var catalog := get_map_catalog()
	return null if catalog == null else catalog.find(_map_id)


## The region this run is in, as the resource. Null when none has been picked, or
## when the chosen map does not have one by that name.
func get_region() -> MapRegion:
	var map := get_map()
	return null if map == null else map.find_region(_region_id)


## What hour the run is happening at, as the resource.
##
## [b]It is asked rather than stored.[/b] The time of day is not a third thing the
## player picks - it is worked out by [DayClock] from where the session started
## and how many rounds have been played, and the map's own list of hours is what
## that index means. Reading it here rather than keeping a copy is what stops the
## run's idea of the hour and the world's from ever disagreeing.
func get_time_stage() -> DayStage:
	return get_time_stage_at_offset(0)


## The hour [param offset] stages along from the one being played, wrapping round
## the end of the day exactly as the cycle itself does - so 0 is now and 4 is what
## the desert will look like after a four-day ride.
##
## It exists so that the travel screen can show the player what hour each journey
## would land them at [i]without[/i] working the wrap out for itself. The order of
## the hours is the map's own array and the position in them is [DayClock]'s, so a
## previewed arrival and the arrival that actually happens are the same
## arithmetic read twice rather than two calculations that could disagree.
func get_time_stage_at_offset(offset: int) -> DayStage:
	var map := get_map()
	if map == null or map.day_stages.is_empty():
		return null

	var index := 0
	var clock := get_node_or_null(day_clock_path)
	if clock != null and clock.has_method(&"get_stage_index"):
		index = clock.call(&"get_stage_index", map.day_stages.size())

	return map.day_stages[posmod(index + offset, map.day_stages.size())]


## The hour as a handle, matching a [member DayStage.stage_name] - and so matching
## what a wanted poster holds as its answer for the time category. Empty when
## there is no map to read hours from.
func get_time_id() -> StringName:
	var stage := get_time_stage()
	return &"" if stage == null else stage.stage_name


## Sets the hour the run is to happen at. Called by the time selection screen once
## the player commits, and the only thing in the run that ever moves the clock.
##
## [b]It stores nothing.[/b] There is one answer to "what time is it" in this game
## and it is [DayClock]'s - see [method get_time_stage], which asks that clock and
## has done since before this question was put to the player. All this does is
## move the clock to the hour that was picked, so the world's darkness, the HUD's
## icon and the round intro's title card carry on reading the time from exactly
## where they always did and cannot disagree with the choice. Keeping a chosen
## hour here as well would be a second clock, and the two would drift the first
## time a round advanced.
##
## The hour is named rather than numbered - [param time_id] matches a
## [member DayStage.stage_name] - and turned into a position by looking it up in
## the chosen map's own list. A map with no hours, or an hour that is not one of
## that map's, changes nothing and reports false: nowhere in this file is there a
## name or a count that a map with a different set of hours would break.
func choose_time(time_id: StringName) -> bool:
	if time_id == &"":
		return false

	var map := get_map()
	if map == null or map.day_stages.is_empty():
		return false

	var index := -1
	for position: int in range(map.day_stages.size()):
		var stage := map.day_stages[position]
		if stage != null and stage.stage_name == time_id:
			index = position
			break
	if index < 0:
		return false

	var clock := get_node_or_null(day_clock_path)
	if clock == null or not clock.has_method(&"set_stage_index"):
		return false

	clock.call(&"set_stage_index", index, map.day_stages.size())
	time_chosen.emit(time_id)
	return true


## The roster of maps, loaded once. A missing catalogue leaves every question
## about the map unanswerable rather than erroring, so a world opened on its own
## still plays.
func get_map_catalog() -> MapCatalog:
	if _catalog != null:
		return _catalog
	if ResourceLoader.exists(map_catalog_path):
		_catalog = load(map_catalog_path) as MapCatalog
	if _catalog == null:
		push_warning("RunSessionState: no map catalogue at %s." % map_catalog_path)
	return _catalog


## Sets out on [param map_id]. Called by the map selection menu once the player
## has picked; the region screen follows it, and the world is rebuilt once both
## have been answered.
##
## Choosing a map clears the region on purpose. Picking the desert and then
## backing out to pick the town must not leave the run pointed at the desert's C,
## and re-picking the same map is treated the same way: the player is being asked
## the question again either way.
func begin(map_id: StringName) -> void:
	if map_id == &"":
		return
	_map_id = map_id
	_region_id = &""
	_destination_region_id = &""
	# A journey belongs to the run it was made in. Setting out on a new one from
	# the base cannot leave the world thinking it should come back as a road, nor
	# the first world of the run thinking it was ridden into.
	_travelling = false
	_arrival_owed = false
	# A new run is a full pouch and a whole hide. Both are owed here rather than
	# handed over here, because the world that will receive them has not been built
	# yet - see [method take_outfit] and [RunVitals].
	_outfit_owed = true
	_clear_vitals()
	run_began.emit(_map_id)


## Whether this world should kit the player out, taking the answer as it gives it
## so only the first world of a run ever gets a yes.
##
## The next round rebuilds the world exactly as setting out does, so "did they just
## leave the base" cannot be read off the world itself - it has to be remembered
## across the rebuild, which is what this is. A caller with no run under way gets
## false.
func take_outfit() -> bool:
	if not _outfit_owed:
		return false
	_outfit_owed = false
	return true


## Whether a resupply is still owed, for anything wanting to ask without spending
## it.
func is_outfit_owed() -> bool:
	return _outfit_owed


## Whether this world is the one the player has just ridden into, taking the answer
## as it gives it so only the first world built after a journey ever gets a yes.
##
## Every round rebuilds the world exactly as arriving does, so "did they just get
## here" cannot be read off the world itself - it has to be remembered across the
## rebuild, which is what this is. Taken by [RegionArrival]; a caller in a world
## that was not travelled to gets false and enters the region as any other round
## does.
func take_arrival() -> bool:
	if not _arrival_owed:
		return false
	_arrival_owed = false
	return true


## Whether an arrival is still owed, for anything wanting to ask without spending
## it.
func is_arrival_owed() -> bool:
	return _arrival_owed


func _clear_vitals() -> void:
	var vitals := get_node_or_null(vitals_path)
	if vitals != null and vitals.has_method(&"clear"):
		vitals.call(&"clear")


## Back to no run. Nothing calls it during play yet - a death carries the player
## home without ending the session - but it is what a "quit to base" would use,
## and it keeps the state something that can be put back rather than only set.
func end() -> void:
	if _map_id == &"":
		return
	_map_id = &""
	# The region goes with the map it belonged to. It is not a preference the
	# player carries between runs the way the weapon is - it is where this
	# particular run was headed.
	_region_id = &""
	_destination_region_id = &""
	_travelling = false
	_outfit_owed = false
	# A Free Run ends where every other run ends: at the base, having died, gone home
	# or backed out. Cleared here so the flag cannot outlive the game it belonged to
	# and take the next story run's round over from the pit.
	_free_run = false
	_arrival_owed = false
	# The wounds of a run belong to that run. Walking back into the base is walking
	# in whole, which is also what stops a player who went home on half a heart from
	# being stuck with it.
	_clear_vitals()
	run_ended.emit()


## Whether the player is on a Free Run - the endless search, with no story run to
## finish and no bottom to the ladder.
func is_free_run() -> bool:
	return _free_run


## Says which kind of game this is. Called by the title screen before the world is
## built, because the answer has to be in place by the time [WorldBoot] asks it.
##
## Setting it does not begin anything: what a Free Run [i]is[/i] belongs to the
## world - see [method WorldBoot._free_run_takes_the_round] - and this is only the
## fact that it is one.
func set_free_run(free_run: bool) -> void:
	_free_run = free_run
