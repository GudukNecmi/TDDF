class_name WorldBountyEncounter
extends RefCounted
## What a [WorldBountyBoss] contact was worth, at the moment the fight opened.
##
## The bounty-boss twin of [WorldBanditEncounter] - see that class's own doc
## for why this is a plain snapshot rather than a state, and for the promise
## it makes that a later encounter source can fill "the same payload" rather
## than [WorldMapCombatBridge] growing a second shape of result. This is that
## second source: [method WorldMapCombatBridge.try_begin_boss_encounter]
## builds one as the fight opens and hands it out on
## [signal WorldMapCombatBridge.boss_encounter_started], for anything that
## wants to know what is being fought without reaching into the bridge's own
## private fields.
##
## [b]It does not outlive the fight it describes.[/b] The bridge drops its
## own reference the moment the encounter ends, win or lose, the same
## discipline [WorldBanditEncounter] holds itself to.

## The contract this fight is over.
var bounty: Bounty
## The [WorldBountyBoss] this encounter came from. May already be marked
## defeated - see [method WorldBountyBoss.mark_defeated] - by the time
## anything downstream reads it back out, so a caller wanting to know
## whether it is still standing has to ask [method WorldBountyBoss.get_state]
## itself rather than assume.
var boss: WorldBountyBoss
## [constant Bounty.CATEGORY_REGION]'s true value at the moment of contact -
## read once, the same way [member WorldBanditEncounter.region_id] is.
var region_id: StringName = &""
## [member MapLocation.location_id] of the camp this boss was standing at,
## or empty if it had none assigned.
var camp_location_id: StringName = &""
## Where the player was standing on the World Map when the fight opened -
## the exact point [WorldMapCombatBridge] returns them to when it is over.
var world_position: Vector2 = Vector2.ZERO
## Always [code]&"bounty_boss"[/code] today - kept as a field, exactly as
## [member WorldBanditEncounter.encounter_type] is, rather than assumed.
var encounter_type: StringName = &"bounty_boss"
## The world day and degree [WorldTimeManager] was showing as the fight
## opened - the bounty-boss twin of [member WorldBanditEncounter.world_day]
## and [member WorldBanditEncounter.world_degree]; see those fields' own doc.
var world_day: int = 0
var world_degree: float = 0.0
