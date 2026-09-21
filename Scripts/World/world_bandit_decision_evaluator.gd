class_name WorldBanditDecisionEvaluator
extends RefCounted
## Reads a bandit contact the way the design brief asks for it: STRONGER,
## EQUAL or WEAKER, from exactly two facts and nothing invented to go with
## them.
##
##   [codeblock]
##   one medium-range shot kills a bandit   AND   group_strength < 40   ->  EQUAL
##   exactly one of the two holds                                      ->  STRONGER
##   neither holds                                                     ->  WEAKER
##   [/codeblock]
##
## [b]The brief states STRONGER as an OR and EQUAL as an AND of the same two
## conditions[/b], which taken as plain boolean logic makes EQUAL a subset of
## STRONGER rather than a third case of its own. Checked as three
## independent branches that could never happen: read the way the AND is
## checked first here, the same pair of facts sorts a contact into exactly
## one of the three - "both" is EQUAL, "exactly one" is STRONGER and
## "neither" is WEAKER - which is the only reading that gives the brief's own
## third tier anywhere to actually happen. Nothing about which facts matter
## is changed by it.
##
## [b]"One medium-range shot" is read off the weapon actually in the
## player's hands, not invented.[/b] Every weapon already carries this
## exact number: its [member CarriedWeapon.projectile_scene] holds a
## [Projectile] with its own [ProjectileProfile], and
## [method ProjectileProfile.damage_at] is the whole of how far a shot has
## carried already turns into how much it still hits for.
## [constant MEDIUM_RANGE_PROGRESS] reads that curve at its own midpoint -
## the natural meaning of "medium" for a curve authored as near/far - rather
## than a distance this file invents a threshold for. A shotgun's own
## [member Shotgun.pellet_count] is folded in as one trigger pull's whole
## payload, since "one shot" is what the player fired, not one pellet of it.
##
## [b]"A bandit" is read off the region the contact happened in.[/b]
## [member MapRegion.enemy_base_health] is already "what an ordinary enemy
## standing in this part of the map is worth, in hit points" - the exact
## figure a bandit becomes the moment the group turns into Arena enemies -
## so this asks that file rather than a new number of its own.
##
## [b]Nothing here is a stat.[/b] There is no rating attached to the player
## and nothing is written back onto the weapon, the bandit or the region;
## every call reads the two facts fresh and throws the answer away the
## moment the decision screen has used it.

enum Tier { STRONGER, EQUAL, WEAKER }

## Where on a projectile's own damage curve "medium range" is read from - the
## middle of the near/far progression every [ProjectileProfile] is already
## built on, not a distance invented for this file.
const MEDIUM_RANGE_PROGRESS := 0.5
## What a group's own strength has to fall under for the design brief's
## "group < 40" half of the reading.
const GROUP_STRENGTH_THRESHOLD := 40.0


## The full reading for one contact: [param bandit]'s own group, weighed
## against whatever the player is currently holding and wherever they are
## standing.
##
## [param strength_override] is read instead of [member WorldBandit.group_strength]
## when zero or greater - the seam [WorldMapCombatBridge] reads a contact's
## own strength plus whatever nearby groups have joined it through, so a
## reinforced encounter is judged by the size the player is actually about to
## face rather than the one bandit that happened to make contact first.
## Negative - the default - leaves this exactly as it always read: the
## contacted bandit's own, unreinforced strength.
static func evaluate(bandit: WorldBandit, from_node: Node, strength_override: float = -1.0) -> Tier:
	var region_id := &"" if bandit == null else bandit.region_id
	var strength := strength_override if strength_override >= 0.0 \
		else (0.0 if bandit == null else bandit.group_strength)
	return evaluate_group(region_id, strength, from_node)


## The same reading for a group that is not a [WorldBandit] standing on a map -
## a run map's own bandit point, which is a fact on a graph rather than a node
## with a position. [method evaluate] is this same call with the two facts read
## off the contacted man instead, so both doors sort a contact by exactly one
## rule and there is never a second copy of it to disagree.
##
## [param roster] is how the weapon half of the reading is answered where there
## is no player body in the scene to carry one - see
## [method medium_range_shot_damage]. Left null, a screen opened away from the
## player reads as holding nothing, which would make every small group look
## like a fight that cannot be talked out of.
static func evaluate_group(region_id: StringName, strength: float, from_node: Node,
		roster: WeaponCatalog = null) -> Tier:
	return _resolve(
		can_one_shot_kill(from_node, region_id, roster),
		strength < GROUP_STRENGTH_THRESHOLD)


static func _resolve(one_shot: bool, group_small: bool) -> Tier:
	if one_shot and group_small:
		return Tier.EQUAL
	if one_shot or group_small:
		return Tier.STRONGER
	return Tier.WEAKER


## Whether the weapon currently in the player's hands would kill an ordinary
## bandit of [param region_id] with one medium-range shot.
##
## [param roster] is only read where there is no player in the scene to ask -
## see [method medium_range_shot_damage].
static func can_one_shot_kill(from_node: Node, region_id: StringName,
		roster: WeaponCatalog = null) -> bool:
	var damage := medium_range_shot_damage(from_node, roster)
	var health := bandit_health(from_node, region_id)
	return damage > 0.0 and damage >= health


## One trigger pull's worth of damage at [constant MEDIUM_RANGE_PROGRESS] on
## whatever weapon is currently drawn. 0 when there is nothing to read -
## no weapon to find, or one carrying no projectile - which every caller reads
## as "cannot one-shot anything".
##
## [b]The live weapon is always preferred.[/b] [WeaponMount] holds the weapon the
## player is actually carrying, with whatever a run has done to it, so wherever
## there is one this reads that and nothing else.
##
## [param roster] is the way to ask on a screen where there is no player body at
## all - a run map, which is a graph of points rather than a place to stand -
## and is ignored entirely wherever a mount exists. It is read exactly the way
## [WeaponMount] itself reads it: the weapon id off [RunSessionState], looked up
## in the same catalogue, and its own scene built and thrown away on the spot,
## the same one-shot instancing [method _projectile_damage_at] already does for
## a projectile. Without it - and without a mount - the answer is 0, which is
## the honest reading for a question asked where the gun is not.
static func medium_range_shot_damage(from_node: Node,
		roster: WeaponCatalog = null) -> float:
	var weapon := _live_weapon(from_node)
	var built_here: Node = null
	if weapon == null:
		built_here = _build_chosen_weapon(from_node, roster)
		weapon = built_here
	if weapon == null:
		return 0.0

	var per_projectile := _projectile_damage_at(weapon, MEDIUM_RANGE_PROGRESS)
	var pellet_count: Variant = weapon.get(&"pellet_count")
	var pellets := 1 if pellet_count == null else maxi(int(pellet_count), 1)
	if built_here != null:
		built_here.queue_free()
	if per_projectile <= 0.0:
		return 0.0
	return per_projectile * float(pellets)


## The weapon actually in the player's hands, or null in a scene with no mount
## in it.
static func _live_weapon(from_node: Node) -> Node:
	var mount := WeaponMount.get_active(from_node)
	return null if mount == null else mount.get_weapon()


## A fresh copy of whichever weapon the run is being played with, off
## [param roster] - built here and freed by the caller. Null when there is no
## roster to ask, no session to ask it about, or no scene on the entry.
static func _build_chosen_weapon(from_node: Node, roster: WeaponCatalog) -> Node:
	if roster == null or from_node == null or not from_node.is_inside_tree():
		return null
	var definition: WeaponDefinition = null
	var session := from_node.get_node_or_null(^"/root/RunSession")
	if session != null and session.has_method(&"get_weapon_id"):
		definition = roster.find(session.call(&"get_weapon_id"))
	if definition == null:
		definition = roster.get_default()
	if definition == null or definition.scene == null:
		return null
	return definition.scene.instantiate()


## Damage a fresh instance of [param weapon]'s own [member CarriedWeapon.projectile_scene]
## reports at [param progress] along its [ProjectileProfile] - built and
## freed on the spot, since nothing about a weapon exposes its profile
## without one.
static func _projectile_damage_at(weapon: Node, progress: float) -> float:
	var scene := weapon.get(&"projectile_scene") as PackedScene
	if scene == null:
		return 0.0

	var built := scene.instantiate()
	var projectile := built as Projectile
	var damage := 0.0
	if projectile != null:
		var profile := projectile.profile
		if profile == null:
			profile = ProjectileProfile.new()
		damage = profile.damage_at(progress)
	built.queue_free()
	return damage


## What an ordinary enemy of [param region_id] is worth, in hit points - see
## [member MapRegion.enemy_base_health]. Read the same way
## [method DangerDirector._current_region] already reads a region off the
## run's own session: [method RunSessionState.get_map] then
## [method MapDefinition.find_region], never a second lookup of this
## project's own. [constant FALLBACK_HEALTH] when there is no region to
## ask - a session with no map, or an id nothing matches - which is read as
## "assume nothing about how tough a bandit is" the same way every other
## World Map system falls back when a piece it asks for is missing.
const FALLBACK_HEALTH := 100.0

static func bandit_health(from_node: Node, region_id: StringName) -> float:
	if not from_node.is_inside_tree():
		return FALLBACK_HEALTH
	var session := from_node.get_node_or_null(^"/root/RunSession")
	if session == null or not session.has_method(&"get_map"):
		return FALLBACK_HEALTH
	var map := session.call(&"get_map") as MapDefinition
	if map == null:
		return FALLBACK_HEALTH
	var region := map.find_region(region_id)
	if region == null or region.enemy_base_health <= 0.0:
		return FALLBACK_HEALTH
	return region.enemy_base_health
