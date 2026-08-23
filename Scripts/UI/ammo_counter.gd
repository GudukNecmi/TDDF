class_name AmmoCounter
extends HBoxContainer
## Shows how many rounds the weapon in the player's hands has left: "47 / 60".
##
## It reads the [code]Ammo[/code] locker ([AmmoLocker]) and nothing else, exactly
## as [BloodCounterLabel] reads the wallet. It never counts anything itself, so it
## cannot drift from the real total, and because the locker outlives the scene the
## number is already right on the first frame of a new round rather than starting
## from the weapon's capacity.
##
## [b]It follows the equipped weapon rather than any particular gun.[/b] Two
## signals drive it and there is no polling: [signal AmmoLocker.ammo_changed]
## for a round spent or bought, and [signal AmmoLocker.equipped_changed] for the
## player picking up a different weapon. A pistol swapped in later shows its own
## count, in its own capacity, with nothing here changed - the counter never
## learns which weapons exist.
##
## [b]Where the look lives.[/b] Everything about how it is drawn is an ordinary
## node property on this container and its three labels, so it is all tunable in
## the inspector without a script field mirroring it:
##
##   * [b]Position and size[/b] - this container's anchors and offsets. It is
##     anchored to the bottom-right corner, so the offsets are the margin from
##     that corner and the counter stays put at any window size.
##   * [b]Spacing[/b] - this container's [code]separation[/code] constant, the gap
##     between the count, the slash and the capacity.
##   * [b]Outline, colour and font size[/b] - each label's own theme overrides.
##     The three are separate labels precisely so the live count can be the loud
##     one and the capacity can sit back, which is what makes the pair readable at
##     a glance.
##   * [b]The divider[/b] - the text authored on the middle label, so it can be a
##     slash, a dash or nothing at all. Nothing in this file writes to it.
##
## What is exported here is only what is not a node property: which labels to
## write into, and the nudge the number gives when it changes.

## The locker this mirrors, reached by path exactly as [BloodCounterLabel]
## reaches the wallet.
@export var locker_path: NodePath = ^"/root/Ammo"
## The live count - the number that moves.
@export var current_label_path: NodePath = ^"Current"
## The capacity, including anything a weapon shop has added to it.
@export var max_label_path: NodePath = ^"Max"
## Optional label naming the ammunition - "SHELLS", "RIFLE ROUNDS" - taken from
## the equipped weapon's [AmmoType]. Left empty, no name is shown; the counter
## is the two numbers on their own.
@export var name_label_path: NodePath
## Whether the counter disappears when the player has no weapon in hand. On, so
## an empty-handed player is not shown a count of nothing.
@export var hide_without_weapon: bool = true

@export_group("Pulse")
## How much larger the count gets at the peak of a resupply. Kept small - this is
## a nudge, not a jump.
@export var pulse_scale: float = 1.16
@export var pulse_out_time: float = 0.06
@export var pulse_back_time: float = 0.14

@onready var _locker: AmmoLocker = get_node_or_null(locker_path) as AmmoLocker
@onready var _current: Label = get_node_or_null(current_label_path) as Label
@onready var _max: Label = get_node_or_null(max_label_path) as Label
@onready var _name: Label = get_node_or_null(name_label_path) as Label

## What is on screen right now, so a change can be told from a resupply without
## asking the locker what it used to be.
var _shown: int = -1
var _pulse_tween: Tween


func _ready() -> void:
	_centre_pivot()
	resized.connect(_centre_pivot)

	if _locker == null:
		visible = not hide_without_weapon
		return

	_locker.ammo_changed.connect(_on_ammo_changed)
	_locker.equipped_changed.connect(_on_equipped_changed)
	# Refreshed rather than assumed: the weapon may have claimed the equipped slot
	# before this ran, in which case its signal has already been and gone.
	_refresh()


## Scaling happens around the middle of the counter rather than its top-left
## corner, so a pulse grows the number in place instead of shoving it sideways.
func _centre_pivot() -> void:
	pivot_offset = size * 0.5


## Ignores every weapon but the one in hand, so a reserve being topped up
## elsewhere - a shop restocking a holstered gun later - cannot flicker the
## wrong number onto the screen.
func _on_ammo_changed(ammo_id: StringName, _current_rounds: int, _maximum: int) -> void:
	if ammo_id != _locker.get_equipped_id():
		return
	_refresh()


## A different weapon is in hand. The count is replaced outright and silently -
## picking up a full pistol is not a resupply of the shotgun, so it must not
## pulse.
func _on_equipped_changed(_ammo_id: StringName) -> void:
	_shown = -1
	_refresh()


## The one place the display is written, driven off the locker rather than off
## whatever caused the change - so however the count moved, what is on screen is
## the real one.
func _refresh() -> void:
	var reserve := _locker.get_equipped_reserve()
	if reserve == null:
		_shown = -1
		if hide_without_weapon:
			visible = false
		return

	visible = true
	var rounds := reserve.get_current()

	if _current != null:
		_current.text = str(rounds)
	if _max != null:
		_max.text = str(reserve.get_max())
	if _name != null:
		var type := reserve.get_type()
		_name.text = type.get_plural_name().to_upper() if type != null else ""

	# Only a gain pulses, exactly as the blood counter only celebrates blood
	# coming in. Firing is felt through the weapon; it does not need the HUD to
	# flinch as well. A first fill - _shown of -1 - is the counter appearing
	# rather than the player being resupplied, so it is silent too.
	if _shown >= 0 and rounds > _shown:
		_play_pulse()
	_shown = rounds


## Restarts from the resting scale every time, so a stream of purchases cannot
## stack the pulses or leave the number permanently enlarged.
func _play_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_running():
		_pulse_tween.kill()

	scale = Vector2.ONE
	_pulse_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE * pulse_scale, pulse_out_time) \
		.set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, pulse_back_time) \
		.set_ease(Tween.EASE_IN)
