class_name CutawayBuilding
extends Node2D
## A building you can walk into: its exterior fades away and its interior fades
## in while the player is inside, and both swap back on the way out.
##
## Nothing here is specific to the saloon. A building is two lists of art and one
## entry area, so a tent, a shop front and a two-storey saloon are all the same
## component with different children - which is the point, since every shop in the
## base will eventually want an inside.
##
## It only ever writes [member CanvasItem.modulate] and [member CanvasItem.visible]
## on the nodes it is given, never their transforms, so art underneath is free to
## be animated, scaled or parallaxed without this fighting it. Visibility is
## switched at the ends of the fade rather than instead of it, so hidden art costs
## nothing to draw while still fading rather than popping.
##
## The interior is authored *visible* in the editor - that is the only way to lay
## an inside out and see it - and hidden on ready. What the editor shows is
## therefore the building opened up, which is the useful view while building one.

## Emitted as the player crosses in, before the fade has finished.
signal entered
## Emitted as the player crosses back out.
signal exited

## Area whose bodies decide whether anyone is inside. Its shape is the doorway
## plus the floor beyond it, and it is deliberately a separate node from the art
## so the trigger can be reshaped without touching the drawing.
@export var entry_area_path: NodePath = ^"EntryArea"
## Art hidden while someone is inside - the roof, the front wall, the awning.
@export var exterior_paths: Array[NodePath] = []
## Art revealed while someone is inside.
@export var interior_paths: Array[NodePath] = []
## Only bodies in this group open the building, so enemies wandering through a
## doorway cannot strip its roof off.
@export var body_group: StringName = &"player"

@export_group("Fade")
## How long the swap takes each way.
@export var fade_time: float = 0.22
## What the exterior fades down to. 0 removes it completely; a low value leaves a
## ghost of the roof, which reads well on a building whose inside is small.
@export_range(0.0, 1.0) var exterior_open_alpha: float = 0.0
## What the interior sits at while the building is shut. Above 0 lets a lit
## window show through from outside.
@export_range(0.0, 1.0) var interior_closed_alpha: float = 0.0

var _exterior: Array[CanvasItem] = []
var _interior: Array[CanvasItem] = []
var _exterior_alpha: Array[float] = []
var _interior_alpha: Array[float] = []
var _inside: int = 0
var _open: bool = false
var _tween: Tween


func _ready() -> void:
	_collect(exterior_paths, _exterior, _exterior_alpha)
	_collect(interior_paths, _interior, _interior_alpha)

	var area := get_node_or_null(entry_area_path) as Area2D
	if area != null:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

	_apply(0.0)


## True while the roof is off.
func is_open() -> bool:
	return _open


## Opens or shuts the building directly, for a cutscene or a debug key. The entry
## area keeps working afterwards - the next crossing simply corrects it.
func set_open(open: bool) -> void:
	if open == _open:
		return
	_open = open
	_play()
	if open:
		entered.emit()
	else:
		exited.emit()


## Each node's authored alpha is remembered, so a roof deliberately drawn at 80%
## fades back to 80% rather than being forced to fully opaque.
func _collect(paths: Array[NodePath], into: Array[CanvasItem], alphas: Array[float]) -> void:
	for path: NodePath in paths:
		var node := get_node_or_null(path) as CanvasItem
		if node == null:
			continue
		into.append(node)
		alphas.append(node.modulate.a)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(body_group):
		return
	_inside += 1
	if _inside == 1:
		set_open(true)


## Counted rather than flagged, because a body can leave one of the area's shapes
## while still standing in another - a doorway plus a room is two shapes, and a
## flag would slam the roof back on halfway through the door.
func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group(body_group):
		return
	_inside = maxi(_inside - 1, 0)
	if _inside == 0:
		set_open(false)


func _play() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()

	if fade_time <= 0.0:
		_apply(0.0)
		return

	# Anything about to become visible is shown up front, so it fades in rather
	# than appearing at the end of a fade that was never seen.
	_prepare_visibility()

	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD)
	for i in _exterior.size():
		_tween.tween_property(_exterior[i], "modulate:a", _exterior_goal(i), fade_time)
	for i in _interior.size():
		_tween.tween_property(_interior[i], "modulate:a", _interior_goal(i), fade_time)
	_tween.chain().tween_callback(_settle_visibility)


func _apply(_unused: float) -> void:
	for i in _exterior.size():
		_exterior[i].modulate.a = _exterior_goal(i)
	for i in _interior.size():
		_interior[i].modulate.a = _interior_goal(i)
	_settle_visibility()


func _exterior_goal(index: int) -> float:
	return exterior_open_alpha * _exterior_alpha[index] if _open else _exterior_alpha[index]


func _interior_goal(index: int) -> float:
	return _interior_alpha[index] if _open else interior_closed_alpha * _interior_alpha[index]


func _prepare_visibility() -> void:
	for i in _exterior.size():
		_exterior[i].visible = _exterior[i].visible or _exterior_goal(i) > 0.001
	for i in _interior.size():
		_interior[i].visible = _interior[i].visible or _interior_goal(i) > 0.001


## Fully transparent art is switched off outright once it has finished fading, so
## a closed building costs nothing to draw.
func _settle_visibility() -> void:
	for i in _exterior.size():
		_exterior[i].visible = _exterior_goal(i) > 0.001
	for i in _interior.size():
		_interior[i].visible = _interior_goal(i) > 0.001
