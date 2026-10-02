@tool
class_name LootArtCrystal
extends LootObjectArt
## A Charm on the table: the placeholder crystal of [method CharmDefinition.draw_crystal],
## in the reward's own colour, with a slow pulse of light round it.

## The crystal's height from centre to tip, as a fraction of the object's height.
@export_range(0.1, 0.6, 0.01) var size: float = 0.36
## How strongly it glows, and how much and how fast that pulses.
@export var glow: float = 0.6
@export var glow_pulse: float = 0.25
@export var pulse_speed: float = 0.7


func draw(canvas: CanvasItem, rect: Rect2, reward: LootReward, time: float) -> void:
	var centre := rect.get_center()
	var radius := rect.size.y * size
	draw_shadow(canvas, centre + Vector2(0.0, radius * 1.15), Vector2(radius * 0.7, radius * 0.18))
	var tint := reward.get_tint() if reward != null else Color.WHITE
	var pulse := glow + sin(time * TAU * pulse_speed) * glow_pulse
	CharmDefinition.draw_crystal(canvas, centre, radius, tint, pulse)
