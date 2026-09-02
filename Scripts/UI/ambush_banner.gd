class_name AmbushBanner
extends Control
## The one line of warning a World Map ambush shows: "AMBUSH", up for as long
## as [WorldMapAmbushDirector] says one of its three groups is still closing
## in, and nothing else.
##
## [b]It knows nothing about bandits, distances or probability.[/b] The
## director alone decides when a group is ambushing and when the player has
## gotten away; this only answers [method show_banner] and
## [method hide_banner], the same "raised and lowered by whoever owns the
## moment" split every other screen in the project already keeps - see
## [InteractionPrompt] and [LoadingCurtain] for the identical shape.
##
## Sits under [RunHUD]'s own [CanvasLayer], the same layer 2 every other run
## screen already draws on, so it composites under [FilmPostProcess] exactly
## like [WorldBanditDecisionMenu] and [TravelLetterbox] beside it - nothing
## here asks for a layer, a shader or a shape of its own.

## Group this joins, so [WorldMapAmbushDirector] can find the one banner in
## the world even without a path across the scene - the fallback its own
## [method _resolve_banner] uses.
const GROUP := &"ambush_banner"

@export var label_path: NodePath = ^"Label"
## How long the word takes to fade up and back down.
@export var fade_time: float = 0.25
## How large the pulse swings the word's scale, as a fraction either way.
@export var pulse_scale: float = 0.06
## Pulses per second while the banner is up.
@export var pulse_speed: float = 1.4

@onready var _label: Control = get_node_or_null(label_path) as Control

var _shown: bool = false
var _time: float = 0.0
var _fade_tween: Tween


func _ready() -> void:
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	set_process(false)


## Raises the banner. Guarded, so a director that calls this every frame an
## ambush is active - it does not - would still cost nothing extra.
func show_banner() -> void:
	if _shown:
		return
	_shown = true
	_time = 0.0
	visible = true
	set_process(true)
	_fade_to(1.0)


## Lowers the banner. Safe to call on one already down.
func hide_banner() -> void:
	if not _shown:
		return
	_shown = false
	set_process(false)
	_fade_to(0.0)


func is_banner_shown() -> bool:
	return _shown


func _process(delta: float) -> void:
	if _label == null:
		return
	_time += delta
	var t := 1.0 + sin(_time * pulse_speed * TAU) * pulse_scale
	_label.scale = Vector2.ONE * t


func _fade_to(alpha: float) -> void:
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", alpha, fade_time)
	if alpha <= 0.0:
		_fade_tween.tween_callback(hide)
