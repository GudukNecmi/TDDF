class_name RunCharmHolder
extends Node
## The Charms the player wears for the current run - the one authority a Charm is
## added through. Registered as the [code]Charms[/code] autoload.
##
## [b]Run-only, never permanent.[/b] Like [RunCardHolder], the Charms are taken
## off as a run begins and as it ends, and it is an autoload because a run is
## played across real scene changes - a Charm taken from a fight's pouch is still
## worn on the run map and in the next fight.
##
## [b]Charms stack and there is no cap.[/b] The same Charm taken twice is held
## twice - [method get_count] - and nothing here ever refuses one.
##
## [b]It holds Charms, it does not play them.[/b] Anything a Charm does later
## listens to [signal charm_added] or asks [method get_count].

## Emitted once a Charm has been added, with how many of it are now worn.
signal charm_added(charm: CharmDefinition, count: int)
## Emitted whenever the Charms change, including being cleared.
signal charms_changed

## The run's state - the [code]RunSession[/code] autoload - listened to for the
## moments the Charms are taken off.
@export var session_path: NodePath = ^"/root/RunSession"

## Every Charm worn, in the order it was added. A Charm taken twice is in here
## twice.
var _charms: Array[CharmDefinition] = []


func _ready() -> void:
	var session := get_node_or_null(session_path)
	if session == null:
		return
	if session.has_signal(&"run_began") and not session.is_connected(&"run_began", _on_run_began):
		session.connect(&"run_began", _on_run_began)
	if session.has_signal(&"run_ended") and not session.is_connected(&"run_ended", clear):
		session.connect(&"run_ended", clear)


## The holder in this tree, or null when the autoload is missing.
static func get_active(from_node: Node) -> RunCharmHolder:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().root.get_node_or_null(^"Charms") as RunCharmHolder


## Adds one [param charm]. Returns whether it went - always, for a real Charm.
func add_charm(charm: CharmDefinition) -> bool:
	if charm == null:
		return false
	_charms.append(charm)
	charm_added.emit(charm, get_count(charm))
	charms_changed.emit()
	return true


## Every Charm worn, in order. A copy, so a readout cannot edit it.
func get_charms() -> Array[CharmDefinition]:
	return _charms.duplicate()


## Each different Charm worn once, in the order it was first taken - what a
## readout draws one icon per.
func get_kinds() -> Array[CharmDefinition]:
	var kinds: Array[CharmDefinition] = []
	var seen: Array[StringName] = []
	for charm: CharmDefinition in _charms:
		if charm != null and not seen.has(_key(charm)):
			seen.append(_key(charm))
			kinds.append(charm)
	return kinds


## How many copies of [param charm] are worn, matched by [member CharmDefinition.id].
func get_count(charm: CharmDefinition) -> int:
	if charm == null:
		return 0
	var count := 0
	for held: CharmDefinition in _charms:
		if held != null and _key(held) == _key(charm):
			count += 1
	return count


func get_total() -> int:
	return _charms.size()


## Takes every Charm off.
func clear() -> void:
	if _charms.is_empty():
		return
	_charms.clear()
	charms_changed.emit()


func _on_run_began(_map_id: StringName) -> void:
	clear()


func _key(charm: CharmDefinition) -> StringName:
	return charm.id if charm.id != &"" else StringName(charm.resource_path)
