class_name CrosshairAmmo
extends Label
## How many rounds are actually in the weapon, drawn beside the sight.

## [b]It is not the ammunition counter.[/b] The counter in the corner of the HUD is
## the [i]pouch[/i] - forty-five rifle rounds the player is carrying - and this is the
## gun: six in the cylinder, seven in the tube. They are genuinely different numbers,
## which is why the revolver can read 3 here and 40 down there, and why a player
## fanning the hammer watches this one.
##
## [b]It counts nothing.[/b] There is no second ammunition state anywhere in this
## file: every frame it asks whatever weapon is in the player's hands how many rounds
## it is holding and draws the answer. A round fired, a chamber fed, a magazine thrown
## on the ground and a weapon swapped out are therefore all already correct here
## without any of them being wired to it - and it can never drift from the weapon,
## because it never has a number of its own to drift with.
##
## [b]No weapon is named.[/b] The question is asked by method name, from
## [member count_methods], and the first name the weapon answers to is the one used -
## so a revolver's cylinder and a rifle's tube are the same lookup, and a weapon added
## later joins by having a method rather than by this learning about it. A weapon that
## answers to none of them has no magazine worth showing and the number simply is not
## drawn.
##
## [b]Where it sits is the weapon's own business.[/b] It is a child of [Crosshair], so
## it follows the sight around the screen for nothing, and its offset, size and colour
## are read off that weapon's [CrosshairStyle] - which is where the rest of that
## weapon's sight is already described. The revolver and the rifle can therefore be
## placed and sized differently without either being written down here.

## Methods a weapon might answer "how many rounds are in you" with, tried in order.
## The first one the weapon has is the one asked, so the revolver's cylinder and the
## rifle's magazine are one lookup rather than two branches.
@export var count_methods: Array[StringName] = [
	&"get_loaded_count",
	&"get_magazine_count",
]
## Whether the number goes away while the weapon is in the belt. On: a stowed weapon
## has no sight either, and a count hanging in the middle of the screen with nothing
## beside it reads as a bug.
@export var hide_while_stowed: bool = true

@export_group("Nodes")
## The sight this hangs off. Defaults to this label's parent, which is where it
## belongs - being a child is what makes it follow the sight with no code at all.
@export var crosshair_path: NodePath = ^".."
## The mount the weapon is read from. Left unresolved it is found by group.
@export var mount_path: NodePath

@onready var _crosshair: Crosshair = get_node_or_null(crosshair_path) as Crosshair

var _mount: WeaponMount
## The last text written, so the label is only touched when the number has actually
## moved rather than every frame.
var _shown: String = ""
## The last style applied, for the same reason - the placement only changes when the
## weapon does.
var _applied: CrosshairStyle


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# It must not push the sight around or be pushed around by it: it is a number
	# floating at an offset, not part of any layout.
	size = Vector2.ZERO
	text = ""
	visible = false


## Polled rather than driven by signals, because what it is watching is not one
## weapon: the player can be handed a different gun at any moment, and a poll follows
## that for free where a connection would have to be torn down and remade.
func _process(_delta: float) -> void:
	var style := _crosshair.get_style() if _crosshair != null else null
	var weapon := _get_weapon()
	var count := _count_for(weapon)

	if style == null or not style.ammo_shown or count < 0:
		if visible:
			visible = false
		return

	if style != _applied:
		_applied = style
		_apply_style(style)

	visible = true
	var wanted := str(count)
	if wanted != _shown:
		_shown = wanted
		text = wanted


## How many rounds the weapon says it is holding, or -1 for "do not draw a number" -
## no weapon, a weapon in the belt, or a weapon with no magazine to report.
func _count_for(weapon: CarriedWeapon) -> int:
	if weapon == null:
		return -1
	if hide_while_stowed and weapon.is_stowed():
		return -1
	for method: StringName in count_methods:
		if weapon.has_method(method):
			return maxi(weapon.call(method) as int, 0)
	return -1


## Everything about how the number looks comes from the weapon's own sight resource,
## applied only when the weapon changes.
func _apply_style(style: CrosshairStyle) -> void:
	position = style.ammo_offset
	add_theme_font_size_override(&"font_size", maxi(style.ammo_font_size, 1))
	add_theme_color_override(&"font_color", style.ammo_colour)


func _get_weapon() -> CarriedWeapon:
	var mount := _get_mount()
	return mount.get_weapon() if mount != null else null


func _get_mount() -> WeaponMount:
	if _mount == null or not is_instance_valid(_mount):
		_mount = get_node_or_null(mount_path) as WeaponMount
		if _mount == null:
			_mount = WeaponMount.get_active(self)
	return _mount
