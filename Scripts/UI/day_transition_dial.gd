class_name DayTransitionDial
extends Control
## The hour turning over, watched: a disk as wide as the screen, hinged on the bottom
## edge of it, with the hour the player is leaving on the face that is up and the one
## they are walking into on the face still buried below the edge, rolled round to the
## left until the new one has come up.
##
## [b]It is not a widget sitting on the screen - it is the screen.[/b] The circle's
## diameter is the window's own width and its horizontal diameter line lies exactly
## along the bottom edge, so the whole of the upper half stands over the play area and
## the whole of the lower half is buried underneath it. That line does not move: the
## disk only ever turns about it, which is what makes the movement read as something
## enormous rolling up from below the world rather than as a dial being spun. Nothing
## about that changes with the window's size, because both the radius and the hinge
## are read from the screen every time it is drawn.
##
##   [codeblock]
##          ,----------------.        <- the hour, on the face that is up
##         /                  \
##   -----+--------------------+-----  <- bottom edge of the screen == diameter line
##         \                  /
##          `----------------'         <- the next hour, still buried
##   [/codeblock]
##
## [b]It decides nothing about the clock.[/b] It is raised over a transition, told
## how long that transition lasts, and says one thing back - [signal turned], on the
## beat the halves have swapped. Whoever raised it spends the hour on that beat; see
## [method DangerDirector._turn_the_day]. So what the player watches happen and what
## the game believes has happened are the same event rather than two things that have
## to be kept in step.
##
## [b]And it holds no hours of its own.[/b] Both faces are read from the map's
## [DayCycleDirector] as the dial goes up - offset 0 for the hour now and offset 1 for
## the one after it - which is the same call the corner of the HUD and the round's
## opening card read themselves from. A map with no day cycle simply shows two empty
## faces, and a world with no dial at all leaves the hour moving exactly as it did
## before there was anything to watch it move on.
##
## The turn itself is three beats, and the middle one is the point of it:
##
##   [codeblock]
##   ...quiet...  ->  10 deg the wrong way  ->  190 deg to the left  ->  ...held...
##                      anticipation_time          turn_time
##                                                        ^ the swap, and [signal turned]
##   [/codeblock]
##
## The short lean the other way is what makes the roll read as a movement somebody
## made rather than as a number changing, and it is why the whole sweep covers about
## 190 degrees for a half turn of 180.
##
## [b]The faces do not turn with it.[/b] The dial's halves, its divider and its rim
## are drawn round to wherever the turn has got to, and the icon and the word are
## carried round the same circle without being rotated - so the hour is legible
## through the whole of the movement instead of arriving upside down half way.

## Emitted on the beat the halves have swapped and the new hour is the one on top.
## [b]It always fires[/b] once [method play] has been called - including on a dial
## switched off - so a caller waiting on it to spend the hour can never be left
## waiting.
signal turned()

## Group the dial joins, so anything can find it without a path across the HUD.
const GROUP := &"day_transition_dial"

## Whether the turn is drawn at all. Off, [signal turned] is emitted the instant the
## dial is asked to play and nothing is shown, which is the transition exactly as it
## was before this existed.
@export var enabled: bool = true

@export_group("Nodes")
## The block carried round the top of the circle: the hour being left.
@export var now_face_path: NodePath = ^"NowFace"
@export var now_icon_path: NodePath = ^"NowFace/Icon"
@export var now_label_path: NodePath = ^"NowFace/Name"
## The block carried round the bottom of it: the hour being walked into, which the
## turn brings up.
@export var next_face_path: NodePath = ^"NextFace"
@export var next_icon_path: NodePath = ^"NextFace/Icon"
@export var next_label_path: NodePath = ^"NextFace/Name"

@export_group("Where it sits")
## The point the disk turns about, as a fraction of the screen.
##
## [b]Bottom edge, dead centre[/b] - so the circle's horizontal diameter line lies
## along the bottom of the window, its upper half stands over the play area and its
## lower half is buried below the screen. Read as a fraction rather than in pixels so
## the hinge stays welded to that edge whatever size the window is, and it is read
## again on every frame of the turn, so the disk cannot drift off the edge while it
## moves.
@export var centre := Vector2(0.5, 1.0)
## How wide the disk is across, as a fraction of the screen's width.
##
## 1.0 is the rule as written: [b]diameter equals screen width[/b], which with the
## hinge on the bottom edge is what makes the upper half stand over the whole of the
## play area. Above 1 overhangs the sides, which a very wide window may want so the
## corners are covered through the sweep as well.
@export var diameter_scale: float = 1.0
## A radius in pixels, used instead of [member diameter_scale] when it is above zero.
## For a fixed-size disk; left at nothing the screen decides.
@export var radius_override: float = 0.0
## How far out from the hinge a face is carried, as a fraction of the radius - so the
## hour sits in the same place on the disk however large the screen has made it.
##
## High up the dome rather than half way, because the middle of the screen is where
## the man on foot walks and the bottom third is where the crossing writes its own
## title: the hour is put in the band above his hat, between them and the crown of the
## disk.
@export_range(0.0, 1.0) var face_reach: float = 0.86

@export_group("Look")
## The half that is currently up, and the half that is currently under it. Two
## colours rather than one so the turn is legible even before the faces have been
## given anything to show.
@export var upper_colour := Color(0.16, 0.05, 0.05, 0.94)
@export var lower_colour := Color(0.07, 0.03, 0.03, 0.94)
## The rim and the divider across the middle - the game's own red.
@export var rim_colour := Color(0.82, 0.1, 0.1, 1.0)
@export var rim_width: float = 5.0
@export var divider_width: float = 4.0
## How many segments the circle is drawn from. Higher is rounder - and at this size
## the edge is metres long on screen, so it wants rather more of them than a small
## dial would.
@export var arc_points: int = 96
## How faded the face that is currently underneath is drawn, so the half that is up
## is always the one being read.
@export_range(0.0, 1.0) var low_face_alpha: float = 0.22
## How long the dial takes to appear, in seconds.
@export var fade_in_time: float = 0.3

@export_group("The turn")
## Where in the transition the halves swap, as a fraction of it.
##
## [b]0.5 is the middle of the screen[/b], which is exactly where the man on foot is
## at the same instant - the crossing runs from [member TravelLoading.travel_from] to
## [member TravelLoading.travel_to], which are symmetrical about the middle - so the
## hour changes on the frame he walks through the centre of it.
@export_range(0.0, 1.0) var turn_at: float = 0.5
## How long the main sweep takes, in seconds. It [i]ends[/i] on the swap rather than
## starting on it, so the new hour is already the one on top by the time the walker
## reaches the middle.
@export var turn_time: float = 0.6
## How far the main sweep carries the dial, in degrees, to the left.
@export var turn_degrees: float = 180.0
## How long the lean the other way lasts, in seconds, immediately before the sweep.
@export var anticipation_time: float = 0.5
## How far that lean goes, in degrees, to the right. Added to the sweep, so a 180
## degree turn with a 10 degree wind-up is about 190 degrees of movement.
@export var anticipation_degrees: float = 10.0

var _playing: bool = false
var _turned: bool = false
## How far through the transition the dial is, in seconds. Counted here rather than
## driven by a tween, for the reason the road's own cart is: a beat that has to land
## with the walker cannot be left half way by a tween somebody killed.
var _time: float = 0.0
var _duration: float = 1.0
## Where the turn has got to, in radians. Negative is to the left.
var _angle: float = 0.0
var _fade: Tween


func _ready() -> void:
	add_to_group(GROUP)
	# Runs while the tree is paused, because the walk it is drawn over freezes the
	# world behind it - the same reason the crossing underneath it does.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	set_process(false)


## The dial in this world, or null when it has none - which every caller reads as
## "the hour moves without being watched".
static func get_active(from_node: Node) -> DayTransitionDial:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as DayTransitionDial


func is_playing() -> bool:
	return _playing


## Whether the halves have already swapped in the turn being played.
func has_turned() -> bool:
	return _turned


## Where the dial has got to, in degrees. Negative is to the left. For a readout or
## a test.
func get_degrees() -> float:
	return rad_to_deg(_angle)


## Raises the dial over a transition [param duration] seconds long, and turns it so
## the halves swap [member turn_at] of the way through.
##
## The two hours are read here rather than being handed in, so the dial cannot be
## showing an hour the map disagrees with.
##
## [b]It always shows the hour now against the hour after it[/b], whether or not the
## transition it is raised over is the one that spends it. The face that comes up is a
## picture of what is coming, not a report of what has happened: the walk into the
## first Danger of a search costs nothing on the clock, and still shows the player the
## hour they are working towards. Spending it remains entirely the caller's - see
## [method DangerDirector._spend_the_day] - so nothing here can move the clock early.
func play(duration: float) -> void:
	if not enabled:
		# Nothing to watch. The caller is told at once that the turn is over, so the
		# hour is spent on the beat it would have been spent on anyway.
		turned.emit()
		return

	_duration = maxf(duration, 0.0001)
	_time = 0.0
	_angle = 0.0
	_turned = false
	_playing = true

	_read_the_clock()
	visible = true
	_advance()
	set_process(true)
	_fade_up()


## Takes the dial back off. Called as the transition it was raised over ends, and
## safe on one that is already down.
func stop() -> void:
	_playing = false
	set_process(false)
	visible = false
	modulate.a = 0.0
	if _fade != null and _fade.is_running():
		_fade.kill()


func _process(delta: float) -> void:
	if not _playing:
		return

	_time += delta
	_advance()

	if _turned:
		return
	if _time < _duration * clampf(turn_at, 0.0, 1.0):
		return
	_turned = true
	turned.emit()


## Both hours, taken from the map's own clock - the one authority on what time it is
## - so the dial and the world's light cannot be showing two different answers.
##
## Offset 0 on the face that is up and offset 1 on the one still buried, every time it
## is raised. The clock is only ever [i]read[/i] here: the hour underneath is the next
## one whether or not this particular turn is the one that buys it.
func _read_the_clock() -> void:
	var day := DayCycleDirector.get_active(self)
	var now_stage: DayStage = null
	var next_stage: DayStage = null
	if day != null:
		now_stage = day.get_stage_at_offset(0)
		next_stage = day.get_stage_at_offset(1)

	_write_face(now_icon_path, now_label_path, now_stage)
	_write_face(next_icon_path, next_label_path, next_stage)


## One face given its hour's picture and its hour's name, written in that hour's own
## colour - the same three things [DayStageDisplay] puts on the corner of the HUD.
func _write_face(icon_path: NodePath, label_path: NodePath, stage: DayStage) -> void:
	var icon := get_node_or_null(icon_path) as TextureRect
	if icon != null:
		icon.texture = stage.icon if stage != null else null
		icon.visible = stage != null and stage.icon != null

	var label := get_node_or_null(label_path) as Label
	if label == null:
		return
	label.text = stage.display_name if stage != null else ""
	if stage != null:
		label.add_theme_color_override(&"font_color", stage.icon_colour)


func _advance() -> void:
	_angle = _angle_at(_time)
	_place_faces()
	queue_redraw()


## Where the dial stands at [param time], in radians.
##
## Negative is to the left, which is the direction the day is read in. The three
## beats are laid out backwards from the swap rather than forwards from the start, so
## the sweep finishes exactly on the frame the hour changes however long the walk it
## is drawn over happens to be.
func _angle_at(time: float) -> float:
	var swap := _duration * clampf(turn_at, 0.0, 1.0)
	var sweep := maxf(turn_time, 0.0001)
	var lead := maxf(anticipation_time, 0.0)
	var sweep_from := swap - sweep
	var lead_from := sweep_from - lead

	var back := deg_to_rad(maxf(anticipation_degrees, 0.0))
	var over := -deg_to_rad(turn_degrees)

	if time <= lead_from:
		return 0.0
	if time < sweep_from:
		# The wind-up, eased out so it settles into the lean rather than snapping to
		# it and waiting there.
		var wound := 1.0 if lead <= 0.0 else clampf((time - lead_from) / lead, 0.0, 1.0)
		return lerpf(0.0, back, 1.0 - pow(1.0 - wound, 2.0))
	if time < swap:
		var swept := clampf((time - sweep_from) / sweep, 0.0, 1.0)
		return lerpf(back, over, smoothstep(0.0, 1.0, swept))
	return over


## The hinge: the middle of the bottom edge, unless somebody has moved it.
func _centre_point() -> Vector2:
	return size * centre


## Half the screen's width, so the disk measures the window rather than a number
## somebody guessed - overridden only when a fixed size is asked for.
func _radius() -> float:
	if radius_override > 0.0:
		return radius_override
	return size.x * 0.5 * maxf(diameter_scale, 0.0)


func _place_faces() -> void:
	var mid := _centre_point()
	var reach := _radius() * clampf(face_reach, 0.0, 1.0)
	_place(get_node_or_null(now_face_path) as Control,
		mid + Vector2(0.0, -reach).rotated(_angle), mid, reach)
	_place(get_node_or_null(next_face_path) as Control,
		mid + Vector2(0.0, reach).rotated(_angle), mid, reach)


## One face put where the turn has carried it, and faded by how far under the middle
## it has sunk. It is moved rather than rotated, so the hour stays the right way up
## through the whole sweep.
func _place(face: Control, at: Vector2, mid: Vector2, reach: float) -> void:
	if face == null:
		return
	face.position = at - face.size * 0.5
	if reach <= 0.0:
		return
	var height := clampf(-(at.y - mid.y) / reach, -1.0, 1.0)
	face.modulate.a = lerpf(clampf(low_face_alpha, 0.0, 1.0), 1.0, (height + 1.0) * 0.5)


func _draw() -> void:
	var span := _radius()
	if span <= 0.0:
		return

	var mid := _centre_point()
	# Drawn from the turn rather than by rotating the node, so the faces can be
	# carried round the same circle without being turned with it. Both halves are laid
	# down whole - the one below the hinge is off the bottom of the screen until the
	# sweep brings it up, and the drawing is not clipped to the control's own rect.
	draw_colored_polygon(_half(mid, span, PI, TAU), upper_colour)
	draw_colored_polygon(_half(mid, span, 0.0, PI), lower_colour)

	if divider_width > 0.0:
		var arm := Vector2(span, 0.0).rotated(_angle)
		draw_line(mid - arm, mid + arm, rim_colour, divider_width, true)
	if rim_width > 0.0:
		draw_arc(mid, span, 0.0, TAU, maxi(arc_points, 8), rim_colour, rim_width, true)


## One half of the face, swept from [param from] to [param to] and carried round by
## however far the dial has turned.
func _half(mid: Vector2, span: float, from: float, to: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := maxi(arc_points, 8)
	for step: int in range(steps + 1):
		var along := lerpf(from, to, float(step) / float(steps)) + _angle
		points.append(mid + Vector2(span, 0.0).rotated(along))
	return points


## The dial arriving. Ignores the time scale because the world it is drawn over is
## frozen, and because the ending before it may have left the scale near zero.
func _fade_up() -> void:
	if _fade != null and _fade.is_running():
		_fade.kill()
	modulate.a = 0.0
	_fade = create_tween().set_ignore_time_scale(true)
	_fade.tween_property(self, "modulate:a", 1.0, maxf(fade_in_time, 0.0001))
