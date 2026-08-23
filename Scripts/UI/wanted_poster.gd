class_name WantedPoster
extends PanelContainer
## One sheet of paper on the wanted board: a face, a name, what is known about
## where he is, and what he pays.
##
## The poster owns the whole of its presentation and none of the decisions.
## Pressing TAKE reports [signal accept_requested] and stops there - whether
## there is a free slot, whether the contract is still on the board and what
## locking the reward means all belong to [BountyLedger], exactly the way
## [UpgradeCard] leaves the money to [UpgradeMenu]. That is what keeps one place
## in the game able to say yes.
##
## The face is the outlaw himself rather than a stock portrait: it is printed from
## the wardrobe [MiniBossDirector] will dress the boss out of, keyed by the same
## identity - see [method _print_the_outlaw] and [MiniBossPortrait] - so the man pinned
## to the board is the man who walks out of the region, and he is the same man every
## time the contract is looked at.
##
## The three information lines are built from the knowledge categories it is
## handed rather than authored as three rows, so a fourth kind of knowledge added
## to [BountySettings] appears on every poster with nothing here to change. An
## unknown line prints the category's own question mark, in its own colour, so
## "what you do not know yet" reads at a glance across five posters.

## Emitted when the player asks to take this contract. Whether they can is not
## this node's decision.
signal accept_requested(poster: WantedPoster)

## What the top of the sheet says.
@export var heading_text: String = "WANTED"
## How the price is written. The blood count is substituted in.
@export var reward_format: String = "%d BLOOD"
## What the button reads while the contract can be taken.
@export var accept_text: String = "TAKE"
## What it reads once it has been.
@export var accepted_text: String = "TAKEN"
## What an empty poster - one with no bounty on it - is called.
@export var empty_name: String = "NO NAME"

@export_group("Nodes")
@export var heading_label_path: NodePath = ^"Layout/Heading"
@export var portrait_path: NodePath = ^"Layout/Portrait"
## The outlaw printed out of the wardrobe he is actually dressed from - see
## [MiniBossPortrait]. Optional: a poster without one falls back to
## [member BountyTarget.portrait], exactly as the board did before.
@export var mugshot_path: NodePath = ^"Layout/Portrait/Mugshot"
@export var name_label_path: NodePath = ^"Layout/Name"
@export var crime_label_path: NodePath = ^"Layout/Crime"
@export var facts_box_path: NodePath = ^"Layout/Facts"
@export var reward_label_path: NodePath = ^"Layout/Reward"
@export var accept_button_path: NodePath = ^"Layout/TakeButton"

@export_group("Ink")
## Size the knowledge lines are written at.
@export var fact_font_size: int = 16
## Colour of the category name down the left of each line.
@export var fact_label_colour := Color(0.36, 0.24, 0.14)
## Colour a line is written in once it is known.
@export var fact_known_colour := Color(0.18, 0.1, 0.05)
## Colour of a line that is still a question mark, so an unknown reads as unknown
## rather than as a short answer.
@export var fact_unknown_colour := Color(0.55, 0.4, 0.25)

@export_group("Rarity")
## Whether the sheet is edged in its rung's colour - see [BountyRarity]. What
## makes a legendary readable across the board without the player reading a word
## of it.
@export var show_rarity_outline: bool = true
## How thick that edge is drawn, in pixels, before the rung's own strength is
## applied.
@export var rarity_outline_width: float = 4.0
## How far the glow bleeds past the edge, in pixels.
@export var rarity_glow_size: float = 10.0
## How strong the bled glow is against the edge itself.
@export_range(0.0, 1.0) var rarity_glow_alpha: float = 0.35
## Where the rung's name is printed. Optional - a poster without the label still
## glows.
@export var rarity_label_path: NodePath = ^"Layout/Rarity"

@export_group("Appearance")
## How far the sheet is faded once the contract has been taken, so a poster the
## player already holds is obviously spent.
@export_range(0.0, 1.0) var accepted_alpha: float = 0.42

@onready var _heading: Label = get_node_or_null(heading_label_path) as Label
@onready var _portrait: TextureRect = get_node_or_null(portrait_path) as TextureRect
@onready var _mugshot: MiniBossPortrait = get_node_or_null(mugshot_path) as MiniBossPortrait
@onready var _name: Label = get_node_or_null(name_label_path) as Label
@onready var _crime: Label = get_node_or_null(crime_label_path) as Label
@onready var _facts: Container = get_node_or_null(facts_box_path) as Container
@onready var _reward: Label = get_node_or_null(reward_label_path) as Label
@onready var _accept: Button = get_node_or_null(accept_button_path) as Button
@onready var _rarity_label: Label = get_node_or_null(rarity_label_path) as Label

var _bounty: Bounty
var _categories: Array[BountyKnowledgeCategory] = []
var _rarity: BountyRarity
## The rim drawn in the rung's colour, made once and then recoloured.
var _edge: Panel
## The fainter rim just outside it, which is what reads as a glow.
var _glow: Panel
var _acceptable: bool = true


func _ready() -> void:
	if _accept != null:
		_accept.pressed.connect(_on_accept_pressed)
	_refresh()


## The contract on this sheet. [param categories] is the order the information
## lines are printed in and comes from [BountySettings], so the poster needs no
## idea where the tuning lives.
##
## Re-reading the bounty is hung off its own [signal Bounty.bounty_changed], so a
## line revealed by a later system redraws the poster without anything having to
## remember to ask.
## [param rarity] is the rung the contract was dealt at, handed in for the same
## reason the categories are: the poster prints what it is given rather than going
## looking for the tuning. Null leaves the sheet unedged.
func set_bounty(
	bounty: Bounty,
	categories: Array[BountyKnowledgeCategory],
	rarity: BountyRarity = null
) -> void:
	if _bounty != null and _bounty.bounty_changed.is_connected(_refresh):
		_bounty.bounty_changed.disconnect(_refresh)

	_bounty = bounty
	_categories = categories
	_rarity = rarity
	if _bounty != null:
		_bounty.bounty_changed.connect(_refresh)
	_refresh()


func get_bounty() -> Bounty:
	return _bounty


## Whether this contract can be taken right now. Told to the poster rather than
## worked out by it, because the answer depends on how many slots are free -
## which is the ledger's business, not the sheet's.
func set_acceptable(acceptable: bool) -> void:
	if acceptable == _acceptable:
		return
	_acceptable = acceptable
	_refresh()


func _on_accept_pressed() -> void:
	if _bounty == null or _bounty.accepted:
		return
	accept_requested.emit(self)


## The single place the sheet's look is decided, so the face, the price and the
## button cannot get out of step with each other.
func _refresh() -> void:
	if _heading != null:
		_heading.text = heading_text

	var taken := _bounty != null and _bounty.accepted

	if _name != null:
		_name.text = empty_name
		if _bounty != null and _bounty.target != null:
			_name.text = _bounty.target.display_name

	if _crime != null:
		_crime.text = ""
		if _bounty != null and _bounty.target != null:
			_crime.text = _bounty.target.crime

	var printed := _print_the_outlaw()
	if _portrait != null:
		# The stand-in silhouette only where there is no man to print, so a sheet is
		# never carrying a face and a figure at once.
		_portrait.texture = null
		if not printed and _bounty != null and _bounty.target != null:
			_portrait.texture = _bounty.target.portrait

	if _reward != null:
		_reward.text = reward_format % (0 if _bounty == null else _bounty.reward)

	if _accept != null:
		_accept.text = accepted_text if taken else accept_text
		_accept.disabled = _bounty == null or taken or not _acceptable

	modulate.a = accepted_alpha if taken else 1.0
	_apply_rarity()
	_rebuild_facts()


## The man on the sheet, printed out of the very parts he will be wearing when the
## player meets him. Returns whether there was one to print.
##
## [b]The poster asks the encounter rather than deciding anything.[/b] Both halves of
## the answer - which wardrobe he is dressed from and which outlaw he is, see
## [member MiniBossDirector.wardrobe] and [method MiniBossDirector.look_key_for] - are
## read off the director that will build the body, so there is no second roster and
## nothing for the sheet and the fight to disagree about. The draw itself is a pure
## function of that key (see [method MiniBossWardrobe.indices_for]), which is what
## makes checking the same contract twice print the same man both times without a
## result being stored anywhere.
##
## A world with no director, or a director with no wardrobe, prints nobody and lets
## the sheet fall back on [member BountyTarget.portrait] - so the board is exactly what
## it was before mini bosses had faces rather than being broken by the absence.
func _print_the_outlaw() -> bool:
	if _mugshot == null:
		return false

	var director := MiniBossDirector.get_active(self)
	if _bounty == null or director == null:
		_mugshot.clear()
		return false

	return _mugshot.show_boss(director.wardrobe, director.look_key_for(_bounty))


## The rung, drawn as an edge around the sheet and a word under the heading.
##
## The edge is a copy of whatever stylebox the sheet is already wearing, with its
## border and shadow recoloured - so the paper keeps its authored look and the glow
## is added on top rather than replacing it. Copied rather than edited, because
## that stylebox is shared with every other poster on the board.
func _apply_rarity() -> void:
	if _rarity_label != null:
		_rarity_label.text = "" if _rarity == null else _rarity.display_name
		if _rarity != null:
			_rarity_label.add_theme_color_override(&"font_color", _rarity.outline_colour)

	if not show_rarity_outline:
		return

	# Drawn as its own edge laid over the sheet rather than by recolouring the
	# sheet's stylebox. The paper is a [StyleBoxTexture] - a picture of paper, with
	# no border to colour - so the glow has to be something of its own, and this way
	# it also works for whatever a poster is made of later.
	if _edge == null:
		_edge = Panel.new()
		_edge.name = "RarityEdge"
		_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
		_edge.show_behind_parent = false
		add_child(_edge)

	if _rarity == null or _rarity.outline_strength <= 0.0:
		_edge.visible = false
		if _glow != null:
			_glow.visible = false
		return

	var width := maxi(int(round(rarity_outline_width * _rarity.outline_strength)), 1)
	_edge.add_theme_stylebox_override(&"panel", _rim(_rarity.outline_colour, width, 4))
	_edge.visible = true

	# The bleed is a second, fainter rim sitting just outside the first rather than
	# a stylebox shadow: a shadow is a filled shape drawn behind the box, and behind
	# an unfilled box it washes straight across the paper.
	if _glow == null:
		_glow = Panel.new()
		_glow.name = "RarityGlow"
		_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_glow)
		move_child(_glow, 0)

	var bleed := maxf(rarity_glow_size * _rarity.outline_strength, 0.0)
	if bleed <= 0.0 or rarity_glow_alpha <= 0.0:
		_glow.visible = false
		return

	_glow.offset_left = -bleed
	_glow.offset_top = -bleed
	_glow.offset_right = bleed
	_glow.offset_bottom = bleed
	var faded := Color(
		_rarity.outline_colour.r, _rarity.outline_colour.g, _rarity.outline_colour.b,
		rarity_glow_alpha)
	_glow.add_theme_stylebox_override(&"panel", _rim(faded, int(round(bleed)), 8))
	_glow.visible = true


## An unfilled rounded rim in [param colour]. The poster underneath is what should
## be seen; this only ever draws its edge.
func _rim(colour: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	box.set_border_width_all(maxi(width, 1))
	box.border_color = colour
	box.set_corner_radius_all(radius)
	return box


## One row per category, rebuilt rather than patched. Five posters times three
## lines is fifteen labels - cheap enough that keeping the rows and the
## categories in step is not worth the bookkeeping it would take.
func _rebuild_facts() -> void:
	if _facts == null:
		return

	for child: Node in _facts.get_children():
		_facts.remove_child(child)
		child.queue_free()

	if _bounty == null:
		return

	for category: BountyKnowledgeCategory in _categories:
		if category == null:
			continue
		_facts.add_child(_build_fact_row(category))


func _build_fact_row(category: BountyKnowledgeCategory) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)

	var label := Label.new()
	label.text = category.display_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", fact_font_size)
	label.add_theme_color_override(&"font_color", fact_label_colour)
	row.add_child(label)

	var known := _bounty.is_known(category.category_id)
	var value := Label.new()
	value.text = _bounty.get_fact_text(category.category_id, category.unknown_text)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.add_theme_font_size_override(&"font_size", fact_font_size)
	value.add_theme_color_override(&"font_color", fact_known_colour if known else fact_unknown_colour)
	row.add_child(value)

	return row
