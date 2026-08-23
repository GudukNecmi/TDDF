class_name DevBalanceStore
extends Node
## Where the developer panel's numbers live between sessions, and the one place
## they are pushed into the game.
##
## The class and the singleton are named apart on purpose, exactly as
## [BloodWallet], [DayClock] and [AmmoLocker] are: a [code]class_name[/code]
## matching an autoload's name shadows it and refuses to compile. Reach the live
## one as [code]DevConfig[/code]; the type is [DevBalanceStore] where a reference
## has to be statically typed.
##
## [b]There are two copies of the balance and they have different jobs.[/b]
##
##   * The [i]authored[/i] one, at [member defaults_path], is a project file and
##     carries only the links - which [AmmoType] and which [ProjectileProfile] each
##     weapon is made of. It holds no numbers worth keeping, because the numbers
##     already live in those resources.
##   * The [i]saved[/i] one, at [member override_path] under [code]user://[/code],
##     is whatever the developer last pressed SAVE on. It is the only thing that
##     survives the game being closed, and deleting the file puts every value back
##     to what the project authored.
##
## On the way up the saved copy is loaded if there is one and applied; if there is
## not, the authored copy captures the live values instead and nothing is changed.
## Either way the panel opens showing exactly what the game is running.
##
## Nothing here knows what a weapon is. It loads a resource, tells it to apply
## itself and writes it back out - what a number *does* is [DevWeaponBalance]'s
## business, which is why adding a tunable value never reaches this file.

## Emitted once new values have actually been pushed into the game, so a readout
## can redraw against them.
signal balance_applied(balance: DevBalance)

## The authored balance: the list of weapons and the resources each is made of.
@export var defaults_path: String = "res://Resources/dev_balance.tres"
## Where a saved override is kept. Under [code]user://[/code] deliberately - it is
## one developer's working numbers, not something the project ships.
@export var override_path: String = "user://dev_balance.tres"
## The ammunition locker, told to re-announce its capacities after a save so a
## readout showing "24 / 40" redraws when the 40 moves.
@export var locker_path: NodePath = ^"/root/Ammo"

var _balance: DevBalance
var _loaded_from_override: bool = false


func _ready() -> void:
	_load()


## The live balance - the numbers the game is currently running on. The panel
## edits a copy of this rather than this itself; see [method DevBalance.working_copy].
func get_balance() -> DevBalance:
	if _balance == null:
		_load()
	return _balance


## Whether the values in play came from a saved override rather than from what the
## project authored. For a panel wanting to say so.
func is_overridden() -> bool:
	return _loaded_from_override


## Takes [param edited] as the new balance, pushes it into the game and writes it
## out. [b]This is the only thing that changes any of these numbers[/b] - the panel
## edits a copy and hands it here, which is what makes typing in a box harmless
## until SAVE is pressed.
##
## Returns whether the write went through. A failed write still applies: the
## developer asked for the numbers now, and losing them at the next launch is the
## lesser of the two failures.
func save(edited: DevBalance) -> bool:
	if edited == null:
		return false

	_balance = edited
	_apply()
	_loaded_from_override = true

	var result := ResourceSaver.save(_balance, override_path)
	if result != OK:
		push_warning("DevBalanceStore could not write %s (error %d)." % [override_path, result])
		return false
	return true


## Loads whichever balance should be in force and puts it into the game.
func _load() -> void:
	_balance = _load_override()
	_loaded_from_override = _balance != null

	if _balance == null:
		_balance = _load_defaults()
		if _balance == null:
			return
		# Nothing has been overridden, so the numbers to show are the ones the
		# project authored - read straight off the resources rather than stored a
		# second time here.
		_balance.capture()
		return

	_apply()


func _load_override() -> DevBalance:
	if not ResourceLoader.exists(override_path):
		return null
	# Cache ignored so a balance saved this session is re-read from the file rather
	# than handed back out of memory.
	var loaded := ResourceLoader.load(
		override_path, "", ResourceLoader.CACHE_MODE_IGNORE) as DevBalance
	if loaded == null:
		push_warning("DevBalanceStore could not read %s - the authored values stand." % override_path)
	return loaded


## Duplicated on the way in, so applying a balance can never write through into the
## project's own [code].tres[/code] on disk.
func _load_defaults() -> DevBalance:
	var authored := load(defaults_path) as DevBalance
	if authored == null:
		push_warning("DevBalanceStore has no authored balance at %s." % defaults_path)
		return null
	return authored.working_copy()


## Pushes the balance into the resources the game reads, then tells the ammunition
## locker that its capacities have moved - a reserve reads its ceiling off the
## [AmmoType] live, so the number is already right, but nothing has announced it
## and a readout would still be showing the old one.
func _apply() -> void:
	if _balance == null:
		return

	_balance.apply()

	var locker := get_node_or_null(locker_path) as AmmoLocker
	if locker != null:
		locker.refresh_capacities()

	balance_applied.emit(_balance)

