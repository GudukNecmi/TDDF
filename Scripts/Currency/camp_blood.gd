extends BloodWallet
## The blood stashed at the camps out on the trail.
##
## This is the [i]third[/i] blood total the game keeps, and the split between the
## three is the whole point:
##
##   * [code]Blood[/code] ([BloodWallet]) is CARRIED blood. What the collector's
##     hand picks up in the arena, and what a death spills.
##   * [code]BloodBank[/code] is STORED blood, banked in the base's pool. Safe
##     from everything, and what a future base upgrade is bought with.
##   * [code]CampBlood[/code] (this) is what the player has put into a camp on the
##     way through. Somewhere between the two: out of their hands, so a death
##     cannot spill it, but not home either. It arrives multiplied by the player's
##     streak, exactly as the ride home does - see [method CampMenu.deposit_blood] -
##     because it is a pile leaving their hands for somewhere safe.
##
## [b]How much may go into one camp is not here.[/b] A camp will only take so much
## - see [member CampMenu.camp_blood_capacity] - and that ceiling belongs to the
## camp the player is standing in rather than to the pile the blood ends up in,
## which is what makes "300 per camp" mean per camp rather than per game and what
## lets a later upgrade raise it.
##
## It adds no behaviour of its own, exactly as [BloodBank] does not: every total
## in the game is a [BloodWallet], so one counter script, one transfer primitive
## and one set of signals serve all three, and moving blood between any two of
## them is [method BloodWallet.transfer_to].
##
## It deliberately declares no [code]class_name[/code]: a global class and an
## autoload cannot share a name, and the autoload is the useful one. Anything
## holding a reference types it as [BloodWallet], which is what it is.
