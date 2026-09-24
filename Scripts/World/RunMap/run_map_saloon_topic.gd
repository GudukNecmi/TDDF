class_name RunMapSaloonTopic
extends Resource
## One thing the player can ask about at a run map saloon: what the subject is
## called, what asking costs, and what is said back until a real source of that
## information exists.
##
## [b]This is the structure, not the database.[/b] The saloon's information half
## is deliberately built as an empty seam: a topic names a subject and carries a
## line to say when nothing answers it, and whatever eventually knows the answer
## - the bounty log for a wanted man, [MapKnowledge] for a place the sandstorm
## has covered, a run's own record for anything else - answers by listening for
## [signal RunMapSaloonScreen.information_asked] and calling
## [method RunMapSaloonScreen.tell]. Nothing in the screen reads a database, and
## adding the first real answer will add no branch to it either.
##
## [b]Adding a subject is a [code].tres[/code].[/b] One of these per subject goes
## into [member RunMapSaloonScreen.topics]; the screen builds one row per entry
## from the button authored in its own scene, so a fourth subject is a resource
## dropped in the Inspector and no edit to any script.

## The handle a listener matches on to recognise which subject was asked about.
## Never shown to the player.
@export var id: StringName = &""
## What the row asking about this subject says.
@export var label: String = ""
## What asking costs in blood. 0 - the default, and what every subject with only
## a placeholder behind it should be authored at - is a free question. Blood is
## taken as the question is asked, so a subject is only worth charging for once
## something really answers it.
@export var cost: int = 0
## What the bartender says when nothing answered the question. [b]This is what a
## topic is until its real source exists[/b]: a line that tells the player the
## subject is a real one and that there is nothing to tell them yet, rather than
## a silent button.
@export_multiline var placeholder_line: String = ""

@export_group("Pointing somewhere out on the map")
## Which kinds of place asking about this subject can point out, matched against
## [member RunMapSite.kind]. [b]Left empty - the default - the subject points
## nothing out[/b] and stays the pure placeholder described above, which is what
## a subject wants until there is a real source behind it. Listing kinds here
## makes the subject a map reveal: see [RunMapSaloonInformation], which finds
## the nearest point of one of these kinds the player has not learned yet, takes
## the question mark off it, and keeps it known for the rest of the run.
@export var reveals_kinds: Array[StringName] = []
## What the bartender says when a place has been pointed out. [code]%s[/code] is
## what the place is called.
@export_multiline var reveal_line: String = ""
## What the bartender says when there is nothing of this subject's kinds left to
## point out - every one of them already on the player's map. Left empty the
## placeholder line is used instead.
@export_multiline var nothing_left_line: String = ""
