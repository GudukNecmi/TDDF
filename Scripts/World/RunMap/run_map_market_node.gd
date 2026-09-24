class_name RunMapMarketNode
extends RunMapSaloonNode
## The run map's market points: what happens when the piece arrives on one.
##
## [b]It is [RunMapSaloonNode], pointed at a different screen.[/b] A market is
## walked into exactly the way a saloon is - a screen raised over the board, the
## map's roads closed underneath it until the player leaves, the piece never
## moving - and walked back into through the same re-entry seam
## ([member RunMapSiteKind.re_enterable] on the market's kind). So every line of
## that is inherited, and the only difference is which screen it raises: a
## [RunMapMarketScreen], found by its own group when [member screen_path] is not
## set, never the saloon's. The inherited [signal saloon_entered] and
## [signal saloon_left] fire for a market's arrival and departure.
##
## Set [member kinds] to [code][&"market"][/code] and [member screen_path] to the
## market screen on the node in the scene.


func _resolve_screen() -> RunMapSaloonScreen:
	if _screen != null and is_instance_valid(_screen):
		return _screen
	_screen = get_node_or_null(screen_path) as RunMapMarketScreen
	if _screen == null:
		_screen = RunMapMarketScreen.get_active_market(self)
	return _screen
