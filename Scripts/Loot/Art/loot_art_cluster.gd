@tool
class_name LootArtCluster
extends LootObjectArt
## A little heap of pieces - Gems - one picture per piece, up to
## [member max_shown], scattered in a fixed pattern so the heap never jumps
## about while it is looked at.
##
## The picture is the reward's own ([method LootReward.get_icon] - a Gem's colour
## art from the existing Gem data) or [member texture]; with neither, each piece
## is the placeholder crystal in the reward's tint.

## Used when the reward has no picture of its own.
@export var texture: Texture2D
## How many pieces at most are drawn, whatever the amount.
@export_range(1, 12) var max_shown: int = 5
## Draws this many pieces whatever the amount. 0 follows the amount.
@export_range(0, 12) var fixed_count: int = 0
## One piece's size, as a fraction of the object's height.
@export_range(0.1, 1.0, 0.01) var piece_size: float = 0.42
## How far the pieces spread from the middle, as a fraction of the height.
@export_range(0.0, 0.6, 0.01) var spread: float = 0.2
## How much each piece is turned, at most, in degrees.
@export var piece_tilt_degrees: float = 18.0
## Multiplies the picture - white leaves it as drawn.
@export var modulate: Color = Color.WHITE
## A soft sparkle drifting over the heap.
@export var sparkle: float = 0.6
@export var sparkle_speed: float = 1.3


func draw(canvas: CanvasItem, rect: Rect2, reward: LootReward, time: float) -> void:
	var centre := rect.get_center()
	var h := rect.size.y
	var count := fixed_count
	if count <= 0:
		count = reward.get_amount() if reward != null else 1
	count = clampi(count, 1, maxi(max_shown, 1))
	var picture := reward.get_icon() if reward != null else null
	if picture == null:
		picture = texture
	var tint := reward.get_tint() if reward != null else Color.WHITE
	var piece := h * piece_size

	draw_shadow(canvas, centre + Vector2(0.0, piece * 0.55), Vector2(piece * (0.6 + 0.15 * count),
		piece * 0.16))
	for i: int in count:
		var offset := _offset(i, count) * h * spread
		var angle := deg_to_rad(piece_tilt_degrees * _wobble(i))
		var at := centre + offset
		if picture != null:
			# A turned quad rather than draw_set_transform, which would replace the
			# object's own hover and lean transform instead of adding to it.
			var picture_size := picture.get_size()
			var half := picture_size * (piece / maxf(picture_size.x, picture_size.y)) * 0.5
			var corners := PackedVector2Array()
			for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
					Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
				corners.append(at + corner.rotated(angle))
			canvas.draw_polygon(corners, PackedColorArray([modulate]),
				PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]),
				picture)
		else:
			CharmDefinition.draw_crystal(canvas, at, piece * 0.45, tint)

	if sparkle > 0.0:
		var spark_at := centre + _offset(int(time * sparkle_speed) % count, count) * h * spread \
			+ Vector2(-piece * 0.15, -piece * 0.2)
		var phase := fposmod(time * sparkle_speed, 1.0)
		var bright := Color(1, 1, 1, sparkle * sin(phase * PI))
		var arm := piece * 0.18 * sin(phase * PI)
		canvas.draw_line(spark_at - Vector2(arm, 0), spark_at + Vector2(arm, 0), bright, 1.5, true)
		canvas.draw_line(spark_at - Vector2(0, arm), spark_at + Vector2(0, arm), bright, 1.5, true)


## A fixed heap pattern: one in the middle, the rest round it, back ones higher.
func _offset(index: int, count: int) -> Vector2:
	if count <= 1:
		return Vector2.ZERO
	var spots: Array[Vector2] = [Vector2(0.0, 0.25), Vector2(-0.85, 0.1), Vector2(0.85, 0.05),
		Vector2(-0.4, -0.55), Vector2(0.45, -0.6), Vector2(0.0, -1.0), Vector2(-1.1, -0.6),
		Vector2(1.1, -0.55), Vector2(-0.8, 0.85), Vector2(0.8, 0.8), Vector2(0.0, 1.05),
		Vector2(-1.4, 0.3)]
	return spots[index % spots.size()]


func _wobble(index: int) -> float:
	return sin(float(index) * 2.39 + 0.7)
