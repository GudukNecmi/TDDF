class_name LootLayout
extends Resource
## Where the Loot Screen deals its cards around the pouch, and how they fly
## there - every number of the table's arrangement, in one Inspector resource.
##
## [b]Cards sit on an ellipse around the pouch.[/b] A table of up to
## [member ring_capacity] rewards is one ring; more start a second ring
## [member ring_growth] further out. Within a ring the cards are spread evenly
## over [member arc_degrees], centred on [member middle_angle_degrees] - so with
## the defaults one card lands above the pouch, two either side of it and three
## in a triangle round it.

@export_group("Placement")
## The ellipse the first ring sits on, in pixels from the pouch's centre.
@export var radius: Vector2 = Vector2(360.0, 150.0)
## Moves the whole arrangement relative to the pouch's centre.
@export var center_offset: Vector2 = Vector2.ZERO
## The angle the middle of each ring's spread faces, in degrees; -90 is straight
## up.
@export_range(-360.0, 360.0, 1.0) var middle_angle_degrees: float = -90.0
## How much of the ellipse a ring spreads over. 360 spaces the cards all the way
## round; less fans them over an arc.
@export_range(0.0, 360.0, 1.0) var arc_degrees: float = 360.0
## The most cards on one ring before a second ring is started.
@export_range(1, 32) var ring_capacity: int = 6
## How much bigger each further ring's ellipse is than the one inside it.
@export var ring_growth: float = 1.4

@export_group("Dealing")
## How long one card takes to fly from the pouch to its place, in seconds.
@export var fly_time: float = 0.55
## The gap between one card setting off and the next, in seconds.
@export var stagger: float = 0.09
## How high a card arcs on its way out, in pixels, over the straight line.
@export var arc_lift: float = 90.0
## The size a card leaves the pouch at, as a fraction of its own.
@export var spawn_scale: float = 0.15
## A little spin on the way out, in degrees, settled to nothing on landing.
@export var spawn_spin_degrees: float = 25.0
@export var fly_transition: Tween.TransitionType = Tween.TRANS_BACK
@export var fly_ease: Tween.EaseType = Tween.EASE_OUT


## The centre of every card's resting place, relative to the pouch's centre.
func positions(count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var capacity := maxi(ring_capacity, 1)
	var remaining := count
	var ring := 0
	while remaining > 0:
		var in_ring := mini(remaining, capacity)
		var ring_radius := radius * pow(maxf(ring_growth, 0.01), ring)
		for slot: int in in_ring:
			var angle := deg_to_rad(_angle_for(slot, in_ring))
			result.append(center_offset + Vector2(cos(angle) * ring_radius.x,
				sin(angle) * ring_radius.y))
		remaining -= in_ring
		ring += 1
	return result


func _angle_for(slot: int, in_ring: int) -> float:
	if in_ring <= 1:
		return middle_angle_degrees
	# A full circle spaces by its share so the first and last never meet; an arc
	# spaces so its two ends are both used.
	var full := arc_degrees >= 359.0
	var step := arc_degrees / float(in_ring if full else in_ring - 1)
	return middle_angle_degrees + (float(slot) - float(in_ring - 1) * 0.5) * step
