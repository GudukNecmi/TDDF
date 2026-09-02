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
