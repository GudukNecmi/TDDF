class_name CombatLootDirector
extends Node
## Fills [WorldMapCombatBridge]'s [CombatLoot] the instant a bandit fight
## opens, so the right side of the Horse Cart already has something to show by
## the time a win reveals it.
##
## [b]It never touches the bridge.[/b] [WorldMapCombatBridge] is explicitly
## left alone by this pass - see the class doc on [method WorldMapCombatBridge.get_combat_loot]:
## "the container a later pass fills in, never this one". This is that later
## pass, and it reaches the bridge only through the seams it already offers
## everyone else: [signal WorldMapCombatBridge.encounter_started] to learn a
## fight has opened and [method WorldMapCombatBridge.get_combat_loot] to reach
## the very [CombatLoot] [HorseCartScreen] will read back out of the same
## bridge later. Nothing here is a second source of loot, and nothing here
## could ever race the bridge's own ending, because it never waits for one.
##
## [b]Rolled the instant the fight opens, not when it is won.[/b]
## [member WorldBanditEncounter.group_strength] - the battle's true, uncapped
## size - is already known the moment [signal WorldMapCombatBridge.encounter_started]
## fires, so there is nothing to gain by waiting for
## [signal WorldMapCombatBridge.encounter_ended] and every reason not to: that
## signal is also what opens [HorseCartScreen], and generating the loot in the
## same breath would be racing the very screen that reads it. A fight that ends
## in the player's own death simply leaves its rolled loot unread - the bridge
## opens a fresh, empty [CombatLoot] the next time a fight starts, so nothing
## is ever carried across encounters by accident.
##
## [b]Bandits only, today.[/b] A bounty camp's boss fight has no equivalent
## "authoritative battle size" to roll against - see [WorldBountyEncounter]'s
## own fields - and every worked example this pass was handed is a bandit
## group's own [code]group_strength[/code], so [signal WorldMapCombatBridge.boss_encounter_started]
## is deliberately left unheard. A boss fight's own reward stays exactly what
## it already was: the contract's payout, paid through [BountyLedger] the same
## way it always has been.

## The tuning ladder - see [CombatLootTable]. Loaded once on first use rather
## than in [method Node._ready], the same discipline [method BountyLedger.get_settings]
## already follows, so a missing or broken file fails soft into an empty
## table - every roll simply has nothing to give - instead of an error.
@export var table_path: String = "res://Resources/World/combat_loot_table.tres"
@export var bridge_path: NodePath = ^"../WorldMapCombatBridge"

var _table: CombatLootTable
var _bridge: WorldMapCombatBridge


func _ready() -> void:
	_bind_bridge.call_deferred()


func _process(_delta: float) -> void:
	if _bridge == null or not is_instance_valid(_bridge):
		_bind_bridge()


func get_table() -> CombatLootTable:
	if _table != null:
		return _table
	if ResourceLoader.exists(table_path):
		_table = load(table_path) as CombatLootTable
	if _table == null:
		push_warning("CombatLootDirector: no loot table at %s - fights will pay nothing." % table_path)
		_table = CombatLootTable.new()
	return _table


func _bind_bridge() -> void:
	_bridge = get_node_or_null(bridge_path) as WorldMapCombatBridge
	if _bridge == null:
		_bridge = WorldMapCombatBridge.get_active(self)
	if _bridge == null:
		return
	if not _bridge.encounter_started.is_connected(_on_encounter_started):
		_bridge.encounter_started.connect(_on_encounter_started)


## The fight has opened. Its [CombatLoot] is the bridge's own, fresh and empty
## the instant a fight begins - see [method WorldMapCombatBridge._begin_encounter] -
## so filling it here is filling exactly what [HorseCartScreen] will read once
## the win it is behind reveals the screen.
func _on_encounter_started(payload: WorldBanditEncounter) -> void:
	if payload == null or _bridge == null or not is_instance_valid(_bridge):
		return
	var loot := _bridge.get_combat_loot()
	if loot == null:
		return
	CombatLootGenerator.generate(payload.group_strength, loot, get_table())
