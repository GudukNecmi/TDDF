class_name BanditIdentity
extends Node
## The name a Bandit is known by - what a nearby friend screams when he sees
## this man die and flies into a rage over it.
##
## [b]It holds exactly one fact and does nothing with it.[/b] Every Bandit is
## dressed with a name from [constant NAMES] the moment he is built, the same way
## [BanditAppearance] dresses him with a face - and like that draw, it is never
## read by the man carrying it. [EnemyEnrage] is the one reader, reaching for
## [method name_for] on whichever man has just died so the friend enraged by it
## has something specific to shout - see that class's own
## [method EnemyEnrage._make_him_shout].
##
## [b]Left empty, one is drawn at ready.[/b] [member name_callout] can be authored
## by hand - a boss's own men, say, all sharing one specific roster - but an
## ordinary Bandit built by the spawner is simply handed the next random name, so
## adding this component costs nothing anywhere a name has not been chosen on
## purpose.

## The forty names a Bandit might be known by.
const NAMES: PackedStringArray = [
	"JOOOHN!!!", "JAAACK!!!", "WILLIAAAM!!!", "THOMAAAS!!!", "SAMUUUEL!!!",
	"HEEENRY!!!", "CHARAALES!!!", "JAAAMES!!!", "JEEESSE!!!", "BIIILLY!!!",
	"FRAAANK!!!", "WYAAATT!!!", "ARTHUUUR!!!", "COOOLE!!!", "CLIIINT!!!",
	"ROOOY!!!", "HAAANK!!!", "JOOOE!!!", "LUUUKE!!!", "AMOOOS!!!",
	"DUUUTCH!!!", "HOOOSEA!!!", "BIIILL!!!", "JAVIEEER!!!", "MICAAAH!!!",
	"LEEENNY!!!", "SEAAAN!!!", "KIERAAAN!!!", "COOOLM!!!", "TRELAWNY!!!",
	"JOSIAAAH!!!", "STRAUUUSS!!!", "PEAARSON!!!", "SWAAANSON!!!", "HAMIIISH!!!",
	"FLAAACO!!!", "GAVIIIIN!!!", "SEAAAMUS!!!", "TAAAVISH!!!", "WINTON!!!",
]
## The same forty, as they are said rather than screamed - in the same order, so
## entry [i]n[/i] here is entry [i]n[/i] of [constant NAMES]. Read by
## [method spoken_name] for the quiet line an enraged man says as he dies.
const SPOKEN_NAMES: PackedStringArray = [
	"John", "Jack", "William", "Thomas", "Samuel",
	"Henry", "Charles", "James", "Jesse", "Billy",
	"Frank", "Wyatt", "Arthur", "Cole", "Clint",
	"Roy", "Hank", "Joe", "Luke", "Amos",
	"Dutch", "Hosea", "Bill", "Javier", "Micah",
	"Lenny", "Sean", "Kieran", "Colm", "Trelawny",
	"Josiah", "Strauss", "Pearson", "Swanson", "Hamish",
	"Flaco", "Gavin", "Seamus", "Tavish", "Winton",
]

## The name the last man to go berserk screamed, so the next one never screams the
## same. Shared by every [EnemyEnrage] in the game - see [method draw_rage_name].
static var _last_rage_name: StringName = &""
## What is left of the current shuffled pass through [constant NAMES]. A bag rather
## than an independent roll each time, so the same few names cannot cluster.
static var _rage_bag: Array[StringName] = []

## This Bandit's own name. Left empty, [method _ready] draws one at random.
@export var name_callout: StringName = &""


func _ready() -> void:
	if name_callout == &"":
		name_callout = NAMES[randi() % NAMES.size()]


## [param enemy]'s own name, or an empty string when he carries no
## [BanditIdentity] at all - a Bomber, say, which [EnemyEnrage] reads as "no name
## to shout" rather than as an error.
##
## Named [code]name_for[/code] rather than [code]get_name[/code] - [Node] already
## owns that one for its own node name, and shadowing it is refused by the
## compiler.
static func name_for(enemy: Node) -> StringName:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return &""
	var identity := enemy.get_node_or_null(^"BanditIdentity") as BanditIdentity
	return identity.name_callout if identity != null else &""


## The name a man going berserk screams, for the whole of his rage.
##
## [param preferred] is the dead friend's own name - see [method name_for] - and is
## kept whenever it can be. It is refused only when it is the name the previous
## enraged man screamed, because two in a row shouting the same name is the one
## thing that must never happen; a random one is drawn instead.
##
## [b]Random, but not streaky.[/b] Drawn names come out of a shuffled pass through
## all forty - every name once before any comes round again - and a name equal to
## the one just used is stepped past at the seam between passes. So the draw is
## random, never repeats back to back, and cannot fall into the short loops an
## independent roll each time produces.
static func draw_rage_name(preferred: StringName = &"") -> StringName:
	var chosen := preferred
	if chosen == &"" or chosen == _last_rage_name:
		chosen = _draw_from_bag()
	else:
		# Kept out of the current pass, so the friend's name is not drawn again for
		# somebody else a moment later.
		_rage_bag.erase(chosen)
	_last_rage_name = chosen
	return chosen


static func _draw_from_bag() -> StringName:
	if _rage_bag.is_empty():
		for callout: String in NAMES:
			_rage_bag.append(StringName(callout))
		_rage_bag.shuffle()
	# The back of the bag is what is drawn. A name matching the last one is stepped
	# past, which only ever happens at a reshuffle's seam.
	for i: int in range(_rage_bag.size() - 1, -1, -1):
		if _rage_bag[i] != _last_rage_name:
			var picked := _rage_bag[i]
			_rage_bag.remove_at(i)
			return picked
	# The only name left is the one just used: start a fresh pass and draw from it.
	_rage_bag.clear()
	return _draw_from_bag()


## [param callout] as it is said rather than screamed - [code]ARTHUUUR!!![/code]
## becomes [code]Arthur[/code]. Looked up in [constant SPOKEN_NAMES]; a name
## authored by hand outside the pool is simply stripped of its exclamation marks.
static func spoken_name(callout: StringName) -> String:
	var index := NAMES.find(String(callout))
	if index >= 0 and index < SPOKEN_NAMES.size():
		return SPOKEN_NAMES[index]
	return String(callout).replace("!", "").strip_edges().capitalize()
