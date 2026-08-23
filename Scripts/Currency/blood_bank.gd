extends BloodWallet
## The blood banked in the base's pool, kept for good.
##
## This is the *second* of the two blood totals the game keeps, and the split
## between them is the whole point:
##
##   * [code]Blood[/code] ([BloodWallet]) is CARRIED blood. It is what the
##     collector's hand picks up in the arena, it comes home with the player, and
##     it is what a deposit spends.
##   * [code]BloodBank[/code] (this) is STORED blood. It only ever changes
##     because the player deposited into the pool or drew back out of it, and it
##     is what a future upgrade will be bought with.
##
## Both are autoloads, so both survive the scene reload that starts the next run -
## carrying blood into a run and banking blood across runs are the same mechanism,
## and neither is ever cleared by a transition. Nothing in a run's teardown
## touches either total.
##
## It adds no behaviour of its own on purpose. Everything a bank needs -
## [method BloodWallet.add], [method BloodWallet.spend],
## [method BloodWallet.can_afford], [method BloodWallet.transfer_to] and the
## [signal BloodWallet.changed] signal a readout follows - is already the wallet's,
## and having the two totals be the same type is what lets one counter script, one
## transfer primitive and one set of signals serve both.
##
## It deliberately declares no [code]class_name[/code]: a global class and an
## autoload cannot share a name, and the autoload is the useful one. Anything
## holding a reference to it types it as [BloodWallet], which is what it is.
##
## Access it as [code]BloodBank[/code] from anywhere:
## [code]BloodBank.get_total()[/code]. How much the pool will *hold* is not here:
## a capacity is a property of the pool the player can see, so it lives on
## [BloodPool] where it can be tuned in the inspector.
