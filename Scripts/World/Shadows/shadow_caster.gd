class_name ShadowCaster
extends Node2D
## One part of a shadow. Drop it under anything with a [Sprite2D] and that sprite's
## silhouette joins whatever object's shadow it belongs to - see [ShadowGroup] -
## and is thrown onto the floor by the map's one [SunController].
##
## [b]It contributes a picture and a place to stand. It does not project
## anything.[/b] A caster hands its group the artwork's real world transform and
## nothing else; the group assembles every part of the object in world space and
## the sun is asked where each point of that picture lands. No sprite has a shadow
## direction, a shadow offset or a shadow length of its own, so a character turning
## to face left, a revolver spinning in the air and a head rolling across the sand
## all keep their shadows lying the same way as everything else in the world - and
## no part can stretch, widen or drag any other part of the same object.
##
## [b]It does not know what it is attached to.[/b] There is no branch here for a
## player, an enemy, a boss, a bomber, a severed head, a weapon, a prop or a chest,
## and there must never be one. Every difference between a cactus and a thrown bone
## is inspector values on this node.
##
## [b]The coordinate model is the part to understand.[/b] Two things are kept
## strictly apart:
##
##   * [b]ground position[/b] - where the object is standing on the arena floor. It
##     comes from the root's world transform plus [member ground_anchor_local], and
##     nothing else.
##   * [b]height[/b] - how far the artwork is drawn [i]above[/i] that ground
##     position, in world pixels.
##
## In a top-down game world Y is depth into the arena, not height, and confusing
## the two is the mistake this class exists to make impossible. Walking north moves
## the ground position and leaves the height at zero; jumping on the spot leaves the
## ground position alone and raises the height.
##
## Because of that, [b]airborne needs no special case[/b] and needs no number
## either: a part drawn further up the screen than the ground line simply [i]is[/i]
## higher, and the group measures it. There is no [code]is_jumping[/code], no jump
## start or land callback and no class that has to be a bomber.
## [member height_source] is only for an owner whose artwork does [i]not[/i] move
## when it rises - a projectile on an arc that knows its own height as a number -
## and it adds a lift on top of what is drawn.
##
## [b]Which shadow it joins is worked out from the tree.[/b] See
## [method resolve_group]. A part of a larger thing draws into that thing's
## [ShadowGroup] so the whole object reads as one mark on the floor; the same part
## torn loose finds no group above it any more and becomes its own. Nothing
## announces the change and nothing knows what kind of piece it is.

## How often the shadow is worked out.
enum CastMode {
	## Every frame. For anything that moves, turns or leaves the ground.
	CAST_DYNAMIC,
	## Only when the sun moves. For scenery that never moves - a cactus, a tent -
	## which is most of the shadows in a map.
	CAST_STATIC,
	## Only when [method update_shadow] is called. For something ticked by its owner
	## on its own schedule.
	CAST_MANUAL,
}

## Where an [i]extra[/i] lift comes from, on top of where the artwork is actually
## drawn.
enum HeightSource {
	## None. The artwork's own drawn position is the whole of its height, which is
	## what everything that lifts its art off the ground wants - and that is nearly
	## everything.
	HEIGHT_VISUAL_OFFSET,
	## Asked of the ground root by calling [member height_method] on it. For an
	## owner that rises without its artwork moving. Generic: any node that answers
	## the method qualifies, and this node does not care which.
	HEIGHT_METHOD,
	## Pushed in from outside with [method set_visual_height].
	HEIGHT_MANUAL,
	## None, and never asked for.
	HEIGHT_NONE,
}

## How the node that says where the object is standing is found.
enum GroundRootMode {
	## The node at [member ground_root_path]. What anything that keeps the same
	## parent for its whole life uses, which is nearly everything.
	GROUND_ROOT_PATH,
	## The nearest ancestor marked as a ground root - see
	## [member ground_root_group] - falling back to [member ground_root_path] when
	## there is none above it any more.
	##
	## [b]This is what lets one caster survive being torn off its owner.[/b] A part
	## of a larger thing stands where that thing stands; the same part, thrown
	## clear, stands where it has landed. Both are the same question - "what am I
	## attached to?" - asked again after the hierarchy changed, and the answer is
	## re-resolved automatically every time the caster re-enters the tree, which is
	## what a reparent is.
	GROUND_ROOT_NEAREST_MARKED,
}

## How the shadow this caster draws into is found.
enum GroupMode {
	## The nearest [ShadowGroup] at or above this caster, and a group of its own
	## when there is none. See [method resolve_group].
	GROUP_NEAREST,
	## The group at [member shadow_group_path], for a part that has to be told.
	GROUP_PATH,
	## Always its own group, whatever it is attached to. For something that should
	## keep a shadow of its own even while it is carried.
	GROUP_OWN,
}

## Group every caster joins, so the world can find them all without being wired to
## any - including ones spawned long after the map loaded.
const GROUP := &"shadow_caster"

## Whether this caster contributes at all. Off drops its part out of the object's
## shadow and stops the work.
@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_node_ready():
			if _group != null:
				_group.refresh_processing()
			refresh_shadow()
## How often the shadow is recalculated - see [enum CastMode].
@export var cast_mode: CastMode = CastMode.CAST_DYNAMIC:
	set(value):
		cast_mode = value
		if is_node_ready() and _group != null:
			_group.refresh_processing()

@export_group("Source")
## The [Sprite2D] whose silhouette is contributed. Left empty, the first sprite with
## a texture found under [member ground_root_path] is used, so an ordinary character
## or prop needs nothing filled in here at all.
@export var source_sprite_path: NodePath:
	set(value):
		source_sprite_path = value
		if is_node_ready():
			rebind()
## The node whose world transform says where the object is standing. Its origin plus
## [member ground_anchor_local] is the ground position, and it is the only thing
## consulted for it - so artwork lifted off the ground cannot move it.
@export var ground_root_path: NodePath = ^"..":
	set(value):
		ground_root_path = value
		if is_node_ready():
			rebind()
## How that node is found - see [enum GroundRootMode]. The default reads the path
## above and nothing else.
@export var ground_root_mode: GroundRootMode = GroundRootMode.GROUND_ROOT_PATH:
	set(value):
		ground_root_mode = value
		if is_node_ready():
			_needs_root_resolve = true
			refresh_shadow()
## Group an object's root joins to say "things attached to me stand where I stand".
## Read only under [constant GROUND_ROOT_NEAREST_MARKED].
##
## Nothing but membership is required of it, so marking a new object is adding it to
## a group in the inspector and no code anywhere learns a new name.
@export var ground_root_group: StringName = &"shadow_ground_root"
## Method the ground root is asked for its own ground position, when it answers it.
## For anything that fakes height by moving its artwork down the screen - a bouncing
## piece of debris, a thrown object - whose real footing on the floor is not where
## its node happens to be drawn. Any node that answers it qualifies.
@export var ground_position_method: StringName = &"get_shadow_ground_position"

@export_group("Ground anchor")
## Whether the ground anchor is measured from the artwork instead of typed in.
##
## [b]It is sampled once, as the caster readies, and then held.[/b] That is
## deliberate: the anchor is where the object meets the floor when it is resting on
## it, and a live measurement would rise with the artwork during a jump and report a
## height of zero for the whole flight. Call [method resample_ground_anchor] if the
## resting pose has genuinely changed.
@export var auto_ground_anchor: bool = true:
	set(value):
		auto_ground_anchor = value
		if is_node_ready():
			resample_ground_anchor()
## Where the object meets the ground, in the ground root's own local space. Used when
## [member auto_ground_anchor] is off, and holds the sampled answer when it is on.
## Never assume a sprite's origin is at its feet - measure or set this.
@export var ground_anchor_local := Vector2.ZERO:
	set(value):
		ground_anchor_local = value
		if is_node_ready() and not auto_ground_anchor:
			_anchor = value
			refresh_shadow()

@export_group("Height")
## Where an extra lift comes from, on top of where the artwork is drawn - see
## [enum HeightSource]. Leave it alone unless the owner rises without its art
## moving.
@export var height_source: HeightSource = HeightSource.HEIGHT_VISUAL_OFFSET
## Method called on the ground root for that lift. Any node that answers it
## qualifies; nothing here knows what kind of node that is.
@export var height_method: StringName = &"get_visual_height"
## Scales the extra lift before the sun projects it. For a hop that should read as
## bigger or smaller than the number the owner reports.
@export_range(0.0, 8.0, 0.01) var height_multiplier: float = 1.0

@export_group("Shadow group")
## How the shadow this caster draws into is found - see [enum GroupMode].
@export var group_mode: GroupMode = GroupMode.GROUP_NEAREST:
	set(value):
		group_mode = value
		if is_node_ready():
			_needs_group_resolve = true
			refresh_shadow()
## The group to draw into under [constant GROUP_PATH].
@export var shadow_group_path: NodePath
## Method the ground root is asked for the node it is currently carried by, when it
## answers it. A weapon in a hand is part of the figure holding it and belongs in
## that figure's shadow; the same weapon lying in the sand is not and does not.
##
## [b]It is the object that declares what it is attached to, not the shadow
## system.[/b] Anything that answers this joins its carrier's shadow, and anything
## that stops answering it - or answers null - is on its own again, with no code
## here that knows a weapon from a hat.
@export var group_owner_method: StringName = &"get_shadow_group_owner"
## Where a group made for this caster alone puts its shadow in the draw order.
## Ignored when the caster joins a group that already exists.
@export var shadow_z_index: int = -8

@export_group("Tuning")
## Shifts the finished shadow in world pixels, [b]after[/b] the sun has placed it.
##
## Negative values pull the mark back towards the thing casting it, which is what a
## prop drawn with its base a little above its own footing wants. It is a nudge to
## the result and [b]never a way to fake the light[/b]: it cannot turn a shadow, it
## cannot lengthen one, and it does not move with the hour. Read from the group's
## anchor part, so on an assembled object it belongs on the part standing on the
## floor - see [member ShadowGroup.shadow_offset] for the same control on the whole
## object.
@export var shadow_offset := Vector2.ZERO
## How far the finished shadow is pulled back along the light, in world pixels.
##
## [b]Positive brings the mark closer to the object, negative pushes it further
## away.[/b] This is the control to reach for when a prop's shadow sits away from
## its base - a cactus drawn with its lowest pixels a little above where it actually
## meets the sand throws from that height, and the gap that leaves is closed by
## pulling the mark back a few pixels towards it.
##
## It is [member shadow_offset] said in the one direction that means anything: the
## offset is two numbers in world pixels and has to be re-authored for every hour,
## because the light turns as the day does. This is measured [i]along the
## projection[/i], so a value set once at noon still closes the same gap at dusk.
##
## Like the offset it slides the finished shadow and nothing else. It cannot turn
## the light, lengthen a shadow or bend a silhouette - see
## [member ShadowGroup.shadow_pull] for the same control on the whole object.
@export_range(-512.0, 512.0, 1.0) var shadow_pull: float = 0.0
## Scales how solid this part is inside its group's silhouette. Left at 1 - which is
## what a part of an assembled object wants - the whole object fades as one.
@export_range(0.0, 1.0, 0.01) var opacity_multiplier: float = 1.0
## Overrides the hour's own shadow edge softness for the group this caster
## makes for itself - see [member ShadowGroup.softness_override], which this
## simply hands to that group the moment it is made.
##
## [b]Only reaches a group this caster made on its own.[/b] Nearly every small
## prop in the game is exactly that - one [ShadowCaster], no [ShadowGroup] of
## its own in the scene - so this is the one field a prop's own scene sets to
## read a little harder than a character's soft-edged shadow without ever
## becoming a sharp cut-out. A caster that joins somebody else's group - a
## part of an assembled character - leaves this at -1 and reads that group's
## own value instead, set directly on the [ShadowGroup] node when one exists.
@export_range(-1.0, 1.0, 0.01) var shadow_softness_override: float = -1.0
## Whether the silhouette fades with its source. On, a piece being faded out - or
## hidden, or stowed - takes its share of the shadow with it even when the shadow is
## drawn somewhere else in the tree.
@export var follow_source_alpha: bool = true

@export_group("Sun")
## The map's [SunController], found by group when left unresolved. Only read when
## this caster has to make a group of its own.
@export var sun_path: NodePath

var _root: Node2D
var _source: Sprite2D
var _group: ShadowGroup
## The group this caster made for itself because there was none above it. Kept so it
## can be taken down again if the caster is later attached to something.
var _own_group: ShadowGroup
var _result := ShadowTransform.new()
## Whether [member _result] still has to be worked out from the last frame's pose.
## The readout costs more than the drawing does and nothing in the game reads it, so
## it is filled in when somebody asks rather than every frame - see
## [method get_last_result].
var _result_stale: bool = true
var _result_group: ShadowGroup
var _result_drawn: bool = false
var _anchor := Vector2.ZERO
## The root's own rotation and scale as they stood when [member _anchor] was
## sampled. The anchor is where the object rests on the floor, so it is carried by
## the root's [i]position[/i] alone from then on: a revolver spun in a hand turns
## about its own origin and does not walk the point it is standing on round in a
## circle - see [method get_ground_position].
var _anchor_basis := Transform2D.IDENTITY
var _manual_height: float = 0.0
## This frame's pose and fade, taken once by [method prepare_frame] and read back by
## the group. Held rather than re-derived so the group can find out whether anything
## moved before it builds anything.
var _frame_world := Transform2D.IDENTITY
var _frame_alpha: float = 0.0
var _frame_ok: bool = false
## What is being drawn, as one number: the texture, which frame of it, and which way
## round. Changing any of them changes the silhouette even when the pose has not
## moved at all.
var _frame_stamp: int = 0
## Drawn size of the source's opaque artwork, cached against the texture it was
## measured from so an animating sprite re-measures only on a real change.
var _source_size := Vector2.ONE
var _measured_texture: Texture2D
## Set every time the caster enters the tree, so a reparent is noticed without
## anything having to announce it.
var _needs_root_resolve: bool = false
var _needs_group_resolve: bool = false
## Who the object last said it was being carried by, and whether it answers the
## question at all - see [method _check_carrier]. A reparent is noticed by the tree;
## changing hands without moving in the tree is noticed here.
var _carrier: Node
var _carrier_asked: bool = false
## Instance ids of the group and everything above it, so the walk that gathers the
## source's own fade knows where the tree takes over - see [method _source_alpha].
var _alpha_stops: Dictionary = {}


## [b]A reparent is an exit and an entry[/b], so this is where a caster torn off its
## owner - or handed to a new one - finds out.
##
## The work itself is deferred rather than done here. It has to be: leaving the tree
## dropped the caster out of the group that was ticking it, so nothing would ask it
## for a shadow again and it would simply go dark - and doing it inside the
## notification would read a hierarchy that is still half way through changing.
func _enter_tree() -> void:
	add_to_group(GROUP)
	if not is_node_ready():
		return
	_needs_root_resolve = true
	_needs_group_resolve = true
	reattach.call_deferred()


func _exit_tree() -> void:
	if _group != null:
		_group.unregister(self)
		_group = null


func _ready() -> void:
	rebind()
	resolve_group()
	refresh_shadow()


## Works out afresh what this caster is attached to and which shadow it draws into,
## then draws it. Called a frame after any reparent, and safe to call by hand.
func reattach() -> void:
	if not is_inside_tree() or not is_node_ready():
		return
	_root = _resolve_ground_root()
	_needs_root_resolve = false
	resolve_group()
	# The root changed, so what this part stands on changed - and with it whether it
	# is one of the object's own parts or something the object is carrying.
	if _group != null:
		_group.refresh_anchor()
	refresh_shadow()


## Finds the root, the source sprite and the group again, and re-measures the
## artwork. Call after swapping a sprite's texture for one of a different shape, or
## after re-parenting.
func rebind() -> void:
	_root = _resolve_ground_root()
	_needs_root_resolve = false

	_source = _resolve_source_sprite()
	_measure_source()
	resample_ground_anchor()


## Works out which shadow this caster draws into and joins it, leaving whichever one
## it was in before.
##
## [b]The rule is the tree, and one question the object itself may answer.[/b] The
## nearest [ShadowGroup] at or above the caster wins, so every part of an assembled
## object finds the same one; failing that, the ground root is asked
## [member group_owner_method] - which is how something being carried says whose
## figure it is currently part of - and failing that the caster makes a group of its
## own. Nothing here knows what kind of part it is, and a part that changes hands or
## is torn loose simply gets a different answer the next time it is asked.
func resolve_group() -> ShadowGroup:
	_needs_group_resolve = false
	_carrier = get_group_owner_node()
	var found := _find_group()
	if found == _group and found != null:
		_build_alpha_stops()
		return _group

	if _group != null:
		_group.unregister(self)
		_group = null
	if found == null:
		found = _make_own_group()
	else:
		_discard_own_group(found)

	_group = found
	if _group != null:
		_group.register(self)
	_build_alpha_stops()
	return _group


## The node whose world transform says where this part is standing - see
## [member ground_root_path]. A part of a larger thing answers that thing; a part
## lying loose in the world answers itself.
##
## It is what tells a group's contributors apart from the things one of them is
## [i]carrying[/i]: a body and a head stand where the figure stands, and a weapon in
## its hand does not stand anywhere at all - see
## [method ShadowGroup._resolve_anchor].
func get_ground_root() -> Node2D:
	return _root


## Whatever the object says is carrying it right now, or null when it is not being
## carried - and null for anything that never answers the question.
func get_group_owner_node() -> Node:
	if not _carrier_asked or not is_instance_valid(_root):
		return null
	var owner_node: Node = _root.call(group_owner_method)
	return null if owner_node == _root else owner_node


## Notices that the object has been picked up, drawn, holstered or dropped, and
## joins whichever shadow that answer now points at.
##
## [b]It has to be asked, because nothing announces it.[/b] Something carried by a
## figure without being parented to it - a weapon that lives beside its owner in the
## scene and only follows the hand - is never reparented, so the tree cannot report
## a change of hands the way it reports a severed head being thrown clear. The
## object's own answer is the only thing that changes, so it is compared once a
## frame: one call returning a node while the answer holds.
##
## The re-resolve itself is deferred. This is asked from inside the group's own walk
## over its contributors, and joining another group there would take this caster out
## of the list being walked.
func _check_carrier() -> void:
	if _needs_group_resolve:
		return
	var carrier := get_group_owner_node()
	if carrier == _carrier:
		return
	_carrier = carrier
	_needs_group_resolve = true
	resolve_group.call_deferred()


## Measures the ground anchor from the artwork's resting pose, or takes the typed
## value when [member auto_ground_anchor] is off.
func resample_ground_anchor() -> void:
	if not auto_ground_anchor or _source == null or _root == null:
		_anchor = ground_anchor_local
		_capture_anchor_basis()
		return
	# Where the artwork currently meets the floor, brought back into the root's own
	# space. Sampled now, held from now on - see auto_ground_anchor.
	var contact := _source.global_transform * SpriteBounds.local_footing(_source)
	_anchor = _root.global_transform.affine_inverse() * contact
	ground_anchor_local = _anchor
	_capture_anchor_basis()


## Where this caster is standing on the arena floor, in world space.
##
## [b]Read off the root and nothing else.[/b] Artwork lifted for a jump cannot move
## it, which is exactly what keeps world Y - arena depth - from being mistaken for
## height. A root that knows its own footing better than its transform does says so
## by answering [member ground_position_method].
##
## [b]The root's turn is not a move.[/b] The anchor is carried by the root's
## position and by the rotation it was resting in when the anchor was sampled - not
## by whatever pose it is in now. A revolver spun in a hand turns about its own
## origin; if the anchor turned with it, the point the weapon is standing on would
## orbit that origin and its shadow would swing round with the spin instead of
## staying put underneath it.
func get_ground_position() -> Vector2:
	if not is_instance_valid(_root):
		return global_position
	if _root.has_method(ground_position_method):
		return _root.call(ground_position_method)
	return _root.global_position + _anchor_basis.basis_xform(_anchor)


## Remembers the pose the ground anchor was measured in, so that from now on only
## the root's position carries it.
func _capture_anchor_basis() -> void:
	if not is_instance_valid(_root):
		_anchor_basis = Transform2D.IDENTITY
		return
	var pose := _root.global_transform
	_anchor_basis = Transform2D(pose.x, pose.y, Vector2.ZERO)


## How far this part's artwork is currently drawn above its ground position, in world
## pixels. Zero means resting on the floor.
##
## A readout: the group measures the whole object's bounds for itself and does not
## call this. It is what a test, a debug panel or an owner curious about its own
## piece reads.
func get_visual_height() -> float:
	var height := get_projection_lift()
	if _source != null and _source.texture != null:
		var contact := _source.global_transform * SpriteBounds.local_footing(_source)
		height += get_ground_position().y - contact.y
	# Held at the floor. Artwork drawn a hair below its sampled anchor - a leg
	# mid-stride, a rounding error in a transform - is resting on the ground, not
	# sunk into it, and a reader asking how high something is wants zero for that.
	return maxf(height, 0.0)


## The extra lift this part claims on top of where its artwork is drawn, in world
## pixels - see [enum HeightSource]. Zero for everything that simply moves its art.
func get_projection_lift() -> float:
	var lift := 0.0
	match height_source:
		HeightSource.HEIGHT_METHOD:
			if is_instance_valid(_root) and _root.has_method(height_method):
				lift = float(_root.call(height_method))
		HeightSource.HEIGHT_MANUAL:
			lift = _manual_height
		_:
			lift = 0.0
	return maxf(lift, 0.0) * height_multiplier


## Sets that lift directly, for an owner that knows it and would rather push it than
## have it measured. Only used under [constant HEIGHT_MANUAL].
func set_visual_height(height: float) -> void:
	_manual_height = height
	if cast_mode == CastMode.CAST_MANUAL:
		return
	refresh_shadow()


## The source sprite's live pose, with its own mirroring folded into the transform.
## A readout - see [member ShadowTransform.scale] - so a caller can tell a mirrored
## silhouette from an upright one without asking a sprite about
## [member Sprite2D.flip_h]. The shadow itself is drawn with the sprite's own flip
## flags copied across, so the picture is reproduced rather than reconstructed.
func get_source_transform() -> Transform2D:
	if _source == null:
		return global_transform
	var xf := _source.global_transform
	var mirror := Vector2(-1.0 if _source.flip_h else 1.0, -1.0 if _source.flip_v else 1.0)
	if not mirror.is_equal_approx(Vector2.ONE):
		xf = xf.scaled_local(mirror)
	return xf


## Whether this caster has something to contribute to its object's silhouette right
## now.
func is_contributing() -> bool:
	return enabled and is_node_ready() and _source != null and _source.texture != null


## The top and bottom of this part's artwork in world space, as (highest y, lowest
## y). What the group measures the object's ground line and height from, and it is
## the [i]opaque[/i] artwork rather than the texture canvas - so a rotated weapon
## and a raised arm move it and nothing has to be authored.
func get_world_height_band() -> Vector2:
	if _source == null or _source.texture == null:
		return Vector2.ZERO
	var corners := SpriteBounds.global_corners(_source)
	var lift := get_projection_lift()
	var top := INF
	var bottom := -INF
	for corner: Vector2 in corners:
		var y := corner.y - lift
		top = minf(top, y)
		bottom = maxf(bottom, y)
	return Vector2(top, bottom)


## The last result worked out for this part, for a test or a debug readout.
##
## Worked out here rather than while drawing. Nothing in the game reads it - the
## silhouette is in the geometry, not in a transform - and following a part's axes
## through the sun costs more than putting its shadow on the floor does, so a crowd
## of enemies does not pay for a readout nobody asked for.
func get_last_result() -> ShadowTransform:
	if _result_stale:
		_result_stale = false
		if _frame_ok and is_instance_valid(_result_group):
			_record(_result_group, _frame_world, _frame_alpha, _result_drawn)
		else:
			_result.visible = false
	return _result


## The source sprite currently being contributed, or null when none was found.
func get_source_sprite() -> Sprite2D:
	return _source


## The texture the silhouette is drawn from - the source's own, never a copy.
func get_source_texture() -> Texture2D:
	return null if _source == null else _source.texture


## The drawn size of that artwork's opaque part, in world pixels.
func get_source_size() -> Vector2:
	return _source_size


## The shadow this caster draws into, or null before it has readied.
func get_group() -> ShadowGroup:
	return _group


## The mesh this caster's part of the shadow is drawn on. It is owned by the
## group, not by this node, and its vertices are already standing where the sun
## put them.
func get_shadow_item() -> ShadowShape:
	return null if _group == null else _group.get_shape_for(self)


## Redraws this part's object. [b]The whole object[/b] - a part cannot be redrawn on
## its own, because where it goes is decided by a projection worked out for the
## assembled picture it belongs to.
func refresh_shadow() -> void:
	if not is_node_ready():
		return
	if _needs_group_resolve:
		resolve_group()
	if _group == null:
		return
	if _needs_root_resolve:
		# The hierarchy changed under this caster - it was reparented, or its owner
		# was. The anchor itself is deliberately left alone: it is where the object
		# meets the floor when resting, and re-sampling it here would take that
		# measurement from whatever pose the piece happened to be thrown in.
		_needs_root_resolve = false
		_root = _resolve_ground_root()
	_group.update_group(true)


## The old name for [method refresh_shadow], kept because it reads better from
## outside: an owner ticking its own piece asks for its shadow to be updated.
func update_shadow() -> void:
	refresh_shadow()


## Hands this part's artwork and its real world pose to [param group], which cuts
## it up and puts every point of it through the sun, and records where it landed.
##
## [b]The pose handed over is the artwork's own[/b] - not turned, not scaled, not
## straightened, and carrying whatever extra lift this part claims. That is all a
## part contributes. It does not decide a direction, a length or a footing, so a
## head stays above a body, a knife stays out at arm's length, and nothing a part
## does to itself can reach any other part of the same object.
func write_into_group(group: ShadowGroup) -> bool:
	if group == null:
		return false
	# The whole object, because a part cannot be drawn on its own: where it goes is
	# decided by a projection worked out for the assembled picture it belongs to, and
	# against a ground point the group measures rather than this part.
	group.update_group(true)
	return _result_drawn


## Takes this part's pose and fade for the frame, without building anything.
##
## [b]This is the whole of what a part reports.[/b] The artwork's own world
## transform - carrying its position, its turn, its scale, its mirroring and
## whatever extra lift the part claims - and how faded it is. It decides no
## direction, no length and no footing, so nothing a part does to itself can reach
## another part of the same object or turn the light.
##
## It is separate from drawing on purpose: the group asks every part where it is
## [i]before[/i] it builds anything, both because the assembled bounds have to be
## known before the first point is projected, and because comparing the answer with
## last frame's is how a group that has not moved gets to do no work at all.
func prepare_frame() -> bool:
	# Asked whether or not there is anything to draw: a weapon is holstered out of
	# sight for as long as it takes to change hands.
	_check_carrier()
	if not is_contributing():
		_frame_ok = false
		return false

	_sync_texture()

	# The lift moves the whole part rather than its origin alone, which is why it
	# goes on the transform: every point of the artwork is that much higher up.
	var world := _source.global_transform
	world.origin.y -= get_projection_lift()
	_frame_world = world

	var alpha := opacity_multiplier
	if follow_source_alpha:
		alpha *= _source_alpha()
	_frame_alpha = clampf(alpha, 0.0, 1.0)

	_frame_stamp = _source.texture.get_instance_id() + _source.frame * 4 \
		+ (2 if _source.flip_h else 0) + (1 if _source.flip_v else 0)
	_frame_ok = true
	return true


## The pose taken by the last [method prepare_frame] - the artwork's own world
## transform with its lift folded in.
func get_frame_world() -> Transform2D:
	return _frame_world


## The fade taken by the last [method prepare_frame].
func get_frame_alpha() -> float:
	return _frame_alpha


## What is being drawn, as one number - the texture, the frame of it and the
## mirroring. Two frames with the same stamp draw the same picture, so a group can
## tell that a part's silhouette is unchanged without comparing any of it.
func get_frame_stamp() -> int:
	return _frame_stamp


## Notes what became of this part's contribution, for the readout in
## [method get_last_result]. The readout itself is not worked out here - see
## [member _result_stale].
func note_frame(group: ShadowGroup, drawn: bool) -> void:
	_result_group = group
	_result_drawn = drawn
	_result_stale = true


## Fills in where this part's silhouette actually landed, in world space, so a test
## or a debug readout can ask without repeating the group's arithmetic.
##
## The projection varies from point to point, so there is no one transform to
## report. What is reported instead is the projection [i]as it stands where this
## part is[/i]: each axis of the part's own pose followed through the sun, either
## side of the middle of its artwork. That is the local shape of the mark this part
## makes - which is what a reader wants when it asks how long, how turned or how
## mirrored a part's shadow is.
##
## It is taken about the middle of the artwork rather than about the part's origin
## on purpose: a part whose origin sits on its own ground line has nothing below it
## to project, so a difference taken there would come out flat.
func _record(
		group: ShadowGroup, world: Transform2D, alpha: float, drawn: bool) -> void:
	var middle := world * SpriteBounds.local_rect(_source).get_center()

	_result.ground_position = group.get_ground_position()
	_result.visual_height = get_visual_height()
	_result.direction = group.get_shadow_direction()
	_result.basis = Transform2D(
		(group.project_world(middle + world.x)
			- group.project_world(middle - world.x)) * 0.5,
		(group.project_world(middle + world.y)
			- group.project_world(middle - world.y)) * 0.5,
		Vector2.ZERO)
	# Where this part's own origin lands. The origin and not the artwork's footing,
	# because the artwork turns about the origin: a revolver spun in a hand has to
	# report the same place all the way round, and its lowest corner does not.
	_result.position = group.project_world(world.origin)
	_result.offset = _result.position - _result.ground_position
	# How long this part's own silhouette ends up on the floor: its artwork's height,
	# put through its pose and then through the projection.
	_result.length = (_result.basis * Vector2(0.0, -_source_size.y)).length()

	# The silhouette's own pose, mirroring included - taken apart WITHOUT asking a
	# mirrored transform for its angle. A mirror negates the x column, and
	# [method Transform2D.get_rotation] reads that column, so a flipped sprite
	# reports its rotation half a turn out.
	var pose := get_source_transform()
	var mirrored := pose.determinant() < 0.0
	var upright := pose
	if mirrored:
		upright = Transform2D(-pose.x, pose.y, Vector2.ZERO)
	_result.rotation = upright.get_rotation()
	_result.scale = Vector2(
		pose.x.length() * (-1.0 if mirrored else 1.0), pose.y.length())

	var state := group.get_sun_state()
	_result.local_opacity = alpha
	_result.day_opacity = group.get_composite_alpha()
	_result.modulate = Color(0.0, 0.0, 0.0, clampf(alpha * _result.day_opacity, 0.0, 1.0))
	if state != null:
		_result.modulate = Color(
			state.shadow_color.r, state.shadow_color.g, state.shadow_color.b,
			_result.modulate.a)
		_result.softness = state.shadow_softness
		_result.fade = state.shadow_fade
	_result.visible = drawn


## The node this caster is standing on the floor by. Worked out fresh whenever the
## hierarchy under it changed, so a caster is never left measuring against a parent
## it no longer has.
func _resolve_ground_root() -> Node2D:
	var found: Node2D = null
	if ground_root_mode == GroundRootMode.GROUND_ROOT_NEAREST_MARKED:
		found = _find_marked_ancestor()
	if found == null:
		found = get_node_or_null(ground_root_path) as Node2D
	if found == null:
		found = get_parent() as Node2D
	if found == null:
		found = self
	# Whether this object answers for whatever is carrying it. Asked once here
	# rather than every frame - it cannot change while the root has not.
	_carrier_asked = found.has_method(group_owner_method)
	return found


## The nearest ancestor that has said it is a ground root. Null when there is none,
## which is the whole of "this piece is on its own now" - no signal, no state and
## nothing that knows what kind of piece it is.
##
## The walk stops at anything that is not a [Node2D] and at the scene root, so a
## piece lying loose in the world finds nothing rather than climbing out into the map
## and adopting it.
func _find_marked_ancestor() -> Node2D:
	if not is_inside_tree():
		return null
	var stop: Node = get_tree().current_scene
	var node: Node = get_parent()
	while node != null:
		var as_2d := node as Node2D
		if as_2d == null:
			return null
		if as_2d.is_in_group(ground_root_group):
			return as_2d
		if as_2d == stop:
			return null
		node = node.get_parent()
	return null


## The group this caster should draw into, before falling back to one of its own.
func _find_group() -> ShadowGroup:
	match group_mode:
		GroupMode.GROUP_OWN:
			return null
		GroupMode.GROUP_PATH:
			return get_node_or_null(shadow_group_path) as ShadowGroup
		_:
			pass

	# Started at the parent so a caster never finds the group it made for itself and
	# concludes it is attached to something.
	var found := ShadowGroup.find_for(get_parent())
	if found != null and found != _own_group:
		return found

	# Nothing above it in the tree. The object itself gets the last word: anything
	# being carried says so by naming its carrier, and joins that figure's shadow.
	var owner_node := get_group_owner_node()
	if owner_node != null:
		var carried := ShadowGroup.find_for(owner_node)
		if carried != null and carried != _own_group:
			return carried
	return null


## Makes the group a caster with nothing above it draws into. It is a child of the
## caster, so it travels with it and dies with it.
func _make_own_group() -> ShadowGroup:
	if _own_group != null and is_instance_valid(_own_group):
		return _own_group
	var group := ShadowGroup.new()
	group.name = "ShadowGroup"
	group.shadow_z_index = shadow_z_index
	group.sun_path = sun_path
	group.softness_override = shadow_softness_override
	_own_group = group
	add_child(group)
	return group


## Takes down the group this caster made for itself, now that it has found one to
## join. A part picked up off the floor stops being its own object.
func _discard_own_group(joined: ShadowGroup) -> void:
	if _own_group == null or _own_group == joined:
		return
	if is_instance_valid(_own_group):
		_own_group.queue_free()
	_own_group = null


## The first sprite with a texture under the ground root, when none was named. Depth
## first and in tree order, so the artwork a character is drawn with is found before
## anything hanging off it.
func _resolve_source_sprite() -> Sprite2D:
	if not source_sprite_path.is_empty():
		return get_node_or_null(source_sprite_path) as Sprite2D
	return _find_sprite(_root)


func _find_sprite(node: Node) -> Sprite2D:
	if node == null:
		return null
	for child: Node in node.get_children():
		if child == self:
			continue
		var sprite := child as Sprite2D
		if sprite != null and sprite.texture != null:
			return sprite
		var found := _find_sprite(child)
		if found != null:
			return found
	return null


## Measures the drawn size of the source's opaque artwork, for the readout in
## [ShadowTransform]. The placement itself needs no measurement at all - the
## silhouette is the artwork, projected point by point where the artwork is.
func _measure_source() -> void:
	if _source == null or _source.texture == null:
		_measured_texture = null
		_source_size = Vector2.ONE
		return
	var used := SpriteBounds.used_rect(_source.texture)
	_measured_texture = _source.texture
	_source_size = Vector2(maxf(used.size.x, 1.0), maxf(used.size.y, 1.0))


func _sync_texture() -> void:
	if _source.texture == _measured_texture:
		return
	_measure_source()


## The instance ids of the group and every node above it. Everything from there up is
## already applied to the shadow by the tree itself, so the walk that gathers the
## source's own fade knows where to stop and nothing is counted twice.
func _build_alpha_stops() -> void:
	_alpha_stops.clear()
	var node: Node = _group
	while node != null:
		_alpha_stops[node.get_instance_id()] = true
		node = node.get_parent()


## How much of the source's own fade this part should take, for the stretch of tree
## the group does not share with it.
##
## It is what lets a weapon drawn into the player's shadow disappear when it is
## stowed, without the player's own shadow being faded twice over when a corpse
## fades out.
func _source_alpha() -> float:
	if _source == null:
		return 0.0
	var alpha := 1.0
	var node: CanvasItem = _source
	while node != null:
		if _alpha_stops.has(node.get_instance_id()):
			break
		if not node.visible:
			return 0.0
		alpha *= node.modulate.a * node.self_modulate.a
		if node == _root:
			break
		node = node.get_parent() as CanvasItem
	return alpha
