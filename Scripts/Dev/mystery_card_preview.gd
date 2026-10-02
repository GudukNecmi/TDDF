extends Node
## Windowed preview of the Mystery ? cards on the real Loot Screen, inside the
## real [code]RunHUD[/code] - so the game's own [GameCursor] is the pointer - with
## a Bounty Boss's three ? for the equipped weapon. For looking at the reveal,
## the hover lean and glare, the rarity colours and particles, and hearing the
## flip and stingers. Run the scene from the editor; nothing here is gameplay.

@export var hud_scene: PackedScene
@export var source: LootSourceMysteryCards
## The point kind the table is dealt for - bounty is three ?.
@export var site_kind: StringName = &"bounty"
## The weapon the cards are for, by id.
@export var weapon_id: StringName = &"shotgun"


func _ready() -> void:
	var hud := hud_scene.instantiate()
	add_child(hud)
	await get_tree().process_frame
	var loot := hud.find_child("LootScreen", true, false) as LootScreen
	var session := get_node_or_null(^"/root/RunSession") as RunSessionState
	var weapon: WeaponDefinition = null
	if session != null and session.get_weapon_catalog() != null:
		weapon = session.get_weapon_catalog().find(weapon_id)
	var context := LootContext.create(self, null, site_kind)
	var bundle := LootBundle.new()
	bundle.context = context
	source.contribute(bundle, context)
	for reward: LootReward in bundle.rewards:
		if reward is LootRewardMystery and weapon != null:
			(reward as LootRewardMystery).weapon = weapon
	loot.present(bundle)
