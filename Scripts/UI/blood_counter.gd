class_name BloodCounterLabel
extends Label
## Shows the player's banked blood, and nudges the number whenever more comes in.
##
## It reads [BloodWallet] - the [code]Blood[/code] autoload - and nothing else.
## It never counts anything itself, so it cannot drift from the real total, and
## because the wallet outlives the scene the number is already correct on the
## first frame of a new run rather than counting up from zero.
##
## Driven by [signal BloodWallet.changed] rather than polled every frame, since
## the total only moves when blood is actually banked or spent.

## The wallet this mirrors.
@export var wallet_path: NodePath = ^"/root/Blood"
## Printed before the number. Set to "" for a bare count.
@export var prefix: String = "BLOOD "

@export_group("Pulse")
## How much larger the number gets at the peak of a gain. Kept small - this is a
## nudge, not a jump, and blood arrives in a steady stream.
@export var pulse_scale: float = 1.18
@export var pulse_out_time: float = 0.06
@export var pulse_back_time: float = 0.14

@onready var _wallet: BloodWallet = get_node_or_null(wallet_path) as BloodWallet

var _pulse_tween: Tween


func _ready() -> void:
	_centre_pivot()
	resized.connect(_centre_pivot)

	if _wallet == null:
		text = prefix + "0"
		return

	_wallet.changed.connect(_on_changed)
	_wallet.deposited.connect(_on_deposited)
	_refresh(_wallet.get_total())


## Scaling happens around the middle of the label rather than its top-left
## corner, so a pulse grows the number in place instead of shoving it sideways.
func _centre_pivot() -> void:
	pivot_offset = size * 0.5


func _on_changed(total: int) -> void:
	_refresh(total)


## Only a *gain* pulses. Spending on a future upgrade should not celebrate.
func _on_deposited(_amount: int, _total: int) -> void:
	_play_pulse()


func _refresh(total: int) -> void:
	text = prefix + str(total)


## Restarts from the resting scale every time, so a stream of arriving blood
## cannot stack the pulses or leave the number permanently enlarged.
func _play_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_running():
		_pulse_tween.kill()

	scale = Vector2.ONE
	_pulse_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE * pulse_scale, pulse_out_time) \
		.set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, pulse_back_time) \
		.set_ease(Tween.EASE_IN)
