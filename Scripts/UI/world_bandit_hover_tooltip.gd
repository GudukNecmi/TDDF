class_name WorldBanditHoverTooltip
extends Node2D
## The small label that names a [WorldBandit] group's real size while the
## mouse sits over it on the World Map.
##
## [b]Polled against the mouse's own world position[/b] rather than wired
## through a per-bandit [Area2D] and its own input events, since a
## [WorldBandit] is deliberately one lightweight [Node2D] with no collision
## shape of its own - see that class's doc. One tooltip, found by every
## bandit's [member Node2D.global_position] and a hover radius read off its
## own formation, is the smallest way to answer "which one is the cursor
## over" without adding a click target to twelve-plus authored groups.
##
## [b]Fog and occlusion are never checked here.[/b] They do not have to be:
## [method WorldBandit._update_fog_visibility] already hides a group's whole
## node - itself and every trailing formation box under it - the instant fog
## or a blocking rock takes it out of view, so this only ever has to read
## [member CanvasItem.visible] on the candidate the same way anything else
## drawing over a bandit already would. A group fog has not revealed can
## never be the closest visible candidate because it is never a candidate at
## all.
##
## Shows the real [member WorldBandit.group_strength] rather than the boxed
## [code]ceil(group_strength / people_per_box)[/code] count the formation
## draws - "show its real group_strength" - so a hover always answers with
## the true number, not the stylised count of boxes standing in for it.

@export var body_group: StringName = &"world_bandit"
@export var label_path: NodePath = ^"Label"
## How far past a group's own drawn size the cursor still counts as hovering
## it, in pixels - generous, since the formation's boxes trail some way
## behind the leader and the whole row should read as one hoverable group.
@export var hover_padding: float = 46.0
## Where the tooltip is written relative to the hovered group, in world
## pixels.
@export var label_offset := Vector2(0.0, -60.0)
@export var fact_format: String = "%d BANDITS"

@onready var _label: Label = get_node_or_null(label_path) as Label

var _hovered: WorldBandit


func _ready() -> void:
	top_level = true
	visible = false


func _process(_delta: float) -> void:
	var mouse := get_global_mouse_position()

	var best: WorldBandit
	var best_distance := INF
	for node: Node in get_tree().get_nodes_in_group(body_group):
		var bandit := node as WorldBandit
		if bandit == null or not bandit.active or not bandit.visible:
			continue
		var radius := _hover_radius(bandit)
		var distance := bandit.global_position.distance_to(mouse)
		if distance <= radius and distance < best_distance:
			best = bandit
			best_distance = distance

	_set_hovered(best)
	if _hovered != null:
		global_position = _hovered.global_position + label_offset


func _hover_radius(bandit: WorldBandit) -> float:
	var icon := bandit.get_node_or_null(^"Icon") as Sprite2D
	if icon == null or icon.texture == null:
		return hover_padding
	var extent: Vector2 = icon.texture.get_size() * icon.scale * 0.5
	return maxf(extent.x, extent.y) + hover_padding


func _set_hovered(bandit: WorldBandit) -> void:
	if bandit == _hovered:
		return
	_hovered = bandit
	if _hovered == null:
		visible = false
		return
	if _label != null:
		_label.text = fact_format % int(round(_hovered.group_strength))
	visible = true
