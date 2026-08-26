class_name ShadowWiringSmoke
extends Node2D
## A short smoke test over the seven representative objects wired in the first
## real pass of the shadow architecture.
##
## It loads the real Desert - [code]World.tscn[/code], with its own
## [SunController] and its own props - and drops the remaining
## representatives into it, then checks that each one has a live shadow and that
## the generic component read the object's real transform rather than a guess
## about it.
##
## [b]It is a smoke test, not a gameplay test.[/b] Nothing here plays the game or
## measures how anything looks; it asks whether the wiring is live and whether the
## numbers move when the thing they are derived from moves.

@export var world_scene: PackedScene
@export var enemy_scene: PackedScene
@export var bomber_scene: PackedScene
@export var revolver_scene: PackedScene
@export var tent_scene: PackedScene
@export var chest_scene: PackedScene
@export var quit_when_done: bool = true

var _failures: int = 0
var _world: Node


func _ready() -> void:
	# The death test kills an enemy, and a death can pause or slow the tree; this
	# runner has to keep ticking through it or the test would never finish.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_world = world_scene.instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()
	print("")
	print("shadow wiring: %s (%d failure(s))" % [
		"OK" if _failures == 0 else "BROKEN", _failures])
	if quit_when_done:
		get_tree().quit(1 if _failures > 0 else 0)


func _run() -> void:
	var arena := _world.get_node_or_null(^"Arena") as Node2D
	var director := SunController.get_active(self)

	_check("Desert loads", arena != null, "no Arena under World")
	_check("Desert has one Sun", director != null, "none found by group")
	if arena == null or director == null:
		return
	_check("the Sun carries six stages", director.stages.size() == 6,
		"%d stages" % director.stages.size())

	# 1. Player - already in World.tscn.
	var player := _world.get_node_or_null(^"Player") as Node2D
	var player_caster := _caster_of(player)
	_live("Player shadow exists", player_caster)
	if player_caster != null:
		_check("Player shadow is grounded at the artwork's bottom contact",
			_grounded(player_caster),
			"ground %s vs artwork footing %s" % [
				player_caster.get_ground_position(), _footing_of(player_caster)])

	# 2. A normal Enemy.
	var enemy := _spawn(enemy_scene, arena, Vector2(-300.0, -100.0))
	await get_tree().process_frame
	var enemy_caster := _caster_of(enemy)
	_live("Enemy shadow exists", enemy_caster)
	if enemy_caster != null:
		_check("Enemy shadow is grounded at the artwork's bottom contact",
			_grounded(enemy_caster),
			"ground %s vs artwork footing %s" % [
				enemy_caster.get_ground_position(), _footing_of(enemy_caster)])
	# 2b. Body, head and held knife are ONE shadow, not three.
	_test_composite_group("Enemy", enemy, 3)
	_test_composite_group("Player", player, 2)

	# 3. Suicide Bomber - the hop is a visual offset on its own Visual node, and
	# the caster reads that offset rather than the bomber's world Y.
	var bomber := _spawn(bomber_scene, arena, Vector2(300.0, -100.0))
	await get_tree().process_frame
	var bomber_caster := _caster_of(bomber)
	_live("Bomber shadow exists", bomber_caster)
	if bomber_caster != null:
		await _test_bomber_arc(bomber, bomber_caster)

	# 4. Detached head - the same enemy, killed, its head torn off and thrown.
	if enemy != null and enemy_caster != null:
		await _test_detached_head(enemy, enemy_caster)

	# 5. Revolver - its own transform, not the player's.
	var revolver := _spawn(revolver_scene, arena, Vector2(0.0, 200.0))
	await get_tree().process_frame
	var revolver_caster := _caster_of(revolver)
	_live("Revolver shadow exists", revolver_caster)
	if revolver_caster != null:
		_test_revolver(revolver, revolver_caster)

	# 6 and 7. Tent and chest - static scenery, taking their contact point from
	# their own sprite bounds.
	var tent := _spawn(tent_scene, arena, Vector2(-700.0, 300.0))
	var chest := _spawn(chest_scene, arena, Vector2(700.0, 300.0))
	await get_tree().process_frame
	await get_tree().process_frame
	var tent_caster := _caster_of(tent)
	var chest_caster := _caster_of(chest)
	_live("Dust Camp Tent shadow exists", tent_caster)
	_live("Reward Chest shadow exists", chest_caster)
	if tent_caster != null:
		_check("Tent uses its own sprite bounds for the contact point",
			_grounded(tent_caster),
			"ground %s vs artwork footing %s" % [
				tent_caster.get_ground_position(), _footing_of(tent_caster)])
	if chest_caster != null:
		_check("Chest uses its own sprite bounds for the contact point",
			_grounded(chest_caster),
			"ground %s vs artwork footing %s" % [
				chest_caster.get_ground_position(), _footing_of(chest_caster)])

	# 8. The hour reaches every shadow at once.
	await _test_day_stage(director, player_caster)

	# 9. Nothing a shadow adds can be touched, hit or clicked.
	_test_harmless(player_caster)


## Ascent, apex, descent and landing, driven by the bomber's own visual offset -
## the node its hop moves - and never by its world Y.
func _test_bomber_arc(bomber: Node2D, caster: ShadowCaster) -> void:
	var visual := bomber.get_node_or_null(^"Visual") as Node2D
	if visual == null:
		_check("bomber has a Visual node to hop", false)
		return

	var rest := visual.position
	var samples: Array[float] = []
	var offsets: Array[float] = []
	for lift: float in [0.0, 8.0, 16.0, 8.0, 0.0]:
		visual.position = rest - Vector2(0.0, lift)
		caster.update_shadow()
		samples.append(caster.get_visual_height())
		# Signed, along the direction the shadow lies in. The raw offset length is
		# not monotonic: at rest the shadow is pulled back under the object by the
		# hour's length_anchor, and the airborne slide has to cancel that before it
		# starts pushing the shadow out - so the magnitude dips through zero on the
		# way up while the projection itself only ever grows.
		var cast_result := caster.get_last_result()
		offsets.append(cast_result.offset.dot(cast_result.direction))
		await get_tree().process_frame

	_check("bomber ascent increases the projection",
		offsets[1] > offsets[0] and offsets[2] > offsets[1],
		"offsets %s" % [offsets])
	_check("bomber apex is the maximum",
		offsets[2] >= offsets.max(), "offsets %s" % [offsets])
	_check("bomber descent decreases the projection",
		offsets[3] < offsets[2], "offsets %s" % [offsets])
	# A tolerance rather than an exact match: the bomber goes on swaying between
	# these frames and the hour may still be blending, so the projection lands back
	# on the grounded value rather than on the identical float.
	_check("bomber landing returns to the grounded shadow",
		absf(offsets[4] - offsets[0]) < 0.05 and is_zero_approx(samples[4]),
		"offsets %s, heights %s" % [offsets, samples])

	# Horizontal travel moves the ground shadow with the bomber, and does not read
	# as height.
	visual.position = rest
	caster.update_shadow()
	var ground_before := caster.get_ground_position()
	bomber.position += Vector2(120.0, 90.0)
	caster.update_shadow()
	_check("bomber walking moves its ground shadow with it",
		caster.get_ground_position().is_equal_approx(ground_before + Vector2(120.0, 90.0))
			and is_zero_approx(caster.get_visual_height()),
		"ground %s -> %s, height %.3f" % [
			ground_before, caster.get_ground_position(), caster.get_visual_height()])


## The head comes off through the game's own death path, and takes its own caster
## with it - reparented along with the sprite, exactly as its dead eyes are.
func _test_detached_head(enemy: Node2D, body_caster: ShadowCaster) -> void:
	var head := enemy.get_node_or_null(^"HeadAim/Head") as Sprite2D
	var head_caster := _caster_of(head)
	_live("detached head has its own ShadowCaster", head_caster)
	if head_caster == null or head == null:
		return
	_check("head caster is not the body caster", head_caster != body_caster)

	# Attached: the head stands where the enemy stands. Its ground position must
	# come from the enemy's own root, not from the head node hanging off it.
	head_caster.update_shadow()
	body_caster.update_shadow()
	var attached_ground := head_caster.get_ground_position()
	var attached_height := head_caster.get_visual_height()
	_check("attached head grounds at the enemy's own root",
		attached_ground.is_equal_approx(enemy.global_position),
		"head ground %s vs enemy root %s" % [attached_ground, enemy.global_position])
	# The body's ground sits a few pixels off the root, because its anchor is
	# sampled from the body artwork's own footing. What matters is that the head is
	# down at the feet with it rather than up at the head node it hangs from.
	_check("attached head grounds at the feet, not up at the head node",
		attached_ground.distance_to(body_caster.get_ground_position()) < 10.0,
		"head ground %s vs body ground %s" % [
			attached_ground, body_caster.get_ground_position()])
	_check("attached head reads its height from the head itself",
		attached_height > 1.0,
		"height is %.3f - the head should be above the feet" % attached_height)

	var health := enemy.get_node_or_null(^"Health")
	if health == null or not health.has_method(&"kill"):
		_check("enemy can be killed for the separation test", false)
		return

	var body_ground_before := body_caster.get_ground_position()
	health.call(&"kill", Vector2.RIGHT)
	# The reparent is deferred out of the physics callback, and the throw runs for
	# a few frames after that.
	for _i: int in range(8):
		await get_tree().process_frame

	var separated := head.get_parent() != null and head.get_parent().name == "SeveredHead"
	_check("the head separated from the body", separated,
		"head's parent is %s" % [head.get_parent()])
	if not separated:
		return

	_check("the head's caster travelled with it",
		head_caster.is_inside_tree() and head_caster.get_parent() == head,
		"caster parent is %s" % [head_caster.get_parent()])
	# The generic half of the separation: the head was part of the body's one
	# shadow and is now its own object, with nothing anywhere told about it.
	_check("the detached head left the body's shadow group",
		head_caster.get_group() != body_caster.get_group(),
		"both are still in %s" % [body_caster.get_group()])
	_check("the body's shadow group dropped the head",
		not body_caster.get_group().get_casters().has(head_caster),
		"the body group still lists the head")
	_check("body shadow stays on the body",
		body_caster.get_ground_position().is_equal_approx(body_ground_before),
		"body ground moved to %s" % body_caster.get_ground_position())
	_check("head shadow follows the head independently",
		not head_caster.get_ground_position().is_equal_approx(
			body_caster.get_ground_position()),
		"both shadows are at %s" % head_caster.get_ground_position())

	# Rolling: the carrier travels, and the head's ground position travels with it
	# - re-resolved by the caster itself when the reparent moved it.
	var carrier := head.get_parent() as Node2D
	head_caster.update_shadow()
	var rolled_from := head_caster.get_ground_position()
	carrier.position += Vector2(90.0, 0.0)
	head_caster.update_shadow()
	_check("head shadow rolls with the head after separation",
		head_caster.get_ground_position().is_equal_approx(
			rolled_from + Vector2(90.0, 0.0)),
		"ground %s -> %s" % [rolled_from, head_caster.get_ground_position()])

	# And the other half of the same model: a loose piece fakes its height by being
	# drawn further up the screen, so lifting the carrier is height and not arena
	# depth - the mark stays on the floor line it will land on.
	var lifted_from := head_caster.get_ground_position()
	var height_from := head_caster.get_visual_height()
	carrier.position -= Vector2(0.0, 40.0)
	head_caster.update_shadow()
	_check("lifting the rolling head is height, not depth",
		head_caster.get_ground_position().is_equal_approx(lifted_from)
			and head_caster.get_visual_height() > height_from + 1.0,
		"ground %s -> %s, height %.2f -> %.2f" % [
			lifted_from, head_caster.get_ground_position(),
			height_from, head_caster.get_visual_height()])
	carrier.position += Vector2(0.0, 40.0)
	head_caster.update_shadow()
	_check("the rolling head's shadow is still live",
		_is_drawn(head_caster.get_shadow_item()),
		"the shadow went out once the head came off")

	# The carrier spins the head as it rolls, and that reaches its own shadow.
	head_caster.update_shadow()
	var turn_before := head_caster.get_last_result().rotation
	carrier.rotation += deg_to_rad(50.0)
	head_caster.update_shadow()
	_check("head rotation affects its own shadow",
		is_equal_approx(angle_difference(turn_before, head_caster.get_last_result().rotation),
			deg_to_rad(50.0)),
		"shadow turned by %.4f rad" % angle_difference(turn_before, head_caster.get_last_result().rotation))

	# The flip is the head's own scale sign - the same one LookAtTarget writes.
	var mirror_before := signf(head_caster.get_last_result().scale.x)
	head.scale.x = -head.scale.x
	head_caster.update_shadow()
	_check("flip mirrors the silhouette",
		signf(head_caster.get_last_result().scale.x) != mirror_before,
		"scale.x stayed %.3f" % head_caster.get_last_result().scale.x)


## The weapon's own transform: the spin, the flip and the scale all live on its
## Art pivot, and the shadow is anchored to the weapon rather than to the player.
func _test_revolver(revolver: Node2D, caster: ShadowCaster) -> void:
	var art := revolver.get_node_or_null(^"Art") as Node2D
	if art == null:
		_check("revolver has an Art pivot", false)
		return

	caster.update_shadow()
	var turn_before := caster.get_last_result().rotation
	art.rotation += deg_to_rad(90.0)
	caster.update_shadow()
	_check("Revolver shadow follows the spin rotation",
		is_equal_approx(angle_difference(turn_before, caster.get_last_result().rotation), deg_to_rad(90.0)),
		"shadow turned by %.4f rad" % angle_difference(turn_before, caster.get_last_result().rotation))
	art.rotation -= deg_to_rad(90.0)

	# HeldItemFlip writes scale.y on the Art pivot; the caster sees the mirroring
	# through the transform's determinant rather than by asking a weapon anything.
	caster.update_shadow()
	var mirror_before := signf(caster.get_last_result().scale.x)
	art.scale.y = -art.scale.y
	caster.update_shadow()
	_check("Revolver shadow follows the left/right flip",
		signf(caster.get_last_result().scale.x) != mirror_before,
		"scale.x stayed %.3f" % caster.get_last_result().scale.x)
	art.scale.y = -art.scale.y

	# The complaint this pass fixes, at the weapon: a revolver spinning in the hand
	# turns through every angle there is, and at none of them may it choose a
	# different sun or wander off the weapon. Its silhouette turns with it - it has
	# to, it is the artwork - but the light it is laid down along, and the point on
	# the floor the weapon is standing on, are the sun's and the weapon's and cannot
	# be moved by a rotation.
	caster.update_shadow()
	var group := caster.get_group()
	var sun := group.get_shadow_direction()
	var standing := group.get_ground_position()
	var wrong_way := 0
	var moved_ground := 0.0
	var wandered := 0.0
	for degrees: float in [0.0, 60.0, 120.0, 180.0, 240.0, 300.0]:
		art.rotation = deg_to_rad(degrees)
		caster.update_shadow()
		if not group.get_shadow_direction().is_equal_approx(sun):
			wrong_way += 1
		moved_ground = maxf(
			moved_ground, group.get_ground_position().distance_to(standing))
		wandered = maxf(
			wandered, caster.get_last_result().position.distance_to(standing))
	art.rotation = 0.0
	caster.update_shadow()
	_check("spinning the Revolver never redirects the shadow", wrong_way == 0,
		"%d of 6 sampled angles pointed somewhere else" % wrong_way)
	_check("spinning the Revolver never moves the point it is standing on",
		moved_ground < 0.01, "the ground point wandered %.3f px" % moved_ground)
	# It turns inside its own silhouette rather than swinging out on an arm: the
	# whole excursion has to stay inside the weapon's own artwork.
	var reach := caster.get_source_size().length()
	_check("spinning the Revolver keeps its shadow on the weapon",
		wandered < reach, "it reached %.1f px from a %.1f px weapon" % [wandered, reach])

	# And the same of the flip, which is where a weapon's shadow used to jump to the
	# far side of it every time the player turned round. The silhouette mirrors -
	# the artwork did - but the light and the footing do not move.
	caster.update_shadow()
	var upright_scale := caster.get_last_result().scale.x
	art.scale.y = -art.scale.y
	caster.update_shadow()
	_check("flipping the Revolver never redirects or moves its shadow",
		group.get_shadow_direction().is_equal_approx(sun)
			and group.get_ground_position().is_equal_approx(standing),
		"light %s, footing %s" % [
			group.get_shadow_direction(), group.get_ground_position()])
	_check("flipping the Revolver still mirrors its silhouette",
		signf(caster.get_last_result().scale.x) != signf(upright_scale),
		"scale.x stayed %.3f" % caster.get_last_result().scale.x)
	art.scale.y = -art.scale.y
	caster.update_shadow()

	caster.update_shadow()
	var length_before := caster.get_last_result().length
	revolver.scale *= 2.0
	caster.update_shadow()
	_check("Revolver shadow follows the weapon scale",
		caster.get_last_result().length > length_before * 1.5,
		"length %.2f -> %.2f" % [length_before, caster.get_last_result().length])
	revolver.scale *= 0.5

	var ground_before := caster.get_ground_position()
	revolver.position += Vector2(150.0, -40.0)
	caster.update_shadow()
	_check("Revolver shadow is anchored to the weapon, not the player",
		caster.get_ground_position().is_equal_approx(
			ground_before + Vector2(150.0, -40.0)),
		"ground %s -> %s" % [ground_before, caster.get_ground_position()])


## The hour reaches the shadows through the director, and changes both how long
## they are and which way they lie.
func _test_day_stage(director: SunController, caster: ShadowCaster) -> void:
	if caster == null:
		return
	var noon := -1
	var evening := -1
	for i: int in range(director.stages.size()):
		if director.stages[i].stage_name == &"noon":
			noon = i
		elif director.stages[i].stage_name == &"evening":
			evening = i
	if noon < 0 or evening < 0:
		_check("the desert has a noon and an evening", false)
		return

	director.force_stage(noon, 0.0)
	caster.update_shadow()
	var noon_length := caster.get_last_result().length
	var noon_direction := caster.get_last_result().direction

	director.force_stage(evening, 0.0)
	caster.update_shadow()
	var evening_length := caster.get_last_result().length
	var evening_direction := caster.get_last_result().direction

	_check("the day stage changes shadow length",
		evening_length > noon_length * 2.0,
		"noon %.2f, evening %.2f" % [noon_length, evening_length])
	_check("the day stage changes shadow direction",
		noon_direction.angle_to(evening_direction) > 0.5,
		"noon %s, evening %s" % [noon_direction, evening_direction])


## What a shadow adds to a scene must be inert: a sprite, no body, no area, no
## control - and nothing at all when the caster joined a group that already
## existed.
func _test_harmless(caster: ShadowCaster) -> void:
	if caster == null:
		return
	var added := caster.get_children()
	_check("a caster adds at most one node", added.size() <= 1,
		"it added %d" % added.size())
	var shadow: Node = caster.get_shadow_item()
	_check("the shadow is a plain ShadowShape - no body, no area, no control",
		shadow is ShadowShape and not (shadow is CollisionObject2D)
			and not (shadow is Control),
		"it is a %s" % [shadow])
	var root := caster.get_group().get_render_root()
	_check("the shadow draws on the ground layer",
		root != null and root.z_index < 0 and not root.z_as_relative
			and not root.y_sort_enabled,
		"z %d, relative %s, y_sort %s" % [
			root.z_index, root.z_as_relative, root.y_sort_enabled])


## The correction the whole pass exists for: a figure made of a body, a head and
## whatever it is holding is ONE shadow, composited once, rather than a pile of
## overlapping ones.
func _test_composite_group(label: String, node: Node2D, expected_parts: int) -> void:
	var casters := _casters_under(node)
	_check("%s has %d shadow contributors" % [label, expected_parts],
		casters.size() == expected_parts, "it has %d" % casters.size())
	if casters.is_empty():
		return

	var groups: Array[ShadowGroup] = []
	for caster: ShadowCaster in casters:
		var group := caster.get_group()
		if group != null and not groups.has(group):
			groups.append(group)
	_check("%s body, head and weapon share ONE shadow group" % label,
		groups.size() == 1, "%d groups: %s" % [groups.size(), groups])
	if groups.size() != 1:
		return

	var group := groups[0]
	_check("%s composites its parts into one silhouette" % label, group.is_union(),
		"the group is drawing its %d parts separately" % group.get_caster_count())
	_check("%s fades that silhouette once, not once per part" % label,
		is_equal_approx(group.get_caster_alpha_scale(), 1.0),
		"parts are being faded individually at %.3f" % group.get_caster_alpha_scale())
	var root := group.get_render_root()
	_check("%s draws one shadow, on the ground layer" % label,
		root != null and root.visible and root.z_index < 0,
		"render root is %s" % [root])


func _casters_under(node: Node) -> Array[ShadowCaster]:
	var found: Array[ShadowCaster] = []
	if node == null:
		return found
	var caster := node as ShadowCaster
	if caster != null:
		found.append(caster)
	for child: Node in node.get_children():
		found.append_array(_casters_under(child))
	return found


func _spawn(scene: PackedScene, parent: Node, at: Vector2) -> Node2D:
	if scene == null:
		return null
	var node := scene.instantiate() as Node2D
	if node == null:
		return null
	parent.add_child(node)
	node.global_position = at
	return node


## The first caster on a node or under it. Deliberately a search rather than a
## path, so the test does not encode where any particular object keeps its caster.
func _caster_of(node: Node) -> ShadowCaster:
	if node == null:
		return null
	for child: Node in node.get_children():
		var caster := child as ShadowCaster
		if caster != null:
			return caster
	return null


## Where the caster's artwork actually meets the floor, measured independently of
## the caster so the check is not the caster agreeing with itself.
func _footing_of(caster: ShadowCaster) -> Vector2:
	var sprite := caster.get_source_sprite()
	if sprite == null:
		return Vector2.ZERO
	return sprite.global_transform * SpriteBounds.local_footing(sprite)


func _grounded(caster: ShadowCaster) -> bool:
	return caster.get_ground_position().distance_to(_footing_of(caster)) < 1.0


func _live(what: String, caster: ShadowCaster) -> void:
	if caster == null:
		_check(what, false, "no ShadowCaster on the object")
		return
	var shadow := caster.get_shadow_item()
	_check(what, _is_drawn(shadow),
		"caster present but its shadow mesh is %s" % [shadow])


func _check(what: String, passed: bool, detail: String = "") -> void:
	if passed:
		print("PASS  %s" % what)
		return
	_failures += 1
	print("FAIL  %s%s" % [what, "" if detail.is_empty() else "  -  " + detail])


## Whether a shadow mesh is actually putting something on the floor: it is shown,
## it has artwork to be the silhouette of, and geometry was built for it this
## frame. Alpha lives in the vertex colours now, so a modulate cannot be asked.
func _is_drawn(item: ShadowShape) -> bool:
	return item != null and item.visible and item.has_shape()
