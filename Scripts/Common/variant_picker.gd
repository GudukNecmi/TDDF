class_name VariantPicker
extends RefCounted
## Picks one index out of a fixed set, biased away from whatever has been used
## most.
##
## Uniform random is wrong for a crowd: over a hundred enemies it reliably hands
## out one face six times and another once, and the population stops reading as
## varied. A strict rota is wrong the other way - it is perfectly even but the
## order repeats, and a repeating order is exactly what the eye picks up on.
##
## This sits between the two. Every variant carries how many times it has been
## handed out; a pick is a weighted roll where a variant's weight is how far
## *behind* the most-used one it is, raised to [member bias]. Nothing is ever
## impossible, so the order stays unpredictable, but the further a variant falls
## behind the harder it is pulled back, so the counts converge on even. The
## variant that came out last is penalised on top of that, which is what stops
## the same face twice in a row while a set is still evenly matched.
##
## Cost is one pass over the variants per pick and one integer each - nothing is
## remembered per enemy, so this scales to as many of them as the arena can hold.

## How sharply an under-used variant is favoured. 1 makes the pull linear in how
## far behind it is; higher tightens the spread at the cost of predictability.
var bias: float = 1.6
## What the variant handed out last is multiplied by. 0 forbids repeats
## outright; 1 allows them freely.
var repeat_penalty: float = 0.3

var _counts: PackedInt32Array = PackedInt32Array()
var _last: int = -1


func _init(variant_count: int = 0, pick_bias: float = 1.6, penalty: float = 0.3) -> void:
	bias = pick_bias
	repeat_penalty = penalty
	resize(variant_count)


## Number of variants currently being chosen between.
func size() -> int:
	return _counts.size()


## Sets how many variants there are, forgetting the tally if the count changed.
## Called rather than checked by users, so a set that grows between runs simply
## starts even again.
func resize(variant_count: int) -> void:
	var wanted := maxi(variant_count, 0)
	if wanted == _counts.size():
		return
	_counts = PackedInt32Array()
	_counts.resize(wanted)
	_counts.fill(0)
	_last = -1


## One index, or -1 when there is nothing to pick from.
func pick() -> int:
	var count := _counts.size()
	if count <= 0:
		return -1
	if count == 1:
		_counts[0] += 1
		_last = 0
		return 0

	var most := 0
	for i: int in count:
		most = maxi(most, _counts[i])

	# Weight is the deficit against the most-used variant, so an even set gives
	# every variant a weight of one and the roll is plain uniform - the bias only
	# appears once the counts have actually drifted apart.
	var weights := PackedFloat32Array()
	weights.resize(count)
	var total := 0.0
	for i: int in count:
		var weight := pow(float(most - _counts[i] + 1), bias)
		if i == _last:
			weight *= repeat_penalty
		weights[i] = weight
		total += weight

	var chosen := _roll(weights, total)
	_counts[chosen] += 1
	_last = chosen
	_rebase()
	return chosen


## Everything can be zero-weighted only if the penalty is 0 and the set has one
## variant left standing, so the fallback is the last index rather than a
## failure.
func _roll(weights: PackedFloat32Array, total: float) -> int:
	if total <= 0.0:
		return randi() % weights.size()

	var roll := randf() * total
	for i: int in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1


## Only the gaps between the counts matter, so the smallest is subtracted from
## all of them after every pick. The weights are unchanged by that shift and the
## tally can never grow without bound however long a run lasts.
func _rebase() -> void:
	var least := _counts[0]
	for i: int in _counts.size():
		least = mini(least, _counts[i])
	if least <= 0:
		return
	for i: int in _counts.size():
		_counts[i] -= least
