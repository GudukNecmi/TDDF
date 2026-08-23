class_name RevolverChambers
extends Control
## The revolver's cylinder, drawn from behind at the foot of the screen.
##
## It is the ammunition readout for this weapon, and it says something the number
## in the corner cannot: *which* chambers are loaded. A revolver holding three
## rounds behind the hammer and a revolver holding three in front of it are the
## same number and completely different situations, and the player can see the
## difference here at a glance.
##
## [b]The top of the ring is the live chamber, always.[/b] The cylinder turns
## under it - one sixth of a turn per shot - rather than a marker moving around a
## still cylinder, which is what a real one does and what makes the rotation worth
## drawing at all.
##
## It reads the weapon and never writes to it. The chambers it draws are whatever
## the revolver last announced, so the display cannot drift out of step with the
## weapon, and a world with no revolver in it simply shows nothing.
##
## The art is inspector fields, so the cylinder plate, a loaded chamber and an
## empty one are three textures that can be replaced without touching this.

## Where the weapon is found. Nothing is drawn until one appears, and the display
## follows a weapon that is swapped in later.
@export var mount_group: StringName = &"weapon_mount"

@export_group("Layout")
## How far each chamber sits from the middle of the plate, in pixels.
@export var chamber_radius: float = 34.0
## Size each chamber is drawn at, in pixels.
@export var chamber_size := Vector2(26.0, 26.0)
## The plate the chambers sit on. Optional - without one the chambers float.
@export var plate_path: NodePath = ^"Plate"
## Size the plate is drawn at.
@export var plate_size := Vector2(104.0, 104.0)

@export_group("Art")
## A chamber with a round in it.
@export var loaded_texture: Texture2D
## A chamber that has been fired, or has not been loaded yet.
@export var empty_texture: Texture2D
## Tint over a loaded chamber.
@export var loaded_tint := Color(1.0, 0.92, 0.72)
## Tint over an empty one. Darker, so a spent cylinder reads as spent from across
## the screen.
@export var empty_tint := Color(0.45, 0.35, 0.33, 0.9)

@export_group("Motion")
## How long the cylinder takes to turn one chamber, in seconds.
@export var turn_time: float = 0.12
## How much a chamber swells as its round goes in, as a fraction. The one bit of
## motion that is not the turn, and it is what makes a reload visible when the
## cylinder is not moving.
@export var load_pop_scale: float = 1.35
@export var load_pop_time: float = 0.14

@onready var _plate: Control = get_node_or_null(plate_path) as Control

var _weapon: Revolver
var _chambers: Array[bool] = []
var _slots: Array[TextureRect] = []
var _turn_tween: Tween
## How far the ring has been turned, in whole chambers.
var _turned: int = 0


func _ready() -> void:
	if _plate != null:
		_plate.size = plate_size
		_plate.position = -plate_size * 0.5
	_find_weapon()


## The weapon is looked for every frame until one is found, and again if the one
## being watched goes away - the world is rebuilt between rounds and the revolver
## comes back as a different node.
func _process(_delta: float) -> void:
	if _weapon == null or not is_instance_valid(_weapon):
		_find_weapon()


func _find_weapon() -> void:
	var mount := get_tree().get_first_node_in_group(mount_group) as WeaponMount
	var weapon := mount.get_weapon() as Revolver if mount != null else null
	if weapon == null:
		_weapon = null
		visible = false
		return
	if weapon == _weapon:
		return

	_weapon = weapon
	visible = true
	_weapon.chambers_changed.connect(_on_chambers_changed)
	_weapon.cylinder_turned.connect(_on_cylinder_turned)
	_weapon.chamber_loaded.connect(_on_chamber_loaded)
	_build(_weapon.get_chambers())


## One slot per chamber, laid out around the ring and never rebuilt again - a
## shot changes what a slot is *showing*, not how many there are.
func _build(chambers: Array[bool]) -> void:
	for slot: TextureRect in _slots:
		slot.queue_free()
	_slots.clear()

	_chambers = chambers
	for i in _chambers.size():
		var slot := TextureRect.new()
		slot.custom_minimum_size = chamber_size
		slot.size = chamber_size
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.pivot_offset = chamber_size * 0.5
		add_child(slot)
		_slots.append(slot)

	_place_slots(0.0)
	_refresh()


## Puts every slot on the ring, with the whole ring turned by [param turn]
## chambers.
##
## [b]A slot is a hole in the metal, not a round.[/b] Slot 3 is the same piece of
## the cylinder before and after a shot - it has simply moved round - so the
## slots are placed by *subtracting* the turn, which walks the whole ring past the
## top rather than moving the contents between fixed holes. That is the difference
## between a cylinder that rotates and a row of lights that shift along.
func _place_slots(turn: float) -> void:
	var count := maxi(_slots.size(), 1)
	var step := TAU / float(count)
	for i in _slots.size():
		var angle := -PI * 0.5 + step * (float(i) - turn)
		var at := Vector2(cos(angle), sin(angle)) * chamber_radius
		_slots[i].position = at - chamber_size * 0.5


## What each hole is holding.
##
## The weapon keeps its ring with the live chamber always first, so the hole that
## has turned to the top is the one showing the weapon's chamber 0, and every
## other hole is read back from there. That mapping is the whole reason the
## display can never disagree with the gun.
func _refresh() -> void:
	var count := maxi(_slots.size(), 1)
	for i in _slots.size():
		var logical := posmod(i - _turned, count)
		var loaded: bool = logical < _chambers.size() and _chambers[logical]
		_slots[i].texture = loaded_texture if loaded else empty_texture
		_slots[i].modulate = loaded_tint if loaded else empty_tint
func _on_chambers_changed(chambers: Array[bool]) -> void:
	if chambers.size() != _slots.size():
		_build(chambers)
		return
	_chambers = chambers
	_refresh()


func _on_cylinder_turned(_top_chamber: int) -> void:
	_turned += 1
	if _turn_tween != null and _turn_tween.is_running():
		_turn_tween.kill()

	# Animated by walking the placement rather than rotating the node, because the
	# chambers must stay upright as the cylinder turns - a rotated node would spin
	# the rounds with it.
	var from := float(_turned - 1)
	var to := float(_turned)
	if turn_time <= 0.0:
		_place_slots(to)
		return

	_turn_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_turn_tween.tween_method(_place_slots, from, to, turn_time)


## The round going in is punched rather than merely appearing, so a reload is
## visible even though the cylinder has not moved. [param chamber] is the weapon's
## own index, so it is mapped back to the hole standing there now.
func _on_chamber_loaded(chamber: int) -> void:
	if _slots.is_empty() or load_pop_scale <= 1.0:
		return

	var slot := _slots[posmod(chamber + _turned, _slots.size())]
	slot.scale = Vector2.ONE * load_pop_scale
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(slot, "scale", Vector2.ONE, maxf(load_pop_time, 0.0001))
