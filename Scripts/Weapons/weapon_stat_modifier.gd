class_name WeaponStatModifier
extends Resource
## One change to one weapon stat: which [enum WeaponStats.Stat] it moves and by
## how much.
##
## The unit is the stat's own - a fraction for the percentage stats (0.1 is +10%),
## whole rounds for magazine size and ammo capacity. A [WeaponUpgrade] applies its
## modifiers once per level bought; a card or a unique weapon upgrade later is the
## same resource summed into the same [WeaponStats].

@export var stat: WeaponStats.Stat = WeaponStats.Stat.DAMAGE
## How much one application adds.
@export var amount: float = 0.1
## What the stat is called on a card: "DAMAGE", "CRIT CHANCE".
@export var label: String = "DAMAGE"
## The player-facing Turkish line on a reward card: [code]%s[/code] is the amount,
## written by [method format_card_amount] - "Hasarını %s artırır." reads
## "Hasarını %40 artırır." at four applications of +10%.
@export var card_text: String = ""


## The amount in Turkish card style for [param times] applications: "%40" for a
## percentage stat, "8" for a count. No sign - the sentence says which way.
func format_card_amount(times: float = 1.0) -> String:
	var total := absf(amount * times)
	if WeaponStats.is_percent(stat):
		return "%%%d" % roundi(total * 100.0)
	return str(roundi(total))


## The card line for [param times] applications, or empty when none is authored.
func describe_card(times: float = 1.0) -> String:
	if card_text.is_empty():
		return ""
	return card_text % format_card_amount(times)


## "+10%" or "+2", for [param times] applications.
func format_amount(times: float = 1.0) -> String:
	var total := amount * times
	var prefix := "+" if total >= 0.0 else "-"
	if WeaponStats.is_percent(stat):
		return "%s%d%%" % [prefix, roundi(absf(total) * 100.0)]
	return "%s%d" % [prefix, roundi(absf(total))]
