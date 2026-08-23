class_name MiniBoss
extends Node
## What makes one Enemy1 in the arena the man on the poster: a name, the contract
## it belongs to, and a red outline round it.
##
## [b]There is no boss enemy and no boss scene.[/b] A mini boss is the game's
## ordinary [code]Enemy.tscn[/code], built by the world's own [EnemySpawner], with
## ordinary AI - so it walks, steers round its neighbours, flashes, bleeds, reacts
## to hits and dies through exactly the same components every other enemy uses, and
## nothing about how an enemy works is written twice. What the boss actually *is* -
## how large, how much health, how fast, how hard it hits - is not here either: it
## is [MiniBossTier], applied by [MiniBossDirector] as the instance is built.
##
## This node is only the three things that are true of a boss and of nothing else:
##
##   * [b]It is somebody.[/b] It carries the id of the contract it answers and the
##     name off that contract's poster, so the introduction has a name to put on
##     screen and a later milestone has a contract to close out. Nothing is
##     recalculated from it and the reward is never touched.
##   * [b]It is outlined.[/b] See [method apply_outline] - and [method apply_tint],
##     which is the same material written to a second way for a phase that wants the
##     man himself to change colour rather than his edge.
##   * [b]It is findable.[/b] It joins [constant GROUP], so the director, the HUD
##     and a test can reach the boss without being wired to whatever container it
##     was spawned into.
##
## Taking this node off an enemy leaves a large, tough, fast Enemy1 with no outline
## and no name - which is exactly what it should leave.

## Group the boss's marker component joins, for [DestinationArrow] to point at.
const GROUP := &"mini_boss"

@export_group("Outline")
## Sprites the outline is drawn round. Every one needs a [ShaderMaterial] running
## [code]hit_flash.gdshader[/code]; anything else is skipped, so a future enemy with
## a different set of parts costs nothing here.
##
## It is the same five sprites [member HitReaction.flash_paths] lists, and on
## purpose: the outline is written onto the materials that component already
## duplicated per character - see [method HitReaction.get_flash_materials] - so the
## flash and the outline share one material each instead of replacing one another.
@export var outline_paths: Array[NodePath] = [
	^"../Visual/Body",
	^"../Visual/Legs/LeftLeg",
	^"../Visual/Legs/RightLeg",
	^"../HeadAim/Head",
	^"../KnifeAim/KnifeHand/Knife",
]
## The outline's colour. The HUD's own red, so a boss reads as part of the game
## rather than as a debug highlight.
@export var outline_color := Color(1.0, 0.11, 0.11, 1.0)
## How thick it is drawn, in *source texture* pixels.
##
## The Enemy1 art is authored around a thousand pixels tall and drawn at 0.113
## scale, so this is roughly nine times thinner on screen than the number suggests -
## and thinner again for the arena's zoomed-out view. A boss scaled up by its rung
## draws the same texture larger, so the outline grows with the man for free, which
## is why it does not need to be generous: at 14 a 2.5x boss carries an edge of
## about two screen pixels at the fight's 0.6x zoom, which reads as a red line
## round the man rather than as a border he is standing inside.
@export var outline_width: float = 14.0
## The [HitReaction] whose per-character materials are written to. Left unresolved,
## the sprites' own materials are duplicated here instead, so an enemy with no hit
## reaction is still outlined.
@export var hit_reaction_path: NodePath = ^"../HitReaction"

## Id of the contract this boss answers. Set by [MiniBossDirector]; empty on a boss
## placed by hand in the editor, which is a boss with nobody's name on it.
var bounty_id: StringName = &""
## The name off that contract's poster - "JAMES DICAMPO". What the introduction puts
## on screen.
var target_name: String = ""
## How much the contract knew when it was accepted, kept for a readout and for a
## test. [b]Nothing is derived from it here[/b] - the rung was already chosen and
## applied by the time this node exists.
var accepted_knowledge: int = -1

## Materials the outline was written onto, kept so it can be changed or lifted again
## rather than only ever set once.
var _materials: Array[ShaderMaterial] = []


func _enter_tree() -> void:
	add_to_group(GROUP)


## Deferred, because whose materials these are depends on [HitReaction] having
## already duplicated them. Which of the two runs first is a question about the
## order nodes sit in rather than anything either should depend on, and writing the
## outline onto the scene's *shared* material would put a red outline round every
## enemy in the arena.
func _ready() -> void:
	apply_outline.call_deferred()


## The boss in this world, or null when there is none. Every caller reads null as
## "there is no boss here", which is every ordinary round.
static func get_active(from_node: Node) -> MiniBoss:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as MiniBoss


## The boss component on [param enemy], or null for an ordinary enemy. For anything
## holding a body and needing to know which it has.
static func find_on(enemy: Node) -> MiniBoss:
	if enemy == null:
		return null
	for node: Node in enemy.find_children("*", "MiniBoss", true, false):
		var boss := node as MiniBoss
		if boss != null:
			return boss
	return null


## The body this component belongs to.
func get_body() -> Node2D:
	return get_parent() as Node2D


## What the poster calls him, falling back to [param fallback] so an introduction
## always has something to print.
func get_display_name(fallback: String = "THE OUTLAW") -> String:
	return target_name if not target_name.is_empty() else fallback


## Draws the outline, or lifts it again when [param width] is 0.
##
## Public and re-callable on purpose: the width and the colour are inspector values,
## so retuning them and calling this again takes effect without the boss being
## rebuilt - and a later phase that wants the outline to change as the fight goes on
## has somewhere to say so.
func apply_outline(width: float = -1.0) -> void:
	_collect_materials()
	var drawn := outline_width if width < 0.0 else width
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"outline_color", outline_color)
		material.set_shader_parameter(&"outline_width", maxf(drawn, 0.0))


## Washes the whole man in [param color] at [param strength], or takes the wash off
## again at 0.
##
## [b]It is the outline's own material, written to a second way.[/b] The wash is a
## separate uniform from both the outline and the hit flash - see
## [code]hit_flash.gdshader[/code] - so an enraged boss keeps the red edge it always
## had and still flashes white when it is hit. Nothing here decides when a boss is
## washed or what colour: that is a [MiniBossPhase], applied by [BossPhases].
func apply_tint(strength: float, color: Color = Color(1.0, 0.0, 0.0, 1.0)) -> void:
	_collect_materials()
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"tint_color", color)
		material.set_shader_parameter(&"tint", clampf(strength, 0.0, 1.0))


## The materials to write to: the hit reaction's own if there is one, and otherwise
## duplicates made here.
##
## The duplication in the fallback matters for the same reason it matters in
## [method HitReaction._collect_materials]: the sprites in a scene share one
## material resource, so writing an outline straight onto it would outline every
## enemy in the arena rather than this one.
func _collect_materials() -> void:
	if not _materials.is_empty():
		return

	var reaction := get_node_or_null(hit_reaction_path) as HitReaction
	if reaction != null:
		var owned := reaction.get_flash_materials()
		if not owned.is_empty():
			_materials = owned
			return

	for path: NodePath in outline_paths:
		var sprite := get_node_or_null(path) as CanvasItem
		if sprite == null:
			continue
		var shared := sprite.material as ShaderMaterial
		if shared == null:
			continue
		var own := shared.duplicate() as ShaderMaterial
		sprite.material = own
		_materials.append(own)


func _to_string() -> String:
	return "<MiniBoss %s  contract %s  knowledge %d>" % [
		get_display_name(), String(bounty_id), accepted_knowledge,
	]
