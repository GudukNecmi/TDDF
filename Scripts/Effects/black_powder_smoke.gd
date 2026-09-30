class_name BlackPowderSmoke
extends Node2D
## The cloud a BLACK POWDER shot leaves where it was fired from - see [BlackPowder].
##
## [b]It is only the cloud.[/b] It draws itself, lasts its time and answers one
## question - whether a point is hidden inside it, see [method conceals_point]. What
## hiding does to the enemies is [PlayerStealth]'s, which finds every live cloud
## through [constant GROUP] and reads the perception numbers off the [BlackPowder]
## that made it - see [method get_powder].
##
## [b]The characters stand inside it.[/b] The node sits at [member CanvasItem.z_index]
## 12 - over every body at 0, so the player reads as standing in the smoke, seen
## through it, and under [PlayerStealth]'s white, yellow and red marks at 13, which are
## drawn over it untouched. The player's own artwork is never changed; only how much
## of it the smoke covers is, and that is capped at [member smoke_opacity].
##
## The drawing is only the shared smoke puffs from
## [code]Assets/Efects/Boom Efects[/code], tinted dark red and drifting, inside one
## [CanvasGroup]. Overlapping puffs are merged into one shape before they are faded,
## so the cloud is never thicker than [member smoke_opacity] however many of them
## pile up in one place. Nothing here reads the screen: a shimmer that redrew a copy
## of it over the disc is what used to paint the cloud opaque whenever the frame's
## copy had been taken before the characters were drawn.

## Group every live cloud is in.
const GROUP := &"black_powder_smoke"

@export_group("Size")
## Radius and lifetime used when no [BlackPowder] configures the cloud - one dropped
## into a scene by hand. A shot always hands its own over - see [method configure].
@export var radius: float = 150.0
## Radius the player hides inside, used the same way - a little wider than the
## smoke drawn. See [member BlackPowder.stealth_radius].
@export var stealth_radius: float = 190.0
@export var duration: float = 4.5
## Seconds the cloud takes to billow out to full size and thickness.
@export var grow_time: float = 0.35
## Seconds at the end of [member duration] it spends thinning away.
@export var fade_time: float = 0.9
## How big the cloud starts, as a share of its full size.
@export_range(0.0, 1.0, 0.01) var start_scale: float = 0.55
## How thick the cloud must be, 0..1, before it hides anybody. It stops hiding the
## moment it starts to thin out at the end, however thick it still looks.
@export_range(0.0, 1.0, 0.01) var conceal_threshold: float = 0.6

@export_group("Nodes")
## The [CanvasGroup] the puffs are merged in.
@export var puffs_path: NodePath = ^"Puffs"
## The cloud's own powder fizz - a [LoopingSound], so its volume and how fast it
## fades are that node's Inspector values. One per cloud: it starts with the cloud,
## runs for its whole life and fades as the cloud ends.
@export var sound_path: NodePath = ^"Fizz"

@export_group("Puffs")
## The puff artwork, one picked at random per puff.
@export var puff_textures: Array[Texture2D] = []
@export var puff_count: int = 16
## How wide one puff is drawn, as a share of the cloud's radius.
@export var puff_size: float = 0.9
## How much of a puff texture the smoke itself fills, so [member puff_size] is the
## size of the smoke rather than of the picture around it.
@export_range(0.05, 1.0, 0.01) var puff_texture_fill: float = 0.6
## How far out from the middle the puffs are scattered, as a share of the radius.
@export_range(0.0, 1.0, 0.01) var puff_spread: float = 0.72
## How fast the puffs creep outward, in pixels per second, and spin, in radians per
## second either way.
@export var puff_drift: float = 7.0
@export var puff_spin: float = 0.25
## The puffs' colour - a dark blood red. Its alpha is not used; see
## [member smoke_opacity].
@export var smoke_tint := Color(0.42, 0.13, 0.13, 1.0)
## How see-through the whole cloud is at full thickness, 0..1 - the most it can ever
## cover, however the puffs overlap. It only ever rises and falls with the normal
## billowing in and thinning away.
@export_range(0.0, 1.0, 0.01) var smoke_opacity: float = 0.32
## How much lighter single puffs are than the merged middle, 0..1, so the edge of
## the cloud stays soft. Never adds to [member smoke_opacity].
@export_range(0.0, 1.0, 0.01) var tint_variation: float = 0.3

var _powder: BlackPowder
var _elapsed: float = 0.0
var _dissolving: bool = false
## How thick the cloud was when it was told to dissolve, and when that was.
var _dissolve_from: float = 0.0
var _dissolve_at: float = 0.0
var _group: CanvasItem
var _sound: LoopingSound
## True once the cloud has gone and only its fizz is still fading.
var _ended: bool = false
var _puffs: Array[Sprite2D] = []
var _puff_alpha: PackedFloat32Array = []
var _puff_spin: PackedFloat32Array = []
var _puff_home: PackedVector2Array = []


## Takes the size and lifetime from the [BlackPowder] that fired it. Called before
## the cloud enters the tree.
func configure(powder: BlackPowder) -> void:
	_powder = powder
	if powder != null:
		radius = maxf(powder.smoke_radius, 1.0)
		stealth_radius = maxf(powder.stealth_radius, 1.0)
		duration = maxf(powder.smoke_duration, 0.01)


## The [BlackPowder] that made this cloud, or null for one placed by hand.
func get_powder() -> BlackPowder:
	return _powder


func _ready() -> void:
	add_to_group(GROUP)
	_group = get_node_or_null(puffs_path) as CanvasItem
	_sound = get_node_or_null(sound_path) as LoopingSound
	if _sound != null:
		_sound.set_level(1.0)
	_make_puffs()
	_apply()


func _process(delta: float) -> void:
	if _ended:
		if _sound == null or not _sound.is_audible():
			queue_free()
		return
	_elapsed += delta
	if _elapsed >= duration or (_dissolving and _dissolve_progress() >= 1.0):
		_end()
		return
	for i in _puffs.size():
		var puff := _puffs[i]
		puff.rotation += _puff_spin[i] * delta
		_puff_home[i] += _puff_home[i].normalized() * puff_drift * delta
	_apply()


## How much of the cloud is there, 0..1 - billowing in, holding, thinning away.
func get_presence() -> float:
	var grow := clampf(_elapsed / maxf(grow_time, 0.001), 0.0, 1.0)
	var fade_start := maxf(duration - fade_time, 0.0)
	var fade := clampf((_elapsed - fade_start) / maxf(duration - fade_start, 0.001), 0.0, 1.0)
	return smoothstep(0.0, 1.0, grow) * (1.0 - smoothstep(0.0, 1.0, fade))


## Whether the cloud is thick enough to hide anybody right now.
func is_concealing() -> bool:
	if _dissolving or is_queued_for_deletion():
		return false
	if _elapsed >= maxf(duration - fade_time, 0.0):
		return false
	return get_presence() >= conceal_threshold


## Whether [param point] is hidden inside the cloud right now.
func conceals_point(point: Vector2) -> bool:
	return is_concealing() and global_position.distance_to(point) <= get_stealth_radius()


## The cloud's radius as it is now, grown or growing.
func get_current_radius() -> float:
	var grow := clampf(_elapsed / maxf(grow_time, 0.001), 0.0, 1.0)
	return radius * lerpf(start_scale, 1.0, smoothstep(0.0, 1.0, grow))


## How far from the middle the player hides right now - [member stealth_radius],
## growing in step with the drawn cloud.
func get_stealth_radius() -> float:
	return stealth_radius * get_current_radius() / maxf(radius, 1.0)


## Stops hiding anybody at once and thins away from however thick it is now across
## [member fade_time] - the Legendary switched off.
func dissolve() -> void:
	if _dissolving:
		return
	_dissolve_from = _visible_presence()
	_dissolve_at = _elapsed
	_dissolving = true


## Every live cloud under [param tree] thins away and stops hiding anybody.
static func dissolve_all(tree: SceneTree) -> void:
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group(GROUP):
		var cloud := node as BlackPowderSmoke
		if cloud != null:
			cloud.dissolve()


## How thick the cloud is drawn: its presence, or once dissolving, a steady thinning
## from wherever it was - never a jump back up.
func _visible_presence() -> float:
	if not _dissolving:
		return get_presence()
	var natural := get_presence()
	var thinned := _dissolve_from * (1.0 - smoothstep(0.0, 1.0, _dissolve_progress()))
	return minf(natural, thinned)


func _dissolve_progress() -> float:
	return clampf((_elapsed - _dissolve_at) / maxf(fade_time, 0.001), 0.0, 1.0)


func _make_puffs() -> void:
	if puff_textures.is_empty():
		return
	var into: Node = _group if _group != null else self
	for i in maxi(puff_count, 0):
		var texture: Texture2D = puff_textures[randi() % puff_textures.size()]
		if texture == null:
			continue
		var puff := Sprite2D.new()
		puff.texture = texture
		puff.rotation = randf() * TAU
		into.add_child(puff)
		# Square-root spread, so the puffs fill the disc evenly rather than bunching
		# in the middle.
		var home := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * puff_spread
		if home.is_zero_approx():
			home = Vector2.RIGHT * 0.01
		_puffs.append(puff)
		_puff_home.append(home * radius)
		_puff_spin.append(randf_range(-1.0, 1.0) * puff_spin)
		_puff_alpha.append(1.0 - randf() * tint_variation)


func _apply() -> void:
	var presence := _visible_presence()
	var grow := clampf(_elapsed / maxf(grow_time, 0.001), 0.0, 1.0)
	var size := lerpf(start_scale, 1.0, smoothstep(0.0, 1.0, grow))
	for i in _puffs.size():
		var puff := _puffs[i]
		var width := maxf(float(puff.texture.get_width()) * puff_texture_fill, 1.0)
		puff.scale = Vector2.ONE * (radius * puff_size * size / width)
		puff.position = _puff_home[i] * size
		# Opaque inside the group, so the merged shape is the cloud's whole coverage;
		# how see-through it is is decided once, on the group, below.
		puff.modulate = Color(smoke_tint.r, smoke_tint.g, smoke_tint.b, _puff_alpha[i])
	var opacity := clampf(smoke_opacity, 0.0, 1.0) * presence
	if _group != null:
		_group.modulate = Color(1.0, 1.0, 1.0, opacity)
	else:
		for puff: Sprite2D in _puffs:
			puff.modulate.a *= opacity


## The cloud is gone: nothing is drawn and nobody hides in it any more, and the node
## only stays until its fizz has faded out - see [member sound_path].
func _end() -> void:
	_ended = true
	remove_from_group(GROUP)
	for puff: Sprite2D in _puffs:
		puff.visible = false
	if _sound == null:
		queue_free()
		return
	_sound.set_level(0.0)
