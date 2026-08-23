class_name PlayerLoadout
extends Node
## What the player is holding, decided by where they are standing.
##
## In the arena they carry the shotgun. In the base they carry nothing at all:
## the weapon is stowed and an ordinary pair of hands is shown instead. Walking
## back out hands both back exactly as they were.
##
## The decision is not made here. It is read off whichever [WorldZone] the player
## is in, so somewhere new that disarms them is a rectangle drawn in the editor
## rather than a branch added to this file.
##
## Nothing is reimplemented either. The weapon goes away through its own
## [method Node2D.stow] - which keeps it following the player, keeps it aiming
## and keeps its half-finished pump exactly where it was - and the hands are a
## node that is shown or hidden. This component owns only the *decision* and the
## fade, which is why switching it off leaves the player permanently armed
## rather than permanently broken.

## Emitted as the player is disarmed or handed their weapon back.
signal loadout_changed(unarmed: bool)

## Body whose position picks the zone. Defaults to this component's parent.
@export var body_path: NodePath = ^".."
## The weapon put away, when there is no [WeaponMount] in the world to ask.
##
## The mount is the ordinary answer - it is what builds whichever weapon the
## player chose, so asking it is what makes this work for a weapon that did not
## exist when the player scene was authored. This path is only the fallback, for a
## test scene with a weapon dropped straight into it.
@export var weapon_path: NodePath = ^"../../Shotgun"
## The bare hands shown in its place. Their walking motion is a [LegAnimator]
## of their own, running whether they are visible or not, so they are already
## mid-stride the instant they appear.
@export var hands_path: NodePath = ^"../Visual/Hands"

@export_group("Timing")
## How long the weapon takes to shrink away to the belt on the way in.
@export var holster_time: float = 0.45
## How long it takes to come back out on the way out. A touch quicker than it
## went away, so leaving reads as arming up.
@export var draw_time: float = 0.35
## How long the bare hands fade in and out over, so neither pair pops.
@export var hands_fade_time: float = 0.3

@onready var _body: Node2D = get_node_or_null(body_path) as Node2D
@onready var _hands: CanvasItem = get_node_or_null(hands_path) as CanvasItem

var _unarmed: bool = false
var _hands_tween: Tween


## The starting loadout is applied without any of the motion: the player is
## already standing wherever they start, so a weapon sliding out of the belt on
## the first frame would be a transition that never happened.
func _ready() -> void:
	_unarmed = _should_be_unarmed()
	_apply(true)

	# The weapon is built by the [WeaponMount], which may not have run yet - and a
	# weapon that arrives after this has decided is a weapon nobody has stowed. So
	# the loadout is re-applied the moment one is built, which is what a weapon
	# swapped at the rack and a throwable picked up off the ground both come back
	# through.
	#
	# [b]The binding is deferred, and it has to be.[/b] The player is a child of the
	# world and the mount is its sibling, so this runs before the mount has joined
	# its group and asking for it here finds nothing - which left the signal
	# permanently unlistened to and every later swap unapplied.
	_watch_mount.call_deferred()


func _watch_mount() -> void:
	var mount := WeaponMount.get_active(self)
	if mount == null or mount.weapon_built.is_connected(_on_weapon_built):
		return
	mount.weapon_built.connect(_on_weapon_built)


## A weapon has just been put in the player's hands. Applied without any of the
## motion for the same reason the starting loadout is: it is appearing, not being
## drawn.
func _on_weapon_built(_weapon: Node) -> void:
	refresh(true)


func _process(_delta: float) -> void:
	var unarmed := _should_be_unarmed()
	if unarmed == _unarmed:
		return
	_unarmed = unarmed
	_apply(false)
	loadout_changed.emit(_unarmed)


## True while the player is standing empty-handed.
func is_unarmed() -> bool:
	return _unarmed


## Re-applies the loadout for wherever the player is standing right now.
##
## This is how anything that borrows the weapon hands it back: [PlayerDeathSequence]
## puts it away as the body goes down and calls this once the player is on their
## feet again, rather than drawing the weapon itself. There is still exactly one
## node deciding what the player is holding, so the two can never disagree about
## whether the shotgun should be out.
func refresh(instant: bool = false) -> void:
	_unarmed = _should_be_unarmed()
	_apply(instant)


func _should_be_unarmed() -> bool:
	var zone := WorldZone.get_zone_for(self, _body)
	return zone != null and zone.holster_weapons


func _apply(instant: bool) -> void:
	var weapon_time := 0.0 if instant else (holster_time if _unarmed else draw_time)

	var weapon := _get_weapon()
	if weapon != null:
		if _unarmed and weapon.has_method(&"stow"):
			weapon.call(&"stow", weapon_time)
		elif not _unarmed and weapon.has_method(&"unstow"):
			weapon.call(&"unstow", weapon_time)

	_show_hands(_unarmed, instant)


## Whatever is in the player's hands right now.
##
## Asked of the [WeaponMount] rather than held, because the weapon is built from
## the player's choice and can be replaced - a loadout holding a reference would
## be stowing a weapon that had already been thrown away. Nothing here knows which
## weapon it is: [method CarriedWeapon.stow] is the whole of the contract, so a
## weapon added later is put away by this without a line being touched.
func _get_weapon() -> Node2D:
	var mount := WeaponMount.get_active(self)
	if mount != null:
		var built := mount.get_weapon()
		if built != null:
			return built
	return get_node_or_null(weapon_path) as Node2D


## The hands are faded rather than switched, and hidden outright at the end of
## the fade so a pair the player is not using costs nothing to draw.
func _show_hands(shown: bool, instant: bool) -> void:
	if _hands == null:
		return

	if _hands_tween != null and _hands_tween.is_running():
		_hands_tween.kill()

	if instant or hands_fade_time <= 0.0:
		_hands.modulate.a = 1.0 if shown else 0.0
		_hands.visible = shown
		return

	# Shown before the fade starts rather than after it, so the hands are already
	# on screen to be faded up.
	if shown:
		_hands.visible = true

	_hands_tween = create_tween()
	_hands_tween.tween_property(_hands, "modulate:a", 1.0 if shown else 0.0, hands_fade_time)
	if not shown:
		_hands_tween.tween_callback(_hands.hide)
