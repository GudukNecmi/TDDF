extends Node
## Turns a state's [member MusicState.shuffle_pool] over on its own, so a
## state built from several tracks - the decision screen's eight-song loop -
## keeps changing songs for as long as it stays the state playing, with no
## caller having to ask again.
##
## [b]A companion, not a rewrite.[/b] Built the same way
## [code]travel_letterbox_gate.gd[/code] sits beside [TravelLetterbox] rather
## than inside it: this only ever asks [MusicStateBoard] for what it already
## exposes publicly - [signal MusicStateBoard.state_entered],
## [method MusicStateBoard.get_player] and [method MusicStateBoard.set_state_track] -
## and the board itself needs no idea this exists. A world with no shuffle
## pool authored on any state plays exactly as it always has; this simply
## never has anything to do.
##
## [b]Why the player's own loop is switched off for a pool.[/b]
## [member MusicState.loops] authored [code]false[/code] on a shuffle state
## leaves [method MusicPlayer._on_finished] doing nothing when the track
## ends, which is what leaves [signal AudioStreamPlayer.finished] free for
## this to answer instead of racing it. See the pool's own [code].tres[/code]
## - the decision state is the one authored this way.
##
## [b]The pick never repeats the track that was just playing.[/b] One
## [VariantPicker] per pool, held here rather than on the resource, with its
## repeat penalty at 0 - "randomize the next track when one ends... do not
## play the same song twice in a row" - so eight songs turn over for as long
## as the decision runs and the same one is never heard back to back.

## The board this watches - the [code]MusicStates[/code] autoload.
@export var states_path: NodePath = ^"/root/MusicStates"

var _board: MusicStateBoard
## state_id -> [VariantPicker], one per pool actually turned over so far.
var _pickers: Dictionary = {}
## state_id -> the [MusicPlayer]'s own [signal AudioStreamPlayer.finished]
## connection, kept so a pool is only ever wired once however many times its
## state is entered.
var _wired: Dictionary = {}


func _ready() -> void:
	_board = get_node_or_null(states_path) as MusicStateBoard
	if _board == null:
		_board = MusicStateBoard.get_active(self)
	if _board == null:
		return
	_board.state_entered.connect(_on_state_entered)


func _on_state_entered(state_id: StringName) -> void:
	var player := _board.get_player(state_id)
	if player == null:
		return

	var pool := _pool_for(state_id)
	if pool.is_empty():
		return

	_wire(state_id, player, pool)
	# The board already started the player on whatever [member MusicState.stream]
	# was left assigned - this restarts it on a fresh, freely-random pick of
	# its own pool instead, so the very first track of a shuffle state is not
	# always the same one. Changing [member AudioStreamPlayer.stream] alone
	# would not be heard until the player is asked to play again, which is
	# why this always restarts rather than only doing so from the second
	# track on.
	_advance(state_id, player, pool)


func _wire(state_id: StringName, player: MusicPlayer, pool: Array) -> void:
	if _wired.get(state_id, false):
		return
	_wired[state_id] = true
	player.finished.connect(_on_track_finished.bind(state_id))


func _on_track_finished(state_id: StringName) -> void:
	var player := _board.get_player(state_id)
	var pool := _pool_for(state_id)
	if player == null or pool.is_empty():
		return
	# Only while this is still genuinely the state sounding - a pool whose
	# state has already been left has nothing left to turn over, and the
	# player's own [signal AudioStreamPlayer.finished] can still arrive a
	# frame after [method MusicStateBoard._stow] has already silenced it.
	if _board.get_state() != state_id:
		return
	_advance(state_id, player, pool)


## Picks the pool's next track and starts it playing from the top - a fresh
## take every time, never a resume, which is what "randomize the next track"
## means for a pool built out of short, otherwise-unrelated loops rather than
## one long piece of music.
func _advance(state_id: StringName, player: MusicPlayer, pool: Array) -> void:
	var picker := _picker_for(state_id, pool.size())
	var index := picker.pick()
	if index < 0 or index >= pool.size():
		return

	var track := pool[index] as AudioStream
	if track == null:
		return

	_board.set_state_track(state_id, track)
	player.play_from(0.0)


func _pool_for(state_id: StringName) -> Array:
	var state := _authored_state(state_id)
	return [] if state == null else state.shuffle_pool


func _authored_state(state_id: StringName) -> MusicState:
	for state: MusicState in _board.states:
		if state != null and state.state_id == state_id:
			return state
	return null


func _picker_for(state_id: StringName, variant_count: int) -> VariantPicker:
	var picker := _pickers.get(state_id) as VariantPicker
	if picker == null:
		picker = VariantPicker.new(variant_count, 1.6, 0.0)
		_pickers[state_id] = picker
	else:
		picker.resize(variant_count)
	return picker
