class_name BountyBossFateChoice
extends WorldBanditDecisionChoice
## One answer to what is done with a beaten bounty boss - a button on the same
## decision screen a bandit contact is answered on, and what pressing it does.
##
## [b]It is a [WorldBanditDecisionChoice] with the consequences written on it[/b],
## so the three answers live in one [WorldBanditDecisionTier] file that
## [WorldBanditDecisionMenu] shows without knowing it is about a boss. The wording is
## the label, the answer the story remembers is the
## [member WorldBanditDecisionChoice.outcome], and whether he dies of it is
## [member kills] - read by [RunMiniBossFight], which records the answer in the
## [BountyLedger] and nothing else decides it.

## Whether this answer is the end of him. It is what the ledger remembers - see
## [method BountyLedger.was_killed] - and, on, the body on the ground is finished
## off through [BossDefeat]'s own corpse kill.
@export var kills: bool = false
## Whether the gun in the player's hands is heard going off - its own firing
## sound, off its own [SoundBank].
@export var fires_weapon: bool = false
## Recordings played as the answer lands, alongside the gun where it fires. A list,
## so a second sound for an answer is one more entry and nothing else.
@export var sounds: Array[AudioStream] = []
