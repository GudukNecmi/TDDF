class_name WaveRoster
extends Node
## What a wave is made of, as opposed to how large it is.
##
## [b]It never touches the wave count.[/b] [WaveManager] works out how many
## enemies wave N is worth exactly as it always has - the base count, the
## per-wave multiplier and the round's own growth - and then hands that number
## here to be filled in. This returns one entry per body, and a null entry means
## "the spawner's own enemy", which is why Bandit remains the dominant population
## without appearing in the list at all.
##
## Every type is one [WaveRosterEntry] in [member entries]. Adding a third enemy
## is dropping a resource in beside the second; there is no name, no threshold and
## no branch here that a new type would have to be written into.

## The types mixed into a wave, in the order they are considered. Earlier entries
## claim their places first, which only matters on a wave too small for both.
@export var entries: Array[WaveRosterEntry] = []

@export_group("Debug")
## Prints what each wave was composed of. Off by default; it is here because the
## mix is random and a run is the only way to see whether it feels right.
@export var log_composition: bool = false


## The bodies wave [param wave_number] is made of, one per enemy, [param count]
## long. A null in the returned array is the spawner's own enemy scene.
##
## Safe to call with an empty roster, which returns a wave of nulls - exactly the
## wave the game spawned before any of this existed.
func build_wave(wave_number: int, count: int) -> Array[PackedScene]:
	var plan: Array[PackedScene] = []
	plan.resize(maxi(count, 0))
	if plan.is_empty():
		return plan

	# Free places rather than a search: an entry takes slots off this list, so two
	# entries can never be handed the same one and the last entry cannot be starved
	# by an unlucky run of collisions.
	var free_slots: Array[int] = []
	for i: int in plan.size():
		free_slots.append(i)

	for entry: WaveRosterEntry in entries:
		if entry == null or entry.scene == null:
			continue
		var wanted := mini(count_for(entry, wave_number, plan.size()), free_slots.size())
		for i: int in wanted:
			var pick := randi() % free_slots.size()
			plan[free_slots[pick]] = entry.scene
			free_slots.remove_at(pick)
		if log_composition and wanted > 0:
			var label := entry.display_name if not entry.display_name.is_empty() \
				else entry.scene.resource_path.get_file()
			print("[WaveRoster] wave %d: %d x %s of %d" % [wave_number, wanted, label, count])

	return plan


## How many of [param entry] wave [param wave_number] gets out of
## [param wave_size]. Public so the mix can be asserted without spawning anything.
##
## The three rules are applied in the order the brief states them: the ordinary
## mix, then the burst that may replace it, then the guarantee that may raise
## either.
func count_for(entry: WaveRosterEntry, wave_number: int, wave_size: int) -> int:
	if entry == null or wave_size <= 0 or wave_number < entry.first_wave:
		return 0

	var wanted := _mixed_in(entry, wave_number, wave_size)
	if _is_burst(entry, wave_number):
		wanted = maxi(wanted, randi_range(
			maxi(entry.burst_min, 0), maxi(entry.burst_max, entry.burst_min)))
	if _is_guaranteed(entry, wave_number):
		wanted = maxi(wanted, maxi(entry.guaranteed_minimum, 0))

	return clampi(wanted, 0, wave_size)


## The ordinary share, with the leftover fraction rolled rather than dropped - so
## a one-in-six entry really is one in six over a run rather than one in eight.
##
## [b]The share grows with the wave number, and the count falls out of the wave's
## own size.[/b] What is worked out here is a fraction - the entry's starting
## share plus [member WaveRosterEntry.share_growth_per_wave] for every wave since
## it was first allowed - and that fraction is then applied to the count the wave
## already had. So a wave of a hundred and a wave of three are filled by the same
## rule, the type turns up gradually more often as the round goes on, and there is
## no wave number or fixed figure written anywhere for a new type to have to be
## added to.
func _mixed_in(entry: WaveRosterEntry, wave_number: int, wave_size: int) -> int:
	var share := share_of_wave(entry, wave_number)
	if share <= 0.0:
		return 0

	var raw := float(wave_size) * share
	var whole := int(floor(raw))
	if randf() < raw - float(whole):
		whole += 1

	# The ceiling is on the mix only. A guarantee and a concentrated attack are both
	# deliberate exceptions to "this type never dominates a wave".
	return mini(whole, int(floor(float(wave_size) * entry.max_fraction)))


## What fraction of wave [param wave_number] this entry is worth, before the wave's
## size is applied to it. Public arithmetic kept in one place so the progression can
## be read - or asserted - without a wave being built.
func share_of_wave(entry: WaveRosterEntry, wave_number: int) -> float:
	if entry == null or wave_number < entry.first_wave:
		return 0.0

	var base := 0.0
	if entry.one_per_enemies > 0:
		base = 1.0 / float(entry.one_per_enemies)

	var waves_in := maxi(wave_number - entry.first_wave, 0)
	var grown := base + maxf(entry.share_growth_per_wave, 0.0) * float(waves_in)
	return clampf(grown, 0.0, maxf(entry.max_fraction, 0.0))


func _is_burst(entry: WaveRosterEntry, wave_number: int) -> bool:
	if entry.burst_chance <= 0.0 or wave_number < entry.burst_first_wave:
		return false
	return randf() < entry.burst_chance


func _is_guaranteed(entry: WaveRosterEntry, wave_number: int) -> bool:
	if entry.guarantee_every_waves <= 0:
		return false
	return wave_number % entry.guarantee_every_waves == 0
