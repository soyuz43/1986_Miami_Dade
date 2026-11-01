class_name BallisticSolver

const ZERO_DAMAGE_DISTANCE_UNITS: float = 1000.0
const DEFAULT_RANDOM_SEED: int = 1

static var _random_generator: RandomNumberGenerator = null

static func resolve_shot(
		shooter_pos: Vector3,
		target_pos: Vector3,
		weapon: WeaponData,
		barrier_density: float
) -> ShotResult:
	var result: ShotResult = ShotResult.new()
	var shot_distance: float = shooter_pos.distance_to(target_pos)

	if weapon.penetration_power < barrier_density:
		result.reason = "BLOCKED"
		return result

	var damage_multiplier: float = clampf(
		1.0 - shot_distance / ZERO_DAMAGE_DISTANCE_UNITS,
		0.0,
		1.0
	)
	var random_generator: RandomNumberGenerator = _get_random_generator()
	var hit_roll: float = random_generator.randf()

	result.hit_success = true
	result.final_damage = weapon.damage_base * damage_multiplier
	result.penetration_remaining = maxf(0.0, weapon.penetration_power - barrier_density)
	if hit_roll < 0.2:
		result.hit_location = "HEAD"
	elif hit_roll < 0.8:
		result.hit_location = "TORSO"
	else:
		result.hit_location = "LIMB"
	return result

static func set_random_seed(seed_value: int) -> void:
	_get_random_generator().seed = seed_value

static func _get_random_generator() -> RandomNumberGenerator:
	if _random_generator == null:
		_random_generator = RandomNumberGenerator.new()
		_random_generator.seed = DEFAULT_RANDOM_SEED
	return _random_generator
