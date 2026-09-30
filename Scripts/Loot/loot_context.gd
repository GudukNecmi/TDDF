class_name LootContext
extends RefCounted
## What a [LootSource] and a [LootReward] are handed to do their work: a node in
## the scene to look things up from, the fight's bridge, and the run map point
## kind the fight was opened from.
##
## [b]It is information, never a switch.[/b] Nothing on the Loot Screen reads
## [member site_kind]; a source may, to decide whether it pays (see
## [member RunMapUpgradeReward.site_kinds]), which keeps "which encounter pays
## what" in the data that already says so.

## A node inside the running scene, for group and autoload lookups. Always the
## [PostCombatLootDirector] that built the bundle.
var host: Node
## The fight's bridge. Null for a bundle opened outside a fight (a smoke check).
var bridge: WorldMapCombatBridge
## [member RunMapSite.kind] as it stood before the fight cleared it. Empty for a
## fight that was not opened from a run map point.
var site_kind: StringName = &""
## The generator every roll made for this bundle is taken from.
var rng: RandomNumberGenerator


static func create(host_node: Node, fight_bridge: WorldMapCombatBridge,
		kind: StringName) -> LootContext:
	var context := LootContext.new()
	context.host = host_node
	context.bridge = fight_bridge
	context.site_kind = kind
	context.rng = RandomNumberGenerator.new()
	context.rng.randomize()
	return context
