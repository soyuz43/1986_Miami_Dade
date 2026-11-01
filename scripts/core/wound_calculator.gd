class_name WoundCalculator

enum ActorState {
	ACTIVE,
	WOUNDED,
	DEAD,
}

static func apply_wound(current_state: int, damage: float, hit_location: String) -> WoundResult:
	var result: WoundResult = WoundResult.new()
	result.new_state = current_state

	if current_state == ActorState.DEAD:
		return result

	match hit_location.strip_edges().to_upper():
		"HEAD", "SPINE":
			if damage > 50.0:
				result.new_state = ActorState.DEAD
		"TORSO":
			if damage > 60.0:
				result.new_state = ActorState.WOUNDED
				result.bleed_timer = 180.0
				result.motor_degradation = 0.3
		"LIMB":
			if damage > 0.0:
				result.new_state = ActorState.WOUNDED
				result.bleed_timer = 600.0
				result.motor_degradation = 0.5

	return result
