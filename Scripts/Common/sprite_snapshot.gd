class_name SpriteSnapshot
extends RefCounted
## A still copy of a character's artwork as it looks this frame - every visible
## [Sprite2D] under a node, with its texture, frame, flip and global transform, and
## nothing else: no scripts, no animation, no shadow.
##
## For marks left of someone where they stood - see [PlayerStealth]'s silhouettes.


## Builds a [Node2D] under [param parent] holding a copy of every visible sprite
## under [param visual], placed exactly where the originals are drawn now. Every
## copy draws with the new node's [param material] when one is given, so one
## material colours the whole figure.
static func take(visual: Node, parent: Node, material: Material = null) -> Node2D:
	if visual == null or parent == null:
		return null
	var root := Node2D.new()
	root.material = material
	parent.add_child(root)
	var anchor := visual as Node2D
	if anchor != null:
		root.global_position = anchor.global_position
	_copy_sprites(visual, root)
	return root


static func _copy_sprites(from: Node, into: Node2D) -> void:
	for child: Node in from.get_children():
		# A shadow belongs to the body standing there, not to the mark left behind.
		if child is ShadowCaster:
			continue
		# Faded all the way out - the empty hands while a weapon is carried - is
		# not part of the figure.
		if child is CanvasItem and (child as CanvasItem).modulate.a <= 0.01:
			continue
		var sprite := child as Sprite2D
		if sprite != null and sprite.is_visible_in_tree() and sprite.texture != null:
			var copy := Sprite2D.new()
			copy.texture = sprite.texture
			copy.centered = sprite.centered
			copy.offset = sprite.offset
			copy.flip_h = sprite.flip_h
			copy.flip_v = sprite.flip_v
			copy.hframes = sprite.hframes
			copy.vframes = sprite.vframes
			copy.frame = sprite.frame
			copy.region_enabled = sprite.region_enabled
			copy.region_rect = sprite.region_rect
			copy.use_parent_material = true
			into.add_child(copy)
			copy.global_transform = sprite.global_transform
		if child is CanvasItem and (child as CanvasItem).visible:
			_copy_sprites(child, into)
