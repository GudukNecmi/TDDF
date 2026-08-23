class_name BountyEntry
extends PanelContainer
## One contract written out in a list: who it is on, what it pays, how much is
## known about it, and how rare it was.
##
## [b]It is built in code and shared[/b], because two screens show the same thing -
## the list beside the camp's map and the one TAB opens - and a contract that read
## differently in the two would be two ideas of what a bounty is. Both hand this
## the bounty and the tuning; neither knows how a row is laid out.
##
## Everything it prints comes off the bounty itself: the locked reward from
## [member Bounty.reward], the lines from [BountyFact] through
## [method Bounty.get_fact_text] - so an unknown line prints its category's own
## question mark and never the answer behind it - and the rung from
## [method Bounty.get_rarity], which also colours the edge. [b]Nothing here can
## change any of it.[/b] Showing a contract does not reveal it, does not reprice it
## and does not touch what has been learned.
##
## Its look is not authored in a scene: it is created by a list that is itself
## generated, so the colours and sizes are plain fields the list writes before it
## calls [method configure]. Those lists carry the inspector values.

## Emitted when the player asks to give this contract up. Whether they may is not
## this row's decision - see [method BountyLedger.cancel].
signal cancel_requested(bounty: Bounty)

## Colour the outlaw's name is written in.
var name_colour := Color(0.86, 0.78, 0.72)
## Colour of the reward line.
var reward_colour := Color(0.82, 0.1, 0.1)
## Colour of a knowledge line's category.
var label_colour := Color(0.5, 0.36, 0.34)
## Colour a learned line is written in.
var known_colour := Color(0.84, 0.76, 0.73)
## Colour an unlearned line is written in, so a question mark reads as one.
var unknown_colour := Color(0.45, 0.3, 0.3)
var name_font_size: int = 24
var line_font_size: int = 16
## How thick the rung's edge is drawn around the row.
var outline_width: float = 2.0
## Whether the row offers a button to give the contract up.
var show_cancel: bool = false
var cancel_text: String = "GIVE UP"
## Styleboxes the cancel button wears, handed in by the list so every button in
## the game is the same button.
var button_normal: StyleBox
var button_hover: StyleBox
var button_pressed: StyleBox

## How the reward is written: the blood, then the rung.
var reward_format: String = "%d BLOOD   %s"
## How the knowledge count is written.
var knowledge_format: String = "KNOWLEDGE %d / %d"

var _bounty: Bounty


## Fills the row in. Called once by whichever list built it, after that list has
## written its own colours over the defaults above.
func configure(
	bounty: Bounty,
	settings: BountySettings,
	categories: Array[BountyKnowledgeCategory]
) -> void:
	_bounty = bounty
	for child: Node in get_children():
		child.queue_free()
	if bounty == null:
		return

	var rarity := bounty.get_rarity(settings)
	_apply_outline(rarity)

	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 2)
	add_child(body)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override(&"separation", 10)
	body.add_child(heading)

	var who := Label.new()
	who.text = "NO NAME" if bounty.target == null else bounty.target.display_name
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_theme_color_override(&"font_color", name_colour)
	who.add_theme_font_size_override(&"font_size", name_font_size)
	heading.add_child(who)

	if show_cancel:
		var button := Button.new()
		button.text = cancel_text
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override(&"font_size", line_font_size)
		if button_normal != null:
			button.add_theme_stylebox_override(&"normal", button_normal)
			button.add_theme_stylebox_override(&"focus", button_normal)
		if button_hover != null:
			button.add_theme_stylebox_override(&"hover", button_hover)
		if button_pressed != null:
			button.add_theme_stylebox_override(&"pressed", button_pressed)
		button.pressed.connect(_on_cancel_pressed)
		heading.add_child(button)

	# The price and the rung on one line, because the two were decided together and
	# neither moves again.
	var price := Label.new()
	price.text = reward_format % [
		bounty.reward, "" if rarity == null else rarity.display_name]
	price.add_theme_color_override(
		&"font_color", reward_colour if rarity == null else rarity.outline_colour)
	price.add_theme_font_size_override(&"font_size", line_font_size)
	body.add_child(price)

	var count := Label.new()
	count.text = knowledge_format % [bounty.get_knowledge_count(), bounty.get_max_knowledge()]
	count.add_theme_color_override(&"font_color", label_colour)
	count.add_theme_font_size_override(&"font_size", line_font_size)
	body.add_child(count)

	# One line per category, printed the way the poster prints them - what is not
	# known shows the category's own question mark and nothing more.
	for category: BountyKnowledgeCategory in categories:
		if category == null:
			continue
		body.add_child(_build_line(bounty, category))


func get_bounty() -> Bounty:
	return _bounty


func _build_line(bounty: Bounty, category: BountyKnowledgeCategory) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)

	var label := Label.new()
	label.text = category.display_name
	label.custom_minimum_size = Vector2(90.0, 0.0)
	label.add_theme_color_override(&"font_color", label_colour)
	label.add_theme_font_size_override(&"font_size", line_font_size)
	row.add_child(label)

	var known := bounty.is_known(category.category_id)
	var value := Label.new()
	value.text = bounty.get_fact_text(category.category_id, category.unknown_text)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_color_override(&"font_color", known_colour if known else unknown_colour)
	value.add_theme_font_size_override(&"font_size", line_font_size)
	row.add_child(value)

	return row


## The rung's colour, drawn as a thin edge around the row - the same language the
## posters on the board use, so a legendary reads as one wherever it is shown.
func _apply_outline(rarity: BountyRarity) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.02, 0.02, 0.55)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0

	if rarity != null and rarity.outline_strength > 0.0:
		var width := maxi(int(round(outline_width * rarity.outline_strength)), 1)
		box.border_width_left = width
		box.border_width_right = width
		box.border_width_top = width
		box.border_width_bottom = width
		box.border_color = rarity.outline_colour
	add_theme_stylebox_override(&"panel", box)


func _on_cancel_pressed() -> void:
	cancel_requested.emit(_bounty)
