class_name MiniBossPortrait
extends Control
## The outlaw's face on the wanted poster, drawn out of the very parts he will be
## wearing when the player finally meets him.

## [b]It generates nobody.[/b] Every piece of this comes from
## [MiniBossWardrobe.parts_for] - the same call [MiniBossAppearance] dresses the boss
## with, given the same key - so there is no second roster, no second draw and no
## second idea of what an outlaw looks like anywhere in the game. This node only
## decides how those parts are arranged on a sheet of paper.
##
## [b]Which is why the poster cannot lie.[/b] The draw is a pure function of the
## outlaw's identity (see [method MiniBossWardrobe.indices_for]), so the man printed
## here is the man who walks out of the region, checking the same contract twice
## prints him again unchanged, and neither answer is stored anywhere or has to be kept
## in step with the ledger.
##
## [b]The parts line up because the rig lines them up.[/b] A boss's head, body and
## boots are painted on one square canvas each, all three occupying the same square in
## the same place - which is exactly why [MiniBossAppearance] can swap a texture on the
## enemy rig without the head coming off the neck. Here it means the whole man is three
## textures drawn into one rectangle, and [member figure_rect] is the window on that
## canvas he stands in. The weapon is the one part painted on a canvas of its own, so
## it is the one part posed by hand - by [member weapon_anchor] and
## [member weapon_angle_degrees] - at the size the wardrobe already says it is drawn
## next to a body.

## The window on the parts' shared canvas the man stands in, as fractions of it.
##
## Everything outside it is empty paint, so this is what decides whether the sheet
## carries a full-length outlaw or a head and shoulders. Narrowing it to the top
## quarter turns this into a mug shot with nothing here to change.
@export var figure_rect := Rect2(0.19, 0.11, 0.58, 0.76)
## Whether his boots are printed under him. Off is the bust.
@export var shows_legs: bool = true
## Whether the weapon he carries is printed with him - the one part of a mini boss
## that reads as who he is from across a room.
@export var shows_weapon: bool = true

@export_group("The weapon")
## Where the weapon's middle sits, as fractions of the printed figure.
@export var weapon_anchor := Vector2(0.86, 0.58)
## How it lies on the paper, in degrees.
@export var weapon_angle_degrees: float = 24.0
## What its printed size is multiplied by, on top of the size the wardrobe already
## says it is drawn at next to a body - see
## [member MiniBossWardrobe.weapon_scale_multiplier]. 1 prints it exactly the size it
## is in his hand.
@export var weapon_display_scale: float = 1.0

@export_group("Ink")
## What the whole print is multiplied by. White prints him as he is; a wash of brown
## prints him the colour of the paper he is pinned to.
@export var ink_tint := Color(1.0, 1.0, 1.0, 1.0)

## The set he is dressed from and who he is, handed in rather than looked up - the
## poster reads them off [MiniBossDirector], for the same reason it is handed its
## knowledge categories and its rung.
var _wardrobe: MiniBossWardrobe
var _key: StringName = &""
## Head, body and weapon, in that order, exactly as the boss is dressed.
var _worn: Array[Texture2D] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


## Prints the outlaw [param key] out of [param wardrobe]. Returns whether there was
## anything to print - false leaves the sheet to fall back on whatever face
## [member BountyTarget.portrait] carries, so a board in a world with no wardrobe
## authored looks exactly as it did before.
func show_boss(wardrobe: MiniBossWardrobe, key: StringName) -> bool:
	_wardrobe = wardrobe
	_key = key
	_worn = [] as Array[Texture2D]
	if _wardrobe != null:
		_worn = _wardrobe.parts_for(_key)

	queue_redraw()
	return has_figure()


func clear() -> void:
	if _wardrobe == null and _worn.is_empty():
		return
	_wardrobe = null
	_key = &""
	_worn = [] as Array[Texture2D]
	queue_redraw()


## Whether there is a man on this sheet.
func has_figure() -> bool:
	return _reference_part() != null


## Which head, body and weapon is being printed, as indices into the wardrobe's
## arrays - the same [Vector3i] [method MiniBossAppearance.get_indices] reports for
## the body that will be fought. For a readout, and for proving the two agree.
func get_indices() -> Vector3i:
	if _wardrobe == null:
		return Vector3i(-1, -1, -1)
	return _wardrobe.indices_for(_key)


func get_look_key() -> StringName:
	return _key


func _draw() -> void:
	var reference := _reference_part()
	if reference == null:
		return

	var box := _fit(reference.get_size())
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return

	# Boots, then body, then head - the order the enemy scene stacks its own sprites
	# in, so a poster cannot show a man put together differently to the one fought.
	if shows_legs and _wardrobe != null:
		_print(_wardrobe.left_leg_texture, box, Vector2.ZERO, 1.0)
		_print(_wardrobe.right_leg_texture, box, Vector2.ZERO, 1.0)
	if _wardrobe != null:
		_print(_at(1), box, _wardrobe.body_offset_shift, _wardrobe.body_scale_multiplier)
		_print(_at(0), box, _wardrobe.head_offset_shift, _wardrobe.head_scale_multiplier)
		if shows_weapon:
			_print_weapon(_at(2), box, reference.get_size())


## One part of the canvas, printed into [param box].
##
## The placement the wardrobe asks for is applied to the window rather than to the
## paper: shifting the art right is sampling further left, swelling it is sampling a
## smaller square about the canvas's middle. Done that way the print can never spill
## off the sheet however a future set is re-anchored, and no second copy of the rig's
## arithmetic has to be kept in step with [method MiniBossAppearance._dress].
func _print(texture: Texture2D, box: Rect2, shift: Vector2, magnify: float) -> void:
	if texture == null:
		return

	var canvas := texture.get_size()
	if canvas.x <= 0.0 or canvas.y <= 0.0:
		return

	var swell := maxf(magnify, 0.0001)
	var middle := canvas * 0.5
	var window := Rect2(figure_rect.position * canvas, figure_rect.size * canvas)
	window.position = middle + (window.position - middle) / swell - shift / swell
	window.size /= swell
	draw_texture_rect_region(texture, box, window, ink_tint)


## The weapon, laid across the sheet at the size it is drawn at in his hand.
##
## [member MiniBossWardrobe.weapon_scale_multiplier] is the whole of that: it is what
## the weapon art is scaled by against the body art on the rig, so multiplying by it
## here prints a long blade long and a short one short without this file knowing a
## single thing about the pictures.
func _print_weapon(texture: Texture2D, box: Rect2, canvas: Vector2) -> void:
	if texture == null or _wardrobe == null:
		return

	var per_canvas_pixel := box.size.x / maxf(figure_rect.size.x * canvas.x, 1.0)
	var printed := texture.get_size() * per_canvas_pixel \
		* maxf(_wardrobe.weapon_scale_multiplier, 0.0001) * maxf(weapon_display_scale, 0.0001)
	if printed.x <= 0.0 or printed.y <= 0.0:
		return

	draw_set_transform(
		box.position + box.size * weapon_anchor, deg_to_rad(weapon_angle_degrees), Vector2.ONE)
	draw_texture_rect(texture, Rect2(-printed * 0.5, printed), false, ink_tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The figure's window, fitted into whatever room the poster gave this node and
## centred in it - the same thing the [TextureRect] this replaces did with a face.
func _fit(canvas: Vector2) -> Rect2:
	var wanted := figure_rect.size * canvas
	if wanted.x <= 0.0 or wanted.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return Rect2()

	var scale_to := minf(size.x / wanted.x, size.y / wanted.y)
	var printed := wanted * scale_to
	return Rect2((size - printed) * 0.5, printed)


## The part the sheet's proportions are measured from: his body where there is one,
## and whatever else he is made of otherwise, so a wardrobe missing a set still
## prints the sets it has.
func _reference_part() -> Texture2D:
	var body := _at(1)
	if body != null:
		return body
	var head := _at(0)
	if head != null:
		return head
	if _wardrobe == null:
		return null
	return _wardrobe.left_leg_texture


func _at(index: int) -> Texture2D:
	if index < 0 or index >= _worn.size():
		return null
	return _worn[index]


func _to_string() -> String:
	var parts := get_indices()
	return "<MiniBossPortrait %s  head %d  body %d  weapon %d>" % [
		String(_key), parts.x, parts.y, parts.z,
	]
