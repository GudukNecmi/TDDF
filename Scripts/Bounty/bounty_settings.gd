class_name BountySettings
extends Resource
## Every number the bounty system has, and the one place a bounty is made.
##
## This is the tuning resource: how many posters the board carries, how many
## contracts the player may hold, what each rung of knowledge is worth, what the
## reward is rounded to, which outlaws exist and which kinds of information there
## are. All of it is inspector fields on a single [code].tres[/code], so the
## economy is retuned without opening a script.
##
## It also owns generation, because generation is nothing but those numbers
## applied: pick an outlaw, pick where and when he is, decide how much of that
## the poster gives away, and price it off that count. Keeping the roll here
## rather than in the board or the ledger is what stops a second place ever
## inventing a bounty by different rules.
##
## [b]Nothing here knows about the desert.[/b] Maps come from the shared
## [MapCatalog] the run portal already uses, regions and hours come from whatever
## [MapDefinition] was picked, and a category with no roster to draw on falls
## back to the lists below. A forest that gets unlocked later starts appearing on
## posters with no edit to this file.

## The kinds of information a bounty can carry, in the order they are printed.
## [b]The number of them is the maximum knowledge a bounty can have[/b] - three
## today, and a fourth is one more entry here plus one more reward tier.
@export var knowledge_categories: Array[BountyKnowledgeCategory] = []
## Which end of the band each knowledge count leans towards. One tier per count -
## see [BountyRewardTier], whose range is read as a lean rather than as a fence.
@export var reward_tiers: Array[BountyRewardTier] = []
## Least a contract can pay, in blood. The bottom of the band every poster is rolled
## from, whoever it is on and wherever he is hiding.
@export var reward_minimum: int = 500
## Most a contract can pay. The top of the same band.
##
## [b]It is one band, not a range per place.[/b] Every part of the desert can print a
## poster worth anything between the two, so a price cannot be read backwards into a
## region - the country only decides what is [i]likely[/i], never what is possible.
## See [method roll_reward].
@export var reward_maximum: int = 2000
## How rare a contract at each knowledge count is: its odds, the slots it may
## hang in and the colour it glows. One rung per count - see [BountyRarity].
##
## [b]The board is dealt from these.[/b] While this is empty the board falls back
## to [member knowledge_weights] and fills every slot, which is what it did before
## rarity existed; with rungs in it, slots can come up empty and the rarer of two
## contracts competing for one wins.
@export var rarities: Array[BountyRarity] = []
## What rewards are rounded to. 100 gives 1600 and 1800 and never 1637.
@export var reward_step: int = 100

@export_group("What a contract leans towards")
## How much the part of the map the outlaw is hiding in pulls the price, against how
## much the poster giving itself away does. 0 leaves the price entirely to knowledge,
## as it was before the desert was divided up; 1 leaves it entirely to the country.
##
## Read against [member MapRegion.difficulty], so the quiet end of a map leans cheap
## and its deadliest corner leans rich, and a map divided into nine parts works the
## same way as one divided into five with nothing here to change.
@export_range(0.0, 1.0, 0.01) var region_reward_influence: float = 0.45
## How hard a lean is. 1 is no lean at all - every price in the band equally likely,
## everywhere. 2.6 is roughly "the favoured half comes up two and a half times as
## often", and the disfavoured end is still rolled.
@export var reward_bias_strength: float = 2.6

@export_group("Board")
## How many posters are pinned up at once.
@export var poster_count: int = 5
## How many contracts the player may hold at a time.
@export var active_slots: int = 5
## Whether taking a poster down puts a fresh one up in its place.
##
## [b]Off.[/b] A poster taken is a gap on the board, and the gap is meant to stay
## there: bare slots are only dealt into when the player next comes home - see
## [method BountyLedger.refill_board] - so what is on offer is a consequence of what
## has already been taken rather than an endless supply. Turning it on restores the
## older behaviour, where the board always carried [member poster_count].
@export var refill_board_on_accept: bool = false
## Front half of a generated bounty's id. The rest is a running number, so ids
## are unique for as long as the session lasts.
@export var id_prefix: String = "bounty"

@export_group("Contents")
## The outlaws that can be wanted.
@export var targets: Array[BountyTarget] = []
## Where bounties can send the player. The same catalogue the map selection menu
## reads, so the two can never disagree about which maps exist.
@export var map_catalog: MapCatalog
## Whether only maps that can actually be played are used. On - which is what a
## board with one map built wants - every poster is a desert poster until the
## forest is unlocked. Off starts advertising ground that is not finished yet.
@export var only_unlocked_maps: bool = true
## Region names used for a map that lists none of its own. See
## [member MapDefinition.regions], which is where a map that has been divided up
## keeps the real thing.
##
## Deliberately bare names rather than [MapRegion] resources: this is the answer
## for a place nobody has divided up yet, so there is nothing for a poster to
## print but a letter, and nothing for the player to be offered on the selection
## screen at all.
@export var fallback_regions: Array[StringName] = [&"A", &"B", &"C", &"D"]
## Hours used for a map that lists none of its own. See
## [member MapDefinition.day_stages].
@export var fallback_day_stages: Array[DayStage] = []

@export_group("Knowledge")
## How likely a generated bounty is to come with 0, 1, 2 ... pieces of
## information already on it, as relative weights read in that order. The
## default leans blind, because a blind contract is the one that pays.
##
## Weights past the end of the list count as 1, and a list of all zeroes leaves
## every bounty blind.
@export var knowledge_weights: Array[float] = [0.35, 0.3, 0.25, 0.1]


## The category with [param category_id], or null when there is none.
func get_category(category_id: StringName) -> BountyKnowledgeCategory:
	for category: BountyKnowledgeCategory in knowledge_categories:
		if category != null and category.category_id == category_id:
			return category
	return null


## The outlaw with [param target_id], or null when the roster has none by that
## name. What a restored contract finds its face again with.
func find_target(target_id: StringName) -> BountyTarget:
	if target_id == &"":
		return null
	for target: BountyTarget in targets:
		if target != null and target.target_id == target_id:
			return target
	return null


## How many pieces of knowledge a bounty can hold at most. However many
## categories there are - not a 3 written down anywhere.
func get_max_knowledge() -> int:
	var count := 0
	for category: BountyKnowledgeCategory in knowledge_categories:
		if category != null:
			count += 1
	return count


## How many contracts may be held at once, never below one.
func get_active_slots() -> int:
	return maxi(active_slots, 1)


## The rung a contract generated with [param knowledge_count] pieces belongs to,
## or null when the rungs do not cover that count.
func find_rarity(knowledge_count: int) -> BountyRarity:
	for rarity: BountyRarity in rarities:
		if rarity != null and rarity.knowledge_count == knowledge_count:
			return rarity
	return null


## Whether the board should be dealt by rarity at all. False while no rungs are
## authored, which leaves the older behaviour - every slot filled - in place.
func has_rarities() -> bool:
	for rarity: BountyRarity in rarities:
		if rarity != null:
			return true
	return false


## Rolls one rung against the odds. Null only when there are none.
func roll_rarity() -> BountyRarity:
	var total := 0.0
	for rarity: BountyRarity in rarities:
		if rarity != null:
			total += maxf(rarity.weight, 0.0)
	if total <= 0.0:
		return null

	var roll := randf() * total
	for rarity: BountyRarity in rarities:
		if rarity == null:
			continue
		roll -= maxf(rarity.weight, 0.0)
		if roll <= 0.0:
			return rarity
	return null


## Deals a whole board: one candidate rolled per slot, each sent to a slot its own
## rung allows, and the rarer of any two that land on the same one kept.
##
## [b]Slots are allowed to come up empty[/b], and that is the point of dealing it
## this way rather than filling five posters. A board where two rolls collide
## prints four contracts, and the one the player can see is the rarer of the pair -
## so a legendary never loses its place to a common, and a thin board reads as the
## week having been quiet rather than as something having gone wrong.
##
## Returns which knowledge count belongs in each slot, keyed by slot number
## counting from 1. A slot missing from the dictionary stays bare.
func roll_board_slots(slot_count: int) -> Dictionary[int, int]:
	var filled: Dictionary[int, int] = {}
	if slot_count <= 0 or not has_rarities():
		return filled

	var winners: Dictionary[int, BountyRarity] = {}
	for _attempt: int in range(slot_count):
		var rarity := roll_rarity()
		if rarity == null:
			continue

		var slots := rarity.get_slots(slot_count)
		if slots.is_empty():
			# A rung whose slots are all off the end of this board simply does not
			# get printed, rather than being forced somewhere it does not belong.
			continue

		var slot: int = slots[randi() % slots.size()]
		var standing: BountyRarity = winners.get(slot)
		if standing == null or rarity.outranks(standing):
			winners[slot] = rarity

	for slot: int in winners:
		filled[slot] = winners[slot].knowledge_count
	return filled


## The tier a bounty with [param knowledge_count] pieces leans by, or null when the
## tiers do not cover that count.
func find_tier(knowledge_count: int) -> BountyRewardTier:
	for tier: BountyRewardTier in reward_tiers:
		if tier != null and tier.knowledge_count == knowledge_count:
			return tier
	return null


## The bottom of the band, in blood, whichever way round the two are authored.
func get_reward_minimum() -> int:
	return mini(reward_minimum, reward_maximum)


## The top of it.
func get_reward_maximum() -> int:
	return maxi(reward_minimum, reward_maximum)


## Where in the band a knowledge count sits, from 0 at the cheap end to 1 at the
## rich one - the middle of its tier's own range, measured against the band.
##
## [b]This is what "the less you know, the more it pays" now means.[/b] The tiers'
## numbers are unchanged and still say exactly what they said: a blind contract is a
## 1500-2000 contract. What has changed is that they lean the roll rather than fence
## it, so a well-read poster can still turn out to be worth a fortune - it simply
## rarely is. A count with no tier authored leans nowhere and is rolled evenly.
func get_knowledge_centre(knowledge_count: int) -> float:
	var tier := find_tier(knowledge_count)
	if tier == null:
		return 0.5

	var low := float(get_reward_minimum())
	var high := float(get_reward_maximum())
	if high <= low:
		return 0.5

	var middle := float(tier.min_reward + tier.max_reward) * 0.5
	return clampf((middle - low) / (high - low), 0.0, 1.0)


## Rolls what a contract is worth: anything in the band, leaning towards the end its
## knowledge count and its country point at.
##
## [param region_difficulty] is [method MapRegion.get_difficulty] for the part of the
## map the outlaw is hiding in - 0 at the map's way in, 1 at its deadliest corner.
## Left at 0.5 the country says nothing and the lean is knowledge's alone, which is
## what a map nobody has divided up produces.
##
## [b]Every price is possible everywhere.[/b] The lean is an exponent on an even
## roll, so it bends how often a price comes up and never what the band contains -
## region A can print a 2000-blood poster and region E a 500-blood one. That is
## deliberate and is the whole reason it is written this way: a player who could read
## the region off the price would never need to buy the region line.
##
## Rolled in whole steps rather than rolled freely and rounded afterwards, so the two
## ends of the band are as likely as everything between them rather than half as
## likely.
func roll_reward(knowledge_count: int, region_difficulty: float = 0.5) -> int:
	var step := maxi(reward_step, 1)
	var lowest := ceili(float(get_reward_minimum()) / float(step))
	var highest := floori(float(get_reward_maximum()) / float(step))
	if highest <= lowest:
		# A band too narrow to hold a whole step at all. Rounded rather than
		# refused, so an oddly tuned band still pays something sensible.
		return snappedi(get_reward_minimum(), step)

	var centre := lerpf(
		get_knowledge_centre(knowledge_count),
		clampf(region_difficulty, 0.0, 1.0),
		clampf(region_reward_influence, 0.0, 1.0))
	# Above 1 the roll is pulled towards the cheap end, below it towards the rich -
	# and at 1, dead centre, it is not pulled at all.
	var lean := pow(maxf(reward_bias_strength, 1.0), 1.0 - centre * 2.0)
	var along := pow(randf(), lean)
	return int(round(lerpf(float(lowest), float(highest), along))) * step


## How much a new poster gives away, rolled against [member knowledge_weights]
## and clamped to however many categories there are.
func roll_knowledge_count() -> int:
	var highest := get_max_knowledge()
	if highest <= 0:
		return 0

	var total := 0.0
	for count: int in range(highest + 1):
		total += _get_weight(count)
	if total <= 0.0:
		return 0

	var roll := randf() * total
	for count: int in range(highest + 1):
		roll -= _get_weight(count)
		if roll <= 0.0:
			return count
	return highest


## Builds one bounty, priced off however much of itself it gives away.
##
## [param bounty_id] is handed in rather than invented here, because uniqueness
## is the ledger's business - it is the thing that knows what has already been
## generated.
##
## [param knowledge_count] below 0 - the default - rolls how much the poster gives
## away, which is what a board dealt without rarity does. A board dealt by rarity
## has already decided, and hands the answer in.
func create_bounty(bounty_id: StringName, knowledge_count: int = -1) -> Bounty:
	var bounty := Bounty.new()
	bounty.bounty_id = bounty_id
	bounty.target = _pick_target()

	var map := _pick_map()
	# Where he is hiding is settled once, before the lines are written, because two
	# things now read it: the region line itself, and the price. Rolling it inside the
	# line would leave the poster naming one part of the desert and the reward leaning
	# towards another.
	var region := _pick_region(map)
	var facts: Array[BountyFact] = []
	for category: BountyKnowledgeCategory in knowledge_categories:
		if category == null:
			continue
		facts.append(_build_fact(category, map, region))
	bounty.facts = facts

	_reveal_starting_knowledge(bounty, knowledge_count)
	# Remembered as it was dealt, because rarity is decided once. Learning where
	# the outlaw is later makes a legendary contract easier; it does not make it a
	# common one, any more than it changes what it pays.
	bounty.generated_knowledge = bounty.get_knowledge_count()
	# Priced last, off what the poster actually ended up showing, so the rule
	# "the reward depends only on how much is known right now" is not a comment -
	# it is the order these two lines are in. The country he is in leans it; see
	# [method roll_reward].
	bounty.reward = roll_reward(
		bounty.get_knowledge_count(),
		0.5 if region == null else region.get_difficulty())
	return bounty


## Turns on a random handful of the bounty's lines. Which ones is deliberately
## unconstrained: one piece of knowledge is one piece whether it is the map, the
## region or the hour.
func _reveal_starting_knowledge(bounty: Bounty, knowledge_count: int = -1) -> void:
	var wanted := knowledge_count if knowledge_count >= 0 else roll_knowledge_count()
	if wanted <= 0:
		return

	var order: Array[BountyFact] = bounty.facts.duplicate()
	order.shuffle()
	for index: int in range(mini(wanted, order.size())):
		var fact := order[index]
		if fact != null:
			fact.known = true


## One line of the poster: the true answer, and no more than that. Whether it is
## shown is decided afterwards.
func _build_fact(
	category: BountyKnowledgeCategory,
	map: MapDefinition,
	region: MapRegion
) -> BountyFact:
	var fact := BountyFact.new()
	fact.category_id = category.category_id

	match category.source:
		BountyKnowledgeCategory.Source.MAP:
			if map != null:
				fact.value_id = map.map_id
				fact.display_text = map.display_name
		BountyKnowledgeCategory.Source.REGION:
			# A map that has been divided up answers with one of its own
			# [MapRegion]s, which is what makes the region a poster names the same
			# object the selection screen offers. The bare letter below is only for
			# a map that has not been divided up yet.
			if region != null:
				fact.value_id = region.region_id
				fact.display_text = region.get_label()
			else:
				var letter := _pick_value(fallback_regions)
				fact.value_id = letter
				fact.display_text = String(letter)
		BountyKnowledgeCategory.Source.TIME_OF_DAY:
			var stage := _pick_day_stage(map)
			if stage != null:
				fact.value_id = stage.stage_name
				fact.display_text = stage.display_name
		BountyKnowledgeCategory.Source.CUSTOM:
			var value := _pick_value(category.custom_values)
			fact.value_id = value
			fact.display_text = String(value)

	return fact


func _pick_target() -> BountyTarget:
	var pool: Array[BountyTarget] = []
	for target: BountyTarget in targets:
		if target != null:
			pool.append(target)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]


## Where the bounty is. Taken from the shared catalogue, so the roster of places
## is the same one the run portal offers.
func _pick_map() -> MapDefinition:
	if map_catalog == null:
		return null

	var pool: Array[MapDefinition] = []
	for map: MapDefinition in map_catalog.maps:
		if map != null and (map.unlocked or not only_unlocked_maps):
			pool.append(map)
	# A catalogue with nothing unlocked still has to produce a poster, so the
	# filter is dropped rather than the bounty being abandoned.
	if pool.is_empty():
		for map: MapDefinition in map_catalog.maps:
			if map != null:
				pool.append(map)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]


## A region of [param map], or null when that map has not been divided up - which
## the caller answers with a letter from [member fallback_regions] instead.
##
## Locked regions are included deliberately: an outlaw can be hiding in a part of
## the map the player cannot travel to yet, and finding that out is information
## worth having. What the player may *pick* is the selection screen's business.
func _pick_region(map: MapDefinition) -> MapRegion:
	if map == null:
		return null

	var pool: Array[MapRegion] = []
	for region: MapRegion in map.regions:
		if region != null:
			pool.append(region)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]


## An hour of [param map], falling back to the shared list for a map with no day
## cycle of its own.
func _pick_day_stage(map: MapDefinition) -> DayStage:
	var pool: Array[DayStage] = []
	if map != null:
		for stage: DayStage in map.day_stages:
			if stage != null:
				pool.append(stage)
	if pool.is_empty():
		for stage: DayStage in fallback_day_stages:
			if stage != null:
				pool.append(stage)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]


func _pick_value(values: Array[StringName]) -> StringName:
	if values.is_empty():
		return &""
	return values[randi() % values.size()]


func _get_weight(count: int) -> float:
	if count < 0 or count >= knowledge_weights.size():
		return 1.0
	return maxf(knowledge_weights[count], 0.0)
