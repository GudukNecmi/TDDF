class_name BountyFact
extends Resource
## One line of a wanted poster: a category, the true answer, and whether the
## player has found it out yet.
##
## [b]The answer is always here.[/b] A bounty knows which map, which region and
## which hour its target is at from the moment it is generated - the outlaw is
## somewhere whether or not anybody has worked out where. What [member known]
## decides is only whether the poster prints the answer or a question mark. That
## is what makes revealing information a single flag rather than a second lookup:
## [method reveal] turns a line on, and nothing has to go and find out what the
## line should say.
##
## It is also why knowledge can only ever be gained. There is no route in this
## class from known back to unknown, and the reward is not stored here at all -
## see [Bounty], which locks it on acceptance.

## What kind of information this is: [code]&"map"[/code], [code]&"region"[/code],
## [code]&"time"[/code]. Matches a [member BountyKnowledgeCategory.category_id].
@export var category_id: StringName = &"category"
## The true answer, as a handle: a map id, a region letter, a day stage name.
## What a later system will match against when it puts the player in front of the
## right boss.
@export var value_id: StringName = &""
## The same answer written out for the poster - "DESERT", "C", "TWILIGHT".
## Stored beside the id rather than looked up, so a poster can be printed without
## reaching for the map catalogue or the map's hours.
@export var display_text: String = ""
## Whether the player has learned this one. False prints
## [member BountyKnowledgeCategory.unknown_text].
@export var known: bool = false


## Marks this line learned and reports whether that was a change, so a caller can
## tell "you found something out" from "you already knew that".
func reveal() -> bool:
	if known:
		return false
	known = true
	return true


## What the poster should print for this line. [param unknown_text] is what an
## unlearned line reads as, and comes from the category rather than from here so
## that all three question marks are one setting.
func get_text(unknown_text: String) -> String:
	return display_text if known else unknown_text


## The line written out for a developer rather than for the player: what is
## printed, and behind it the answer the player has not earned yet.
##
## [b]It deliberately shows the hidden value[/b], which is the whole reason it is
## a separate call from [method get_text] - checking that revealing a line turns
## up the answer that was always there means being able to see that answer before
## it is turned on. Nothing the player looks at may call this.
func describe(unknown_text: String = "?") -> String:
	if known:
		return "%s  [KNOWN]" % get_text(unknown_text)
	if display_text.is_empty():
		return "%s  [UNKNOWN]" % unknown_text
	return "%s  [UNKNOWN - %s]" % [unknown_text, display_text]


## The line flattened to plain values, answer included. [b]The answer is saved
## as well as the flag[/b] - a restored bounty has to be the same contract it was,
## with the outlaw in the same place, and a save that kept only "the region is
## known" would come back knowing a region nobody had decided on.
func to_save_dictionary() -> Dictionary:
	return {
		"category": String(category_id),
		"value": String(value_id),
		"display": display_text,
		"known": known,
	}


## The line rebuilt from [method to_save_dictionary].
static func from_save_dictionary(data: Dictionary) -> BountyFact:
	var fact := BountyFact.new()
	fact.category_id = StringName(data.get("category", ""))
	fact.value_id = StringName(data.get("value", ""))
	fact.display_text = String(data.get("display", ""))
	fact.known = bool(data.get("known", false))
	return fact
