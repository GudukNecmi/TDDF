class_name LootSource
extends Resource
## One authority over part of what a won encounter pays, adding its rewards to
## the [LootBundle] being built for the Loot Screen.
##
## [b]A kind of reward's rules live in its source, not in the screen.[/b]
## [PostCombatLootDirector] asks every source in its list, in order, and the
## bundle is whatever they added. A source decides for itself whether it pays -
## by the point kind in the [LootContext], by what the fight left behind, by
## what the run is carrying - so no script anywhere branches on which encounter
## was won. A new kind of reward is a new subclass and a [code].tres[/code]
## dropped into [member PostCombatLootDirector.sources].


## Override: add this source's rewards for the fight in [param context] to
## [param bundle]. Adding nothing is always allowed.
func contribute(_bundle: LootBundle, _context: LootContext) -> void:
	pass
