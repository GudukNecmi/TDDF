class_name AmmoType
extends Resource
## One kind of ammunition: what it is called, how much of it fits, and what a
## box of it costs.
##
## This is [b]data only[/b]. It describes shells, or rifle rounds, or anything
## added later - it never holds how many the player currently has. That is
## [AmmoReserve], which is created from one of these and kept alive by the
## [code]Ammo[/code] locker. The split is what lets one resource file be shared
## by every weapon that fires the same round while each *weapon* still keeps its
## own count if it uses a round of its own.
##
## Nothing here is shotgun-specific. A weapon points its [WeaponAmmo] at one of
## these in the inspector and inherits its capacity, its starting load, its
## bundle size and its price; a second weapon points at a different one and gets
## completely different numbers without a line of code being written. Adding
## ammunition to the game is dropping a [code].tres[/code] into
## [code]res://Resources/Ammo/[/code].

## Stable identifier, and the key the locker files this ammunition's live count
## under. [b]It must be unique and it must not change[/b] - two ammo types
## sharing an id share a magazine, and renaming one mid-run loses the count kept
## under the old name.
@export var id: StringName = &""
## What one round is called: "Shell", "Rifle Round". Used wherever a single
## round is named.
@export var display_name: String = ""
## What more than one is called: "Shells". Left empty falls back to
## [member display_name] with an "s" on the end, so an ammo type only has to
## fill this in when that would be wrong.
@export var display_name_plural: String = ""
## Picture of the round, for a future ammo readout or shop row. Nothing uses it
## yet.
@export var icon: Texture2D

@export_group("Capacity")
## How many rounds the player can carry before any upgrade. This is the
## *starting* capacity, not a hard ceiling: the base weapon shop raises the live
## capacity through [method AmmoReserve.set_capacity_bonus], which leaves this
## resource untouched, so an upgraded run and a fresh one both read the same
## number from here.
@export var max_ammo: int = 60
## How many rounds the player has the first time this ammunition is ever
## touched. Clamped to the capacity, and only ever applied once - see
## [method create_reserve].
@export var starting_ammo: int = 60

@export_group("Purchase")
## How many rounds one purchase hands over. Buying is by the box, so this is the
## size of the box.
@export var purchase_bundle: int = 10
## What one box costs in blood. [b]The price lives here and nowhere else[/b] -
## the camp's shop will ask the ammunition what it costs rather than carrying a
## price of its own, so re-pricing shells is editing this field.
@export var purchase_cost: int = 10


## The plural name, worked out rather than required. Used by anything printing a
## count.
func get_plural_name() -> String:
	if not display_name_plural.is_empty():
		return display_name_plural
	if display_name.is_empty():
		return String(id)
	return display_name + "s"


## Names [param count] rounds: "1 Shell", "10 Shells".
func format_count(count: int) -> String:
	return "%d %s" % [count, display_name if count == 1 else get_plural_name()]


## What [param bundles] boxes cost. Multiplication lives here rather than in the
## shop so a future bulk discount is a change to this method alone.
func cost_for_bundles(bundles: int) -> int:
	return maxi(bundles, 0) * maxi(purchase_cost, 0)


## How many rounds [param bundles] boxes contain.
func rounds_for_bundles(bundles: int) -> int:
	return maxi(bundles, 0) * maxi(purchase_bundle, 0)


## What [param rounds] loose rounds cost, for the part box a player nearly at
## capacity can still buy - see [method AmmoLocker.purchase_available].
##
## Rounded [i]up[/i], deliberately: a part box is never cheaper per round than a
## full one, so topping up four shells at a time can never be a way of buying
## ammunition at a discount. Like [method cost_for_bundles], the arithmetic lives
## here so a future bulk price is one change in one file.
func cost_for_rounds(rounds: int) -> int:
	var bundle := maxi(purchase_bundle, 0)
	if bundle <= 0:
		return 0
	return ceili(float(maxi(rounds, 0)) * float(maxi(purchase_cost, 0)) / float(bundle))


## A fresh live count of this ammunition, loaded to [member starting_ammo].
##
## Called once per ammo type per session, by the locker. Everything after that
## reads the reserve it made, which is what stops a scene rebuild - or walking
## into the camp - quietly reloading the player's gun.
func create_reserve() -> AmmoReserve:
	return AmmoReserve.new(self)
