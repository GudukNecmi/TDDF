class_name KnowledgeNotice
extends Control
## The line that comes up when the player finds something out: not that they
## learned something, but [i]what[/i].
##
## [b]"+1 KNOWLEDGE" is the thing this exists not to say.[/b] A number going up
## tells the player a transaction happened; the point of the information is that it
## is information, and a contract that was blind a moment ago now says where the
## man is. So the notice names the outlaw and names the answer - "You learned that
## James Balada appears at Twilight." - and the player never has to open the board
## to find out what they were just given.
##
## [b]It is not the surrendered enemy's notice.[/b] It follows
## [signal BountyLedger.knowledge_revealed], which is the one door every piece of
## information in the game arrives by, so a man on the floor talking, a scout, an
## interrogation and a debug key all print through this with nothing added
## anywhere. That is also why it lives on the HUD and not on the thing that paid:
## whoever hands knowledge over should only have to hand it over.
##
## What each kind of knowledge reads like belongs to the kind, not to this - see
## [member BountyKnowledgeCategory.reveal_message] - so a fourth category arrives
## with its own sentence and this file names none of the three.
##
## It is drawn the way [CampPrompt] is, and for the same reason: it is the HUD's
## own bordered dark-red panel with a line of text in it, so a notice looks like
## part of the game rather than like a label somebody left on the screen.

## Emitted as a notice goes up, with the finished line. For a sound to hang off.
signal shown_message(text: String)

## The ledger this listens to.
@export var ledger_path: NodePath = ^"/root/Bounties"
## What is printed for a category that carries no sentence of its own, and for a
## piece of knowledge learned about a contract with no outlaw on it.
## [code]{who}[/code] and [code]{what}[/code] are filled in exactly as they are on
## the categories themselves.
@export var fallback_message: String = "You learned that {who} is at {what}."
## What an outlaw with no name is called, so a contract missing its face still
## produces a sentence rather than a gap.
@export var unknown_target_name: String = "the outlaw"
## Whether the name and the answer are re-cased for a sentence. On: the poster
## keeps its shouted "JAMES BALADA" and "TWILIGHT" and this reads them back as
## "James Balada" and "Twilight", which is what stops the line looking like it was
## pasted out of the board.
@export var sentence_case: bool = true

@export_group("Timing")
## How long the notice fades in and out over.
@export var fade_time: float = 0.22
## How long it stays up once it has arrived. Long enough to be read twice - this is
## the only place the player is told what they learned.
@export var hold_time: float = 4.0

@export_group("Nodes")
## The line of text.
@export var label_path: NodePath = ^"Panel/Body/Label"
## The heading above it. Authored as KNOWLEDGE, which is what a piece of information
## arrives under; anything else borrowing the panel says so for itself - see the
## second argument to [method show_message].
@export var title_path: NodePath = ^"Panel/Body/Title"

@onready var _label: Label = get_node_or_null(label_path) as Label
@onready var _title: Label = get_node_or_null(title_path) as Label

var _ledger: BountyLedger
var _tween: Tween
## What the heading was authored as, so a borrowed notice can be given its own and
## the next piece of knowledge still arrives under the right word.
var _authored_title: String = ""


func _ready() -> void:
	modulate.a = 0.0
	visible = false
	if _title != null:
		_authored_title = _title.text


## The ledger is an autoload and so is always there before the HUD - but the HUD is
## also opened on its own during editing, and a run's world is rebuilt around it, so
## it is looked for until it turns up and this stops running once it has.
func _process(_delta: float) -> void:
	_bind()


func _bind() -> void:
	if _ledger != null and is_instance_valid(_ledger):
		set_process(false)
		return

	_ledger = _get_ledger()
	if _ledger == null:
		return
	_ledger.knowledge_revealed.connect(_on_knowledge_revealed)
	set_process(false)


func _get_ledger() -> BountyLedger:
	return get_node_or_null(ledger_path) as BountyLedger


## Puts a line up. Public so anything with something to say - a night's sleep being
## ruined, a later "he told you nothing" - can use the same panel rather than
## building a second one.
##
## [param heading] gives that line its own word above it; left empty the panel keeps
## the one it was authored with, which is what every piece of knowledge uses. It is
## written on every call rather than only when it changes, so a borrowed notice can
## never leave its heading standing over the next discovery.
func show_message(text: String, heading: String = "") -> void:
	if text.is_empty():
		return

	if _title != null:
		_title.text = _authored_title if heading.is_empty() else heading
	if _label != null:
		_label.text = text
	if _tween != null and _tween.is_running():
		_tween.kill()

	visible = true
	shown_message.emit(text)

	# One tween start to finish, so a second discovery arriving mid-notice replaces
	# the line and restarts the hold rather than stacking two panels or letting the
	# first one's fade take the second one down with it.
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(self, "modulate:a", 1.0, maxf(fade_time, 0.0001))
	_tween.tween_interval(maxf(hold_time, 0.0))
	_tween.tween_property(self, "modulate:a", 0.0, maxf(fade_time, 0.0001))
	_tween.tween_callback(hide)


func _on_knowledge_revealed(bounty: Bounty, category_id: StringName) -> void:
	show_message(compose(bounty, category_id))


## The sentence for one discovery. Separate from showing it so it can be checked
## without a screen, and so anything else that has to word the same fact - a log, a
## camp summary - words it identically.
func compose(bounty: Bounty, category_id: StringName) -> String:
	if bounty == null:
		return ""

	var who := unknown_target_name
	if bounty.target != null and not bounty.target.display_name.is_empty():
		who = bounty.target.display_name

	var fact := bounty.get_fact(category_id)
	# The answer rather than the poster's text for it: the line has just been
	# learned, so there is no question mark to print, but reading the raw field
	# keeps this working for a fact whose display text was never filled in.
	var what := "" if fact == null else fact.display_text
	if what.is_empty():
		what = String(bounty.get_fact_value(category_id))
	# A line with no answer behind it has nothing to announce. It cannot arrive from
	# the ledger, which only reports lines it actually turned on, but a sentence with
	# a hole in it is worse than no notice at all.
	if what.is_empty():
		return ""

	if sentence_case:
		who = who.capitalize()
		what = what.capitalize()

	return _template(category_id).format({"who": who, "what": what})


## The wording for [param category_id], taken from the category itself and falling
## back to the general form - so a category authored without a sentence still says
## something true rather than nothing at all.
func _template(category_id: StringName) -> String:
	var category := _find_category(category_id)
	if category != null and not category.reveal_message.is_empty():
		return category.reveal_message
	return fallback_message


func _find_category(category_id: StringName) -> BountyKnowledgeCategory:
	var ledger := _ledger if _ledger != null else _get_ledger()
	if ledger == null:
		return null
	var settings := ledger.get_settings()
	return null if settings == null else settings.get_category(category_id)
