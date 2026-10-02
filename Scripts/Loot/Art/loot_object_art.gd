@tool
class_name LootObjectArt
extends Resource
## How one kind of physical loot is drawn on the Loot Screen's table - the
## picture inside a [LootTableObject].
##
## [b]Placeholder art, drawn in code.[/b] Every subclass draws from its own
## Inspector numbers and the reward's [method LootReward.get_tint] /
## [method LootReward.get_icon] / [method LootReward.get_amount], so the final
## artwork can replace a subclass (or be a texture in [LootArtCluster]) without
## the table or the screen changing.

## Override: draw [param reward] into [param canvas], fitted to [param rect].
## [param time] runs in seconds for anything that shimmers.
func draw(_canvas: CanvasItem, _rect: Rect2, _reward: LootReward, _time: float) -> void:
	pass


## A soft dark oval under the object, so it sits on the felt.
static func draw_shadow(canvas: CanvasItem, centre: Vector2, radii: Vector2,
		color: Color = Color(0, 0, 0, 0.35)) -> void:
	if radii.x <= 0.0 or radii.y <= 0.0:
		return
	var points := PackedVector2Array()
	for i: int in 24:
		var angle := TAU * float(i) / 24.0
		points.append(centre + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	canvas.draw_colored_polygon(points, color)
