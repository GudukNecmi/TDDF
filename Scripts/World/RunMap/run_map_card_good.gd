class_name RunMapCardGood
extends RunMapSaloonGood
## One [RunCard] on a run map market's shelf.
##
## Priced by the card itself ([member RunCard.price]), paid for in carried blood
## through [BloodWallet] and handed to the [code]RunCards[/code] autoload - see
## [RunCardHolder] - which holds it for the current run only. Nothing here reaches
## the Base's upgrades.
##
## Built by [RunMapMarketProducts] as the shelf is dealt.

## Where carried blood is counted.
@export var wallet_path: NodePath = ^"/root/Blood"
## The run's card holder.
@export var holder_path: NodePath = ^"/root/RunCards"

var card: RunCard
## How the row names it: [code]%s[/code] is the card's name.
var label_format: String = "CARD: %s"


static func create(for_card: RunCard) -> RunMapCardGood:
	var made := RunMapCardGood.new()
	made.card = for_card
	made.display_name = for_card.display_name
	made.note = for_card.description
	made.icon = for_card.icon
	# One slot is one product: once bought it is sold for this shelf.
	made.stock = 1
	return made


## The key a shelf remembers this product by, and the key a refresh excludes.
func get_product_key() -> StringName:
	return product_key(card)


static func product_key(for_card: RunCard) -> StringName:
	return StringName("card:%s" % for_card.id)


func get_label(_from: Node) -> String:
	return label_format % display_name


func get_price(_from: Node) -> int:
	return 0 if card == null else maxi(card.price, 0)


func can_buy(from: Node) -> bool:
	if card == null or _holder(from) == null:
		return false
	var price := get_price(from)
	if price <= 0:
		return true
	var wallet := _wallet(from)
	return wallet != null and wallet.can_afford(price)


func buy(from: Node) -> bool:
	if not can_buy(from):
		return false
	var price := get_price(from)
	var wallet := _wallet(from)
	if price > 0 and (wallet == null or not wallet.spend(price)):
		return false
	if not _holder(from).add_card(card):
		if price > 0:
			wallet.add(price)
		return false
	return true


func _wallet(from: Node) -> BloodWallet:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_node_or_null(wallet_path) as BloodWallet


func _holder(from: Node) -> RunCardHolder:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_node_or_null(holder_path) as RunCardHolder
