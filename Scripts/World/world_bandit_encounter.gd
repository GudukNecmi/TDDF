class_name WorldBanditEncounter
extends RefCounted
## What a [WorldBandit] contact was worth, at the moment it happened.
##
## A snapshot, not a state - [WorldMapCombatBridge] builds one as it opens a
## fight and hands it out on [signal WorldMapCombatBridge.encounter_started]
## for anything else that wants to know what is being fought without asking
## the bridge for its own private fields. Nothing here decides how large the
## fight is; [member group_strength] is read exactly as [WorldBandit] carried
## it, for [WorldMapCombatBridge]'s own smallest-adapter conversion into an
## enemy count - see that class's doc.
##
## [b]It does not outlive the fight it describes.[/b] The bridge drops its own
## reference the moment the encounter ends, win or lose, so nothing is holding
## a stale payload open once the man it names is queued for freeing.

## The [WorldBandit] this encounter came from. May already be freed by the time
## anything downstream reads it back out - it is queued for freeing the instant
## the fight is won - so a caller wanting to know whether it is still around has
## to check [method @GlobalScope.is_instance_valid] itself.
var bandit: WorldBandit
## [member WorldBandit.group_strength], read once as the fight opened.
var group_strength: float = 0.0
## [member WorldBandit.region_id] at the moment of contact - the desert region
## the fight is nominally happening in, for whatever later phase wants to size
## or reward an encounter by where it was picked.
var region_id: StringName = &""
## Where the player was standing on the World Map when contact was made - the
## exact point [WorldMapCombatBridge] returns them to when the fight is over.
var world_position: Vector2 = Vector2.ZERO
## What kind of encounter this is. Always [code]&"bandit"[/code] today - a
## World Map crossing a moving group - kept as a field rather than assumed so a
## later encounter source (an ambush laid rather than walked into, say) can
## fill the same payload without [WorldMapCombatBridge] growing a second shape
## of result.
var encounter_type: StringName = &"bandit"
## [method WorldTimeManager.get_world_day] at the moment contact was made -
## together with [member world_degree], the encounter's own copy of "what
## time was it out here", read once as the fight opened rather than asked of
## the clock again later, since the clock is frozen for the fight's whole
## length anyway. Kept for whatever later replaces the Arena rectangle with a
## Combat Map that actually looks like the place and hour the player was
## standing in - see rule 14 of the World Map -> Combat integration pass. 0
## for a world with no clock to ask.
var world_day: int = 0
## [method WorldTimeManager.get_world_degree] at the same instant.
var world_degree: float = 0.0
