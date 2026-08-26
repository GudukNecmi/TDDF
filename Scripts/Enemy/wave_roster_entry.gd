class_name WaveRosterEntry
extends Resource
## One enemy type's standing orders for how often it turns up in a wave.
##
## [b]It is a share of the wave, not a wave of its own.[/b] Everything here is
## measured against the count [WaveManager] has already decided on - the run's
## existing curve is untouched - so an entry can only ever change [i]what[/i] the
## wave is made of, never how large it is. Whatever is not claimed by an entry is
## the spawner's own [member EnemySpawner.enemy_scene], which is why Enemy1 stays
## the dominant enemy without being listed anywhere.
##
## The three ways a type can appear are deliberately separate numbers rather than
## one rule, because the brief asks for three different feelings and they have to
## be tunable apart from each other:
##
##   * [member one_per_enemies] is the ordinary mix - "roughly one bomber for
##     every six men" - and it is what most waves get.
##   * [member guarantee_every_waves] is the promise - "every fourth wave has at
##     least one" - and it only ever raises a wave that the mix left short.
##   * [member burst_chance] is the occasional concentrated attack - five or six
##     of them together - and it replaces the ordinary mix on the waves it hits.
##
## A second enemy type is another one of these dropped into
## [member WaveRoster.entries]. There is no name, threshold or branch anywhere in
## the roster that a new entry would have to be added to.

## The body this entry spawns. An entry with none is skipped entirely.
@export var scene: PackedScene
## What this type is called in the inspector and in a debug read-out. Cosmetic.
@export var display_name: String = ""

@export_group("Ordinary mix")
## One of these per this many enemies on the first wave they may appear on. 6 is
## "about one in six", which for a wave of twelve is two of them. It is the share
## the progression below starts from, not the share for the whole run.
##
## [b]The fraction is kept rather than thrown away.[/b] A wave of eight at one in
## six is worth 1.33 of them, and the third of an enemy left over is rolled - so
## small waves get one some of the time instead of never, and the long-run ratio
## is the one written here rather than a heavily rounded-down version of it.
##
## 0 switches the ordinary mix off, leaving only the guarantee and the burst.
@export var one_per_enemies: int = 6
## How much larger this type's share of a wave gets with every wave after
## [member first_wave], as a fraction of the wave.
##
## [b]This is the whole of the progression, and it is a ratio rather than a
## count.[/b] The share on the first wave this type may appear on is
## [member one_per_enemies]; every wave after that adds this on top, and the
## result is multiplied by whatever count [WaveManager] has already decided the
## wave is worth - so the type gets gradually more common as the round goes on
## without a single wave number, threshold or fixed figure being written down
## anywhere. A wave of a hundred and a wave of three are filled by the same
## fraction.
##
## 0 keeps the ratio flat for the whole run, which is what it was before any of
## this, so an entry that does not want to grow simply leaves it alone.
##
## It is capped by [member max_fraction] like the rest of the ordinary mix, which
## is what stops a long enough round turning into nothing but this type.
@export_range(0.0, 0.5, 0.001) var share_growth_per_wave: float = 0.0
## First wave this type may appear on at all. Keeps a nastier body out of the
## opening moments of a round.
@export var first_wave: int = 1
## The most of the wave this type may ever take, as a fraction, so the ordinary
## enemy is never replaced by this one however the numbers above are tuned. The
## burst is exempt - it is the deliberate exception - and so is
## [member guaranteed_minimum].
@export_range(0.0, 1.0) var max_fraction: float = 0.35

@export_group("Guarantee")
## Every this many waves, at least [member guaranteed_minimum] of these appear
## whatever the mix rolled. 4 is "every fourth wave". 0 promises nothing.
@export var guarantee_every_waves: int = 4
## How many the guarantee is worth. It is a floor, not a replacement: a wave whose
## ordinary mix already asked for more keeps the larger number.
@export var guaranteed_minimum: int = 1

@export_group("Concentrated attack")
## Chance a qualifying wave is a burst of this type instead of an ordinary mix,
## 0 to 1. 0 switches bursts off.
@export_range(0.0, 1.0) var burst_chance: float = 0.16
## How many turn up in one, rolled between the two.
@export var burst_min: int = 5
@export var burst_max: int = 6
## First wave a burst may land on. Later than [member first_wave] on purpose: a
## concentrated attack is a thing the round builds up to.
@export var burst_first_wave: int = 4
