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
var current_weapon: WeaponData = null
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
		current_weapon = profile.starting_weapon
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
	var actor_name: String = _get_display_name()
	var health_before: float = current_health
	var wound_state: int = WoundCalculator.ActorState.ACTIVE
	match current_state:
		ActorState.WOUNDED, ActorState.INCAPACITATED:
			wound_state = WoundCalculator.ActorState.WOUNDED
		ActorState.DEAD:
			wound_state = WoundCalculator.ActorState.DEAD

	var applied_damage: float = maxf(damage, 0.0)
	if current_state == ActorState.DEAD:
		print("[T:%.2f] %s takes no damage; already dead. Health remains %.1f." % [SimulationManager.current_time, actor_name, current_health])
		return

	var wound_result: WoundResult = WoundCalculator.apply_wound(
		wound_state,
		applied_damage,
		hit_location
	)
	current_health = maxf(current_health - applied_damage, 0.0)
	if wound_result.new_state == WoundCalculator.ActorState.DEAD or current_health <= 0.0:
		current_state = ActorState.DEAD
	elif wound_result.new_state == WoundCalculator.ActorState.WOUNDED and current_state != ActorState.INCAPACITATED:
		current_state = ActorState.WOUNDED
		bleed_timer = maxf(wound_result.bleed_timer, 0.0)
		motor_degradation = clampf(wound_result.motor_degradation, 0.0, 1.0)

	print("[T:%.2f] %s takes %.1f damage to %s. Health: %.1f -> %.1f (%s)." % [
		SimulationManager.current_time,
		actor_name,
		applied_damage,
		hit_location,
		health_before,
		current_health,
		_get_state_name(current_state),
	])
	if wound_result.new_state == WoundCalculator.ActorState.WOUNDED and current_state == ActorState.WOUNDED:
		print("  -> WOUNDED. Bleed timer: %.1fs, motor degradation: %.2f." % [bleed_timer, motor_degradation])

func move_to(destination: Vector3) -> void:
	if current_state == ActorState.INCAPACITATED or current_state == ActorState.DEAD:
		return
	global_position = destination
	if current_state != ActorState.WOUNDED:
		current_state = ActorState.IDLE

func reload_weapon() -> void:
	if current_weapon == null or current_state == ActorState.INCAPACITATED or current_state == ActorState.DEAD:
		return
	current_ammo = maxi(current_weapon.magazine_size, 0)
	if current_state == ActorState.RELOADING:
		current_state = ActorState.IDLE

func set_actor_state(new_state: ActorState) -> void:
	current_state = new_state

func transition_weapon(weapon_slot: String) -> bool:
	if profile == null or current_state == ActorState.INCAPACITATED or current_state == ActorState.DEAD:
		return false

	var selected_weapon: WeaponData = null
	match weapon_slot.to_lower():
		"starting", "primary":
			selected_weapon = profile.starting_weapon
		"backup", "secondary":
			selected_weapon = profile.backup_weapon
		_:
			return false

	if selected_weapon == null:
		return false
	current_weapon = selected_weapon
	current_ammo = maxi(current_weapon.magazine_size, 0)
	return true

func fire_weapon(target: Node3D) -> bool:
	var actor_name: String = _get_display_name()
	if target == null:
		print("[T:%.2f] %s cannot fire: no target was provided." % [SimulationManager.current_time, actor_name])
		return false
	if profile == null:
		print("[T:%.2f] %s cannot fire: no actor profile is assigned." % [SimulationManager.current_time, actor_name])
		return false
	if current_ammo <= 0:
		print("[T:%.2f] %s cannot fire: no ammunition remains." % [SimulationManager.current_time, actor_name])
		return false
	if current_state == ActorState.INCAPACITATED or current_state == ActorState.DEAD or current_state == ActorState.RELOADING:
		print("[T:%.2f] %s cannot fire while %s." % [SimulationManager.current_time, actor_name, _get_state_name(current_state)])
		return false

	var weapon: WeaponData = current_weapon
	if weapon == null:
		print("[T:%.2f] %s cannot fire: no weapon is equipped." % [SimulationManager.current_time, actor_name])
		return false
	var target_name: String = target.name
	if target is Actor:
		target_name = (target as Actor)._get_display_name()
	print("[T:%.2f] %s attempts to fire %s at %s." % [
		SimulationManager.current_time,
		actor_name,
		weapon.display_name,
		target_name,
	])

	if _get_random_generator().randf() < clampf(weapon.malfunction_chance, 0.0, 1.0):
		print("  -> MALFUNCTION. No shot fired; ammunition remains %d." % current_ammo)
		return false

	var shot_result: ShotResult = BallisticSolver.resolve_shot(
		global_position,
		target.global_position,
		weapon,
		ZERO_BARRIER_DENSITY
	)
	current_ammo -= 1

	if shot_result.hit_success:
		print("  -> SHOT FIRED. HIT! Location: %s, Damage: %.1f. Ammunition remaining: %d." % [
			shot_result.hit_location,
			shot_result.final_damage,
			current_ammo,
		])
		if target.has_method("take_damage"):
			target.call("take_damage", shot_result.final_damage, shot_result.hit_location)
		else:
			print("  -> Target has no damage handler; damage was not applied.")
	else:
		var miss_reason: String = shot_result.reason if not shot_result.reason.is_empty() else "No hit was registered."
		var shot_outcome: String = "BLOCKED" if miss_reason.to_upper() == "BLOCKED" else "MISS"
		print("  -> SHOT %s: %s. Ammunition remaining: %d." % [shot_outcome, miss_reason, current_ammo])

	return shot_result.hit_success

static func set_random_seed(seed_value: int) -> void:
	_get_random_generator().seed = seed_value

static func _get_random_generator() -> RandomNumberGenerator:
	if _random_generator == null:
		_random_generator = RandomNumberGenerator.new()
		_random_generator.seed = DEFAULT_RANDOM_SEED
	return _random_generator

func _get_display_name() -> String:
	if profile != null and not profile.display_name.is_empty():
		return profile.display_name
	return name

func _get_state_name(state: ActorState) -> String:
	match state:
		ActorState.IDLE:
			return "IDLE"
		ActorState.MOVING:
			return "MOVING"
		ActorState.FIRING:
			return "FIRING"
		ActorState.RELOADING:
			return "RELOADING"
		ActorState.WOUNDED:
			return "WOUNDED"
		ActorState.INCAPACITATED:
			return "INCAPACITATED"
		ActorState.DEAD:
			return "DEAD"
	return "UNKNOWN"
