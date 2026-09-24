class_name RunMapSaloonGood
extends Resource
## One thing a run map saloon sells: what it is called, how many of it are on
## the shelf, and - in a subclass - what buying it actually does.
##
## [b]A good owns its whole transaction.[/b] The screen asks what a row costs,
## whether it can be bought, and then tells it to sell itself; it never touches
## a wallet, a reserve or an inventory on a good's behalf. That is what lets
## each good be priced and delivered by whatever system already owns it -
## [RunMapSaloonAmmoGood] hands both jobs to [AmmoLocker], which already prices
## a box from its own [AmmoType] and already takes the blood - rather than this
## file growing a second set of prices beside the real ones.
##
## [b]Adding a kind of goods is a subclass; adding an item is a
## [code].tres[/code].[/b] The shop's stock is an array of these on
## [member RunMapSaloonScreen.goods] and nothing in the screen names a single
## one, so a second round type on the shelf is a resource dropped in the
## Inspector. A good that is not ammunition at all - a bed, a drink, a rumour
## sold by the bottle - is a new script extending this one, overriding the four
## methods below, and no edit to the screen.
##
## [b]The base class sells nothing.[/b] It answers "free, unavailable, refused"
## to everything, so a good left as a bare [RunMapSaloonGood] shows on the shelf
## greyed out instead of taking the player's blood for nothing.

## What the row says. Left empty a subclass may name itself from whatever it
## sells - see [method get_label].
@export var display_name: String = ""
## A short second line under the name, for a good that wants one. Optional.
@export var note: String = ""
## Picture for the row. Left null the row is lettering only.
@export var icon: Texture2D
## How many of this may be bought in one visit to a saloon. -1 is no limit,
## which is what a good the player's own capacity already limits wants: a box of
## rounds cannot be over-bought because the reserve fills up.
@export var stock: int = -1


## What the row is called. Overridden by a good that would rather name itself
## from what it sells than have the name written twice.
func get_label(_from: Node) -> String:
	return display_name


## What buying one costs in blood right now, asked of whichever system prices
## it. Live rather than authored, so a good sold by the part box can show the
## real price of the part.
func get_price(_from: Node) -> int:
	return 0


## Whether buying one right now would hand anything over and can be paid for.
## False greys the row rather than hiding it, so the player can see what a
## saloon carries even when they cannot take it.
func can_buy(_from: Node) -> bool:
	return false


## Buys one: charges for it and delivers it, through whatever system owns both.
## Answers whether anything actually changed hands, which is what the screen
## counts against [member stock].
func buy(_from: Node) -> bool:
	return false


## Whether [param bought] purchases have used this good up for the visit.
func is_sold_out(bought: int) -> bool:
	return stock >= 0 and bought >= stock
