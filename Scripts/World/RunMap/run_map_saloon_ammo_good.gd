class_name RunMapSaloonAmmoGood
extends RunMapSaloonGood
## A box of rounds on a run map saloon's shelf.
##
## [b]It prices and delivers nothing itself.[/b] Every one of the four answers
## is handed to [AmmoLocker], which the camp's own trader already buys through:
## the price comes from [method AmmoLocker.purchase_price], which reads the real
## [AmmoType] and quotes a part box by the round; the refusal comes from
## [method AmmoLocker.can_purchase_available]; and the purchase itself is
## [method AmmoLocker.purchase_available], which takes the blood through
## [method BloodWallet.spend] and only ever charges for rounds it actually hands
## over. Retuning what a shell is worth is therefore still one number on one
## [AmmoType] and this shelf follows it.
##
## [b]The locker is an autoload, which is why a saloon can sell at all.[/b] The
## run map is a board with no player body standing on it - no [Health], no
## [RunInventory], both of which live on [Player] in a scene that is not open -
## so the two things a purchase made here can land in are the blood wallet and
## the ammunition locker, and both survive the map being opened and closed.

## Which round this sells. Without one the row is shown and refuses every press.
@export var ammo_type: AmmoType
## How many boxes one press buys. The box's size is the [AmmoType]'s own
## [member AmmoType.purchase_bundle], not a number kept here.
@export var bundles: int = 1
## Where the locker is. The autoload, on every map.
@export var locker_path: NodePath = ^"/root/Ammo"


## The round's own plural name when this good was not given one, so a box of
## shells is not named twice.
func get_label(_from: Node) -> String:
	if not display_name.is_empty():
		return display_name
	return "" if ammo_type == null else ammo_type.get_plural_name()


func get_price(from: Node) -> int:
	var locker := _locker(from)
	if locker == null:
		return 0
	return locker.purchase_price(_reserve(from), maxi(bundles, 1))


func can_buy(from: Node) -> bool:
	var locker := _locker(from)
	if locker == null:
		return false
	return locker.can_purchase_available(_reserve(from), maxi(bundles, 1))


func buy(from: Node) -> bool:
	var locker := _locker(from)
	if locker == null:
		return false
	return locker.purchase_available(_reserve(from), maxi(bundles, 1)) > 0


## How many rounds a press would actually hand over - the whole box, or only
## what is left to fill. For a row that would rather read "4 ROUNDS" than "1
## BOX"; nothing requires it.
func rounds_offered(from: Node) -> int:
	var locker := _locker(from)
	if locker == null:
		return 0
	return locker.purchasable_rounds(_reserve(from), maxi(bundles, 1))


## The reserve this round is kept in, made by the locker the first time it is
## asked for - so a saloon can sell a round the player has never carried.
func _reserve(from: Node) -> AmmoReserve:
	var locker := _locker(from)
	if locker == null or ammo_type == null:
		return null
	return locker.get_reserve(ammo_type)


func _locker(from: Node) -> AmmoLocker:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_node_or_null(locker_path) as AmmoLocker
