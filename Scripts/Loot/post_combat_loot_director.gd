class_name PostCombatLootDirector
extends Node
## Turns a won fight into a [LootBundle] and puts it on the [LootScreen] before
## the ride back to the run map.
##
## [b]It is the reward authority's front door, not a reward system.[/b] What the
## fight pays is decided by [member sources] - each a [LootSource] holding the
## rules of one part of the reward (the free weapon upgrade, the dropped loot,
## the bounty paid on the kill) - and the screen is handed only the bundle they
## built. Neither this node nor the screen ever asks which kind of encounter was
## won.
##
## [b]It rides on the bridge's existing seams.[/b] A win is heard on
## [signal WorldMapCombatBridge.encounter_ended]; the ride home is held with
## [method WorldMapCombatBridge.hold_the_return] and let go with
## [method WorldMapCombatBridge.let_the_return_go] once the screen is left - so
## the point is cleared, the clock is paid and the player is put back on the same
## node exactly as an unheld win always was. A death is never this node's.
##
## [b]Other post-fight screens step aside by asking it.[/b]
## [method claims_the_win] is a pure question - the Horse Cart asks it rather than
## racing this node for the same signal.

## Emitted once a win's bundle has been put up, with the bundle.
signal bundle_presented(bundle: LootBundle)

const GROUP := &"post_combat_loot_director"

## Master switch. Off leaves every win to whatever handled it before.
@export var enabled: bool = true
## Only fights opened from a run map point are presented - a free-roam fight has
## no node to return to and keeps its own Horse Cart.
@export var run_map_points_only: bool = true
## Every authority over what a win pays, asked in order. See [LootSource].
@export var sources: Array[LootSource] = []
## The screen the bundle is presented on.
@export var screen_path: NodePath = ^"../LootScreen"
## The loading curtain, asked whether the ride home has actually begun.
@export var loading_screen_path: NodePath = ^"/root/LoadingScreen"

var _bridge: WorldMapCombatBridge
var _screen: LootScreen
var _bundle: LootBundle


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_bind_bridge.call_deferred()


func _process(_delta: float) -> void:
	if _bridge == null or not is_instance_valid(_bridge):
		_bind_bridge()


## The director in this scene, or null when it has none.
static func get_active(from_node: Node) -> PostCombatLootDirector:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as PostCombatLootDirector


## Whether the win that is ending right now is this node's to present. Pure - it
## changes nothing - so any listener on [signal WorldMapCombatBridge.encounter_ended]
## may ask it in any order.
func claims_the_win() -> bool:
	if not enabled or _resolve_screen() == null:
		return false
	var bridge := _resolve_bridge()
	if bridge == null:
		return false
	return not run_map_points_only or not bridge.get_site_kind().is_empty()


## The bundle currently on the screen, or null.
func get_bundle() -> LootBundle:
	return _bundle


## Asks every source what a win in [param context] pays.
func build_bundle(context: LootContext) -> LootBundle:
	var bundle := LootBundle.new()
	bundle.context = context
	for source: LootSource in sources:
		if source != null:
			source.contribute(bundle, context)
	return bundle


func _bind_bridge() -> void:
	_bridge = WorldMapCombatBridge.get_active(self)
	if _bridge != null and not _bridge.encounter_ended.is_connected(_on_encounter_ended):
		_bridge.encounter_ended.connect(_on_encounter_ended)


func _on_encounter_ended(victory: bool) -> void:
	if not victory or not claims_the_win():
		return
	var bridge := _resolve_bridge()
	var screen := _resolve_screen()
	if not bridge.hold_the_return(self):
		return

	var context := LootContext.create(self, bridge, bridge.get_site_kind())
	_bundle = build_bundle(context)
	if not screen.finished.is_connected(_on_screen_finished):
		screen.finished.connect(_on_screen_finished, CONNECT_ONE_SHOT)
	if screen.present(_bundle):
		bundle_presented.emit(_bundle)
		return
	# The screen would not open - let the win go home as an unheld one does.
	if screen.finished.is_connected(_on_screen_finished):
		screen.finished.disconnect(_on_screen_finished)
	_bundle = null
	bridge.let_the_return_go()


## Left: home, to the same point. The screen stays up under the curtain so the
## arena is never glimpsed on the way out; with no ride to take (an arena opened
## on its own) it is simply closed.
func _on_screen_finished() -> void:
	_bundle = null
	var bridge := _resolve_bridge()
	if bridge != null:
		bridge.let_the_return_go()
	var curtain := get_node_or_null(loading_screen_path) as LoadingCurtain
	if curtain == null or not curtain.is_loading():
		var screen := _resolve_screen()
		if screen != null:
			screen.close()


func _resolve_bridge() -> WorldMapCombatBridge:
	if _bridge == null or not is_instance_valid(_bridge):
		_bind_bridge()
	return _bridge


func _resolve_screen() -> LootScreen:
	if _screen != null and is_instance_valid(_screen):
		return _screen
	_screen = get_node_or_null(screen_path) as LootScreen
	return _screen
