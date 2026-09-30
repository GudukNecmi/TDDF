class_name LootRewardLook
extends Resource
## How one kind of reward is drawn on the Loot Screen's table - its heading, its
## colours, its icon, and optionally the card scene it is dealt as.
##
## [b]This is the only place a kind of reward is told apart visually.[/b]
## [LootScreen] never asks what a reward is; it asks the reward for its look and
## deals whatever card that look names - [member card_scene], or the screen's own
## default card when it is left empty. A new kind of reward is a new
## [code].tres[/code] of this, and a reward that needs a card of its own (a
## charm, a question-mark card, a gem) names that scene here rather than being
## branched on anywhere.

## A handle for the kind, for readouts and smoke checks - never read by the
## screen to decide anything.
@export var kind: StringName = &""
## The kind's heading on its card, e.g. "WEAPON UPGRADE".
@export var label: String = ""
## Drawn on the card face. Optional: a card with none shows only its lettering.
@export var icon: Texture2D

@export_group("Colours")
## The card face.
@export var face_color: Color = Color(0.16, 0.1, 0.08, 1)
## The card's border and heading.
@export var accent_color: Color = Color(0.82, 0.12, 0.1, 1)
## The card's main lettering.
@export var text_color: Color = Color(0.92, 0.87, 0.8, 1)

@export_group("Card")
## The card this kind is dealt as. Empty uses [member LootScreen.default_card_scene].
## Whatever scene is named here must have a [LootRewardCard] (or a subclass) at
## its root.
@export var card_scene: PackedScene
## How an amount above one is written: [code]%d[/code] is the amount.
@export var amount_format: String = "x%d"
