class_name Actor
extends Node3D

enum ActorState {
	IDLE,
	MOVING,
	FIRING,
	RELOADING,
	WOUNDED,
	INCAPACITATED,
	DEAD,
}

const DEFAULT_RANDOM_SEED: int = 1
const ZERO_BARRIER_DENSITY: float = 0.0

static var _random_generator: RandomNumberGenerator = null

@export var profile: ActorProfile

var current_state: ActorState = ActorState.IDLE
var current_health: float = 0.0
var current_ammo: int = 0
var bleed_timer: float = 0.0
var motor_degradation: float = 0.0

func _ready() -> void:
	if profile == null:
		push_error("Actor requires an ActorProfile resource.")
		current_state = ActorState.DEAD
		return

	current_health = maxf(profile.starting_health, 0.0)
	if profile.starting_weapon != null:
		current_ammo = maxi(profile.starting_weapon.magazine_size, 0)

	if current_health <= 0.0:
		current_state = ActorState.DEAD

func _process(delta: float) -> void:
	if current_state != ActorState.WOUNDED:
		return

	bleed_timer = maxf(bleed_timer - maxf(delta, 0.0), 0.0)
	if bleed_timer <= 0.0:
		current_state = ActorState.INCAPACITATED

func take_damage(damage: float, hit_location: String) -> void:
	var wound_state: int = WoundCalculator.ActorState.ACTIVE
	match current_state:
		ActorState.WOUNDED, ActorState.INCAPACITATED:
			wound_state = WoundCalculator.ActorState.WOUNDED
		ActorState.DEAD:
			wound_state = WoundCalculator.ActorState.DEAD

	var applied_damage: float = maxf(damage, 0.0)
	var wound_result: WoundResult = WoundCalculator.apply_wound(
		wound_state,
		applied_damage,
		hit_location
	)

	if current_state == ActorState.DEAD:
		return

	current_health = maxf(current_health - applied_damage, 0.0)
	if wound_result.new_state == WoundCalculator.ActorState.DEAD or current_health <= 0.0:
		current_state = ActorState.DEAD
		return

	if wound_result.new_state == WoundCalculator.ActorState.WOUNDED:
		if current_state == ActorState.INCAPACITATED:
			return
		current_state = ActorState.WOUNDED
		bleed_timer = maxf(wound_result.bleed_timer, 0.0)
		motor_degradation = clampf(wound_result.motor_degradation, 0.0, 1.0)

func fire_weapon(target: Node3D) -> bool:
	if current_ammo <= 0 or target == null or profile == null:
		return false
	if current_state == ActorState.INCAPACITATED or current_state == ActorState.DEAD or current_state == ActorState.RELOADING:
		return false

	var weapon: WeaponData = profile.starting_weapon
	if weapon == null:
		return false

	if _get_random_generator().randf() < clampf(weapon.malfunction_chance, 0.0, 1.0):
		return false

	var shot_result: ShotResult = BallisticSolver.resolve_shot(
		global_position,
		target.global_position,
		weapon,
		ZERO_BARRIER_DENSITY
	)
	current_ammo -= 1

	if shot_result.hit_success and target.has_method("take_damage"):
		target.call("take_damage", shot_result.final_damage, shot_result.hit_location)

	return shot_result.hit_success

static func _get_random_generator() -> RandomNumberGenerator:
	if _random_generator == null:
		_random_generator = RandomNumberGenerator.new()
		_random_generator.seed = DEFAULT_RANDOM_SEED
	return _random_generator