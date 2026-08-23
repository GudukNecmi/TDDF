class_name CampPrompt
extends Control
## The hint in the corner while the player is standing at something they can
## hold a key on, and the bar that fills as they hold it.
##
## It is the same job [InteractionPrompt] does for the blood portal - say that
## something nearby can be used - and it is a separate node for the same reason:
## the thing offering an interaction should only ever report whether it is being
## offered, and where that is drawn is the HUD's business. The difference is only
## that this one has something to say beyond a letter, so it sits in the corner
## with words in it rather than bobbing over the player's head, and it has a hold
## to draw.
##
## [b]It is not the camp's alone.[/b] Everything it follows -
## [signal ArenaPortal.player_entered], [signal ArenaPortal.player_exited] and
## [signal ArenaPortal.hold_changed] - belongs to [ArenaPortal] rather than to any
## one thing that extends it, so the camp's tent and the [HorseCart] at the far
## side of a travel map are both drawn by this same script with nothing but two
## inspector fields between them: which group to follow, and what to say. A third
## held interaction is a third instance of this node, not a third script.
##
## It follows its portal by group, so the HUD is not wired to the world - the same
## arrangement [HeartBar] uses to find the player's health. A world with nothing in
## that group simply never shows this.
##
## Nothing here decides anything. Whether the player is in reach is the portal's
## answer, how far the hold has got is the portal's answer, and this draws both.

## The portal this follows, found by group. The camp joins
## [constant Camp.CAMP_GROUP]; the cart joins [constant HorseCart.CART_GROUP].
@export var source_group: StringName = &"camp"
## What the hint says. The key it names is the portal's own
## [member ArenaPortal.interact_action], so if that is rebound this wants
## rewording with it.
@export var prompt_text: String = "Hold \"E\" for camping"
## Whether the hint hides itself while the screen behind it is up. On - the menu
## says everything the hint was there to say.
@export var hide_while_menu_open: bool = true
## Group the screen this portal opens is found in, so the hint knows which menu
## going up should take it down. Anything with `opened` and `closed` signals
## works; a group with nothing in it simply leaves the hint showing.
@export var menu_group: StringName = &"camp_menu"

@export_group("Nodes")
## The line of text.
@export var label_path: NodePath = ^"Panel/Body/Label"
## The bar that fills as the key is held. Its left edge stays put and its right
## edge is driven, so the fill grows out of the track rather than being resized.
@export var fill_path: NodePath = ^"Panel/Body/Track/Fill"
## The track behind it, hidden along with the fill while nothing is being held.
@export var track_path: NodePath = ^"Panel/Body/Track"

@export_group("Motion")
## How long the hint fades in and out over.
@export var fade_time: float = 0.16
## Whether the track is only shown once a hold has actually started, so the corner
## is a line of text until the player commits to it.
@export var track_only_while_holding: bool = true

@onready var _label: Label = get_node_or_null(label_path) as Label
@onready var _fill: Control = get_node_or_null(fill_path) as Control
@onready var _track: Control = get_node_or_null(track_path) as Control

var _source: ArenaPortal
var _menu: Node
var _shown: bool = false
var _fade_tween: Tween


func _ready() -> void:
	modulate.a = 0.0
	visible = false
	if _label != null:
		_label.text = prompt_text
	_set_progress(0.0)


## The portal may be built - or rebuilt - after the HUD is, and a travel map is
## instanced into the world well after both, so it is looked for until it turns up
## rather than once on ready. Once bound this stops running.
func _process(_delta: float) -> void:
	_bind()


func _bind() -> void:
	if _source != null and is_instance_valid(_source):
		set_process(false)
		return

	_source = get_tree().get_first_node_in_group(source_group) as ArenaPortal
	if _source == null:
		return

	_source.player_entered.connect(_on_player_entered)
	_source.player_exited.connect(_on_player_exited)
	_source.hold_changed.connect(_set_progress)

	_bind_menu()

	# The player can already be standing at it by the time this binds - the camp
	# opens where they are - so the current answer is asked for rather than waited
	# for.
	_set_shown(_source.is_player_in_reach())
	set_process(false)


## The screen going up in front of the hint. Found by group and duck-typed rather
## than named, so the camp's menu and the travel screen are the same arrangement
## and a third one costs nothing.
func _bind_menu() -> void:
	if not hide_while_menu_open:
		return

	_menu = get_tree().get_first_node_in_group(menu_group)
	if _menu == null:
		return
	if _menu.has_signal(&"opened"):
		_menu.connect(&"opened", _on_menu_opened)
	if _menu.has_signal(&"closed"):
		_menu.connect(&"closed", _on_menu_closed)


func _on_player_entered() -> void:
	_set_shown(true)


func _on_player_exited() -> void:
	_set_shown(false)


func _on_menu_opened() -> void:
	_set_shown(false)


func _on_menu_closed() -> void:
	_set_shown(_source != null and is_instance_valid(_source) and _source.is_player_in_reach())


## Whether the hint is up. Guarded, so being told the same thing twice costs
## nothing.
func _set_shown(shown: bool) -> void:
	if shown == _shown:
		return
	_shown = shown

	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()

	if _shown:
		_refresh_text()
		visible = true
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "modulate:a", 1.0, fade_time)
		return

	_set_progress(0.0)
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, fade_time)
	# Hidden at the end of the fade, so a hint nobody is being offered costs
	# nothing to draw.
	_fade_tween.tween_callback(hide)


## The line of text, asked of the portal each time the hint comes up.
##
## [b]Asked rather than fixed[/b], because one portal can offer more than one thing:
## the waggon is held on to make camp and tapped to call the horse back, and it is the
## waggon that knows which of the two it is currently offering. A portal with nothing to
## say - the [HorseCart], anything else held - keeps [member prompt_text], so this costs
## nothing where it is not wanted.
func _refresh_text() -> void:
	if _label == null:
		return
	if _source != null and is_instance_valid(_source) and _source.has_method(&"get_prompt_text"):
		var spoken := String(_source.call(&"get_prompt_text"))
		if spoken != "":
			_label.text = spoken
			return
	_label.text = prompt_text


## The fill, driven by its right anchor rather than by its size, so it grows from
## the left however wide the track happens to be laid out.
func _set_progress(progress: float) -> void:
	var amount := clampf(progress, 0.0, 1.0)
	if _fill != null:
		_fill.anchor_right = amount
	if _track != null and track_only_while_holding:
		_track.visible = amount > 0.0
