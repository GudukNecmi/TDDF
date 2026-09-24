class_name WeaponDefinition
extends Resource
## One weapon the player can take out on a run.
##
## Built the same way [MapDefinition] is, and for the same reason: the roster is
## an inspector array rather than a list in a script, so adding a third weapon is
## dropping a [code].tres[/code] into [WeaponCatalog] and nothing else. No file
## anywhere names the shotgun or the rifle, which is what stops the selection
## screen from having to be rewritten every time a weapon is added.
##
## What a weapon *is* is its scene. This resource is only the roster entry - the
## name on the button, whether it can be taken, and which scene to build when it
## is - so the weapon itself stays one self-contained scene with its own
## mechanism, its own feedback and its own magazine.

## The handle the rest of the game uses. What [RunSessionState] stores when the
## player picks it, and what the world's [WeaponMount] matches against to know
## what to build. Never shown.
@export var weapon_id: StringName = &"weapon"
## What the player is shown it is called, in the selection screen.
@export var display_name: String = "WEAPON"
## One line under the name, for what makes this weapon different from the others.
## Left empty, nothing is shown.
@export var description: String = ""
## The weapon itself: the scene built into the world when this is the one chosen.
## It must extend [CarriedWeapon], which is what lets the player's hands, the
## holster and the loadout treat every weapon the same way.
@export var scene: PackedScene
## The ammunition it feeds on, for a shop or a readout that wants to name it
## without the weapon being in the tree. The weapon's own [WeaponAmmo] is still
## what actually holds the rounds; this is a label, not a second source.
@export var ammo_type: AmmoType
## Whether the weapon can be picked. A locked weapon is still listed - seeing what
## is coming is the point - but cannot be selected and is drawn dimmed, exactly as
## a locked map is.
@export var unlocked: bool = true
## What a locked entry says instead of being selectable.
@export var locked_label: String = "LOCKED"
## Optional picture for the entry.
@export var icon: Texture2D
## What unlocking it costs at the Base's BUY WEAPON screen, in banked blood. A
## weapon that is already [member unlocked] is owned and never asks for it.
@export var purchase_cost: int = 0

@export_group("Upgrades")
## The common upgrades the Base's UPGRADE screen offers for this weapon, in card
## order. Leaving one out is how a weapon goes without it - a shotgun with no
## magazine is offered ammo capacity alone.
@export var upgrades: Array[WeaponUpgrade] = []
## Chance, 0..1, that an attack with this weapon is a critical hit before any
## upgrade. Rolled once per attack, never per pellet.
@export_range(0.0, 1.0) var base_critical_chance: float = 0.0
## What a critical hit's damage is multiplied by before any upgrade.
@export var base_critical_multiplier: float = 1.5

## Levels bought, by [member WeaponUpgrade.id]. Kept on the loaded resource the
## same way [member unlocked] is - [RunSessionState] holds the catalogue for the
## life of the game - so the weapon itself is the record of what was bought.
var _upgrade_levels: Dictionary[StringName, int] = {}
## Levels bought for this run only - at a run map market - by
## [member WeaponUpgrade.id]. Stacked on top of the Base levels in
## [method get_stats] and forgotten when the run begins or ends; see
## [method clear_run_levels].
var _run_levels: Dictionary[StringName, int] = {}
## Modifiers from anything other than the Base upgrades - a card, a unique
## upgrade - keyed by whatever granted them, so each source can be replaced or
## withdrawn on its own. Nothing sets any today.
var _extra_modifiers: Dictionary[StringName, Array] = {}
## Rebuilt on demand after anything above changes.
var _stats: WeaponStats


## Every stat change this weapon currently carries, summed. The one thing the
## combat code reads - see [WeaponStats].
func get_stats() -> WeaponStats:
	if _stats == null:
		_stats = WeaponStats.new()
		_stats.base_critical_chance = base_critical_chance
		_stats.base_critical_multiplier = base_critical_multiplier
		for upgrade: WeaponUpgrade in upgrades:
			if upgrade != null:
				upgrade.apply_to(_stats, get_upgrade_level(upgrade) + get_run_level(upgrade))
		for modifiers: Array in _extra_modifiers.values():
			for modifier: WeaponStatModifier in modifiers:
				_stats.add_modifier(modifier)
	return _stats


func get_upgrade_level(upgrade: WeaponUpgrade) -> int:
	if upgrade == null:
		return 0
	return _upgrade_levels.get(upgrade.id, 0)


## Raises [param upgrade] one level, if this weapon offers it and it is not
## maxed. Returns whether it went. Paying for it is the caller's business.
func raise_upgrade(upgrade: WeaponUpgrade) -> bool:
	if upgrade == null or not upgrades.has(upgrade):
		return false
	var level := get_upgrade_level(upgrade)
	if level >= upgrade.max_level:
		return false
	_upgrade_levels[upgrade.id] = level + 1
	_stats_changed()
	return true


## How many run-only levels of [param upgrade] this run has bought.
func get_run_level(upgrade: WeaponUpgrade) -> int:
	if upgrade == null:
		return 0
	return _run_levels.get(upgrade.id, 0)


## Raises [param upgrade] one run-only level, if this weapon offers it and the run
## stack is under [param cap] (negative is no cap). Returns whether it went.
## Paying for it is the caller's business, exactly as with [method raise_upgrade].
func raise_run_level(upgrade: WeaponUpgrade, cap: int = -1) -> bool:
	if upgrade == null or not upgrades.has(upgrade):
		return false
	var level := get_run_level(upgrade)
	if cap >= 0 and level >= cap:
		return false
	_run_levels[upgrade.id] = level + 1
	_stats_changed()
	return true


## Forgets every run-only level. Called by [RunSessionState] as a run begins and
## ends, so nothing bought at a market outlives the run it was bought in.
func clear_run_levels() -> void:
	if _run_levels.is_empty():
		return
	_run_levels.clear()
	_stats_changed()


## Sets the modifiers granted by [param source], replacing whatever it granted
## before; an empty array withdraws them. The hook a card or a unique weapon
## upgrade uses to change the same stats the Base upgrades do.
func set_modifier_source(source: StringName, modifiers: Array[WeaponStatModifier]) -> void:
	if modifiers.is_empty():
		_extra_modifiers.erase(source)
	else:
		_extra_modifiers[source] = modifiers.duplicate()
	_stats_changed()


## Forgets every level bought and every extra source. For a new save or a debug
## reset, the same as [method AmmoLocker.reset].
func reset_upgrades() -> void:
	_upgrade_levels.clear()
	_run_levels.clear()
	_extra_modifiers.clear()
	_stats_changed()


## Pushes this weapon's ammo capacity bonus onto the reserve [param locker] keeps
## for its [member ammo_type] - the capacity hook the reserve was built with. Run
## whenever the bonus may have moved, so a refill on setting out fills to the
## upgraded ceiling.
func sync_ammo_capacity(locker: AmmoLocker) -> void:
	if locker == null or ammo_type == null:
		return
	var reserve := locker.get_reserve(ammo_type)
	if reserve != null:
		reserve.set_capacity_bonus(get_stats().ammo_capacity_bonus())


func _stats_changed() -> void:
	_stats = null
	emit_changed()


## Whether the player owns this weapon. Owning it and being able to pick it are
## the same thing - [member unlocked] - so buying a weapon is nothing more than
## unlocking it, and the selection screen needs no idea a shop exists.
func is_owned() -> bool:
	return unlocked


## Buys the weapon out of [param wallet] and unlocks it. The wallet decides
## whether it can be afforded, as it does for every other purchase; an owned
## weapon is never sold twice. A free weapon unlocks without touching the wallet.
func purchase(wallet: BloodWallet) -> bool:
	if unlocked or wallet == null:
		return false
	if purchase_cost > 0 and not wallet.spend(purchase_cost):
		return false
	unlocked = true
	emit_changed()
	return true
