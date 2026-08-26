class_name SpriteOutline
extends RefCounted
## A thin coloured edge drawn round a sprite for as long as something wants one.
##
## [b]It is the outline the game already had, lent to things on the floor.[/b] The
## edge is [code]hit_flash.gdshader[/code]'s own [code]outline_width[/code] uniform -
## the one the mini boss is marked out with - so a knife lying in the sand is
## outlined by exactly the same code that outlines a boss, at a width and a colour
## the caller names. Nothing here draws anything: it sets a uniform and takes it
## away again.
##
## [b]The material is duplicated once, per sprite.[/b] Every knife in a scene shares
## one texture and, without this, one material - so writing the width straight onto
## it would put a red edge round every knife on the map the moment the player stood
## over any of them. The duplicate is kept on the sprite itself under
## [constant META], which is what lets the outline be switched on and off again
## hundreds of times without a second material ever being made.

## Where the sprite's own duplicated material is remembered.
const META := &"pickup_outline_material"


## Puts the edge up or takes it down. Safe to call with the same answer every frame -
## a sprite already showing what it is being asked for is left entirely alone.
##
## [param shader] is only ever needed the first time a sprite is outlined, and only
## when it is not already carrying a shader of its own; a sprite that has one has its
## own duplicated instead, so an outline can never replace artwork's material.
static func set_outlined(sprite: CanvasItem, shown: bool, shader: Shader,
		width: float, color: Color) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return

	var material := _material_for(sprite, shader, shown)
	if material == null:
		return

	material.set_shader_parameter(&"outline_color", color)
	material.set_shader_parameter(&"outline_width", maxf(width, 0.0) if shown else 0.0)


## The sprite's own material, made on the first request and remembered after.
##
## Null when there is nothing to write to and nothing is being asked for, which is
## what keeps a sprite that is never outlined from being given a material it does not
## need.
static func _material_for(sprite: CanvasItem, shader: Shader, wanted: bool) -> ShaderMaterial:
	var owned: ShaderMaterial = null
	if sprite.has_meta(META):
		owned = sprite.get_meta(META) as ShaderMaterial
	if owned != null and is_instance_valid(owned):
		return owned
	if not wanted:
		return null

	var existing := sprite.material as ShaderMaterial
	if existing != null:
		owned = existing.duplicate() as ShaderMaterial
	elif shader != null:
		owned = ShaderMaterial.new()
		owned.shader = shader
	else:
		return null

	sprite.material = owned
	sprite.set_meta(META, owned)
	return owned
