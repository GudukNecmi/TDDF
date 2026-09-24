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


## "+10%" or "+2", for [param times] applications.
func format_amount(times: float = 1.0) -> String:
	var total := amount * times
	var prefix := "+" if total >= 0.0 else "-"
	if WeaponStats.is_percent(stat):
		return "%s%d%%" % [prefix, roundi(absf(total) * 100.0)]
	return "%s%d" % [prefix, roundi(absf(total))]
