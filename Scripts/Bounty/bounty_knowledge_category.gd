class_name BountyKnowledgeCategory
extends Resource
## One kind of thing that can be known about a bounty: which map, which region,
## which hour.
##
## A category is a resource rather than a constant in a script so that the set of
## them is an inspector array on [BountySettings]. "A bounty can have 0-3 pieces
## of knowledge" is not a number written anywhere - it is however many categories
## are in that array, so a fourth kind of information later is dropping a
## [code].tres[/code] file in beside these three, with its own reward tier, and
## nothing in code to tell about it.
##
## [member source] is what keeps that promise. A category does not only name
## itself, it says where its answers come from - the map catalogue, the chosen
## map's regions, the chosen map's hours, or a list typed straight into the
## inspector. A category built on [constant Source.CUSTOM] needs no code at all.

## Where the generator looks for this category's answer.
enum Source {
	## The map itself, taken from [member BountySettings.map_catalog].
	MAP,
	## One of the chosen map's [member MapDefinition.regions].
	REGION,
	## One of the chosen map's [member MapDefinition.day_stages].
	TIME_OF_DAY,
	## One of [member custom_values]. The route a category invented later takes,
	## so a new kind of knowledge needs no new code.
	CUSTOM,
}

## The handle the rest of the game asks by: [code]bounty.is_known(&"region")[/code].
## Never shown to the player.
@export var category_id: StringName = &"category"
## What the poster calls this line. Shown.
@export var display_name: String = "CATEGORY"
## What the poster prints when this piece is still unknown.
@export var unknown_text: String = "?"
## What the player is told when they learn this piece - "You learned that James
## Balada appears at Twilight."
##
## [b]The sentence lives here rather than in the thing that shows it[/b], which is
## the same promise the rest of this resource makes: a fourth kind of knowledge is
## a [code].tres[/code] file, and its sentence comes with it rather than being a
## fourth branch somewhere in the HUD. It also means each kind reads as English -
## a map is somewhere you *are in*, an hour is when you *appear*, and nothing that
## has to say both can say either well.
##
## [code]{who}[/code] is replaced with the outlaw's name and [code]{what}[/code]
## with the answer that was just learned; a sentence naming neither is printed as
## it stands. Left empty, [KnowledgeNotice] falls back to its own wording.
@export_multiline var reveal_message: String = ""
## Where the answers come from.
@export var source: Source = Source.CUSTOM
## The answers, for a [constant Source.CUSTOM] category. Ignored by the other
## three, which have a real roster to draw from.
@export var custom_values: Array[StringName] = []
## Picture shown beside the line, if the poster is given one. Optional - the
## three categories that exist today are text only.
@export var icon: Texture2D
