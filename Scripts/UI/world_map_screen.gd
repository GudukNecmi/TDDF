class_name WorldMapScreen
extends Control
## The map the player pulls out of their saddlebag: the current region drawn as
## a map, with what they know of it marked on it. Opened with M through
## [WorldMapOverlayMenu], which is also the MAP tab of that same screen.
##
## [b]It is a map, not a second camera.[/b] What stood here before was a
## [SubViewport] with a [Camera2D] in it pointed at the running scene and
## following the player - the minimap's own technique at a wider zoom - which
## meant it could only ever show whatever happened to be around the player at
## that moment, always with the player in the middle of it. That is exactly what
## a map is not: this draws the region's [i]authored ground plan[/i], the whole
## of it at once, and marks the places on it. Where the player is standing is
## deliberately not on it anywhere.
##
## [b]The ground comes from the one plan everything else is built from.[/b]
## [method TerrainMasses.get_active_shape] hands over the very [TerrainShape]
## the map's collision, its navigation mesh and its scenery clearances are all
## built from - see that resource's own class doc - so the shape of the desert on
## the map is by construction the shape of the desert the player is riding
## through. Nothing here traces, samples or approximates the world a second time,
## and re-drawing a region's outlines updates the map with no work here at all.
##
## [b]What is marked is [MapKnowledge] and nothing else.[/b] A place the player
## has never heard of is not on the map; one they have only been told about is a
## question mark at the right spot with no name and no icon; one they have
## actually ridden to gets its own marker and its own name. This screen never
## asks [WorldMapFog] anything, never measures a distance and never decides what
## counts as found - see [method WorldMapLocation._record_discovery], which is
## the one place that answers that, off the fog the player is actually looking
## through.
##
## [b]Only DustCamp is authored, but nothing here is DustCamp.[/b] The region,
## its ground plan, its locations and their names are all read out of whichever
## region scene is currently built, so the other four regions draw themselves the
## moment their own locations are authored with the same data - there is no
## region name, no id and no rectangle anywhere in this file.

## Where the region's own name is read from - the same autoload every other World
## Map system asks which region is being played.
@export var world_state_path: NodePath = ^"/root/WorldState"
## Margin left around the drawn map inside this panel, in pixels.
@export var map_padding: float = 28.0

@export_group("Wording")
## Printed above the map when there is a region to name. [code]%s[/code] is the
## region's own full label - see [method MapRegion.get_full_label].
@export var title_format: String = "%s"
## Printed instead when there is no region to draw - a screen opened somewhere
## the world has not told anything about.
@export var no_region_text: String = "NO MAP"
## What a place the player has only heard of is drawn as. The same question mark
## every wanted poster already prints for a line that has not been learned.
@export var unknown_marker_text: String = "?"
## The line under the map explaining the question marks. Emptied, no legend is
## drawn.
@export var legend_text: String = "?  —  HEARD OF, NOT YET FOUND"

@export_group("Colours")
## The rock surrounding the walkable desert, and the ground the map sits on.
@export var surround_color := Color(0.16, 0.12, 0.10)
## The walkable desert itself - the parchment the map is really drawn on.
@export var ground_color := Color(0.80, 0.69, 0.49)
## The rock masses standing inside the desert.
@export var rock_color := Color(0.36, 0.27, 0.21)
## The line drawn around the whole map.
@export var border_color := Color(0.62, 0.18, 0.16)
## Both the ring and the question mark of a place that has only been heard of.
@export var unknown_color := Color(0.38, 0.28, 0.22)
## Drawn behind every marker and every piece of text, so a name over pale sand
## and one over dark rock read the same.
@export var ink_color := Color(0.10, 0.07, 0.05)
## The region's name above the map.
@export var title_color := Color(0.90, 0.32, 0.30)

@export_group("Markers")
## Radius of a marker before its own type's [constant WorldMapLocation.SCALES]
## entry is applied, in pixels.
@export var marker_radius: float = 7.0
## Width of the dark edge drawn around every marker.
@export var marker_edge_width: float = 2.0
## Font size a discovered place's name is printed at.
@export var label_font_size: int = 14
## Font size the question mark inside an undiscovered place's ring is drawn at.
@export var unknown_font_size: int = 17
## Font size the region's name is printed at.
@export var title_font_size: int = 26
## How thick the dark edge behind every piece of text is - see
## [method _draw_text].
@export var text_outline_size: int = 5
## The same edge behind the question mark alone, which is a single glyph inside
## a small ring and closes up into a blob at the width a name wants.
@export var glyph_outline_size: int = 2
## Gap between a marker and the name under it, in pixels.
@export var label_offset: float = 12.0
## Whether discovered places print their names. Off leaves the markers bare.
@export var shows_labels: bool = true

## One place worth drawing: where it is, what it is, what it is called and how
## well it is known. Gathered in [method refresh] rather than read during
## [method _draw], so the screen draws the world as it stood when it was opened
## and a paused game is not walked every redraw.
class Entry:
	var world_position := Vector2.ZERO
	var location_type: MapLocation.LocationType = MapLocation.LocationType.NORMAL_CAMP
	var display_name: String = ""
	var discovered: bool = false

var _entries: Array[Entry] = []
var _shape: TerrainShape
var _region: MapRegion


func _ready() -> void:
	resized.connect(queue_redraw)


## Called by [WorldMapOverlayMenu] each time the MAP tab becomes current. Reading
## the world here rather than every frame is the same discipline every other tab
## of that screen follows: a tab nobody is looking at costs nothing.
func refresh() -> void:
	_shape = TerrainMasses.get_active_shape(self)
	_region = _resolve_region()
	_gather()
	queue_redraw()


## Every place currently worth drawing, for a developer readout and for a
## headless check - so what is on the map can be asserted without a screenshot.
func get_entries() -> Array[Entry]:
	return _entries


func _resolve_region() -> MapRegion:
	var state := get_node_or_null(world_state_path) as WorldMapState
	return null if state == null else state.current_region


## Walks the region's own [WorldMapLocation] nodes - the same ones the player
## rides up to - and keeps the ones [MapKnowledge] says are worth drawing. A
## location the player has never heard of is left out entirely rather than drawn
## and hidden, so there is nothing on the screen to read the map's blank spots
## off.
func _gather() -> void:
	_entries.clear()
	for node: Node in get_tree().get_nodes_in_group(WorldMapLocation.GROUP):
		var location := node as WorldMapLocation
		if location == null or not location.is_enabled():
			continue
		var id := location.get_location_id()
		if not MapKnowledge.is_known(id):
			continue

		var entry := Entry.new()
		entry.world_position = location.location.world_position
		entry.location_type = location.get_location_type()
		entry.display_name = location.get_display_name()
		entry.discovered = MapKnowledge.is_discovered(id)
		_entries.append(entry)


func _draw() -> void:
	var font := get_theme_default_font()
	var title_baseline := _draw_title(font)

	if _shape == null or _shape.bounds.size.x <= 0.0 or _shape.bounds.size.y <= 0.0:
		return

	var legend_room := 0.0 if legend_text.is_empty() else float(label_font_size) * 2.0
	var area := Rect2(
		Vector2(map_padding, title_baseline + map_padding),
		Vector2(
			size.x - map_padding * 2.0,
			size.y - title_baseline - map_padding * 2.0 - legend_room))
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return

	var frame := _fit(_shape.bounds, area)
	_draw_ground(frame)
	for entry: Entry in _entries:
		_draw_entry(entry, _to_screen(entry.world_position, frame), font)
	_draw_legend(font, frame)


## The region's name across the top, and how far down the map may start. Drawn
## even when there is no ground plan to show, so a screen opened where there is
## no map still says so rather than coming up blank.
func _draw_title(font: Font) -> float:
	var text := no_region_text if _region == null else title_format % _region.get_full_label()
	if font == null or text.is_empty():
		return 0.0
	var baseline := map_padding + float(title_font_size)
	_draw_text(font, Vector2(map_padding, baseline), text, title_font_size, title_color)
	return baseline


## Where the region's whole rectangle is drawn, fitted into [param area] with its
## proportions kept - a map stretched to the panel would put the places in the
## wrong spots relative to each other, which is the one thing a map may not do.
func _fit(bounds: Rect2, area: Rect2) -> Rect2:
	var scale := minf(area.size.x / bounds.size.x, area.size.y / bounds.size.y)
	var drawn := bounds.size * scale
	return Rect2(area.position + (area.size - drawn) * 0.5, drawn)


## A point of the world in the panel's own space.
func _to_screen(world_pos: Vector2, frame: Rect2) -> Vector2:
	var bounds := _shape.bounds
	var offset := (world_pos - bounds.position) / bounds.size
	return frame.position + offset * frame.size


## The land itself: rock everywhere, the walkable desert cut out of it, and the
## rock masses standing back inside that - the three layers
## [TerrainMasses] already paints in the world, in the same
## order and off the same outlines.
func _draw_ground(frame: Rect2) -> void:
	draw_rect(frame, surround_color)

	if _shape.walkable_outline.size() >= 3:
		draw_colored_polygon(_project(_shape.walkable_outline, frame), ground_color)
	for mass: PackedVector2Array in _shape.masses:
		if mass.size() >= 3:
			draw_colored_polygon(_project(mass, frame), rock_color)

	draw_rect(frame, border_color, false, 2.0)


func _project(outline: PackedVector2Array, frame: Rect2) -> PackedVector2Array:
	var projected := PackedVector2Array()
	projected.resize(outline.size())
	for index: int in outline.size():
		projected[index] = _to_screen(outline[index], frame)
	return projected


## A discovered place as its own marker and name; one only heard of as a hollow
## ring with a question mark in it. The colour and the size of a real marker are
## read straight off [WorldMapLocation]'s own tables, so the dot on the map is
## the same colour as the icon standing in the world and a place that is retinted
## there is retinted here without this file knowing.
func _draw_entry(entry: Entry, at: Vector2, font: Font) -> void:
	if not entry.discovered:
		draw_arc(at, marker_radius * 1.4, 0.0, TAU, 28, unknown_color, marker_edge_width, true)
		if font != null:
			# A thinner edge than a name gets: a single glyph inside a small ring
			# closes up into a blob at the outline every other piece of text on
			# this screen wants.
			_draw_centred(font, at + Vector2(0.0, float(unknown_font_size) * 0.36),
				unknown_marker_text, unknown_font_size, unknown_color, glyph_outline_size)
		return

	var color: Color = WorldMapLocation.COLORS.get(entry.location_type, Color.WHITE)
	var radius: float = marker_radius * float(WorldMapLocation.SCALES.get(entry.location_type, 1.0))
	draw_circle(at, radius + marker_edge_width, ink_color)
	draw_circle(at, radius, color)

	if shows_labels and font != null and not entry.display_name.is_empty():
		_draw_centred(font, at + Vector2(0.0, radius + label_offset + float(label_font_size)),
			entry.display_name, label_font_size, color)


## The line explaining the question marks, tucked under the map's own bottom-left
## corner rather than the panel's - the panel is far wider than the map it ends
## up drawing, and a legend pinned to its corner reads as belonging to the screen
## behind it rather than to the map.
func _draw_legend(font: Font, frame: Rect2) -> void:
	if font == null or legend_text.is_empty():
		return
	_draw_text(font, Vector2(frame.position.x, frame.end.y + float(label_font_size) * 1.4),
		legend_text, label_font_size, unknown_color)


func _draw_centred(
		font: Font, at: Vector2, text: String, font_size: int, color: Color,
		outline: int = -1) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	_draw_text(font, at - Vector2(width * 0.5, 0.0), text, font_size, color, outline)


## Every piece of text on the map is drawn over its own dark edge, the same way
## the run timer, the blood counter and every other reading in this game's HUD
## are - a name has to stay readable over pale sand and over dark rock both.
func _draw_text(
		font: Font, at: Vector2, text: String, font_size: int, color: Color,
		outline: int = -1) -> void:
	var width := text_outline_size if outline < 0 else outline
	draw_string_outline(
		font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, width, ink_color)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
