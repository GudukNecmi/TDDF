class_name BloodStage
extends Resource
## One stage of the player's screen blood: the three frames a single lost heart
## is played through.
##
## The artwork is authored as a set of three - the hit, it running, and what is
## left behind - and keeping the three together in one resource is what lets
## [BloodScreen] hold a plain list of stages. Adding a stage is dropping three
## PNGs into a new entry rather than keeping three parallel arrays in step, and
## nothing anywhere has to be told how many frames a stage has.
##
## Any of the three may be left unset, in which case that beat is simply skipped
## and the sequence carries on to the next one.

## The hit landing - the [code]b[/code] frame.
@export var burst: Texture2D
## The blood running out across the glass - the [code]bb[/code] frame.
@export var spread: Texture2D
## What is left sitting there afterwards - the [code]bd[/code] frame. This is the
## one that stays on screen and eventually blurs away.
@export var settle: Texture2D
