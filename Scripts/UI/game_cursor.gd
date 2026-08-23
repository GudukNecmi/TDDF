class_name GameCursor
extends Control
## The pointer the player picks things with, drawn by the game rather than by the
## window.
##
## [b]It is not the sight.[/b] The two are the same pixel on screen and never both
## visible: while the player is holding a weapon they are aiming, so [Crosshair]
## owns the cursor; the moment they are pointing at something instead, this does.
## Which of the two is up is decided in one place - here - and the sight is switched
## off from here rather than working it out for itself.
##
## [b]Two things put the pointer up, and they are different questions.[/b]
##
## The first is a menu owning the screen, and the answer to that is the pause. Every
## full-screen surface in the game pauses the tree while it is up - the escape
## screen, the camp, the travel planner, the trouble decision, the developer panel -
## so [member SceneTree.paused] is the one honest answer, and a menu added later is
## covered without this being told about it. The exception is a surface that
## deliberately leaves the world running, and those name themselves in
## [member extra_surface_paths] rather than this script naming them.
##
## The second is the player having nothing in their hands. A sight belongs to a
## weapon: standing in the base unarmed there is nothing to aim, so a crosshair there
## is a promise the game cannot keep - and worse, it would be [i]some[/i] weapon's
## crosshair, drawn in that weapon's colour, for a weapon the player is not carrying.
## So an empty-handed player gets the pointer. What "empty-handed" means is asked of
## the [WeaponMount] - no weapon built, or the one that was built stowed away in the
## belt - so nothing here knows which weapons exist or where the player has to stand
## to be disarmed.
##
## It is drawn on a [CanvasLayer] whose process mode is
## [constant Node.PROCESS_MODE_ALWAYS], which is what lets the pointer keep
## following the mouse while the world behind it is frozen.
##
## The system pointer is hidden while this exists and put back when it goes, so
## quitting to a menu or closing the game never leaves the mouse missing.

## The pointer as it normally looks.
@export var default_texture: Texture2D:
	set(value):
		default_texture = value
		_apply_texture()
## Shown while the mouse is over something clickable. Left empty the pointer never
## changes, which is what a game with one cursor art wants.
@export var hover_texture: Texture2D
## Size the pointer is drawn at, in pixels. The artwork is far larger than it wants
## to be on screen, so this is the dial that matters.
@export var cursor_size := Vector2(34.0, 34.0):
	set(value):
		cursor_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_apply_size()
## Where in the artwork the actual point is, as a fraction of its size.
##
## [b]This is what makes the pointer point at what it is over.[/b] The drawing is
## an arrow whose tip is not in the middle of its canvas, so the control is offset
## by this much of its own size and the tip lands on the mouse. Measured as a
## fraction rather than in pixels so it survives [member cursor_size] being
## retuned.
@export var hotspot := Vector2(0.4, 0.27):
	set(value):
		hotspot = value
		_apply_size()

@export_group("Outline")
## How far a dark copy of the pointer is thrown out behind it, in pixels.
##
## The same hairline the sight wears, and for the same reason: the desert is pale
## and busy and an arrow drawn in one flat colour can vanish into it. A pixel of dark
## behind the artwork separates the two without the pointer becoming a dark shape.
## 0 turns it off.
@export var outline_thickness: float = 1.0:
	set(value):
		outline_thickness = value
		_apply_size()
## What that hairline is. Near-black and slightly soft, so it reads as a shadow under
## the pointer rather than as a second drawing around it.
@export var outline_colour := Color(0.0, 0.0, 0.0, 0.85):
	set(value):
		outline_colour = value
		_apply_texture()

@export_group("When it is shown")
## Whether the pause is taken as "a menu owns the screen". On, which is what every
## full-screen surface in the game already means by pausing.
@export var shown_while_paused: bool = true
## Whether an empty-handed player is given the pointer instead of a sight. On - a
## crosshair with no weapon behind it is a sight for a gun the player is not holding.
@export var shown_while_unarmed: bool = true
## Further surfaces that put the pointer up while they are visible, for one that
## leaves the world running. Any [Control]; it counts while it is visible in the
## tree.
@export var extra_surface_paths: Array[NodePath] = []
## Whether the system pointer is hidden while this is drawn. Off draws this on top
## of the ordinary pointer, which is only useful while tuning it.
@export var hide_system_cursor: bool = true

@export_group("Nodes")
## The sight this takes the screen from. Switched off whenever the pointer is up
## and back on whenever it is not, so exactly one of them is ever drawn.
@export var crosshair_path: NodePath = ^"../Crosshair"
## The mount the player's weapon is read from, for [method is_unarmed]. Left
## unresolved it is found by group, so this needs no path across the scene.
@export var mount_path: NodePath

## The eight directions a dark copy of the pointer is thrown in. Eight rather than
## four so a one-pixel outline has no gaps at its corners.
const OUTLINE_DIRECTIONS: Array[Vector2] = [
	Vector2(1.0, 0.0),
	Vector2(0.7071, 0.7071),
	Vector2(0.0, 1.0),
	Vector2(-0.7071, 0.7071),
	Vector2(-1.0, 0.0),
	Vector2(-0.7071, -0.7071),
	Vector2(0.0, -1.0),
	Vector2(0.7071, -0.7071),
]

@onready var _outlines: Array[TextureRect] = _build_outlines()
@onready var _art: TextureRect = _build_art()
@onready var _crosshair: Crosshair = get_node_or_null(crosshair_path) as Crosshair

var _surfaces: Array[Control] = []
var _hovering: bool = false
var _mount: WeaponMount


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for path: NodePath in extra_surface_paths:
		var surface := get_node_or_null(path) as Control
		if surface != null:
			_surfaces.append(surface)

	_apply_size()
	_apply_texture()
	if hide_system_cursor:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


## Followed every frame rather than on mouse-motion events, so the pointer keeps up
## with the mouse while the game is paused and while a menu has the input.
func _process(_delta: float) -> void:
	var wanted := is_pointer_wanted()
	visible = wanted
	if _crosshair != null:
		_crosshair.crosshair_visible = not wanted

	if not wanted:
		return

	global_position = get_viewport().get_mouse_position() - cursor_size * hotspot
	_apply_hover()


## Whether the pointer should be up at all: a menu owning the screen, or the player
## holding nothing. The one question the sight's visibility is the answer to.
func is_pointer_wanted() -> bool:
	return is_ui_mode() or (shown_while_unarmed and is_unarmed())


## Whether a menu currently owns the screen. Public so a test - or a later
## surface - can ask the same question this answers itself with.
func is_ui_mode() -> bool:
	if shown_while_paused and get_tree().paused:
		return true
	for surface: Control in _surfaces:
		if is_instance_valid(surface) and surface.is_visible_in_tree():
			return true
	return false


## Whether the player has nothing in their hands.
##
## Two cases, and they are the same answer: no weapon was built at all - a world with
## no mount, or a mount whose catalogue gave it nothing - and a weapon that was built
## but is away in the belt, which is what standing in the base does. The weapon is
## asked rather than the zone, so wherever a weapon is stowed from, the pointer
## follows without this knowing about that place.
##
## A world with no [WeaponMount] in it at all is deliberately [i]not[/i] unarmed: a
## test scene with a weapon dropped straight into it still shows the sight.
func is_unarmed() -> bool:
	var mount := _get_mount()
	if mount == null:
		return false
	var weapon := mount.get_weapon()
	return weapon == null or weapon.is_stowed()


## Swaps to the hover artwork while the mouse is over something that answers to
## it. Asked of the viewport rather than wired to every button, so a menu added
## later gets it for nothing.
func _apply_hover() -> void:
	if hover_texture == null:
		return
	var over := get_viewport().gui_get_hovered_control() != null
	if over == _hovering:
		return
	_hovering = over
	_apply_texture()


## Looked up lazily and re-looked-up if it goes: the mount is built with the world,
## which this outlives across a scene change.
func _get_mount() -> WeaponMount:
	if _mount == null or not is_instance_valid(_mount):
		_mount = get_node_or_null(mount_path) as WeaponMount
		if _mount == null:
			_mount = WeaponMount.get_active(self)
	return _mount


func _build_art() -> TextureRect:
	var art := TextureRect.new()
	art.name = "Art"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(art)
	return art


## The ring of dark copies, built before the pointer itself so the whole outline
## sits behind the whole drawing - children are drawn in the order they were added.
func _build_outlines() -> Array[TextureRect]:
	var built: Array[TextureRect] = []
	for _direction: Vector2 in OUTLINE_DIRECTIONS:
		var copy := _build_art()
		copy.name = "Outline"
		built.append(copy)
	return built


func _apply_size() -> void:
	if not is_node_ready():
		return
	size = cursor_size
	_art.size = cursor_size
	for i: int in _outlines.size():
		_outlines[i].size = cursor_size
		_outlines[i].position = OUTLINE_DIRECTIONS[i] * outline_thickness


func _apply_texture() -> void:
	if not is_node_ready():
		return
	var wanted := hover_texture if _hovering and hover_texture != null else default_texture
	_art.texture = wanted
	var shown := outline_thickness > 0.0 and outline_colour.a > 0.0
	for copy: TextureRect in _outlines:
		# Tinted rather than redrawn: the artwork is a flat arrow, so a copy modulated
		# to near-black is the arrow's own silhouette and follows a change of pointer
		# without a second asset existing.
		copy.texture = wanted
		copy.self_modulate = outline_colour
		copy.visible = shown


## Put back on the way out, so a scene rebuild or a quit never leaves the player
## without a pointer.
func _exit_tree() -> void:
	if hide_system_cursor and Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
