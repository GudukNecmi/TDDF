class_name PlayerSleep
extends Node
## The player asleep: lying on the ground where they stood, pinned there, with a
## letter drifting up off their face every second or so.
##
## [b]It is the death fall without the death.[/b] Going down is the same three
## things [PlayerDeathSequence] does to put a body on the floor - the [code]Visual[/code]
## node is turned onto its side and settled a few pixels over, the weapon is stowed
## through its own [method CarriedWeapon.stow], and the keys that could walk the
## player out of it are silenced - so a sleeping man is drawn by the same machinery a
## dead one is, at values of this node's own. Nothing about the death sequence is
## touched and neither of them can be running while the other is.
##
## [b]Movement stops because this answers 0 to the player's own speed question.[/b]
## That is [member speed] on the player script - the very seam [TerrainSlow] drags
## them through and the death sequence pins them with - so the player script needs no
## idea that sleeping exists, and a sleep that ended badly can never leave the body
## permanently frozen: the answer is read from the state, not written to the player.
##
## [b]It decides nothing about the night.[/b] How long a sleep lasts, what wakes the
## player and what it costs on the clock are [SleepDirector]'s; this is asked to lie
## down and asked to get up, and everything about how that looks is an inspector
## field here.

## Emitted as the body comes to rest, and again once it is back on its feet.
signal lay_down
signal got_up

## Group this joins, so the sleep system can find the sleeper without a path from
## the world into the player scene.
const GROUP := &"player_sleep"

## The artwork that goes over. Its resting transform is captured on ready and
## everything here is measured from it, so the body always ends up back where it
## belongs however the night was interrupted.
@export var visual_path: NodePath = ^"../Visual"
## Nodes whose input is switched off for as long as the player is asleep - the
## teleport that would otherwise walk them home in their sleep. The weapon is
## silenced too, but through [member stows_weapon], because it is not a child of the
## player and is built rather than authored.
@export var input_blocked_paths: Array[NodePath] = [^"../Teleporter"]

@export_group("Lying down")
## Angle the body comes to rest at, in degrees. A little short of a quarter turn, so
## it lies on its side rather than face down.
@export var lie_rotation_degrees: float = 84.0
## Where it settles relative to where it stood.
@export var lie_offset := Vector2(4.0, 6.0)
## How long lying down and getting up take, in seconds.
@export var lie_time: float = 0.55
@export var rise_time: float = 0.4
## How high the small push off the ground goes as the player gets up, in pixels.
@export var rise_height: float = 14.0

@export_group("The weapon")
## Whether the gun is put away for the night. It goes through the weapon's own
## [method CarriedWeapon.stow] and is handed back by [PlayerLoadout], exactly as the
## death sequence borrows it - so it comes back as ready or as spent as it went away,
## and a player who sleeps in the base still wakes up empty-handed.
@export var stows_weapon: bool = true
@export var weapon_stow_time: float = 0.35
## The component that owns what the player is holding, asked to take the weapon back
## over once they are up rather than this drawing it.
@export var loadout_path: NodePath = ^"../PlayerLoadout"

@export_group("The letters")
## Whether the Zs are drawn at all.
@export var shows_letters: bool = true
## An authored letter, if there is ever art for one. Left empty a plain [Label2D] is
## built from the fields below, which is why sleeping needs no asset of its own.
@export var letter_scene: PackedScene
## What one letter says.
@export var letter_text: String = "Z"
## Seconds between one letter and the next.
@export var letter_interval: float = 0.85
## How long one letter lives, in seconds.
@export var letter_life: float = 2.2
## Where they come from, relative to the player's own origin: the head end of a body
## lying on the ground.
@export var letter_origin := Vector2(6.0, -46.0)
## How far a letter drifts before it is gone, in pixels: up, and sideways.
@export var letter_rise: float = 54.0
@export var letter_drift: float = 26.0
## How much the sideways drift varies from one letter to the next, in pixels, so they
## do not all follow the same line.
@export var letter_scatter: float = 14.0
## How large a letter starts and ends, as a multiple of its authored size - so they
## swell as they fade rather than simply sliding away.
@export var letter_start_scale: float = 0.5
@export var letter_end_scale: float = 1.2

@export_group("The letters - look")
## Used only for the letters this node builds itself; an authored
## [member letter_scene] is drawn however it was authored.
@export var letter_font: Font
@export var letter_font_size: int = 34
@export var letter_colour := Color(0.93, 0.87, 0.84, 0.9)
@export var letter_outline_colour := Color(0.06, 0.01, 0.01, 1.0)
@export var letter_outline_size: int = 8

@onready var _visual: Node2D = get_node_or_null(visual_path) as Node2D
@onready var _loadout: PlayerLoadout = get_node_or_null(loadout_path) as PlayerLoadout

var _asleep: bool = false
var _visual_rest := Vector2.ZERO
var _visual_rest_rotation: float = 0.0
var _tween: Tween
var _letter_timer: float = 0.0
## The letters still drifting, so they can be taken away with the sleep that made
## them. Each one frees itself at the end of its own tween as well.
var _letters: Array[Node] = []


func _ready() -> void:
	add_to_group(GROUP)
	set_process(false)
	if _visual != null:
		_visual_rest = _visual.position
		_visual_rest_rotation = _visual.rotation


## The sleeper in this world, or null when there is none - which every caller reads
## as "nobody can be put to bed here".
static func get_active(from_node: Node) -> PlayerSleep:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as PlayerSleep


func is_asleep() -> bool:
	return _asleep


## The player's movement seam. 0 pins them where they lay down, which is the whole
## of "the player cannot move while sleeping".
func get_speed_multiplier() -> float:
	return 0.0 if _asleep else 1.0


## Puts the player down, and reports whether they were awake to be put down.
func lie_down() -> bool:
	if _asleep:
		return false

	_asleep = true
	_block_input(true)
	_stow_weapon()
	_letter_timer = 0.0
	set_process(shows_letters)
	_play_fall()
	return true


## Stands them back up and hands everything back. Safe on a player who is already
## awake, which is what makes it callable from every way a night can end.
##
## [param rises] is how a night that ended in a death is closed. [b]Dying is the one
## ending the sleeper does not get up from.[/b] [PlayerDeathSequence] takes the body
## over on the same frame - the same [code]Visual[/code] node, turned onto its side by
## a tween of its own - so standing it up as well is two tweens writing one transform,
## a man who picks himself up off the ground while dead, and [PlayerLoadout] drawing
## the weapon back out over a corpse. False therefore lets the night go without
## touching the body, the keys or the gun: the sleep state is cleared, the letters are
## taken away, and everything about how a dead man looks and what he may press is left
## to the sequence that owns him. Every other ending passes true and is unchanged.
func get_up(rises: bool = true) -> bool:
	if not _asleep:
		return false

	_asleep = false
	set_process(false)
	_forget_letters()
	if not rises:
		return true

	_block_input(false)
	_play_rise()
	return true


## Down, in one movement rather than the death's jump and fall: nobody is knocked
## over, they lie down.
func _play_fall() -> void:
	if _visual == null:
		lay_down.emit()
		return

	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_visual, "rotation", deg_to_rad(lie_rotation_degrees),
		maxf(lie_time, 0.0001))
	_tween.parallel().tween_property(_visual, "position", _visual_rest + lie_offset,
		maxf(lie_time, 0.0001))
	_tween.tween_callback(lay_down.emit)


## Up, with the same small push off the ground the revival ends on.
func _play_rise() -> void:
	if _visual == null:
		_finish_rise()
		return

	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_visual, "position", _visual_rest + Vector2(0.0, -rise_height),
		maxf(rise_time, 0.0001) * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_visual, "rotation", _visual_rest_rotation,
		maxf(rise_time, 0.0001) * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_property(_visual, "position", _visual_rest,
		maxf(rise_time, 0.0001) * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_finish_rise)


## Whatever the tween worked out to, the body ends the night exactly where it began
## it - so a sleep torn down half way cannot leave the player lying at an angle.
func _finish_rise() -> void:
	if _visual != null:
		_visual.position = _visual_rest
		_visual.rotation = _visual_rest_rotation
	if _loadout != null:
		_loadout.refresh()
	got_up.emit()


func _process(delta: float) -> void:
	if not _asleep or not shows_letters:
		return

	_letter_timer -= delta
	if _letter_timer > 0.0:
		return
	_letter_timer = maxf(letter_interval, 0.05)
	_breathe_out()


## One letter, drifting up off the head and swelling away to nothing.
func _breathe_out() -> void:
	var parent := get_parent() as Node2D
	if parent == null:
		return
	var letter := breathe_out_into(parent, letter_origin)
	if letter != null:
		_letters.append(letter)


## One letter built and set drifting inside [param parent], starting at
## [param origin] in that parent's own space. Returns it, or null when there was
## nothing to build.
##
## [b]It is public because the night is drawn in two places.[/b] The body lying in
## the world breathes out through [method _breathe_out] above, and [SleepMenu] - the
## screen the player actually watches the night on - breathes out the same letters
## over its own sleeper. Both go through here, so how a letter looks, how far it
## drifts, how it scatters and how long it lives are tuned once, in this node's
## inspector, and the two can never come out looking like different things.
##
## The letters this makes for somebody else are that caller's to take away;
## [method _forget_letters] only clears the ones the body itself breathed out.
func breathe_out_into(parent: Node, origin: Vector2) -> CanvasItem:
	if parent == null or not is_instance_valid(parent):
		return null

	var letter := _make_letter()
	if letter == null:
		return null

	var sideways := letter_drift + randf_range(-letter_scatter, letter_scatter)
	# Written through [method Object.set] because a letter may be either kind of
	# thing: the built-in one is a [Label] and an authored [member letter_scene] is
	# more likely a [Sprite2D]. Both answer to the same three properties, which is
	# also why the tween below can drive either without knowing which it has.
	letter.set(&"position", origin)
	letter.set(&"scale", Vector2.ONE * maxf(letter_start_scale, 0.01))
	parent.add_child(letter)

	var life := maxf(letter_life, 0.05)
	var tween := letter.create_tween().set_parallel(true)
	tween.tween_property(letter, "position",
		origin + Vector2(sideways, -letter_rise), life).set_trans(Tween.TRANS_SINE)
	tween.tween_property(letter, "scale",
		Vector2.ONE * maxf(letter_end_scale, 0.01), life)
	tween.tween_property(letter, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(letter.queue_free)
	return letter


## The letter itself: the authored one where there is one, and a plain label built
## from the inspector fields where there is not - so this needs no artwork to work
## and takes artwork the moment there is any.
##
## It is drawn with the same dark outline behind it the HUD's own text wears, and it
## takes the project's font unless one is dropped in here.
func _make_letter() -> CanvasItem:
	if letter_scene != null:
		return letter_scene.instantiate() as CanvasItem

	var label := Label.new()
	label.text = letter_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if letter_font != null:
		label.add_theme_font_override(&"font", letter_font)
	label.add_theme_font_size_override(&"font_size", maxi(letter_font_size, 1))
	label.add_theme_color_override(&"font_color", letter_colour)
	label.add_theme_color_override(&"font_outline_color", letter_outline_colour)
	label.add_theme_constant_override(&"outline_size", maxi(letter_outline_size, 0))
	return label


## Takes away every letter still in the air.
##
## [b]Waking is not something a letter should outlive.[/b] They fade on tweens of
## their own, and a night that ends with the camp's panel going back up freezes the
## world underneath it - which would leave two or three Zs hanging motionless over a
## man who is already on his feet.
##
## Read by index and tested rather than assigned to a name, because an entry whose
## object has already been freed cannot be read out of a typed array at all.
func _forget_letters() -> void:
	for index: int in range(_letters.size()):
		if is_instance_valid(_letters[index]):
			_letters[index].queue_free()
	_letters.clear()


func _stow_weapon() -> void:
	if not stows_weapon:
		return
	var weapon := _get_weapon()
	if weapon != null:
		if weapon.has_method(&"stow"):
			weapon.call(&"stow", maxf(weapon_stow_time, 0.0))
		# Silenced as well as put away: a stowed weapon is still listening for the
		# trigger, and a man asleep does not fire.
		weapon.set_process_unhandled_input(false)


## Whatever is in the player's hands right now, asked of the mount rather than held -
## the weapon is built from the player's choice and can be replaced, exactly as
## [PlayerLoadout] explains.
func _get_weapon() -> Node2D:
	var mount := WeaponMount.get_active(self)
	return null if mount == null else mount.get_weapon()


func _block_input(blocked: bool) -> void:
	for path: NodePath in input_blocked_paths:
		var node := get_node_or_null(path)
		if node != null:
			node.set_process_unhandled_input(not blocked)
	if blocked:
		return
	# Handed back on the way out rather than by the loadout, because the loadout
	# only decides whether the gun is drawn - not whether it is listening.
	var weapon := _get_weapon()
	if weapon != null:
		weapon.set_process_unhandled_input(true)


func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()


## Nothing is left lying down behind us: a world torn down mid-sleep would otherwise
## hand the next round a player who cannot move.
func _exit_tree() -> void:
	if not _asleep:
		return
	_asleep = false
	_block_input(false)
	_forget_letters()
