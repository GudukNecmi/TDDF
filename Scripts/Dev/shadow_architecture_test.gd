class_name ShadowArchitectureTest
extends Node2D
## Proves the shadow architecture works, on its own, with no game around it.
##
## It is deliberately not a gameplay test. Nothing here checks how a shadow
## [i]looks[/i] - what it checks is that the pieces are wired the way the
## architecture claims: that a caster can read the map's sun, that ground
## position and visual height are genuinely two separate numbers, that a source's
## rotation and mirroring reach the shadow, and that the sun travels from one
## hour to the next rather than snapping.
##
## Run it headless - [code]godot --path . --headless
## Scenes/Dev/ShadowArchitectureTest.tscn[/code] - and it prints a line per check
## and quits. Every line begins PASS or FAIL, so a failure is one grep away.

## The caster under test.
@export var caster_path: NodePath = ^"Subject/ShadowCaster"
## The subject's root - what "where it is standing" is measured from.
@export var subject_path: NodePath = ^"Subject"
## The artwork, moved about to prove height is not depth.
@export var art_path: NodePath = ^"Subject/Art"
## The map's shadow director.
@export var director_path: NodePath = ^"Sun"
## Whether the tree is quit once every check has run. Off leaves the scene up to
## be looked at.
@export var quit_when_done: bool = true

var _failures: int = 0


func _ready() -> void:
	# One frame, so every node has readied and the director has settled on an hour.
	await get_tree().process_frame
	await _run()
	print("")
	print("shadow architecture: %s (%d failure(s))" % [
		"OK" if _failures == 0 else "BROKEN", _failures])
	if quit_when_done:
		get_tree().quit(1 if _failures > 0 else 0)


func _run() -> void:
	var caster := get_node_or_null(caster_path) as ShadowCaster
	var subject := get_node_or_null(subject_path) as Node2D
	var art := get_node_or_null(art_path) as Sprite2D
	var director := get_node_or_null(director_path) as SunController

	if caster == null or subject == null or art == null or director == null:
		_check("test scene is wired", false, "one of the four nodes is missing")
		return

	_test_sun_is_readable(caster, director)
	_test_ground_and_height_are_separate(caster, subject, art)
	_test_airborne_projection(caster, art)
	_test_source_pose_is_read(caster, art)
	_test_direction_is_world_space(caster, art)
	_test_projection_is_along_the_light(caster)
	_test_pure_calculation(director)
	await _test_transition_is_smooth(director)


## 1. A caster can reach the hour's sun at all, and it is the controller's own
## object rather than a copy - which is what lets a hundred casters share one.
func _test_sun_is_readable(caster: ShadowCaster, director: SunController) -> void:
	var sun := director.get_state()
	_check("the sun hands out a live state", sun != null,
		"get_state() returned null")
	if sun == null:
		return
	_check("the sun stands at the map's current hour",
		sun.stage_name == director.stages[director.get_stage_index()].stage_name,
		"the live sun is %s, stage %d is %s" % [
			sun.stage_name, director.get_stage_index(),
			director.stages[director.get_stage_index()].stage_name])
	_check("a caster reads that sun", caster.get_last_result() != null,
		"the caster produced no result")
	_check("the live sun is one shared object",
		director.get_state() == sun,
		"a second call handed back a different object")


## 2. The whole point of the coordinate model: moving the subject through the
## arena moves its ground position and leaves its height alone, and lifting the
## artwork does exactly the reverse. World Y is depth, never height.
func _test_ground_and_height_are_separate(
		caster: ShadowCaster, subject: Node2D, art: Sprite2D) -> void:
	var rest := subject.position
	var art_rest := art.position

	var ground_before := caster.get_ground_position()
	var height_before := caster.get_visual_height()
	_check("standing on the ground reads as height 0",
		is_zero_approx(height_before), "height at rest is %.3f" % height_before)

	# Walk 200 pixels down the arena - the largest possible chance to mistake
	# depth for height.
	subject.position = rest + Vector2(0.0, 200.0)
	var ground_walked := caster.get_ground_position()
	var height_walked := caster.get_visual_height()
	_check("walking down the arena moves the ground position",
		is_equal_approx(ground_walked.y - ground_before.y, 200.0),
		"ground moved by %.3f" % (ground_walked.y - ground_before.y))
	_check("walking down the arena does NOT become height",
		is_zero_approx(height_walked),
		"height after walking is %.3f - world Y leaked into height" % height_walked)

	# Lift the artwork 60 pixels off the ground, without moving the subject.
	art.position = art_rest + Vector2(0.0, -60.0)
	var ground_lifted := caster.get_ground_position()
	var height_lifted := caster.get_visual_height()
	_check("lifting the artwork raises the height",
		is_equal_approx(height_lifted, 60.0),
		"height after a 60px lift is %.3f" % height_lifted)
	_check("lifting the artwork does NOT move the ground position",
		ground_lifted.is_equal_approx(ground_walked),
		"ground moved from %s to %s" % [ground_walked, ground_lifted])

	art.position = art_rest
	subject.position = rest


## 3. Airborne, with nothing anywhere asked whether the subject is jumping: the
## shadow walks away along the light and lengthens as the artwork rises, and comes
## back as it falls.
func _test_airborne_projection(caster: ShadowCaster, art: Sprite2D) -> void:
	var art_rest := art.position

	caster.update_shadow()
	var grounded := caster.get_last_result()
	var ground_offset := grounded.offset
	var ground_length := grounded.length
	var ground_alpha := grounded.modulate.a

	var apex_offset := Vector2.ZERO
	var apex_length := 0.0
	var apex_alpha := 0.0
	for height: float in [30.0, 90.0, 150.0]:
		art.position = art_rest + Vector2(0.0, -height)
		caster.update_shadow()
		var result := caster.get_last_result()
		apex_offset = result.offset
		apex_length = result.length
		apex_alpha = result.modulate.a
		if not is_equal_approx(result.visual_height, height):
			_check("height %.0f reaches the projection" % height, false,
				"projection saw %.3f" % result.visual_height)
			art.position = art_rest
			return

	_check("ascent walks the shadow away from the feet",
		apex_offset.length() > ground_offset.length() + 1.0,
		"offset went from %.2f to %.2f" % [ground_offset.length(), apex_offset.length()])
	# It grows rather than shrinks, and that is the projection being real: a point
	# lifted towards the sun throws a longer mark, exactly as a hand raised over a
	# table does.
	_check("ascent lengthens the shadow", apex_length > ground_length,
		"length went from %.2f to %.2f" % [ground_length, apex_length])
	_check("ascent fades the shadow", apex_alpha < ground_alpha,
		"alpha went from %.3f to %.3f" % [ground_alpha, apex_alpha])

	# Descent and landing are the same number coming back down, which is the whole
	# reason there is no jump state anywhere.
	art.position = art_rest
	caster.update_shadow()
	var landed := caster.get_last_result()
	_check("landing returns the shadow to the feet",
		landed.offset.is_equal_approx(ground_offset) and is_zero_approx(landed.visual_height),
		"landed at offset %s, height %.3f" % [landed.offset, landed.visual_height])


## 4. Rotation, scale and mirroring of the source all reach the shadow, with no
## special case for what kind of object the source is.
func _test_source_pose_is_read(caster: ShadowCaster, art: Sprite2D) -> void:
	var rotation_rest := art.rotation
	var scale_rest := art.scale
	var flip_rest := art.flip_h

	caster.update_shadow()
	var base_rotation := caster.get_last_result().rotation
	var base_scale := caster.get_last_result().scale

	art.rotation = deg_to_rad(35.0)
	caster.update_shadow()
	var turned := caster.get_last_result().rotation
	_check("source rotation reaches the shadow",
		is_equal_approx(angle_difference(base_rotation, turned), deg_to_rad(35.0)),
		"shadow turned by %.3f rad" % angle_difference(base_rotation, turned))
	art.rotation = rotation_rest

	art.flip_h = not flip_rest
	caster.update_shadow()
	var mirrored := caster.get_last_result().scale
	_check("source flip mirrors the shadow",
		signf(mirrored.x) != signf(base_scale.x),
		"scale.x went from %.3f to %.3f" % [base_scale.x, mirrored.x])
	art.flip_h = flip_rest

	art.scale = scale_rest * 2.0
	caster.update_shadow()
	var scaled := caster.get_last_result()
	_check("source scale reaches the shadow", scaled.length > base_scale.y * 1.5,
		"length %.2f against a base scale of %.2f" % [scaled.length, base_scale.y])
	art.scale = scale_rest
	caster.update_shadow()


## 5. The projection is a pure function of the sun and a point: the same two
## arguments give the same answer with no node, no scene and no state involved.
func _test_pure_calculation(director: SunController) -> void:
	var sun := director.get_state()
	var at := Vector2(100.0, 100.0)

	var flat := sun.project(at, 0.0)
	var low := sun.project(at, 40.0)
	var high := sun.project(at, 120.0)

	_check("a point on the floor casts at its own feet", flat.is_equal_approx(at),
		"it cast at %s" % flat)
	_check("height alone moves the shadow", not low.is_equal_approx(flat),
		"both landed at %s" % flat)
	_check("the shadow walks further the higher the point is",
		high.distance_to(at) > low.distance_to(at),
		"40px reached %.2f, 120px reached %.2f" % [
			low.distance_to(at), high.distance_to(at)])
	_check("the walk is along the light and nowhere else",
		(low - at).normalized().is_equal_approx(sun.shadow_direction_at(at))
			and (high - at).normalized().is_equal_approx(sun.shadow_direction_at(at)),
		"it walked along %s, the light runs %s" % [
			(high - at).normalized(), sun.shadow_direction_at(at)])


## 6. The day turns rather than jumps: forced to another hour, the sun
## spends real frames between the two instead of arriving on the first one.
func _test_transition_is_smooth(director: SunController) -> void:
	if director.stages.size() < 2:
		_check("the map has hours to cross between", false, "fewer than two sun stages")
		return

	var from_index := director.get_stage_index()
	var to_index := (from_index + 1) % director.stages.size()
	var from_length := director.stages[from_index].get_length_ratio()
	var to_length := director.stages[to_index].get_length_ratio()

	director.force_stage(to_index, 0.5)
	_check("forcing an hour starts a transition", director.is_travelling(),
		"the sun settled immediately")

	var lengths: Array[float] = []
	for _i: int in range(6):
		await get_tree().process_frame
		lengths.append(director.get_state().length_ratio)

	var moved := false
	var between := false
	for length: float in lengths:
		if not is_equal_approx(length, from_length):
			moved = true
		var low := minf(from_length, to_length) - 0.001
		var high := maxf(from_length, to_length) + 0.001
		if length > low and length < high \
				and not is_equal_approx(length, from_length) \
				and not is_equal_approx(length, to_length):
			between = true
	_check("the sun moves as the day turns", moved,
		"stayed at %.3f" % from_length)
	_check("the sun passes between the two hours", between,
		"went straight from %.3f to %.3f - samples %s" % [from_length, to_length, lengths])

	# And it does arrive.
	for _i: int in range(60):
		if not director.is_travelling():
			break
		await get_tree().process_frame
	_check("the transition arrives",
		is_equal_approx(director.get_state().length_ratio, to_length),
		"settled at %.3f instead of %.3f" % [
			director.get_state().length_ratio, to_length])


## 4b. The invariant this whole pass exists for: the source may turn, mirror and
## scale as much as it likes, and NONE of it may move which way the shadow is
## thrown. Only the hour decides that.
func _test_direction_is_world_space(caster: ShadowCaster, art: Sprite2D) -> void:
	var rotation_rest := art.rotation
	var scale_rest := art.scale
	var flip_rest := art.flip_h

	caster.update_shadow()
	# Copied out rather than held: the caster fills one result object over and over
	# so it allocates nothing per frame, so the "before" would otherwise change
	# under us the moment we ask for the "after".
	var rest := caster.get_last_result()
	var rest_direction := rest.direction
	var rest_position := rest.position
	var rest_scale := rest.scale
	# Where the far tip of the silhouette actually lands, which is the thing a
	# player sees move when a shadow "goes to the other side".
	var rest_tip := _tip_of(rest)

	art.flip_h = not flip_rest
	caster.update_shadow()
	var flipped := caster.get_last_result()
	_check("flipping the source leaves the shadow direction alone",
		flipped.direction.is_equal_approx(rest_direction),
		"direction went from %s to %s" % [rest_direction, flipped.direction])
	_check("flipping the source leaves the shadow where it was",
		flipped.position.is_equal_approx(rest_position),
		"position went from %s to %s" % [rest_position, flipped.position])
	_check("flipping the source does NOT throw the shadow to the far side",
		_tip_of(flipped).dot(rest_direction) > 0.0
			and is_equal_approx(_tip_of(flipped).dot(rest_direction),
				rest_tip.dot(rest_direction)),
		"the tip reached along the light went from %.2f to %.2f" % [
			rest_tip.dot(rest_direction), _tip_of(flipped).dot(rest_direction)])
	_check("flipping the source still mirrors the silhouette",
		signf(flipped.scale.x) != signf(rest_scale.x),
		"scale.x stayed %.2f" % flipped.scale.x)
	art.flip_h = flip_rest

	# A full turn of the source, sampled all the way round. A spinning revolver is
	# this, and at no point in it may the shadow choose a different sun.
	for degrees: float in [45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
		art.rotation = deg_to_rad(degrees)
		caster.update_shadow()
		var turned := caster.get_last_result()
		if not turned.direction.is_equal_approx(rest_direction):
			_check("a turning source never redirects the shadow", false,
				"at %.0f degrees the direction was %s" % [degrees, turned.direction])
			art.rotation = rotation_rest
			return
		# It may slide ALONG the light - turning artwork genuinely lifts its own
		# lowest point off the ground, and height is a slide along the light. What it
		# must never do is wander across the light, which is the whole complaint.
		var drift := turned.position - rest_position
		var across_the_light := drift - rest_direction * drift.dot(rest_direction)
		if across_the_light.length() > 0.01:
			_check("a turning source never moves the shadow across the light", false,
				"at %.0f degrees it had drifted %.3f px sideways" % [
					degrees, across_the_light.length()])
			art.rotation = rotation_rest
			return
	_check("a turning source never redirects the shadow", true)
	_check("a turning source never moves the shadow across the light", true)
	art.rotation = rotation_rest

	art.scale = scale_rest * 1.7
	caster.update_shadow()
	var scaled := caster.get_last_result()
	_check("scaling the source leaves the shadow direction alone",
		scaled.direction.is_equal_approx(rest_direction),
		"direction went from %s to %s" % [rest_direction, scaled.direction])
	art.scale = scale_rest
	caster.update_shadow()


## 4c. The shadow is projected along the light and nowhere else: the silhouette's
## far tip lies along the hour's direction, from the feet, at the hour's length.
func _test_projection_is_along_the_light(caster: ShadowCaster) -> void:
	caster.update_shadow()
	var result := caster.get_last_result()
	var tip := _tip_of(result)
	if tip.is_zero_approx():
		_check("the silhouette is laid down along the light", false, "no tip")
		return
	_check("the silhouette is laid down along the light",
		tip.normalized().is_equal_approx(result.direction),
		"the tip lies along %s, the light along %s" % [
			tip.normalized(), result.direction])
	_check("the silhouette reaches the hour's own length",
		is_equal_approx(tip.length(), result.length),
		"tip reaches %.2f, the hour says %.2f" % [tip.length(), result.length])


## Where the top of the artwork ends up, measured from the shadow's own origin.
## The shadow sprite is drawn with its footing on that origin and the artwork
## running up its local -Y, so this is the basis applied to a unit of "up".
func _tip_of(result: ShadowTransform) -> Vector2:
	return result.basis * Vector2(0.0, -_source_height())


## The drawn height of the subject's artwork, in world pixels.
func _source_height() -> float:
	var caster := get_node_or_null(caster_path) as ShadowCaster
	if caster == null:
		return 0.0
	var sprite := caster.get_source_sprite()
	if sprite == null:
		return 0.0
	return SpriteBounds.used_rect(sprite.texture).size.y

func _check(what: String, passed: bool, detail: String = "") -> void:
	if passed:
		print("PASS  %s" % what)
		return
	_failures += 1
	print("FAIL  %s%s" % [what, "" if detail.is_empty() else "  -  " + detail])
