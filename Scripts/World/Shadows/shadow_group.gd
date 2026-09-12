class_name ShadowGroup
extends Node2D
## One logical object's shadow: every [ShadowCaster] that belongs to the same
## thing, assembled into a single silhouette and thrown onto the floor by the
## map's one [SunController].
##
## [b]Every point of the artwork gets its own ray.[/b] This is the whole of what
## the class does. A point of a picture is read as a point in the world - a place
## on the arena floor plus a height above it - and where its shadow lands is where
## the line from the sun through it meets the floor again. See
## [method project_world], which is three lines long and is the only place in the
## game that answers the question.
##
## That is not the same thing as leaning the picture over. Laying a whole figure
## down with one shear moves its head and its feet by amounts fixed in advance and
## keeps every horizontal line horizontal and every width unchanged - a sheet of
## paper folded flat onto the ground. A real cast shadow does none of those things:
## it spreads as it goes, because the rays that make it are spreading, and the top
## of a thing travels disproportionately further than the middle of it. Projecting
## per point gets that for nothing, and gets it from the sun rather than from a
## number, so a head lands beyond a body, a raised knife lands beyond a hand, and a
## thing thrown into the air walks out from under itself without a special case.
##
## [b]And an object may be standing on more than a line.[/b] Read as above, a prop
## is a picture standing upright at one depth, so its base is a line and every last
## pixel of it swings round with the light - which is what makes a tent's mark look
## detached from the tent. A prop that has authored a footprint - see
## [member ShadowCaster.ground_contact_path] - is projected as what it really is
## instead: the band of artwork standing on that footing is [i]lying on the
## ground[/i] and is drawn exactly where it is drawn, fixed under the prop at every
## hour, and the rest of the picture is a thing standing on the back of that patch.
## So the mark is the object's own footing with a rake growing out of it, and it
## cannot leave the thing casting it. See [method _norm].
##
## [b]Assembled first, all the same.[/b] The parts are laid out in [i]group
## space[/i] - a flat copy of the world with its origin at the point the object is
## standing on - each at its own real world transform, and every one of them is
## projected against the same ground line, through the same sun, with the same
## group-level offsets. So the parts cannot disagree with each other: no part has a
## direction, a length or a footing of its own, and no part can stretch, widen or
## drag another. What comes out is one silhouette, unioned once and coloured once.
##
## [b]The composite is measured, never authored.[/b] Where the ground line is, how
## tall the object stands and how far the shape reaches all come from the world
## bounds of the artwork actually contributing this frame - see
## [method _measure]. Adding a part, dropping a part, an animation that raises an
## arm: the bounds move with them, and nothing is cropped because the geometry is
## built from those bounds rather than fitted into a rectangle.
##
## [b]It knows nothing about what it is the shadow of.[/b] There is no branch here
## for a player, an enemy, a boss, a head or a weapon and there must never be one.
## A group is a list of contributors; membership is worked out by
## [method ShadowCaster.resolve_group] from the tree, so a part torn off its owner
## leaves this group and becomes its own without anything announcing it, and a
## weapon picked up joins its carrier's group the same way.
##
## [b]What it costs.[/b] One [ShadowShape] per contributor, drawn with the
## source's own texture, its geometry a small grid - see
## [member projection_subdivisions] - rebuilt only for the parts that actually
## moved. No shadow texture is generated, nothing is raymarched, and the composite
## buffer a true union needs is only allocated once a group genuinely has more than
## one contributor - see [enum CombineMode]. A group whose contributors are all
## static does not run at all except when the sun moves.

## How a group's contributors are put together.
enum CombineMode {
	## A [CanvasGroup] once there is more than one contributor, a plain container
	## while there is only one - where a union and a single mesh give the same
	## picture anyway. The default, and what nearly everything should use.
	COMBINE_AUTO,
	## Always composite through a [CanvasGroup], even for a single contributor.
	COMBINE_UNION,
	## Never composite. Each contributor is drawn on its own, so overlapping parts
	## darken each other - which is only ever what a group of one wants.
	COMBINE_LAYERED,
}

## Group every shadow group joins, so a caster - or a test - can find them all
## without being wired to any.
const GROUP := &"shadow_group"

## The look for a part drawn on its own, and for a part being written into a union.
const SHADOW_SHADER_PATH := "res://Shaders/shadow_silhouette.gdshader"
## The look for the assembled object, written for the premultiplied buffer a
## [CanvasGroup] composites through. See the shader itself for why the two cannot
## be one file.
const COMPOSITE_SHADER_PATH := "res://Shaders/shadow_composite.gdshader"

## How far above its ground line an object is measured over when its reach is
## worked out, in world pixels, if it has no measurable height at all. Only ever
## reached by a group whose artwork is a flat line.
const MIN_SPAN := 1.0

## How sharply a shadow settles onto the shortest length it is allowed - see
## [method _pool_extent]. The two lengths are joined as
## [code](reach^n + pool^n)^(1/n)[/code], which is a floor that is smooth
## everywhere and has no corner to pop over. Raising it makes the floor bite later
## and harder; 4 leaves a shadow twice its own footing lengthened by under half a
## percent, which is well below a pixel, while still holding one at the floor
## firmly.
const POOL_FALLOFF := 4.0

## Where along its own length a mark that is entirely the pool sits against the
## point its object is standing on. Half is directly underneath, which is where the
## patch of ground a thing stands on is; a cast shadow is anchored on its object's
## footing instead - or on the hour's own authored slide, where the map has not asked
## for the footing - and the two are blended by how much of the mark is which. See
## [method _place].
const POOL_CENTRE := 0.5

## How many texels of blur a softness of 1 asks for. Shared with the shaders, which
## do the same multiplication, so the padding put round the geometry and the blur
## drawn into it agree.
const SOFTNESS_TEXELS := 12.0

## Where in the frame a group ticks. Last, deliberately: an object's animation, its
## aim, its hand, the weapon following that hand and the head soft-following the
## body all move in ordinary [method Node._process] calls, and a shadow read before
## them is a shadow of where the object was last frame. Processing order is tree
## order until a priority says otherwise, and a group is written high up its owner's
## scene - so without this every shadow in the game trails a frame behind the thing
## casting it, which reads as the shadow lagging on anything that moves quickly.
const PROCESS_PRIORITY := 1000

## How far the object's footing or its top may drift, in world pixels, before the
## silhouette's own shape is worked out again.
##
## It has nothing to do with where the shadow is - the container carries that
## exactly, however far the object walks - only with how stale the spread
## [i]inside[/i] the shape may be, and a fraction of a pixel of drift in how tall an
## object measures is worth a fraction of a pixel at the tip of its shadow.
const SHAPE_SLACK := 2.0

## Materials shared between every shadow asking for the same look, keyed by it and
## by the patch of texture it masks. The hundred cacti in the desert share a
## handful of textures, so they share a handful of materials.
static var _materials: Dictionary = {}

## Triangle indices for a grid of a given fineness, worked out once for the whole
## game. The vertices move every frame; how they are joined up never does.
static var _index_cache: Dictionary = {}

# TEMPORARY PROBE - gather, measure+place, apply, vertex loop, set_shape, material,
# groups updated, parts rebuilt.
static var probe := PackedFloat64Array([0, 0, 0, 0, 0, 0, 0, 0])


## One contributor's drawing, and everything about it that is worth not doing twice.
##
## [b]It exists so that a shadow which has not moved costs nothing.[/b] The pose,
## the fade and the picture are compared against last frame's before anything is
## built; the buffers the geometry is written into are kept and refilled rather than
## made again; and the material is looked up only when the hour or the frame of
## artwork actually changes. A crowd of a hundred enemies is a crowd of three
## hundred of these, so everything here is either reused or skipped.
class Part:
	extends RefCounted

	## The node this part is drawn on.
	var item: ShadowShape
	## The geometry, kept and rewritten in place. Resized only when the grid the
	## artwork is cut into changes shape.
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	## How many cells across and down the artwork is currently cut into.
	var steps := Vector2i.ZERO

	## Last frame's pose, fade and picture - see [method ShadowCaster.prepare_frame].
	## The pose is held [i]against the object's ground point[/i] rather than against
	## the world, so an object that walked without moving any of its parts compares
	## equal and nothing is rebuilt - see [method ShadowGroup._norm].
	var pose := Transform2D.IDENTITY
	var alpha: float = -1.0
	var stamp: int = 0
	var contributing: bool = false
	## Whether any of those three changed since this part was last drawn.
	var dirty: bool = true
	## Whether there is geometry on the mesh to show at all.
	var built: bool = false

	## The look this part's material was made for, so it is not looked up again
	## while neither the hour nor the frame of artwork has moved.
	var material_look: int = -1
	var material_frame := Rect2()
	var material_in_group: bool = false

	## Which patch of which texture is being drawn, and where it is drawn in the
	## source's own space. Reading it back out of the sprite means finding the frame,
	## the region and the opaque part of the artwork again; none of that can change
	## while the picture has not, so it is worked out once per picture instead of
	## once per frame.
	var art_stamp: int = -1
	var art_pad: float = -1.0
	var art_quad := Rect2()
	var art_uv := Rect2()
	var art_from := Vector2.ZERO
	var art_to := Vector2.ZERO

	## The triangles for the grid this part is currently cut into, shared with every
	## other shadow in the game cut the same way - see [method ShadowGroup._grid_indices].
	var indices := PackedInt32Array()

	func _init(shape: ShadowShape) -> void:
		item = shape


## Whether this group draws at all.
@export var enabled: bool = true:
	set(value):
		enabled = value
		mark_dirty()
		_refresh_processing()
		if is_node_ready():
			update_group(true)
## How the contributors are put together - see [enum CombineMode].
@export var combine_mode: CombineMode = CombineMode.COMBINE_AUTO:
	set(value):
		combine_mode = value
		mark_dirty()
		if is_node_ready():
			_refresh_containers()
## Scales how dark this whole object's shadow is against the hour. Applied once, to
## the assembled silhouette, which is why a part's own multiplier can be left alone
## and the object still fades as one.
@export_range(0.0, 4.0, 0.01) var opacity_multiplier: float = 1.0:
	set(value):
		opacity_multiplier = value
		mark_dirty()
## Scales how tall every point of this object is taken to be, and so how far its
## shadow reaches, without moving where the object stands.
##
## [b]It is a height, not a length[/b] - the sun turns it into a length - and 1
## means "exactly as tall as the artwork is drawn", which is what a correctly drawn
## object wants. It is here for the cases where the artwork is not the whole of the
## thing: a figure seen from above whose legs are foreshortened, a prop drawn
## squat. Because it scales the height going into the projection rather than the
## picture coming out of it, a taller object throws a shadow that spreads more as
## well as one that reaches further, which is what the sun would do.
@export_range(0.0, 6.0, 0.01) var height_scale: float = 1.0:
	set(value):
		height_scale = value
		mark_dirty()
## Shifts the finished shadow in world pixels, after the sun has placed it.
##
## For nudging a whole object's mark without touching the light - see
## [member ShadowCaster.shadow_offset], which is the same control on a single part
## and is what a prop uses. The two are added together, and both take negative
## values.
##
## Two numbers in world pixels means the nudge has to be re-authored for every hour,
## because the light turns as the day does. When what is wanted is simply "closer to
## the object" or "further from it", reach for [member shadow_pull] instead.
@export var shadow_offset := Vector2.ZERO:
	set(value):
		shadow_offset = value
		mark_dirty()
## How far the finished shadow is pulled back along the light, in world pixels.
##
## [b]Positive brings the mark closer to the object, negative pushes it further
## away.[/b] Measured along the projection rather than in world pixels, so a value
## set once holds as the day turns - which is what makes it the control to author a
## prop's contact gap with. Added to [member ShadowCaster.shadow_pull] on the part
## the group stands by.
##
## It slides the finished shadow and nothing else: it cannot turn the light, it
## cannot lengthen a shadow, and it cannot bend a silhouette.
@export_range(-512.0, 512.0, 1.0) var shadow_pull: float = 0.0:
	set(value):
		shadow_pull = value
		mark_dirty()
## How finely each part's artwork is cut up before being projected.
##
## The projection is not a shear, so a straight line in the picture is not a
## straight line on the floor: the further from the sun a point is the more it
## spreads, and a piece of artwork drawn as one flat quad would miss all of that
## between its corners. Each part is cut into a grid this many cells across and the
## corners of every cell are projected exactly, so the curve is followed rather
## than guessed at.
##
## Higher is more faithful and costs a few more vertices; 1 would be the old flat
## quad. The default is enough that the error inside a cell is under a pixel at
## every hour the desert uses.
##
## [b]It is a ceiling, not a count.[/b] What is actually asked for is worked out per
## part, from how far a flat quad would be out - see
## [member projection_tolerance]. A picture standing upright is cut across its
## height and not across its width at all, because the projection does not curve
## across a row; and a figure under a high sun needs two or three cuts down its
## height rather than the two dozen a very low one would.
@export_range(1, 24, 1) var projection_subdivisions: int = 8:
	set(value):
		projection_subdivisions = value
		mark_dirty()
## How far the drawn edge of a shadow may be out from the true projection, in world
## pixels, before a part is cut more finely.
##
## [b]This is the quality dial, and it is measured rather than guessed.[/b] The
## projection bends by a knowable amount over a part - it depends on how high the
## sun is, how far away it stands and how tall the part is - so the number of cuts
## that keeps the error inside this many pixels can simply be worked out. What comes
## out of it is a system that spends nothing on the things that do not need it and
## finds the fineness by itself where they do: a grounded figure under a midday sun
## is very nearly a flat quad, the same figure at dusk is not, and a tall tent is
## cut more finely than a bush without anything being authored for either.
##
## [b]It also decides when a shadow is worth redrawing at all.[/b] The same question
## asked of movement rather than of a straight line: a part whose pose has shifted by
## less than this much, once the projection's own spread is taken into account, would
## draw the same picture, so it keeps the one it has - see [method _pose_settled].
## That is what a walking crowd actually costs, since an animation moves every one of
## them by a fraction of a pixel every frame.
##
## Raise it to make a whole crowd cheaper, lower it to spend more on faithfulness.
## Half a pixel is under what can be seen through a soft edge.
@export_range(0.05, 8.0, 0.05) var projection_tolerance: float = 0.5:
	set(value):
		projection_tolerance = value
		mark_dirty()
## Scales what this one object asks for against that tolerance.
##
## The importance dial, for the cases where the measurement is not the whole story: a
## boss worth spending on takes more than 1, a swarm enemy nobody looks at closely
## takes less. At 0 every part of this object is drawn as a flat quad.
@export_range(0.0, 4.0, 0.05) var projection_detail_scale: float = 1.0:
	set(value):
		projection_detail_scale = value
		mark_dirty()
## Overrides the hour's own shadow edge softness - see [member SunStage.shadow_softness]
## - for just this one object, 0 to 1. Below 0, the default, follows the sun
## exactly like everything else in the map.
##
## [b]This is the whole of the prop-versus-character distinction.[/b] Every
## shadow in a map shares one sun and, through it, one softness, which is right
## for a crowd of identical men and wrong the moment a hard-edged prop and a
## soft-edged character are meant to read differently on the same ground. A
## character's shadow is left alone - soft, and following the hour like the
## rest of the world - and a prop that wants to read a little harder without
## ever becoming a sharp cut-out sets this instead, once, in its own scene.
@export_range(-1.0, 1.0, 0.01) var softness_override: float = -1.0:
	set(value):
		softness_override = value
		mark_dirty()
## Where the shadow sits in the draw order. Above the floor and the marks on it,
## below everything standing on it. Absolute, never relative, and never y-sorted: a
## shadow is on the ground whatever its own y happens to be as it passes a cactus.
@export var shadow_z_index: int = -8:
	set(value):
		shadow_z_index = value
		_apply_container_layout()
## How far outside its contributors the composite buffer reaches, in pixels. It has
## to cover the softened edge of the finished shadow; too small clips it.
@export_range(0.0, 256.0, 1.0) var fit_margin: float = 32.0:
	set(value):
		fit_margin = value
		if _union != null:
			_union.fit_margin = value

@export_group("Sun")
## The map's [SunController], found by group when left unresolved.
@export var sun_path: NodePath

## Contributors, in registration order, each mapped to the [Part] drawing it.
var _parts: Dictionary = {}
var _casters: Array[ShadowCaster] = []
## The contributor the group stands by - see [method _resolve_anchor].
var _anchor: ShadowCaster
var _sun: SunController
var _state: SunState
var _layered: Node2D
var _union: CanvasGroup
var _active: CanvasItem
var _dynamic_count: int = 0
var _direction := Vector2.DOWN
var _ground := Vector2.ZERO
## Added to every projected point, so it slides the finished shadow without bending
## it - the art offsets, the anchor slide and the sun's own distance limit.
var _post_offset := Vector2.ZERO
## How far the assembled artwork's own ground line is above the group's ground
## point, in world pixels. Zero for anything resting on the floor; the lift itself
## for anything in the air.
var _base_height: float = 0.0
## How tall the assembled artwork stands above that line, in world pixels.
var _span: float = MIN_SPAN
## How far to the side of the object's ground line its artwork reaches, in world
## pixels - the half-width of the patch of ground it stands on. What the shortest
## its shadow may be is taken from, so the floor is the object's own size and there
## is nothing to author per prop. See [method _pool_extent].
var _half_width: float = MIN_SPAN
## The height of the highest point of the artwork, in world pixels above the ground
## line. What the length fade is measured against, so the tip of a shadow is always
## the far end of it whatever the object is.
var _top_height: float = MIN_SPAN
## How far the top of the object throws, in world pixels. A readout, and what the
## anchor slide is taken as a fraction of.
var _reach: float = 0.0

## Where the object was standing when it was last asked, before anything was
## measured from it. Compared rather than acted on - see [method _gather].
var _ground_probe := Vector2.ZERO
## Whether any contributor moved [i]against the object[/i] since the last update, as
## opposed to the whole object having travelled. What decides whether the assembled
## bounds have to be measured again.
var _shape_moved: bool = true
## The projection every part of this object shares, as it stood when they were last
## built. While it holds, a part that did not move does not have to be rebuilt.
## Where the object is standing is deliberately not among them - see [method apply].
var _built_base: float = INF
var _built_top: float = INF
## Bumped whenever the hour, an inspector value or the membership changes -
## everything, in other words, that is not a contributor moving. Materials and
## geometry both hang off it, so one number is enough to make the whole object
## rebuild itself.
var _look_serial: int = 0
## The serial the geometry was last built at.
var _built_look: int = -1
## The composite's own state as it was last written, so a group that has not moved
## does not touch its container at all.
var _composite_alpha: float = -1.0
var _composite_look: int = -1

## The sun's own numbers, unpacked once per update so the inner loop that projects
## every point of the artwork is arithmetic and nothing else - see [method apply].
var _ray_positional: bool = false
var _ray_sun := Vector2.ZERO
var _ray_height: float = 1.0
var _ray_fall := Vector2.ZERO
var _ray_width: float = 1.0
## How far the sun's own rise is scaled by before it is written into a vertex, and
## what one unit of that rise is worth in world pixels - the two halves of the
## factorisation described in [method _norm]. The first is the same for every object
## in the map; the second is where the object happens to be standing, and is carried
## by the container rather than by any vertex.
var _shape_rise: float = 1.0
var _shape_lean := Vector2.DOWN
## Which way the silhouette's own width lies on the ground, and how much of it there
## is.
##
## Straight across the screen for a caster taken as a flat card; for one taken as
## having a body, the same side of the screen still, narrowed and tilted by however
## its footprint presents to the light - see [method _lay_across], which is where
## the whole of the reasoning is. It is the other axis of the container's basis, so
## it costs nothing per vertex and cannot bend the silhouette any more than the lean
## can. Its [b]length is not 1[/b]: it carries the foreshortening of the body and
## the rounding off into the pool.
var _shape_across := Vector2(1.0, 0.0)
## How much of this object's artwork, measured up from the point it is standing on,
## is lying on the ground rather than standing up - the authored footprint gathered
## off the contributors, in world pixels. Zero for an object that has authored none,
## and for every object on a map whose sun has not asked for footprints, which is
## what leaves those projected exactly as they always were. See
## [method ShadowCaster.get_ground_contact].
var _contact_authored: float = 0.0
## The same number as this update actually draws it: the authored one, or zero for
## an hour whose basis has no inverse to write a flat band through - see
## [method _lay_flat].
var _contact_height: float = 0.0
## How far that patch of floor spreads either side of the object, in world pixels.
## What the pool underneath it is sized from - see [method _pool_extent].
var _contact_half_width: float = 0.0
## The container's basis read backwards: what one world pixel across and one world
## pixel down the screen are worth as a vertex. The ground-contact band is written
## through these, which is the whole of why it stays where it is drawn while the
## light swings round - see [method _norm]. Both are the identity when there is no
## footprint to draw, and the band is skipped rather than drawn through a basis
## that cannot be inverted.
var _flat_x := Vector2(1.0, 0.0)
var _flat_y := Vector2(0.0, 1.0)
## How much of the finished mark is the pool underneath the object rather than the
## shadow thrown from it - 1 when the sun is straight overhead, 0 for anything with
## a shadow much longer than its own footing. See [member SunController.minimum_shadow_ratio].
var _pool_blend: float = 0.0
## How hard the projection bends over this object right now, as the second
## derivative of the shadow's displacement with respect to height. What the number
## of cuts a part needs is worked out from - see [method _grid_steps].
var _ray_curve: float = 0.0
## How far a contributor may move against the object, in world pixels, before its
## silhouette is worth drawing again - see [method _pose_settled]. Worked back from
## [member projection_tolerance] through how much this hour magnifies a movement.
var _pose_slack: float = 0.0

## Whether this group is sitting out an hour it owes a rebuild for because it is
## outside the view - see [method _worth_rebuilding_now]. It is the one case the
## return has to be watched for: the map's own scenery cull announces itself
## through [signal CanvasItem.visibility_changed], but a landmark that is simply
## off the side of the screen never stops being visible and nothing tells it that
## the camera has come back. So the group processes - a rectangle test and nothing
## else - for exactly as long as it is waiting.
var _view_deferred: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)
	if is_node_ready():
		_connect_sun()


func _ready() -> void:
	# Last in the frame, so nothing a shadow is drawn from is still about to move -
	# see PROCESS_PRIORITY.
	if process_priority == 0:
		process_priority = PROCESS_PRIORITY
	_refresh_containers()
	_connect_sun()
	# Built once here whatever the view says, so no object is ever without a shadow
	# it has simply never got round to making. Only the *re*builds are ever skipped.
	update_group(true)
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	_refresh_processing()


func _exit_tree() -> void:
	_disconnect_sun()


func _process(_delta: float) -> void:
	# Waiting for the camera to come back, and nothing else - see
	# [member _view_deferred]. Paying the debt does the dynamic parts too, so there
	# is nothing left to do this frame.
	if _view_deferred and _worth_rebuilding_now():
		_unpack_sun()
		update_group(true)
		return
	update_group(false)


## The group a node's shadow belongs to: the nearest one at or above
## [param from_node], where "at" means a group hanging off the same object.
##
## [b]The whole of how membership is decided.[/b] Walking the tree is what makes a
## piece torn off its owner become its own shadow with no code that knows what kind
## of piece it is - a reparent is an exit and an entry, the walk is run again, and
## the answer is simply different. The walk stops at the scene root so a piece lying
## loose in the world finds nothing rather than climbing out and adopting the map.
static func find_for(from_node: Node) -> ShadowGroup:
	if from_node == null or not from_node.is_inside_tree():
		return null
	var stop: Node = from_node.get_tree().current_scene
	var node: Node = from_node
	while node != null:
		var as_group := node as ShadowGroup
		if as_group != null:
			return as_group
		for child: Node in node.get_children():
			var child_group := child as ShadowGroup
			if child_group != null:
				return child_group
		if node == stop:
			return null
		node = node.get_parent()
	return null


## The material for a given look over a given patch of texture, made once and
## shared by everything asking for the same one.
##
## [param color] is the map's own - see [member SunStage.shadow_color] - so two
## maps with different coloured shadows are two materials between all of their
## objects rather than one per object. [param frame_uv] is the part of the texture
## the silhouette is cut from, which the shader needs so its blur does not reach
## into the neighbouring frame of a sheet; everything drawn from the same picture
## shares it. [param composited] picks the premultiplied variant, which is what a
## [CanvasGroup] has to be drawn with, and [param into_group] the pass that writes
## a part into that group's buffer rather than to the screen.
static func get_shared_material(
		softness: float, fade: float, color: Color, frame_uv: Rect2,
		composited: bool = false, into_group: bool = false) -> ShaderMaterial:
	# Quantised, so two shadows a thousandth apart are not two materials.
	var key := "%d_%d_%s_%s_%s_%s" % [
		roundi(softness * 50.0), roundi(fade * 50.0), color.to_html(false),
		frame_uv if not composited else Rect2(), composited, into_group]
	var cached: ShaderMaterial = _materials.get(key)
	if cached != null:
		return cached

	var shader: Shader = load(
		COMPOSITE_SHADER_PATH if composited else SHADOW_SHADER_PATH)
	if shader == null:
		return null
	var made := ShaderMaterial.new()
	made.shader = shader
	made.set_shader_parameter(&"softness", roundi(softness * 50.0) / 50.0)
	made.set_shader_parameter(&"fade_strength", roundi(fade * 50.0) / 50.0)
	made.set_shader_parameter(&"shadow_color", Color(color.r, color.g, color.b, 1.0))
	if not composited:
		made.set_shader_parameter(&"into_group", into_group)
		made.set_shader_parameter(&"frame_uv", Vector4(
			frame_uv.position.x, frame_uv.position.y, frame_uv.size.x, frame_uv.size.y))
	_materials[key] = made
	return made


## Takes [param caster] on as a contributor and hands it the mesh it draws with.
## Called by the caster itself as it resolves which group it belongs to.
func register(caster: ShadowCaster) -> void:
	if caster == null or _parts.has(caster):
		return
	var item := ShadowShape.new()
	item.visible = false
	item.name = "Shadow_%s" % caster.get_instance_id()
	_parts[caster] = Part.new(item)
	_casters.append(caster)
	if _active != null:
		_active.add_child(item)
	mark_dirty()
	_refresh_containers()
	_resolve_anchor()
	_refresh_processing()


## Drops [param caster] and frees its mesh. Called when a caster is disabled, or
## leaves the tree, or finds it now belongs somewhere else.
func unregister(caster: ShadowCaster) -> void:
	if caster == null or not _parts.has(caster):
		return
	var part: Part = _parts[caster]
	_parts.erase(caster)
	_casters.erase(caster)
	if part != null and is_instance_valid(part.item):
		part.item.queue_free()
	mark_dirty()
	_refresh_containers()
	_resolve_anchor()
	_refresh_processing()


## Notes that something other than a contributor moving has changed - the hour, an
## inspector value, or which parts this object is made of - so the next update
## rebuilds rather than finding nothing to do.
func mark_dirty() -> void:
	_look_serial += 1


## The node [param caster] draws its silhouette on, or null when it is not a
## contributor here.
func get_shape_for(caster: ShadowCaster) -> ShadowShape:
	var part: Part = _parts.get(caster)
	return null if part == null else part.item


## Everything currently contributing to this shadow.
func get_casters() -> Array[ShadowCaster]:
	return _casters.duplicate()


## How many parts this object's shadow is made of.
func get_caster_count() -> int:
	return _casters.size()


## The contributor the group stands by - see [method _resolve_anchor].
func get_anchor_caster() -> ShadowCaster:
	return _anchor


## Works out again which contributor the group stands by. Called by a caster whose
## ground root changed, since what a part is standing on decides whether it can be
## the one the whole object stands by.
func refresh_anchor() -> void:
	_resolve_anchor()
	mark_dirty()


## Whether the contributors are being assembled into one silhouette rather than
## drawn one over another.
func is_union() -> bool:
	return _active != null and _active == _union


## The node the shadow meshes hang off. For a test, or a debug readout.
func get_render_root() -> CanvasItem:
	return _active


## The live sun this group projects through, or null when the map has none.
func get_sun_state() -> SunState:
	if _state == null:
		_connect_sun()
	return _state


## Where this object is standing on the arena floor - the origin of group space,
## and the ground plane every point of it is projected against.
func get_ground_position() -> Vector2:
	return _ground


## Which way this object's shadow lies, in world space. The sun's answer at this
## object's own place on the map, and the same one for every part of it.
func get_shadow_direction() -> Vector2:
	return _direction


## How far the top of this object throws its shadow, in world pixels.
func get_reach() -> float:
	return _reach


## How many pixels along the light the shadow reaches per pixel of height, taken
## over the whole object. A readout only - nothing is drawn from it, because the
## projection is not a constant rake.
func get_rake() -> float:
	return _reach / maxf(_top_height, MIN_SPAN)


## How tall the assembled artwork stands, in world pixels.
func get_span() -> float:
	return _span


## Where a point of artwork at [param world_point] throws its shadow, in world
## space.
##
## [b]The whole of the projection, and the only copy of it.[/b] The point is read
## as a place on the arena floor directly below it - the object's own ground line,
## which is what makes the artwork a thing standing up rather than a thing lying
## down - and a height above that line, which is how much higher up the picture it
## was drawn. The sun turns those two into a place on the floor, and the group's
## own offsets slide the answer without bending it.
##
## Nothing about the source enters here. A part's rotation, mirroring, scale and
## parent decide [i]which[/i] point is being asked about and nothing else, so none
## of them can turn a shadow round or lengthen it.
func project_world(world_point: Vector2) -> Vector2:
	if _state == null:
		return world_point
	return project_to_group(world_point) + _ground + _post_offset


## The same point in group space - the flat copy of the world with its origin on the
## point the object is standing on.
func project_to_group(world_point: Vector2) -> Vector2:
	if _state == null:
		return world_point - _ground - _post_offset
	return _ray(
		world_point.x - _ground.x,
		maxf((_ground.y - world_point.y) * height_scale, 0.0))


## Where a point lands in [i]shape space[/i]: the projection with everything about
## where the object is standing taken out of it.
##
## [b]This is what makes a crowd affordable, and it is exact.[/b] Write the sun as a
## point [code](S, H)[/code] above the floor and a point of artwork as
## [code]across[/code] to the side of the object's ground line and [code]h[/code]
## above it. The ray that leaves the sun through that point lands, relative to the
## ground line, at
## [codeblock]
## x = across * (1 + t)  +  t * (ground.x - S.x)
## y =                      t * (ground.y - S.y)      where t = h / (H - h)
## [/codeblock]
## - and the only thing there that depends on [i]where the object is standing[/i] is
## the vector [code]ground - S[/code], which multiplies [code]t[/code] and nothing
## else. So the projection splits cleanly in two: a shape
## [code](across * (1 + t), t)[/code] that does not know where the object is, and one
## 2x2 basis laying that shape's two coordinates onto the ground - its width along
## [member _shape_across] and its rise along [member _shape_lean] - which is what
## the container carries, and which costs the same to set for one object as for a
## hundred.
##
## [b]It is not the flat plane again.[/b] The bend is entirely in [code]t[/code],
## which is worked out per point from that point's own height, and stays in the
## geometry where it belongs. What has been taken out is only the part that genuinely
## was affine, and taking it out is an identity rather than an approximation: the
## same numbers come out of [method project_world] as before, to the last bit.
##
## What it buys is that the geometry of a shadow no longer depends on where its
## object is standing at all. A figure walking across the arena is the same shape all
## the way, so it is built once and the container is moved - which is the whole of
## why an enemy costs nothing to walk.
##
## The rise is scaled by [member _shape_rise] on the way out and unscaled by
## [member _shape_lean] on the way back, purely so the numbers written into a vertex
## stay in pixel-sized units instead of thousandths.
func _norm(art_across: float, height: float) -> Vector2:
	# The hour's own width scale belongs to the spread a projection causes, never to
	# the patch of ground the object is standing on - see the footprint below.
	var across := art_across * _ray_width

	if _contact_height <= 0.0:
		if height <= 0.0:
			# Resting on the floor: the shadow of a point on the ground is that
			# point.
			return Vector2(across, 0.0)
		if not _ray_positional:
			# Parallel rays - or standing exactly under the sun, where there is no
			# direction to lean and the authored one breaks the tie. The rise is the
			# height itself; nothing spreads, so there is no widening either.
			return Vector2(across, height * _shape_rise)
		# The sun cannot be reached, let alone passed: something thrown higher than
		# the sun would flip its shadow to the far side, so the ray is held just
		# below it.
		var lift := minf(height, _ray_height * 0.98)
		var rise := lift / (_ray_height - lift)
		return Vector2(across * (1.0 + rise), rise * _shape_rise)

	# [b]Standing on a footprint.[/b] The band of artwork up to it is not standing
	# up at all - it is the patch of floor the object covers - so it is written
	# through the world's own axes and lands exactly where it is drawn, whatever the
	# light is doing. Everything above it is a thing standing on the back of that
	# patch, so the ray is added as an [i]offset[/i] from the point the band reached
	# rather than from the object's own ground line: the two meet exactly at the
	# seam, and the mark can no longer leave the thing casting it.
	var flat := minf(height, _contact_height)
	var base := art_across * _flat_x - flat * _flat_y
	var lifted := height - _contact_height
	if lifted <= 0.0:
		return base
	if not _ray_positional:
		return base + Vector2(0.0, lifted * _shape_rise)
	var stand := minf(lifted, _ray_height * 0.98)
	var thrown := stand / (_ray_height - stand)
	return base + Vector2(across * thrown, thrown * _shape_rise)


## The basis the shape is drawn through - the container's own transform, and the
## other half of [method _norm]. Its x axis says where the silhouette's own width
## lies on the ground - see [member _shape_across] - and its y axis where a unit of
## the ray's rise lands, which is where the object's own place on the map enters and
## the only place it does.
func _shape_basis() -> Transform2D:
	return Transform2D(_shape_across, _shape_lean, _ground + _post_offset)


## How high above the ground line a point of artwork at [param world_point] is
## taken to be, in world pixels.
func height_of(world_point: Vector2) -> float:
	return maxf((_ground.y - world_point.y) * height_scale, 0.0)


## Where a point of artwork lands, in group space, given how far it stands to the
## side of the object's ground line and how high above it.
##
## [b]This is the projection, and the only copy of it.[/b] It is
## [method SunState.project] written against numbers unpacked once per update
## instead of against the sun object, in the two halves the geometry is actually
## built in - see [method _norm], which is where the whole of the arithmetic is, and
## [method _shape_basis], which is the rest of it.
##
## Nothing draws through here: the shapes are built in [method _norm]'s space and
## the basis is put on the container once. It is the readout - what a test, a debug
## panel or [ShadowTransform] asks when it wants one point's answer in full.
##
## [param art_across] is the artwork's own offset from the object's ground line, before
## the hour's width scale - see [method _norm]; [param height] is
## already scaled by [member height_scale] and never negative.
## The art offsets are deliberately not in here. They shift every point of the
## silhouette by the same amount, so they are carried by the container the geometry
## hangs under instead - which means authoring one, or the hour changing where a
## shadow sits along its own length, moves the mark without a single point of it
## having to be projected again.
func _ray(art_across: float, height: float) -> Vector2:
	var shape := _norm(art_across, height)
	return Vector2(
		shape.x * _shape_across.x + shape.y * _shape_lean.x,
		shape.x * _shape_across.y + shape.y * _shape_lean.y)


## Redraws the group. [param include_static] does the contributors that only repaint
## when the sun moves as well as the ones that move by themselves.
##
## [b]The order is the whole of it.[/b] The object is measured, the sun is asked
## where its ground line and its top go, and only then is any geometry built - so
## every part is projected against one ground plane through one sun.
##
## [b]And the first thing it does is find out whether to do any of that.[/b] Every
## contributor is asked where it is - which costs a transform read and a comparison
## and builds nothing - and a group whose parts are all standing where they were,
## under an hour that has not moved, returns having touched nothing at all. That is
## what makes a field of scenery free and a crowd of enemies cost only the ones
## actually walking.
func update_group(include_static: bool) -> void:
	if _active == null:
		return
	if not enabled or _state == null or _casters.is_empty():
		_active.visible = false
		return

	if not include_static and _dynamic_count == 0:
		return

	var _t0 := Time.get_ticks_usec()
	var moved := _gather()
	probe[0] += Time.get_ticks_usec() - _t0
	var relit := _built_look != _look_serial
	if not moved and not relit:
		return
	probe[6] += 1.0
	_t0 = Time.get_ticks_usec()

	_ground = _ground_probe
	# The assembled bounds cannot have changed while every part is standing exactly
	# where it was against the object, however far the object itself has walked.
	if _shape_moved or relit:
		_measure()
	_place()

	# Everything below this line is shared by every part of the object, so when it is
	# unchanged a part that did not move keeps the geometry it already has.
	#
	# Where the object is standing is not among them and cannot be: the shapes are
	# built with it taken out, and the container puts it back exactly - see
	# [method _norm]. What is left is compared with a little slack, because a
	# fraction of a pixel of drift in how tall the object measures does not change
	# the silhouette by anything that can be seen.
	var rebuild_all := relit \
		or absf(_base_height - _built_base) > SHAPE_SLACK \
		or absf(_top_height - _built_top) > SHAPE_SLACK
	if rebuild_all:
		_built_base = _base_height
		_built_top = _top_height
		_built_look = _look_serial

	_apply_composite_look()
	probe[1] += Time.get_ticks_usec() - _t0
	_t0 = Time.get_ticks_usec()

	var scale := get_caster_alpha_scale()
	var drawn := 0
	for caster: ShadowCaster in _casters:
		if not is_instance_valid(caster):
			continue
		var part: Part = _parts.get(caster)
		if part == null:
			continue
		if not part.contributing:
			part.item.visible = false
			part.built = false
			caster.note_frame(self, false)
			continue
		if rebuild_all or part.dirty or not part.built:
			probe[7] += 1.0
			part.built = apply(caster, part.pose, part.alpha * scale)
			caster.note_frame(self, part.built)
		part.dirty = false
		if part.built:
			drawn += 1
	_active.visible = drawn > 0
	probe[2] += Time.get_ticks_usec() - _t0


## Asks every contributor where it is standing, and says whether any of them has
## moved since it was last asked.
##
## [b]Nothing is built here and nothing is allocated.[/b] A pose is six floats and a
## picture is one number - see [method ShadowCaster.get_frame_stamp] - so finding
## out that an object is exactly where it was costs a handful of comparisons. It is
## the whole of why a hundred enemies standing still cost what one does.
func _gather() -> bool:
	# Where the object is standing, asked before anything else, because every part's
	# pose is compared against it. A part that travelled with the object has not
	# moved as far as its shadow is concerned - which is what an object walking is,
	# and why walking costs nothing.
	#
	# The point can move without any of the artwork moving - a ground root that
	# answers for its own footing says so directly - so it is asked for separately.
	var ground := _anchor.get_ground_position() if is_instance_valid(_anchor) \
		else global_position
	var moved := ground != _ground_probe
	_ground_probe = ground
	_shape_moved = false

	for caster: ShadowCaster in _casters:
		if not is_instance_valid(caster):
			continue
		var part: Part = _parts.get(caster)
		if part == null:
			continue
		var contributing := caster.prepare_frame()
		if not contributing:
			if part.contributing:
				part.contributing = false
				part.dirty = true
				moved = true
				_shape_moved = true
			continue
		# Held against the object rather than against the world - see _norm. This is
		# the one line that decides whether a walking crowd is expensive.
		var pose := caster.get_frame_world()
		pose.origin -= ground
		var alpha := caster.get_frame_alpha()
		var stamp := caster.get_frame_stamp()
		if part.contributing and stamp == part.stamp \
				and is_equal_approx(alpha, part.alpha) \
				and _pose_settled(part.pose, pose, caster.get_source_size()):
			continue
		part.contributing = true
		part.pose = pose
		part.alpha = alpha
		part.stamp = stamp
		part.dirty = true
		moved = true
		_shape_moved = true
	return moved


## Whether a part has moved against the object by so little that its silhouette
## would come out the same picture.
##
## [b]The cheap path through the whole system, and the one a crowd lives on.[/b] An
## animation moves a walking figure's every part by a fraction of a pixel every
## frame, and every one of those fractions would otherwise mean projecting the
## artwork again and handing the canvas a new set of triangles. Asking whether the
## movement is worth drawing costs three subtractions.
##
## [b]It is the same tolerance the geometry is cut to.[/b] The furthest any point of
## the artwork could have travelled is bounded by how far the pose's origin moved
## plus how far each of its axes turned or scaled over the size of the picture; that
## is compared against [member projection_tolerance] worked back through how much
## this hour magnifies a movement - see [member _pose_slack]. So an object under a
## long evening light, where a small movement shows up as a large one on the floor,
## is held to a tighter bound by itself.
func _pose_settled(was: Transform2D, now: Transform2D, art: Vector2) -> bool:
	if was == now:
		return true
	if _pose_slack <= 0.0:
		return false
	return (now.origin - was.origin).length() \
		+ (now.x - was.x).length() * art.x \
		+ (now.y - was.y).length() * art.y < _pose_slack


## Hides one contributor without dropping it, for a caster that is switched off or
## whose source has gone.
func hide_caster(caster: ShadowCaster) -> void:
	var part: Part = _parts.get(caster)
	if part != null and is_instance_valid(part.item):
		part.item.visible = false
		part.built = false


## Recounts how many contributors move by themselves, so a group of scenery does not
## tick at all. Called by a caster whose cast mode changed.
func refresh_processing() -> void:
	_refresh_processing()


## The alpha the assembled silhouette is finally drawn at - the hour's own opacity,
## this object's multiplier and the fade that comes with being off the ground.
## Nothing belonging to any one part enters it, which is why an object fades as one.
func get_composite_alpha() -> float:
	if _state == null:
		return 0.0
	# Height is counted in hundreds of pixels so the falloff reads as "a fraction per
	# hundred pixels up" rather than as a very small number in the inspector.
	var height_units := _base_height * 0.01
	var lifted := clampf(
		1.0 - _state.shadow_height_opacity_falloff * height_units, 0.0, 1.0)
	return clampf(_state.shadow_opacity * opacity_multiplier * lifted, 0.0, 1.0)


## Whether a part has to carry the composite alpha itself. A union fades the
## finished picture once, so its parts go into the buffer at their own alpha only;
## a plain container draws nothing of its own, so there is nothing to fade and the
## alpha travels with the one part instead.
func get_caster_alpha_scale() -> float:
	return 1.0 if is_union() else get_composite_alpha()


## How much transparent margin, in texture pixels, has to be left round a part's
## artwork for the blur to fade into. Grown from the hour's softness, so a soft
## evening does not clip its own edge.
func get_edge_padding() -> float:
	if _state == null:
		return 0.0
	return ceilf(_effective_softness() * SOFTNESS_TEXELS) + 1.0


## The softness this object's shadow is actually drawn with - see
## [member softness_override], and [member SunController.pool_softness] for the
## other half.
##
## A mark that has shortened into the pool under its object is ambient shade rather
## than a cast shadow, and a hard cut-out is a good part of what makes a very short
## shadow read as broken, so the edge softens as the pool takes over. It only ever
## softens: a prop that asked for a softer edge than the map's pool keeps its own.
func _effective_softness() -> float:
	if _state == null:
		return 0.0
	var own := _state.shadow_softness if softness_override < 0.0 \
		else clampf(softness_override, 0.0, 1.0)
	if _pool_blend <= 0.0 or _sun == null:
		return own
	return clampf(
		lerpf(own, maxf(_sun.get_pool_softness(), own), _pool_blend), 0.0, 1.0)


## Builds one contributor's geometry: its artwork cut into a grid and every corner
## of every cell put through [method project_world].
##
## [param world] is the part's pose held against the object's ground point, already
## carrying whatever extra lift it claims. [param alpha] is its own fade. What comes
## out is in shape space - see [method _norm] - so the geometry does not know where
## on the map the object is standing and the container puts that back.
func apply(caster: ShadowCaster, world: Transform2D, alpha: float) -> bool:
	var part: Part = _parts.get(caster)
	if part == null:
		return false
	var item := part.item

	var source := caster.get_source_sprite()
	var texture := SpriteBounds.source_texture(source)
	if texture == null or alpha <= 0.002:
		item.visible = false
		return false

	var texture_size := Vector2(texture.get_size())
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		item.visible = false
		return false

	# Which patch of artwork is being drawn and where it sits in the source's own
	# space. None of it can change while the picture has not - see Part.art_stamp -
	# so it is worked out once per picture rather than once per frame.
	var pad := get_edge_padding()
	if part.art_stamp != part.stamp or not is_equal_approx(part.art_pad, pad):
		part.art_stamp = part.stamp
		part.art_pad = pad
		_measure_art(part, source, texture, texture_size, pad)

	var padded := part.art_quad
	var frame_uv := part.art_uv
	var uv_from := part.art_from
	var uv_to := part.art_to

	# How finely this part has to be cut, in each of its own directions - see
	# _grid_steps. The buffers are only resized when that answer changes, which for
	# anything but a turning weapon is once in its life.
	var steps := _grid_steps(world, padded)
	var wide := steps.x + 1
	var tall := steps.y + 1
	if steps != part.steps:
		part.steps = steps
		part.vertices.resize(wide * tall)
		part.uvs.resize(wide * tall)
		part.colors.resize(wide * tall)
		part.indices = _grid_indices(steps.x, steps.y)

	var vertices := part.vertices
	var uvs := part.uvs
	var colors := part.colors

	# The projection, unpacked into plain floats and written out longhand rather than
	# called - see _norm, which is the same arithmetic said once and readably. This is
	# the innermost loop in the whole system and the only place the shortcut is worth
	# taking.
	var inverse_top := 1.0 / maxf(_top_height, MIN_SPAN)
	var step_down := 1.0 / float(steps.y)
	var step_across := 1.0 / float(steps.x)
	var positional := _ray_positional
	var sun_height := _ray_height
	var lift_cap := sun_height * 0.98
	var rise_scale := _shape_rise
	var width := _ray_width
	# The footprint, unpacked the same way. Zero is the whole of what an object with
	# no authored footing costs: one comparison per point, and the same arithmetic
	# the projection always did.
	var contact := _contact_height
	var flat_x := _flat_x
	var flat_y := _flat_y
	var index := 0
	var colour := Color(0.0, 0.0, 0.0, alpha)
	var _t1 := Time.get_ticks_usec()
	for row: int in range(tall):
		var down := float(row) * step_down
		var edge := padded.position + Vector2(0.0, padded.size.y * down)
		for column: int in range(wide):
			var over := float(column) * step_across
			# Already against the object's ground point: the pose was taken that way,
			# so this whole loop has no idea where on the map it is standing.
			var point := world * (edge + Vector2(padded.size.x * over, 0.0))
			var height := -point.y * height_scale
			if height <= 0.0:
				height = 0.0
			var across := point.x * width
			# How much of this point is standing up. Without a footprint that is the
			# whole of its height; with one, the band below the footing is lying on
			# the floor and only what is above it is thrown - see _norm, which is
			# this said once and readably.
			var lifted := height - contact
			if contact > 0.0:
				var base := flat_x * point.x - flat_y * minf(height, contact)
				if lifted <= 0.0:
					vertices[index] = base
				elif positional:
					var stand := minf(lifted, lift_cap)
					var thrown := stand / (sun_height - stand)
					vertices[index] = base \
						+ Vector2(across * thrown, thrown * rise_scale)
				else:
					vertices[index] = base + Vector2(0.0, lifted * rise_scale)
			elif height <= 0.0:
				vertices[index] = Vector2(across, 0.0)
			elif positional:
				var lift := minf(height, lift_cap)
				var rise := lift / (sun_height - lift)
				vertices[index] = Vector2(across * (1.0 + rise), rise * rise_scale)
			else:
				vertices[index] = Vector2(across, height * rise_scale)
			uvs[index] = Vector2(lerpf(uv_from.x, uv_to.x, over),
				lerpf(uv_from.y, uv_to.y, down))
			# Red carries how high up the object this point was, so the length fade
			# can be measured off the light rather than off the picture's own edges -
			# which is what keeps a swung weapon and a rolling head fading with the
			# rest of the figure instead of along their own texture. Measured from
			# the footing rather than from the ground line, so the band lying on the
			# floor is the near end of the fade rather than a fifth of the way along
			# it.
			colour.r = clampf(lifted * inverse_top, 0.0, 1.0)
			colors[index] = colour
			index += 1

	# Handed to the canvas as the next set of triangles to draw. No resource is
	# rebuilt and no array is allocated - the buffers filled above are the ones that
	# get drawn.
	probe[3] += Time.get_ticks_usec() - _t1
	_t1 = Time.get_ticks_usec()
	item.set_shape(part.indices, vertices, colors, uvs, texture)
	probe[4] += Time.get_ticks_usec() - _t1
	_t1 = Time.get_ticks_usec()

	# Looked up only when the hour, the frame of artwork or the way the part is
	# composited actually changes. The lookup is keyed by a formatted string, which
	# costs more than building the geometry does if it is done every frame.
	var in_group := is_union()
	if part.material_look != _look_serial or part.material_frame != frame_uv \
			or part.material_in_group != in_group:
		part.material_look = _look_serial
		part.material_frame = frame_uv
		part.material_in_group = in_group
		item.material = ShadowGroup.get_shared_material(
			_effective_softness(), _state.shadow_fade, _state.shadow_color, frame_uv,
			false, in_group)
	item.visible = true
	probe[5] += Time.get_ticks_usec() - _t1
	return true


## Works out which patch of texture a part's silhouette is cut from and where that
## patch is drawn, and remembers it on [param part].
##
## [b]The silhouette is the artwork[/b]: the same texture, the same frame of it, the
## same mirroring. Nothing is reconstructed, so the shape being projected is the
## shape on screen.
func _measure_art(part: Part, source: Sprite2D, texture: Texture2D,
		texture_size: Vector2, pad: float) -> void:
	var frame := SpriteBounds.frame_rect(source)
	var quad := SpriteBounds.frame_draw_rect(source)

	# Cut down to the artwork that is actually there. A character part is drawn on a
	# square canvas with a great deal of nothing round it - the enemy's body covers
	# about a fourteenth of its own texture - and every one of those empty pixels
	# would otherwise be projected, blurred and composited. Cutting them off changes
	# no picture at all, because there was nothing in them, and it keeps the buffer a
	# union has to allocate the size of the figure rather than of its canvas.
	if source.hframes <= 1 and source.vframes <= 1 and not source.region_enabled:
		var opaque := SpriteBounds.used_rect(texture).intersection(frame)
		if opaque.size.x >= 1.0 and opaque.size.y >= 1.0 and opaque.size != frame.size:
			# Mirroring turns the picture inside its whole frame, so where the
			# artwork sits within that frame turns with it.
			var inset := opaque.position - frame.position
			if source.flip_h:
				inset.x = frame.size.x - opaque.size.x - inset.x
			if source.flip_v:
				inset.y = frame.size.y - opaque.size.y - inset.y
			quad = Rect2(quad.position + inset, opaque.size)
			frame = opaque

	part.art_quad = quad.grow(pad)
	part.art_uv = Rect2(frame.position / texture_size, frame.size / texture_size)

	var uv_from := (frame.position - Vector2(pad, pad)) / texture_size
	var uv_to := (frame.end + Vector2(pad, pad)) / texture_size
	if source.flip_h:
		var swap := uv_from.x
		uv_from.x = uv_to.x
		uv_to.x = swap
	if source.flip_v:
		var swap_v := uv_from.y
		uv_from.y = uv_to.y
		uv_to.y = swap_v
	part.art_from = uv_from
	part.art_to = uv_to


## How many cells across and down [param caster]'s artwork is cut into, given the
## pose it is standing in.
##
## [b]Cutting it up is only worth doing where the projection bends.[/b] The sun maps
## a whole row of the world - everything at one depth - onto another row by scaling
## it about a point, which is an affine map: a straight line across the world at one
## height comes out straight. All of the curve is in the other direction, where
## every step down the picture is a step to a different height and so to a different
## scale.
##
## So a part is cut according to how much of the [i]world's vertical[/i] each of its
## own axes covers. An upright sprite covers all of it down its own height and none
## of it across its width, and is cut into a ladder of rows two vertices wide - the
## same picture as a full grid, for a fraction of the work. A weapon turned on its
## side covers it the other way round and is cut the other way round. Nothing has to
## know which is which.
##
## [b]How many cuts that is comes from the error, not from a guess.[/b] A straight
## line between two projected points is out from the true curve by about
## [code]bend * span² / 8[/code], where the bend is [member _ray_curve] and the span
## is how much height the piece covers; solving that for the span that keeps the
## error inside [member projection_tolerance] gives the number of cuts directly. A
## grounded figure under a high midday sun comes out at one or two, the same figure
## at dusk at rather more, and a coin at one - and nothing had to be authored for any
## of them.
func _grid_steps(world: Transform2D, padded: Rect2) -> Vector2i:
	var cap := maxi(projection_subdivisions, 1)
	var detail := maxf(projection_detail_scale, 0.0)
	var across := 1
	var down := 1
	if detail > 0.0 and _ray_curve > 0.0:
		# Cuts per world pixel of height covered, from bend * (span / n)^2 / 8 <= tol.
		var tolerance := maxf(projection_tolerance, 0.01) / detail
		var per_pixel := sqrt(_ray_curve / (8.0 * tolerance)) * height_scale
		across = clampi(ceili(absf(world.x.y) * padded.size.x * per_pixel), 1, cap)
		down = clampi(ceili(absf(world.y.y) * padded.size.y * per_pixel), 1, cap)

	if _contact_height > 0.0:
		# [b]A footprint puts a crease across the picture, and a crease has to fall
		# between two rows of vertices to be a crease at all.[/b] The band is lying
		# on the ground and everything above it is standing up - see [method _norm]
		# - so a cell that spans the two is drawn as one smooth ramp between them
		# and the band is sheared after all. Cutting finely enough that a cell
		# covers no more of the world's vertical than the band itself does puts a
		# row inside the band however little the bend alone would have asked for.
		#
		# It is allowed twice the authored cap, because this is a fact about the
		# geometry rather than about how hard the projection happens to be bending,
		# and because what needs it is scenery - which is rebuilt when the sun moves
		# and not otherwise.
		var seam := maxf(_contact_height, 0.01)
		var crease := cap * 2
		across = clampi(maxi(across,
			ceili(absf(world.x.y) * padded.size.x * height_scale / seam)), 1, crease)
		down = clampi(maxi(down,
			ceili(absf(world.y.y) * padded.size.y * height_scale / seam)), 1, crease)
	return Vector2i(across, down)


## Gathers the patch of floor this object is standing on off its contributors - see
## [method ShadowCaster.get_ground_contact].
##
## [b]The largest footing wins, and nothing is averaged.[/b] An object is standing
## on whatever its widest and deepest part is standing on: a tent has one footing,
## and a figure with several stands on the ground its own parts cover between them.
## A part that has authored none says nothing at all rather than pulling the answer
## down to zero, so a weapon in a hand cannot flatten the figure holding it.
##
## Zero on a map whose sun has not asked for footprints - see
## [member SunController.ground_contact_shadows] - which is what leaves the Arena
## and the Base projected exactly as they always were, whatever their props have
## authored.
func _measure_contact() -> void:
	_contact_authored = 0.0
	_contact_half_width = 0.0
	if _sun == null or not _sun.grounds_shadows_on_contact():
		return
	for caster: ShadowCaster in _casters:
		if not is_instance_valid(caster):
			continue
		var part: Part = _parts.get(caster)
		if part == null or not part.contributing:
			continue
		var contact := caster.get_ground_contact()
		if contact.y <= 0.0:
			continue
		_contact_half_width = maxf(_contact_half_width, contact.x)
		_contact_authored = maxf(_contact_authored, contact.y * height_scale)


## Reads the container's basis backwards, so the ground-contact band can be written
## in the world's own axes - see [member _flat_x].
##
## [b]It is the whole of what a footprint costs per update.[/b] Every point of the
## band has to land exactly where its artwork is drawn, and the container the
## geometry hangs under carries the sun's own two axes; so what a vertex has to hold
## is those axes inverted, worked out once here rather than once per point.
##
## A basis with no inverse - a light with no lean for a shadow to lie along - has no
## ground to lay a band on either, so the footprint is dropped for that update and
## the object is projected as the upright card it always was.
func _lay_flat() -> void:
	_flat_x = Vector2(1.0, 0.0)
	_flat_y = Vector2(0.0, 1.0)
	_contact_height = 0.0
	if _contact_authored <= 0.0:
		return
	var determinant := _shape_across.x * _shape_lean.y \
		- _shape_lean.x * _shape_across.y
	if absf(determinant) < 0.0001:
		return
	var inverse := 1.0 / determinant
	_flat_x = Vector2(_shape_lean.y, -_shape_across.y) * inverse
	_flat_y = Vector2(-_shape_lean.x, _shape_across.x) * inverse
	_contact_height = _contact_authored


## How tall the object's assembled artwork stands and how high off the floor it is
## right now.
##
## [b]Both are measured from the artwork actually contributing[/b], so nothing has
## to be authored and nothing can be cropped: an arm raised by an animation, a weapon
## swung out wide and a head thrown clear all move the bounds by themselves.
##
## [b]It is only asked when a part moved against the object.[/b] The poses are held
## against the ground point, so an object that merely walked carries its whole shape
## with it and the answer cannot have changed - see [method _gather].
func _measure() -> void:
	_measure_contact()
	var lowest := -INF
	var highest := INF
	var widest := 0.0
	var found := false
	for caster: ShadowCaster in _casters:
		var part: Part = _parts.get(caster)
		if part == null or not part.contributing:
			continue
		# Measured against the pose already taken for the frame, so no part's
		# transform is read twice and nothing is allocated to hold its corners.
		var box := SpriteBounds.world_box(caster.get_source_sprite(), part.pose)
		if box.size == Vector2.ZERO:
			continue
		found = true
		lowest = maxf(lowest, box.end.y)
		highest = minf(highest, box.position.y)
		# The poses are held against the point the object is standing on, so the
		# widest the artwork reaches either side of x = 0 is the half-width of the
		# ground it covers - which is what a pool under it is sized from.
		widest = maxf(widest, maxf(absf(box.position.x), absf(box.end.x)))

	if not found:
		_base_height = 0.0
		_span = MIN_SPAN
		_top_height = MIN_SPAN
		_half_width = MIN_SPAN
		return
	_half_width = maxf(widest, MIN_SPAN)

	# World Y runs down the screen, so the artwork's own ground line is its lowest
	# point and its top is its highest. Both are turned into heights above the point
	# the object is standing on, which is what the sun works in - and the poses were
	# taken against that point already, so the ground line is simply zero.
	_base_height = maxf(-lowest, 0.0)
	_span = maxf(lowest - highest, MIN_SPAN)
	# How high the top of the artwork stands above the point the object is standing
	# on, which is the only height the sun is ever asked about.
	#
	# Read off the top directly where the map asks for it - see
	# [member SunController.measure_height_to_top]. Artwork drawn [i]below[/i] the
	# ground line - a prop whose base skirts a little under its own footing, a leg
	# mid-stride - is standing on the floor, not sunk beneath it, so the part of it
	# under the line is projected where it is and is no part of how tall the thing
	# is. Adding it in, which is what the sum below does, stretches every such shadow
	# by however far the artwork dips.
	#
	# The sum is still what a map that has not asked gets, to the last bit, because
	# the shadow lengths in those scenes were authored against it.
	if _measures_height_to_top():
		_top_height = maxf(-highest, MIN_SPAN) * height_scale
	else:
		_top_height = maxf((_base_height + _span) * height_scale, MIN_SPAN)
	# The footing is not part of how tall the object is. The band lying on the floor
	# throws nothing, so the height the sun is asked about is what stands above it -
	# which is what keeps a tent's mark the length of the tent above its pegs rather
	# than of the whole picture.
	_top_height = maxf(_top_height - _contact_authored, MIN_SPAN)


## Asks the sun where this object's ground line and its top go, and from that works
## out the offsets that slide the finished shadow.
##
## [b]Only offsets.[/b] Everything here is added to every projected point equally,
## so none of it can bend, stretch or turn the silhouette - which is what keeps the
## art controls from being able to fake a sun direction.
func _place() -> void:
	_post_offset = Vector2.ZERO
	# The sun's own numbers first. Which way the light lies, how far this object
	# throws and how much of the mark is the pool underneath it all come out of
	# there, and every offset below is measured against one of them.
	_unpack_sun()

	var foot := _state.project(_ground, _base_height * height_scale)

	# The near end's walk away from the feet, held to the sun's own limit so a very
	# low sun and a very high jump cannot throw a mark across the whole arena.
	var walked := foot - _ground
	var distance := walked.length()
	if _state.shadow_max_distance > 0.0 and distance > _state.shadow_max_distance:
		_post_offset -= walked * (1.0 - _state.shadow_max_distance / distance)

	# Where along its own length the finished mark sits against the object's feet.
	# Along the light, and only along it.
	#
	# [b]A cast shadow starts at the object's own footing, and that is not an
	# authored number.[/b] The near end of the mark is where the object meets the
	# floor, so it belongs exactly where the sun put that point and nowhere else.
	# Sliding it a fraction of the way down its own length instead walks the mark off
	# its object by a fraction of that object's whole reach - nothing on a bone, half
	# a tent on a tent, which is why it was the large props whose shadows read as
	# detached.
	#
	# What genuinely does want to sit under the feet is the pool: a mark that has
	# shortened onto the patch of ground the object is standing on has no far end
	# left to hang off, so it centres. Blended rather than switched, so the mark
	# slides under the object as the sun climbs instead of arriving there.
	#
	# A map that has not asked for the footing keeps the authored slide as the near
	# end it blends away from - see [member SunController.anchor_shadows_on_footing]
	# - so the Arena and the Base, which have no pool for the blend to reach, are
	# placed exactly where they always were.
	# [b]An object standing on its own footprint is already anchored, so nothing
	# slides it.[/b] The slide along the light and the authored pull both exist to
	# put a mark back on a caster the projection had walked it off - see
	# [member SunController.anchor_shadows_on_footing] - and a shadow grown out of
	# the patch of floor the object covers never left it to begin with. Sliding one
	# of those is what would take the fixed band out from under the prop, so with a
	# footprint in play both are simply not applied.
	if _contact_authored <= 0.0:
		var along := lerpf(_authored_anchor(), POOL_CENTRE, _pool_blend)
		_post_offset -= _direction * (_reach * along)
		# The authored pull, in the one direction that means anything: back along the
		# light towards the object. Positive closes the gap between a prop and its
		# mark.
		#
		# [b]It is a contact gap, so it goes when there is no gap left.[/b] A pull is
		# authored against a raked shadow - the mark leaves the prop's base along the
		# light and a few pixels of pull sit it back down on the footing. A mark that
		# has shortened into the pool underneath the object never left in the first
		# place, and the same pull then walks the pool off the very thing it belongs
		# to, which is what makes a big prop look as though its shadow has come
		# adrift. So it fades out on exactly the curve the pool comes in on, leaving
		# the pool centred on the object's own footing and a raked shadow pulled in
		# full.
		_post_offset -= _direction \
			* ((shadow_pull + _anchor_pull()) * (1.0 - _pool_blend))
	_post_offset += shadow_offset + _anchor_offset()


## Takes the sun's numbers out of [SunState] and into plain floats for [method _ray]
## to work in. Done once per update rather than once per projected point.
func _unpack_sun() -> void:
	if _state == null:
		return
	_ray_width = _state.shadow_width_scale
	_ray_height = maxf(_state.height, 0.001)
	_ray_positional = not _state.directional \
		and not (_ground - _state.position).is_zero_approx()
	_ray_sun = _state.position
	_ray_fall = _state.direction * _state.length_ratio
	_direction = _state.shadow_direction_at(_ground)

	# The two halves of the projection - see _norm. The rise written into a vertex is
	# scaled by the sun's own height, which every object in the map shares, so what a
	# vertex holds stays in pixel-sized numbers; the container then unscales it by
	# the same amount along with the lean of this object's own place on the map.
	if _ray_positional:
		_shape_rise = _ray_height
		_shape_lean = (_ground - _ray_sun) / _ray_height
	else:
		_shape_rise = 1.0
		_shape_lean = _ray_fall

	# How hard the projection bends over this object, so a part can be cut finely
	# enough and no more. A point h above the ground is thrown D * h / (H - h) along
	# the light, where H is the sun's height and D how far away it stands; the second
	# derivative of that is D * 2H / (H - h)^3, and it is what a straight line
	# between two projected points is out by. Parallel rays throw h * a constant, a
	# straight line, and bend not at all.
	var top := minf(maxf(_top_height, MIN_SPAN), _ray_height * 0.98)
	if not _ray_positional:
		_ray_curve = 0.0
	else:
		var away := (_ground - _ray_sun).length()
		var fall := _ray_height - top
		_ray_curve = away * 2.0 * _ray_height / (fall * fall * fall)

	_measure_reach(top)
	_hold_minimum_reach(top)
	_lay_across()
	_lay_flat()

	_pose_slack = _movement_slack(top)


## How far the top of this object throws, worked out from the two halves the
## geometry is actually built in rather than by asking the sun again.
##
## [b]It is the same number [method SunState.project] gives[/b], and deliberately
## so: the tip of a vertex at the top of the object is [param carry] units of rise
## through [member _shape_lean], so a reach taken that way cannot disagree with
## where the drawing actually goes. [param top] is the object's height already held
## below the sun's own.
func _measure_reach(top: float) -> void:
	_reach = _shape_lean.length() * _carry(top)


## How much rise a vertex at the top of the object carries - see [method _norm].
## Multiply [member _shape_lean] by it and you have the tip.
func _carry(top: float) -> float:
	if not _ray_positional:
		return maxf(_top_height, MIN_SPAN)
	return _ray_height * top / maxf(_ray_height - top, 0.001)


## Holds the shadow at the shortest length the object's own footing allows, and
## says how much of what is left is that footing rather than a cast shadow.
##
## [b]A thing standing on the ground covers some of it however high the sun
## climbs.[/b] Under a nearly overhead sun the rake goes to nothing and the
## projection has a whole object compressed into a few pixels along the light,
## which draws as a torn sliver rather than as a shadow. Giving the length a floor
## taken from the object's own width restores what was missing - the patch of
## ground it is standing on - and does it without a second shape to draw or a
## threshold to cross, because it is the same silhouette through the same
## projection with one number held up.
##
## [b]Nothing is switched.[/b] The floor is joined to the true length as
## [code](reach^n + floor^n)^(1/n)[/code] - see [constant POOL_FALLOFF] - which is
## smooth at every length, so a shadow growing out of its pool lengthens
## continuously and there is no instant at which the shape changes. The blend that
## comes back is the same curve read the other way, and is what settles the mark
## under the object's feet - see [constant POOL_CENTRE] - rounds its width off onto
## the same footing - see [method _lay_across] - and softens its edge as it becomes
## a pool. All three arrive together and on the one curve, so what a rising sun
## actually does is shorten a shadow into a small soft round patch underneath its
## object, and a falling one draws it back out again.
##
## The light's own direction is untouched: the lean is rewritten along
## [member _direction], which is where it already pointed in both projection modes.
func _hold_minimum_reach(top: float) -> void:
	_pool_blend = 0.0
	var pool := _pool_extent()
	if pool <= 0.0:
		return

	var thrown := pow(maxf(_reach, 0.0), POOL_FALLOFF)
	var floored := pow(pool, POOL_FALLOFF)
	var want := pow(thrown + floored, 1.0 / POOL_FALLOFF)
	_pool_blend = clampf(floored / maxf(thrown + floored, 0.0001), 0.0, 1.0)

	var carry := _carry(top)
	if carry > 0.0001:
		_shape_lean = _direction * (want / carry)
	_reach = want


## The shortest this object's shadow may be, in world pixels - the patch of ground
## it is standing on, as a fraction of its own measured width. Zero on a map that
## has not asked for a floor at all, which is every arena.
func _pool_extent() -> float:
	if _sun == null:
		return 0.0
	var ratio := _sun.get_minimum_shadow_ratio()
	if ratio <= 0.0:
		return 0.0
	# The ground the object is standing on, where it has said what that is, and the
	# width of its artwork where it has not. A wide-topped thing - a tent, a cactus
	# with arms - covers far less floor than it covers screen, and a pool taken off
	# the picture instead of off the footing is the size of the roof.
	var footing := _contact_half_width if _contact_half_width > 0.0 else _half_width
	# Against the width the shadow is actually drawn at, so the pool stays as round
	# as the hour's own width scale leaves it.
	return ratio * footing * 2.0 * maxf(_ray_width, 0.0)


## Whether this map measures an object's height to the top of its artwork - see
## [member SunController.measure_height_to_top]. A group with no sun measures the
## old way, since that is what a scene opened on its own was always drawn with.
func _measures_height_to_top() -> bool:
	return _sun != null and _sun.measures_height_to_top()


## Where along its own length a mark starts, before the pool centres it - 0 on a map
## that anchors a shadow on its caster's footing, and the hour's own authored slide
## on one that does not. See [member SunController.anchor_shadows_on_footing].
func _authored_anchor() -> float:
	if _state == null or (_sun != null and _sun.anchors_shadows_on_footing()):
		return 0.0
	return _state.shadow_length_anchor


## Lays the silhouette's own width on the ground - see [member _shape_across].
##
## [b]The object's left stays on its left, at every hour of the day.[/b] That is the
## whole of what this method is for, and it is not a matter of taste: the projection
## of an upright thing onto the floor moves points along the light and leaves their
## sideways position alone, so a point drawn to the right of a prop lands to the
## right of it whichever side of the map the sun is on. A width axis that swings
## round with the light does not do that - it carries the silhouette round with the
## sun, so a wide building lit from the side lays its width [i]up the screen[/i] and
## the same building lit from the front lays it out mirrored. That is what a shadow
## flipping over through the afternoon actually is.
##
## [b]So the width is pinned to the screen's own right, and only its length
## changes.[/b] For a caster taken as a flat card - see
## [member SunController.solid_casters] - that is the whole answer, and the card
## loses its shadow entirely at the two hours the light runs along its width, which
## is what a thing with no depth does.
##
## For one taken as having a body, the footprint is an ellipse as wide as the
## artwork and [member SunController.caster_depth_ratio] as deep, and the width is
## laid across whatever that ellipse presents to the light: its full width when the
## light comes down the screen or up it, its depth when the light runs straight
## across, and the support point of the ellipse in between. So the mark narrows and
## opens out over the day the way a body's does, without ever turning round.
##
## [b]And it rounds off into the pool.[/b] As the sun climbs and the mark shortens
## onto the patch of ground the object is standing on - see
## [method _hold_minimum_reach] - the width settles onto that same footing, so what
## is left directly under an overhead sun is a small round shadow rather than the
## object's whole silhouette squashed flat along one axis.
func _lay_across() -> void:
	if _sun == null or _direction.is_zero_approx():
		_shape_across = Vector2(1.0, 0.0)
		return

	# Perpendicular to the light, taken on the side the camera calls right. Both
	# perpendiculars describe the same footprint - an ellipse is symmetric - and this
	# is the one that leaves the artwork the way round it is drawn.
	var normal := Vector2(_direction.y, -_direction.x)
	if normal.x < 0.0:
		normal = -normal

	# The ellipse's support point in that direction, as a multiple of the artwork's
	# own half width: (a*a*n.x, b*b*n.y) normalised, with b = depth * a. Depth 1
	# leaves the normal itself - a round footprint, and the one case that does swing
	# the silhouette round with the sun.
	var depth := _sun.get_caster_depth_ratio()
	if depth <= 0.0:
		# No body to present: a flat card, whose width is across the screen and
		# stays there. Every arena is drawn this way.
		_shape_across = Vector2(1.0, 0.0)
	else:
		var squash := depth * depth
		var scale := sqrt(normal.x * normal.x + squash * normal.y * normal.y)
		_shape_across = Vector2(normal.x, squash * normal.y) / maxf(scale, 0.0001)

	# The pool is the ground the object stands on rather than a picture of the
	# object, so it is as wide as it is long. The length has already been held at
	# twice the footing radius - see _pool_extent - and one half width of artwork
	# reaches that same radius at exactly the map's own ratio, so the two ends of the
	# blend meet without either being authored.
	if _pool_blend > 0.0:
		var round_width := _sun.get_minimum_shadow_ratio()
		_shape_across = _shape_across.normalized() \
			* lerpf(_shape_across.length(), round_width, _pool_blend)


## How far a contributor may move against the object before its silhouette is worth
## drawing again - see [method _pose_settled].
##
## How much this hour magnifies a movement of the artwork: sideways, by how far the
## rays have spread by the time they reach the top of the object; up and down, by
## how many pixels along the light a pixel of height is worth. A movement smaller
## than the tolerance divided by that cannot show.
func _movement_slack(top: float) -> float:
	var spread := _ray_width
	if _ray_positional:
		spread *= _ray_height / maxf(_ray_height - top, 0.001)
	var rake := _reach / maxf(_top_height, MIN_SPAN)
	var detail := maxf(projection_detail_scale, 0.0)
	if detail <= 0.0:
		# Drawn as a flat quad by choice: nothing about this object is worth a redraw
		# it does not need, so the bound is the tolerance in full.
		detail = 1.0
	return maxf(projection_tolerance, 0.0) / detail \
		/ maxf(maxf(spread, rake), 1.0)


func _anchor_offset() -> Vector2:
	return _anchor.shadow_offset if is_instance_valid(_anchor) else Vector2.ZERO


func _anchor_pull() -> float:
	return _anchor.shadow_pull if is_instance_valid(_anchor) else 0.0


## Triangles for a grid [param columns] cells across and [param rows] down, worked
## out once per shape and shared by every shadow in the game. The vertices move
## every frame; how they are joined up never does.
static func _grid_indices(columns: int, rows: int) -> PackedInt32Array:
	var key := columns * 64 + rows
	var cached: PackedInt32Array = _index_cache.get(key, PackedInt32Array())
	if not cached.is_empty():
		return cached

	var side := columns + 1
	var indices := PackedInt32Array()
	indices.resize(columns * rows * 6)
	var at := 0
	for row: int in range(rows):
		for column: int in range(columns):
			var corner := row * side + column
			indices[at] = corner
			indices[at + 1] = corner + 1
			indices[at + 2] = corner + side + 1
			indices[at + 3] = corner
			indices[at + 4] = corner + side + 1
			indices[at + 5] = corner + side
			at += 6
	_index_cache[key] = indices
	return indices


## Stands the container on the object's ground point and fades and colours the
## finished silhouette - once, whatever it is made of.
##
## [b]The container carries where the object is standing.[/b] That is a position and
## the one basis the whole object shares - see [method _norm] - and nothing else: the
## bend of the projection stays in the geometry, where it can vary from point to
## point, and no part of it is guessed at from a rectangle.
func _apply_composite_look() -> void:
	# The container carries the object's ground point, the art offsets, and the half
	# of the projection that is the same for every point of the object - see
	# _shape_basis. Four floats written once an object moves, however many parts and
	# however many thousand vertices it is made of.
	var as_2d := _active as Node2D
	if as_2d != null:
		var stand := _shape_basis()
		if as_2d.global_transform != stand:
			as_2d.global_transform = stand

	if is_union():
		# The union's own alpha, applied to the composite. Its parts go into the
		# buffer at their own alpha only, so this is the only place the hour reaches
		# the screen - which is exactly what stops a head and a body from darkening
		# each other where they overlap.
		var alpha := get_composite_alpha()
		if not is_equal_approx(alpha, _composite_alpha):
			_composite_alpha = alpha
			_active.self_modulate = Color(1.0, 1.0, 1.0, alpha)
		# The material is one shared object per hour, so it is looked up when the
		# hour moves rather than every frame - the lookup itself is the expensive
		# part. See get_shared_material.
		if _composite_look != _look_serial:
			_composite_look = _look_serial
			_active.material = ShadowGroup.get_shared_material(
				_effective_softness(), _state.shadow_fade, _state.shadow_color,
				Rect2(), true)
	else:
		if _composite_alpha != 1.0:
			_composite_alpha = 1.0
			_active.self_modulate = Color.WHITE
		if _composite_look != _look_serial:
			_composite_look = _look_serial
			_active.material = null


## The contributor the group stands by, worked out when the membership changes
## rather than every frame.
##
## [b]A part of the object wins over anything the object is carrying.[/b] A figure
## stands where its feet are, never where the revolver in its hand happens to hang,
## and a carried thing does not stand anywhere at all - it is in the air, held. So
## the walk asks each contributor what it is [i]standing on[/i] - see
## [method ShadowCaster.get_ground_root] - and a part that stands on this object
## wins outright over a part that stands on itself. Among the object's own parts the
## one whose artwork reaches lowest wins, which is the one actually touching the
## floor.
##
## Nothing here knows what kind of part any of them is. A weapon is excluded because
## it stands on itself, and it is let back in the moment it is dropped and becomes
## its own object again.
func _resolve_anchor() -> void:
	var owner_node := get_parent()
	var best: ShadowCaster = null
	var best_rank := -1
	var best_footing := -INF
	for caster: ShadowCaster in _casters:
		if not is_instance_valid(caster):
			continue
		var rank := 0
		var root := caster.get_ground_root()
		if root != null and root == owner_node:
			# It stands where this object stands: one of the object's own parts.
			rank = 2
		elif owner_node != null and owner_node.is_ancestor_of(caster):
			rank = 1
		var footing := caster.get_world_height_band().y
		if best == null or rank > best_rank \
				or (rank == best_rank and footing > best_footing):
			best = caster
			best_rank = rank
			best_footing = footing
	_anchor = best


## Builds whichever container the group needs and moves the meshes into it. A
## union's composite buffer is only ever allocated once a group genuinely has more
## than one part, so scenery never pays for one.
func _refresh_containers() -> void:
	var want_union := combine_mode == CombineMode.COMBINE_UNION \
		or (combine_mode == CombineMode.COMBINE_AUTO and _parts.size() > 1)

	if _layered == null:
		_layered = Node2D.new()
		_layered.name = "Layered"
		add_child(_layered)
	if want_union and _union == null:
		_union = CanvasGroup.new()
		_union.name = "Union"
		_union.fit_margin = fit_margin
		add_child(_union)

	var was := _active
	_active = _union if want_union else _layered
	if was != _active:
		# A different container draws it now, so nothing remembered about how the
		# last one looked still applies.
		_composite_alpha = -1.0
		_composite_look = -1
		mark_dirty()
	_apply_container_layout()
	_reparent_orphan_shapes(_active)


## Puts every contributor's shape under the active container, wherever it was.
func _reparent_orphan_shapes(target: CanvasItem) -> void:
	for caster: ShadowCaster in _casters:
		var part: Part = _parts.get(caster)
		if part == null or not is_instance_valid(part.item):
			continue
		var item := part.item
		if item.get_parent() == target:
			continue
		if item.get_parent() == null:
			target.add_child(item)
		else:
			item.reparent(target, false)
		# Moved between containers, so which pass it is drawn with has changed and
		# the material it was using is the wrong one.
		item.material = null
		part.material_look = -1
	if _layered != null:
		_layered.visible = _active == _layered
	if _union != null:
		_union.visible = _active == _union


## Both containers are top level, so the ground position written onto them is world
## space and a parent turning or scaling cannot apply itself to the answer a second
## time; and never y-sorted, because a shadow is on the ground however deep into the
## arena it lies.
func _apply_container_layout() -> void:
	for container: CanvasItem in [_layered, _union]:
		if container == null:
			continue
		var as_2d := container as Node2D
		if as_2d != null:
			as_2d.top_level = true
		container.y_sort_enabled = false
		container.z_as_relative = false
		container.z_index = shadow_z_index


func _connect_sun() -> void:
	_sun = _resolve_sun()
	if _sun == null:
		return
	_state = _sun.get_state()
	_unpack_sun()
	if not _sun.sun_updated.is_connected(_on_sun_updated):
		_sun.sun_updated.connect(_on_sun_updated)


func _disconnect_sun() -> void:
	if _sun == null:
		return
	if _sun.sun_updated.is_connected(_on_sun_updated):
		_sun.sun_updated.disconnect(_on_sun_updated)


func _resolve_sun() -> SunController:
	if not sun_path.is_empty():
		var node := get_node_or_null(sun_path) as SunController
		if node != null:
			return node
	return SunController.get_active(self)


## Static groups hang off the sun rather than the frame: they repaint while it is
## crossing the sky and cost exactly nothing while it is not.
##
## [b]The debt is taken before the view is consulted.[/b] [method mark_dirty] is
## what records that this object owes a rebuild, and it runs whether or not one
## happens now - so a shadow passed over while nobody could see it is not a shadow
## that has forgotten the hour, it is one that has not got round to it yet, and the
## next update it does rebuilds in full.
func _on_sun_updated(state: SunState) -> void:
	_state = state
	mark_dirty()
	if not _worth_rebuilding_now():
		return
	_unpack_sun()
	update_group(true)


## The map's own answer to "can the player see this", and the whole of the view
## cull. Only ever consulted for a rebuild; see [method _on_sun_updated].
##
## [b]It reuses the culling the map already does rather than measuring again.[/b]
## Scenery that [PropScatter] has taken away is hidden, so the first test is a flag
## the map keeps up to date for its own reasons and this reads for free. What is
## left - the landmarks and the buildings, which are always in the tree because
## nothing culls them - is measured against the camera's own rectangle, and that is
## asked of the sun rather than of the viewport so the whole map pays for one
## camera read a frame.
func _worth_rebuilding_now() -> bool:
	if _sun == null or not _sun.culls_static_rebuilds():
		return _clear_view_deferral(true)
	if not is_visible_in_tree():
		# Taken away by the map's own cull. Nothing has to watch for the return:
		# being handed back is a visibility change and announces itself.
		return _clear_view_deferral(false)

	var view := _sun.get_rebuild_view()
	if view.size.x <= 0.0 or view.size.y <= 0.0:
		# No camera to measure against, so nothing is out of view.
		return _clear_view_deferral(true)
	# A shadow can reach the screen from an object that cannot, so the object's own
	# length is added to the map's margin rather than assumed to be inside it.
	if view.grow(maxf(_reach, 0.0) + maxf(_top_height, 0.0)).has_point(_ground):
		return _clear_view_deferral(true)

	if not _view_deferred:
		_view_deferred = true
		_refresh_processing()
	return false


## Puts down the wait for the camera, if one was being kept, and answers
## [param verdict] - so the two lines that end a deferral live in one place rather
## than at every way out of [method _worth_rebuilding_now].
func _clear_view_deferral(verdict: bool) -> bool:
	if _view_deferred:
		_view_deferred = false
		_refresh_processing()
	return verdict


## Brought back by the map's scenery cull, or by a parent being shown again. A
## group that owes an hour pays it here, in the frame it is handed back, so nothing
## is ever seen wearing the shadow of an hour that has gone.
func _on_visibility_changed() -> void:
	if _built_look == _look_serial or not is_visible_in_tree():
		return
	if not _worth_rebuilding_now():
		return
	_unpack_sun()
	update_group(true)


func _refresh_processing() -> void:
	_dynamic_count = 0
	for caster: ShadowCaster in _casters:
		if is_instance_valid(caster) and caster.enabled \
				and caster.cast_mode == ShadowCaster.CastMode.CAST_DYNAMIC:
			_dynamic_count += 1
	set_process(enabled and (_dynamic_count > 0 or _view_deferred))
