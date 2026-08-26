class_name GunshotSurrender
extends Node
## A shot going off next to a man sometimes breaks his nerve: he throws his knife
## down and gives up on the spot, in the middle of the fight.
##
## [b]It is one node in the world rather than anything on the enemy or the gun.[/b]
## Neither of those should have to know this rule exists - a weapon's job is to fire
## and an enemy's is to fight - so the whole of "a shot was heard nearby, and
## somebody folded" lives here, and switching it off is switching off one node.
##
## Nothing about the weapon is assumed except that it announces its shots. The live
## weapon is taken from [WeaponMount], which is already the one place anything asks
## what the player is holding, and its [code]fired[/code] signal is connected if it
## has one - so the revolver, the shotgun, the rifle and whatever is added to the
## catalogue next all scare enemies identically, with nothing here naming any of
## them. A weapon that announces nothing simply never scares anybody.
##
## Who is close enough is [method EnemyTargeting.nearest], the same question a
## bouncing bullet and a thrown coin ask, measured from the muzzle rather than from
## the player - the noise comes out of the gun, and the gun is held out at arm's
## length. That also means an enemy that has already given up or already died is
## never picked, because it is no longer in the group that search reads.
##
## The roll is made [i]after[/i] somebody has been found, not before, so
## [member chance] is honestly "how often a point-blank shot breaks the man it went
## past" rather than a number diluted by every shot fired across an empty arena.
##
## [b]One attack is one roll, whatever it puts in the air.[/b] A shotgun blast is six
## pellets and a single chance, not six chances - rolling per projectile would turn a
## stated one-in-five into better than two-in-three for the shotgun alone, and would
## quietly re-tune itself every time a pellet count changed. That holds by
## construction, because what is listened to is the weapon announcing a shot rather
## than anything announcing a bullet: every weapon in the catalogue emits
## [code]fired[/code] once per trigger pull, after its projectiles are spawned. The
## frame guard below is insurance for a weapon that does not, so the rule survives a
## weapon that has not been written yet.

## Emitted when a shot actually breaks somebody, with the enemy that gave up.
signal scared(enemy: Node2D)

## Where the live weapon is read from. Left empty the mount is found by group, which
## is what every other reader of it does.
@export var mount_path: NodePath

@export_group("Scare")
## How close to the muzzle an enemy has to be for a shot to be fired "at" it, in
## pixels. Point-blank - this is a man flinching at a barrel beside his head, not
## everyone within earshot.
@export var scare_radius: float = 140.0
## How often a shot that close makes that enemy give up, [b]when there is no
## [MoraleDirector] in the world[/b].
##
## It is the fallback and nothing else. Ordinarily this node finds nobody and rolls
## nothing: it reports the near miss to the director - see
## [member asks_the_morale_director] - which owns the odds, owns the "how many of
## them are left" curve they are drawn from, and owns the rarer chance that the man
## loses his temper instead of his nerve. This flat number is what a scene without
## that director falls back to, so taking the director out leaves the behaviour the
## game had before there was one rather than leaving enemies that never react.
@export_range(0.0, 1.0, 0.01) var chance: float = 0.2
## Whether a near miss is handed to the [MoraleDirector] rather than rolled here.
##
## On. This node's job is to notice that a shot went past somebody - which is a fact
## about the weapon, and is why it lives out here beside the gun rather than on the
## enemy. What that is worth is a fact about the fight, and belongs to the director.
@export var asks_the_morale_director: bool = true
## Whether the rule is live at all. Off leaves every shot a shot.
@export var enabled: bool = true

var _mount: WeaponMount
var _weapon: CarriedWeapon
## The frame the last roll was made on, held as both counts at once. A second
## announcement from the same instant is the same attack being announced twice - a
## weapon emitting once per pellet inside its spawn loop - and gets no second roll.
## Two real trigger pulls cannot share an instant: input is read once a frame and
## every weapon has a state to leave and re-enter between shots, so this can only
## ever swallow the duplicate it exists for.
var _last_process_frame: int = -1
var _last_physics_frame: int = -1


func _ready() -> void:
	_bind()


## The mount builds its weapon in its own [method Node._ready], so which of the two
## nodes runs first is a question about where they sit in the scene. This keeps
## looking until it finds one and then stops running, which answers it either way.
func _process(_delta: float) -> void:
	_bind()


func _bind() -> void:
	if _mount != null and is_instance_valid(_mount):
		set_process(false)
		return

	_mount = get_node_or_null(mount_path) as WeaponMount
	if _mount == null:
		_mount = WeaponMount.get_active(self)
	if _mount == null:
		return

	_mount.weapon_built.connect(_on_weapon_built)
	# Asked for as well as waited for: the weapon may already have been built by the
	# time this binds, and that signal is not coming again.
	_on_weapon_built(_mount.get_weapon())
	set_process(false)


## Duck-typed rather than matched against a list of weapons, so the catalogue is the
## only place weapons are enumerated.
func _on_weapon_built(weapon: CarriedWeapon) -> void:
	_weapon = weapon
	if weapon == null or not weapon.has_signal(&"fired"):
		return
	if weapon.is_connected(&"fired", _on_fired):
		return
	weapon.connect(&"fired", _on_fired)


## One shot, one roll. The frame is claimed before anybody is looked for, so a shot
## that went past nobody still spends the attack - otherwise a weapon announcing
## itself per pellet would get a fresh roll for every pellet that happened to find an
## empty arena, which is the same bug wearing a different hat.
func _on_fired() -> void:
	if not enabled or _weapon == null or not is_instance_valid(_weapon):
		return

	var process_frame := Engine.get_process_frames()
	var physics_frame := Engine.get_physics_frames()
	if process_frame == _last_process_frame and physics_frame == _last_physics_frame:
		return
	_last_process_frame = process_frame
	_last_physics_frame = physics_frame

	var enemy := EnemyTargeting.nearest(self, _weapon.global_position, scare_radius)
	if enemy == null:
		return

	# The near miss is reported, and what it is worth is somebody else's answer. The
	# director refuses a man who is already down, running, berserk or dead, so
	# nothing about who is a fair thing to frighten is decided twice.
	if asks_the_morale_director:
		var director := MoraleDirector.get_active(self)
		if director != null:
			if director.check(enemy, MoraleDirector.Source.NEAR_MISS):
				scared.emit(enemy)
			return

	if randf() >= chance:
		return

	var surrender := EnemySurrender.find_on(enemy)
	if surrender == null or not surrender.surrender():
		return
	scared.emit(enemy)
