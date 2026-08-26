class_name TestSpawnStation
extends Node2D
## The developer's station in the test map: walk up to it, press E, and put any
## enemy or boss the game currently has anywhere on the floor.
##
## [b]It is [WeaponRack] with a different screen behind it[/b], and deliberately the
## same shape: the player is found by group rather than by path, the reach test is a
## circle around this node rather than an area to author, the prompt is [i]told[/i]
## on the crossing rather than asked every frame, and the key is taken in
## [method Node._unhandled_input] and marked handled so the press that opens the
## station cannot also reach anything standing behind it.
##
## [b]The roster is read, never written down.[/b] [method build_entries] asks the
## live world what exists - the [EnemySpawner]'s own enemy scene, the
## [MiniBossDirector]'s rungs, and the outlaws on [BountySettings] - and builds the
## list out of those three. Nothing here names an enemy, a boss or a face, so a
## fifth outlaw or a fourth rung is a [code].tres[/code] file and appears in the
## station by itself. [member extra_enemy_scenes] is the same door for a second
## enemy [i]scene[/i], which the project does not yet have.
##
## [b]Spawning is the game's own spawn.[/b] Every entry goes out through
## [method EnemySpawner.spawn_at] - the same call a wave and a road ambush make - so
## a test enemy is an ordinary enemy with ordinary AI, and there is no second spawner
## in the project. A boss is that same body wearing a [MiniBossAppearance] built from
## the director's own wardrobe and grown to a [MiniBossTier]'s size, which is exactly
## what a real mini boss is made of.
##
## [b]What a test boss deliberately is not given is the encounter.[/b] The real
## [MiniBoss] component carries a contract id and is what [BossPhases] and
## [BossDefeat] hang the fight off - so attaching it here would run a bounty through
## the ledger. It is left off, and a test boss is therefore a boss-shaped man to
## shoot at rather than a contract being played.
##
## Everything it puts down joins [member spawned_group], which is the whole of the
## registry: the clear reads it, and [ZoneEnemyGuard] and [RunEndDefeat] both leave
## it alone. Nothing keeps a second list that could fall out of step with the world.

## Emitted as the player comes within reach, and as they leave it.
signal player_entered
signal player_exited
## Emitted when the station is actually opened.
signal used
## Emitted after a clear, with how many were removed.
signal cleared(count: int)

## Group every station joins, so anything can find one without being wired to it.
const GROUP := &"test_spawn_station"

## How close the player has to stand for the prompt to appear and the key to work,
## in pixels.
@export var interaction_radius: float = 190.0
## Only bodies in this group can use it.
@export var body_group: StringName = &"player"
## Key that opens it.
@export var interact_action: StringName = &"interact"
## Where the reach is measured from, so the circle can sit at the front of the
## artwork rather than at the middle of it.
@export var reach_offset := Vector2(0.0, 40.0)

@export_group("The roster")
## Enemy scenes offered on top of whatever the world's [EnemySpawner] is already
## built around. Empty, and the station offers exactly the one enemy the game has -
## which is the honest answer today. A second enemy scene is one entry here.
@export var extra_enemy_scenes: Array[PackedScene] = []
## Whether every outlaw is listed against every rung, so each boss can be seen
## wearing the face he actually walks out of the desert with.
##
## Off lists one entry per rung, dressed as the first outlaw - for a roster that has
## grown large enough that the full cross is unwieldy.
@export var lists_boss_looks: bool = true
## How an ordinary enemy's button is written. The scene's name is substituted in.
@export var enemy_format: String = "ENEMY  -  %s"
## How a boss's button is written: the outlaw, then how much the contract was known.
@export var boss_format: String = "BOSS  -  %s  ·  KNOWN %d"
## How a boss with no outlaw to wear is written - a world with no contracts authored.
@export var plain_boss_format: String = "BOSS  -  KNOWN %d"

@export_group("The boss")
## What a test boss's health pool is multiplied by.
##
## [b]A real boss is worth what his contract pays[/b] - see
## [method MiniBossDirector.get_boss_health_multiplier] - and a test boss has no
## contract, so there is nothing here to read it off. This is the dial that stands in
## for it: 1 is an ordinary enemy's pool on a very large man, and raising it in the
## inspector is how a fight worth testing is made without a bounty being run through
## the ledger.
@export var boss_health_multiplier: float = 1.0

@export_group("What is spawned into")
## Group everything placed here joins. It is the registry: [method clear_spawned]
## reads it, and the world's two field-clearing systems are told to leave it alone.
@export var spawned_group: StringName = &"test_spawned"
## Node the spawns are moved under once built, so the run's own [code]Enemies[/code]
## container stays exactly the run's. Defaults to this station's parent.
@export var container_path: NodePath = ^".."
## Group the world's [EnemySpawner] can be found in. Left unfound, the station
## searches the running scene for one instead, so it works in a world where nobody
## has grouped it.
@export var spawner_group: StringName = &"enemy_spawner"

@export_group("Nodes")
## The E shown by the player's head while they are in reach. Optional.
@export var prompt_path: NodePath = ^"Prompt"

@onready var _prompt: InteractionPrompt = get_node_or_null(prompt_path) as InteractionPrompt
@onready var _container: Node = get_node_or_null(container_path)

var _in_reach: bool = false
var _menu: TestSpawnMenu
var _placer: TestPlacer
var _spawner: EnemySpawner
var _entries: Array[TestSpawnEntry] = []


func _ready() -> void:
	add_to_group(GROUP)
	if _container == null:
		_container = get_parent()
	if _prompt != null:
		_prompt.set_prompt_visible(false)


## The station the rest of the scene should talk to. Null means this world has none.
static func get_active(from_node: Node) -> TestSpawnStation:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as TestSpawnStation


## Whether [param body] is standing close enough to reach the station.
func is_in_reach(body: Node2D) -> bool:
	if body == null or not body.is_in_group(body_group):
		return false
	return (global_position + reach_offset).distance_to(body.global_position) <= interaction_radius


func is_player_in_reach() -> bool:
	return _in_reach


## Opens the station. Ignored unless the player is actually standing at it, so
## nothing can be triggered from across the map.
##
## A placement already under way is ended first: pressing E again is the player
## asking for the list back, not asking to place two things at once.
func use() -> void:
	if not _in_reach:
		return

	var placer := _get_placer()
	if placer != null and placer.is_placing():
		placer.cancel()

	used.emit()
	if _prompt != null:
		_prompt.set_prompt_visible(false)

	var menu := _get_menu()
	if menu == null:
		return

	if not menu.entry_chosen.is_connected(_on_entry_chosen):
		menu.entry_chosen.connect(_on_entry_chosen)
	if not menu.clear_requested.is_connected(_on_clear_requested):
		menu.clear_requested.connect(_on_clear_requested)

	# Rebuilt every time rather than cached, so a rung or an outlaw edited in the
	# inspector shows up on the next press instead of on the next restart.
	_entries = build_entries()
	menu.open(_entries, count_spawned())


## Everything the game can currently put on the ground, read off the live world.
##
## Public because it is the answer, not a detail: a test written against this can
## assert that a new enemy scene or a new rung actually reaches the station without
## opening a menu.
func build_entries() -> Array[TestSpawnEntry]:
	var entries: Array[TestSpawnEntry] = []
	_gather_enemies(entries)
	_gather_bosses(entries)
	return entries


## The ordinary enemies: whatever the world's spawner is built around, plus anything
## named on this station. Duplicates are dropped, so listing the world's own scene in
## [member extra_enemy_scenes] does not double it.
func _gather_enemies(into: Array[TestSpawnEntry]) -> void:
	var scenes: Array[PackedScene] = []

	var spawner := _get_spawner()
	if spawner != null and spawner.enemy_scene != null:
		scenes.append(spawner.enemy_scene)
	for scene: PackedScene in extra_enemy_scenes:
		if scene != null and not scenes.has(scene):
			scenes.append(scene)

	for scene: PackedScene in scenes:
		var entry := TestSpawnEntry.new()
		entry.kind = TestSpawnEntry.Kind.ENEMY
		entry.scene = scene
		entry.label = enemy_format % _scene_name(scene)
		into.append(entry)


## The bosses: every rung the [MiniBossDirector] is authored with, against every
## outlaw the bounty settings know. Both lists are read live, so neither is written
## down here.
func _gather_bosses(into: Array[TestSpawnEntry]) -> void:
	var director := MiniBossDirector.get_active(self)
	if director == null or director.tiers.is_empty():
		return

	var body := _boss_body(director)
	if body == null:
		return

	var targets := _gather_targets()
	for tier: MiniBossTier in director.tiers:
		if tier == null:
			continue
		if targets.is_empty():
			into.append(_boss_entry(body, tier, null))
			continue
		for target: BountyTarget in targets:
			into.append(_boss_entry(body, tier, target))
			if not lists_boss_looks:
				break


func _boss_entry(body: PackedScene, tier: MiniBossTier, target: BountyTarget) -> TestSpawnEntry:
	var entry := TestSpawnEntry.new()
	entry.kind = TestSpawnEntry.Kind.BOSS
	entry.scene = body
	entry.tier = tier
	entry.target = target
	if target == null:
		entry.label = plain_boss_format % tier.knowledge
	else:
		entry.label = boss_format % [target.display_name, tier.knowledge]
	return entry


## The outlaws, asked of the bounty settings rather than listed here. Reading the
## settings does not touch the board, the ledger or anything the player has accepted -
## it is the same roster the wanted posters are printed from.
func _gather_targets() -> Array[BountyTarget]:
	var ledger := get_node_or_null(^"/root/Bounties")
	if ledger == null or not ledger.has_method(&"get_settings"):
		return []

	var settings := ledger.call(&"get_settings") as BountySettings
	return [] if settings == null else settings.targets


## The scene a boss is built out of - the ordinary enemy, because that is what a
## mini boss is. Taken from the director's own spawner so the two cannot disagree.
func _boss_body(_director: MiniBossDirector) -> PackedScene:
	var spawner := _get_spawner()
	return null if spawner == null else spawner.enemy_scene


## Builds [param entry] at [param point], in world space, and returns it.
##
## Public and separate from the click that asked for it, so a scripted test can lay
## out a formation without a mouse.
func spawn_entry(entry: TestSpawnEntry, point: Vector2) -> Node2D:
	if entry == null or entry.scene == null:
		return null

	var spawner := _get_spawner()
	if spawner == null:
		return null

	# The spawner builds whichever scene it is holding, so a roster with more than
	# one enemy scene in it is served by lending it this entry's for one call and
	# handing its own straight back. Synchronous, so nothing can spawn in between.
	var lent := spawner.enemy_scene
	if entry.scene != lent:
		spawner.enemy_scene = entry.scene
	var body := spawner.spawn_at(point)
	spawner.enemy_scene = lent

	if body == null:
		return null

	_adopt(body)
	if entry.is_boss():
		_dress_as_boss(body, entry)
	return body


## Taken into the test map's own container and marked as ours.
##
## [b]The move matters.[/b] The spawner parents into the run's [code]Enemies[/code]
## node, and things that persist in there are things [ArenaPortal] waits on before it
## will open - so a test enemy left there would hold the next round's portal shut.
func _adopt(body: Node2D) -> void:
	body.add_to_group(spawned_group)
	if _container != null and is_instance_valid(_container) and body.get_parent() != _container:
		body.reparent(_container, true)
		# Physics interpolation is on project-wide; without this the body is smeared
		# in from wherever the container sat last frame.
		body.reset_physics_interpolation()


## Grows the body to the rung's size, gives it the rung's pace and puts the outlaw's
## face on it - the three things that make an ordinary enemy a mini boss.
##
## Every number is read off the [MiniBossDirector] the world is already carrying, so
## retuning a boss retunes the test one too. What is [i]not[/i] done is the
## encounter: see this class's own notes.
func _dress_as_boss(body: Node2D, entry: TestSpawnEntry) -> void:
	var tier := entry.tier
	if tier == null:
		return

	body.scale = Vector2.ONE * maxf(tier.scale_multiplier, 0.01)

	var director := MiniBossDirector.get_active(self)
	var pace := tier.speed_multiplier
	if pace <= 0.0:
		pace = director.boss_speed_multiplier if director != null else 1.0
	if "speed" in body:
		body.speed = float(body.speed) * maxf(pace, 0.01)
	if director != null and "contact_damage" in body:
		body.contact_damage = maxf(director.boss_contact_damage, 0.0)

	if not is_equal_approx(boss_health_multiplier, 1.0):
		var health := _find_health(body)
		if health != null:
			# Filled to the new ceiling, so he arrives whole - the same way the
			# director builds one.
			health.set_max_health(
				health.get_authored_max_health() * maxf(boss_health_multiplier, 0.01), true)

	if director == null or director.wardrobe == null:
		return

	var look := MiniBossAppearance.new()
	look.name = "MiniBossAppearance"
	look.wardrobe = director.wardrobe
	look.look_key = entry.target.target_id if entry.target != null else &""
	body.add_child(look)


## How many test spawns are standing right now.
func count_spawned() -> int:
	return get_tree().get_nodes_in_group(spawned_group).size() if is_inside_tree() else 0


## Removes everything this station has put down, and nothing else. Returns how many
## went.
##
## [b]They are freed, not defeated.[/b] An [EnemyDefeat] is a death: it pays out
## blood, feeds the streak and leaves a body on the floor - so clearing a test map
## through it would put the developer's rubbish through the player's wallet. Freeing
## is the only ending that costs the game nothing.
##
## Only the group is touched, so the world's own enemies, props, pickups and
## everything else the map is made of are untouched by definition.
func clear_spawned() -> int:
	if not is_inside_tree():
		return 0

	var doomed := get_tree().get_nodes_in_group(spawned_group)
	for node: Node in doomed:
		if is_instance_valid(node):
			node.queue_free()

	if not doomed.is_empty():
		cleared.emit(doomed.size())
	return doomed.size()


func _on_entry_chosen(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return

	var entry := _entries[index]
	var placer := _get_placer()
	if placer == null:
		return

	var menu := _get_menu()
	# The placer calls its builder with the clicked point and nothing else - see
	# [method TestPlacer.begin] - while building one of these needs the entry as well.
	# [method Callable.bind] appends rather than prepends, so a bound entry arrived as
	# `spawn_entry(point, entry)` and the click died on the type check. The entry is
	# carried in by a closure instead, which leaves the public signature - the entry
	# first, the point second - the one a scripted caller reads, and leaves the placer
	# knowing nothing about what it is placing.
	var build := func(point: Vector2) -> Node2D: return spawn_entry(entry, point)
	if placer.begin(build, entry.label):
		if menu != null:
			menu.minimise(entry.label)
	elif menu != null:
		menu.close()


func _on_clear_requested() -> void:
	var removed := clear_spawned()
	var menu := _get_menu()
	if menu != null:
		# Reported back with the count already at zero, so the button reads the world
		# rather than what it thinks it just did.
		menu.report_cleared(removed, 0)


func _process(_delta: float) -> void:
	_watch_player()


## The prompt is told rather than asked, and only on the crossing, so it is not
## rewritten every frame.
func _watch_player() -> void:
	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	var reach := is_in_reach(body)
	if reach == _in_reach:
		return

	_in_reach = reach
	if _prompt != null:
		_prompt.set_prompt_visible(_in_reach)
	if _in_reach:
		player_entered.emit()
	else:
		player_exited.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _in_reach:
		return
	if not event.is_action_pressed(interact_action):
		return

	use()
	get_viewport().set_input_as_handled()


func _get_menu() -> TestSpawnMenu:
	if _menu == null or not is_instance_valid(_menu):
		_menu = TestSpawnMenu.get_active(self)
	return _menu


func _get_placer() -> TestPlacer:
	if _placer == null or not is_instance_valid(_placer):
		_placer = TestPlacer.get_active(self)
	return _placer


## The world's spawner: the grouped one where somebody has grouped it, and otherwise
## whichever one the running scene is carrying. Cached, because the fallback is a
## tree search and the answer does not change while a world is up.
func _get_spawner() -> EnemySpawner:
	if _spawner != null and is_instance_valid(_spawner):
		return _spawner
	if not is_inside_tree():
		return null

	_spawner = get_tree().get_first_node_in_group(spawner_group) as EnemySpawner
	if _spawner != null:
		return _spawner

	var root := get_tree().current_scene
	if root == null:
		return null
	for node: Node in root.find_children("*", "EnemySpawner", true, false):
		_spawner = node as EnemySpawner
		if _spawner != null:
			return _spawner
	return null


## Found by type rather than by a fixed child name, the same way every other system
## that reaches into an enemy finds its pool.
func _find_health(body: Node) -> Health:
	for node: Node in body.find_children("*", "Health", true, false):
		var health := node as Health
		if health != null:
			return health
	return null


func _scene_name(scene: PackedScene) -> String:
	if scene == null:
		return "?"
	var path := scene.resource_path
	return scene.resource_name if path.is_empty() else path.get_file().get_basename()
