extends SceneTree

## Headless verification harness for the crash opening.
##
## Run with:
##   godot --headless --path . --script res://scripts/crash/crash_verifier.gd
##
## It drives the crash sequence to completion, dumps the final vehicle
## transforms, replays the sequence a second time, and compares the two runs
## to confirm the opening is deterministic. It also asserts the documented
## end-state properties of the blockout.

const SEQUENCE_SCRIPT: String = "res://scripts/crash/crash_sequence.gd"
const STEP: float = 1.0 / 60.0


func _initialize() -> void:
	var failures: Array[String] = []

	var run_a: Dictionary = _run_sequence()
	var run_b: Dictionary = _run_sequence()

	_check_determinism(run_a, run_b, failures)
	_check_end_state(run_a, failures)
	_check_restart(run_a, failures)
	_failures = failures
	_report_separation()

	if failures.is_empty():
		print("VERIFY: PASS - crash opening is deterministic and reaches the documented end state.")
		quit(0)
		return

	for failure: String in failures:
		printerr("VERIFY: FAIL - %s" % failure)
	quit(1)


func _run_sequence() -> Dictionary:
	var sequence: Node3D = load(SEQUENCE_SCRIPT).new()
	root.add_child(sequence)

	# Take manual control of time so the run is frame-rate independent.
	sequence.auto_start = false
	sequence.set_process(false)
	sequence.setup()
	sequence.start()

	if sequence.subject_vehicle == null or sequence.manauzzi_car == null \
			or sequence.hanlon_mireles_car == null or sequence.grogan_dove_car == null:
		root.remove_child(sequence)
		sequence.free()
		return {"setup_failed": true}

	var elapsed: float = 0.0
	while elapsed <= sequence.SEQUENCE_DURATION + 0.5:
		sequence._process(STEP)
		elapsed += STEP

	var result: Dictionary = {
		"setup_failed": false,
		"subject_position": sequence.subject_vehicle.position,
		"subject_rotation": sequence.subject_vehicle.rotation.y,
		"manauzzi_position": sequence.manauzzi_car.position,
		"manauzzi_rotation": sequence.manauzzi_car.rotation.y,
		"hanlon_position": sequence.hanlon_mireles_car.position,
		"hanlon_rotation": sequence.hanlon_mireles_car.rotation.y,
		"grogan_position": sequence.grogan_dove_car.position,
		"grogan_rotation": sequence.grogan_dove_car.rotation.y,
		"finished": sequence.is_finished(),
	}

	root.remove_child(sequence)
	sequence.free()
	return result


func _check_determinism(run_a: Dictionary, run_b: Dictionary, failures: Array[String]) -> void:
	for key: String in run_a.keys():
		var value_a: Variant = run_a[key]
		var value_b: Variant = run_b[key]
		if typeof(value_a) == TYPE_FLOAT:
			if absf(float(value_a) - float(value_b)) > 0.000001:
				failures.append("run A and run B differ at '%s' (%s vs %s)." % [key, value_a, value_b])
		elif value_a != value_b:
			failures.append("run A and run B differ at '%s' (%s vs %s)." % [key, value_a, value_b])


func _check_end_state(run: Dictionary, failures: Array[String]) -> void:
	if bool(run.get("setup_failed", true)):
		failures.append("crash sequence failed to build its vehicles; the run produced no state.")
		return

	if not bool(run["finished"]):
		failures.append("sequence did not reach the settled state.")

	var subject_position: Vector3 = run["subject_position"]
	var subject_rotation: float = run["subject_rotation"]

	# The subject vehicle must come to rest facing northbound (FBI incident report).
	# North is -Z, so a north-facing yaw is 0 radians.
	var facing_north: bool = absf(wrapf(subject_rotation, -PI, PI)) < deg_to_rad(20.0)
	if not facing_north:
		failures.append("subject vehicle does not face northbound (yaw %.1f deg)." % rad_to_deg(subject_rotation))

	# The subject vehicle must be on the west side of the road, in the yard.
	if subject_position.x > -5.0:
		failures.append("subject vehicle did not end on the west side of 82nd Avenue (x=%.2f)." % subject_position.x)

	# The subject vehicle must be wedged against the tree, near the parked car.
	var tree_position: Vector3 = CrashBlockout.TREE_POSITION
	var tree_distance: float = subject_position.distance_to(tree_position)
	if tree_distance > 6.0:
		failures.append("subject vehicle is %.2f m from the tree; expected it wedged against the tree." % tree_distance)

	# The subject vehicle must be wedged between the tree and the parked civilian car.
	var parked_distance: float = subject_position.distance_to(CrashBlockout.PARKED_CAR_FINAL)
	if parked_distance > 4.0:
		failures.append("subject vehicle is %.2f m from the parked civilian car; expected it wedged against it." % parked_distance)
	if absf(subject_position.x - CrashBlockout.SUBJECT_FINAL.x) > 0.001:
		failures.append("subject vehicle did not reach its documented final position.")

	# Manauzzi's car must be in contact with the subject vehicle (locked together).
	var manauzzi_position: Vector3 = run["manauzzi_position"]
	var contact_distance: float = manauzzi_position.distance_to(subject_position)
	if contact_distance > 4.0:
		failures.append("Manauzzi's car is %.2f m from the subject vehicle; expected contact." % contact_distance)
	if absf(manauzzi_position.x - CrashBlockout.MANAUZZI_FINAL.x) > 0.001:
		failures.append("Manauzzi's car did not reach its documented final position.")

	# Hanlon/Mireles car must be against the wall, south of the subject vehicle.
	var hanlon_position: Vector3 = run["hanlon_position"]
	if hanlon_position.z < subject_position.z:
		failures.append("Hanlon/Mireles car is not south of the subject vehicle.")
	if hanlon_position.x > -6.0:
		failures.append("Hanlon/Mireles car did not come to rest on the west side (x=%.2f)." % hanlon_position.x)

	# Grogan/Dove car must be behind (south of) the subject vehicle after its U-turn.
	var grogan_position: Vector3 = run["grogan_position"]
	if grogan_position.z <= subject_position.z:
		failures.append("Grogan/Dove car is not behind (south of) the subject vehicle.")

	print("VERIFY: final subject position   %s" % subject_position)
	print("VERIFY: final manauzzi position  %s" % manauzzi_position)
	print("VERIFY: final hanlon position    %s" % hanlon_position)
	print("VERIFY: final grogan position    %s" % grogan_position)
	print("VERIFY: subject yaw              %.1f deg" % rad_to_deg(subject_rotation))

## Restarting the sequence must return the scene to its opening state and then
## reproduce the identical end state. This is the roadmap's "reliable restart"
## requirement.
func _check_restart(run_a: Dictionary, failures: Array[String]) -> void:
	var sequence: Node3D = load(SEQUENCE_SCRIPT).new()
	root.add_child(sequence)
	sequence.auto_start = false
	sequence.set_process(false)
	sequence.setup()

	# Run partway into the sequence.
	sequence.start()
	_drive(sequence, 6.0)

	var mid_position: Vector3 = sequence.subject_vehicle.position
	if mid_position.is_equal_approx(sequence.subject_vehicle.position) and sequence.get_sequence_time() <= 0.0:
		failures.append("sequence did not advance when driven.")

	# Restart must snap every vehicle back to the opening keyframe.
	sequence.start()
	if sequence.get_sequence_time() > 0.0001:
		failures.append("restart did not reset the sequence clock (time=%.4f)." % sequence.get_sequence_time())
	if not sequence.subject_vehicle.position.is_equal_approx(CrashBlockout.SUBJECT_APPROACH):
		failures.append("restart did not return the subject vehicle to its opening position (%s)." % sequence.subject_vehicle.position)
	if not sequence.manauzzi_car.position.is_equal_approx(CrashBlockout.MANAUZZI_APPROACH):
		failures.append("restart did not return Manauzzi's car to its opening position (%s)." % sequence.manauzzi_car.position)
	if sequence.is_finished():
		failures.append("restart did not clear the finished flag.")

	# Running the restarted sequence must reproduce the same end state.
	_drive(sequence)
	if sequence.subject_vehicle.position != (run_a["subject_position"] as Vector3):
		failures.append("restart did not reproduce the subject vehicle's final position.")
	if sequence.manauzzi_car.position != (run_a["manauzzi_position"] as Vector3):
		failures.append("restart did not reproduce Manauzzi's car final position.")
	if sequence.subject_vehicle.rotation.y != (run_a["subject_rotation"] as float):
		failures.append("restart did not reproduce the subject vehicle final rotation.")

	root.remove_child(sequence)
	sequence.free()


## Report vehicle interpenetration across the whole sequence.
##
## Each vehicle is an oriented rectangle on the XZ plane (1.9 m wide by 4.9 m
## long). Two vehicles are flagged when their rectangles actually overlap,
## which distinguishes a genuine ram (rectangles touching) from one vehicle
## driving through another.
const VEHICLE_HALF_WIDTH: float = 0.95
const VEHICLE_HALF_LENGTH: float = 2.45

var _failures: Array[String] = []


func _report_separation() -> void:
	var sequence: Node3D = load(SEQUENCE_SCRIPT).new()
	root.add_child(sequence)
	sequence.auto_start = false
	sequence.set_process(false)
	sequence.setup()
	sequence.start()

	var pairs: Array[Array] = [
		["subject", sequence.subject_vehicle, "manauzzi", sequence.manauzzi_car],
		["subject", sequence.subject_vehicle, "grogan", sequence.grogan_dove_car],
		["subject", sequence.subject_vehicle, "hanlon", sequence.hanlon_mireles_car],
		["manauzzi", sequence.manauzzi_car, "grogan", sequence.grogan_dove_car],
		["hanlon", sequence.hanlon_mireles_car, "manauzzi", sequence.manauzzi_car],
	]
	var worst: Dictionary = {}

	var elapsed: float = 0.0
	while elapsed <= sequence.SEQUENCE_DURATION + 0.5:
		sequence._process(STEP)
		elapsed += STEP
		for pair: Array in pairs:
			var key: String = "%s/%s" % [pair[0], pair[2]]
			var overlap: float = _overlap_depth(
				(pair[1] as Node3D).position, (pair[1] as Node3D).rotation.y,
				(pair[3] as Node3D).position, (pair[3] as Node3D).rotation.y
			)
			if not worst.has(key) or overlap > float((worst[key] as Dictionary)["depth"]):
				worst[key] = {"depth": overlap, "time": sequence.get_sequence_time()}

	for key: String in worst.keys():
		var entry: Dictionary = worst[key]
		var overlap: float = float(entry["depth"])
		var flag: String = ""
		if overlap > 0.05:
			# Vehicles that are in contact (a ram, or the final pile-up) will
			# show an overlap of up to one vehicle length along the axis of
			# contact. What must not happen is one vehicle driving clean
			# through another and emerging on the far side, which shows an
			# overlap deeper than the vehicles are long.
			if overlap > VEHICLE_HALF_LENGTH:
				flag = "  <-- PASSES THROUGH"
		print("VERIFY: worst overlap %-20s %.2f m at t=%.1fs%s" % [key, overlap, float(entry["time"]), flag])
		if overlap > VEHICLE_HALF_LENGTH:
			_failures.append("'%s' interpenetrated by %.2f m, which is deeper than a vehicle is long." % [key, overlap])

	root.remove_child(sequence)
	sequence.free()


## Separating-axis overlap depth for two oriented rectangles on the XZ plane.
## Returns 0.0 when they do not overlap, otherwise the penetration depth.
func _overlap_depth(
	centre_a: Vector3,
	yaw_a: float,
	centre_b: Vector3,
	yaw_b: float
) -> float:
	var axis_a_x: Vector2 = Vector2(cos(yaw_a), -sin(yaw_a))
	var axis_a_z: Vector2 = Vector2(sin(yaw_a), cos(yaw_a))
	var axis_b_x: Vector2 = Vector2(cos(yaw_b), -sin(yaw_b))
	var axis_b_z: Vector2 = Vector2(sin(yaw_b), cos(yaw_b))

	var centre_a_2d: Vector2 = Vector2(centre_a.x, centre_a.z)
	var centre_b_2d: Vector2 = Vector2(centre_b.x, centre_b.z)
	var delta: Vector2 = centre_b_2d - centre_a_2d

	var axes: Array[Vector2] = [axis_a_x, axis_a_z, axis_b_x, axis_b_z]
	var min_depth: float = INF

	for axis: Vector2 in axes:
		var projection_a: float = VEHICLE_HALF_WIDTH * absf(axis.dot(axis_a_x)) + VEHICLE_HALF_LENGTH * absf(axis.dot(axis_a_z))
		var projection_b: float = VEHICLE_HALF_WIDTH * absf(axis.dot(axis_b_x)) + VEHICLE_HALF_LENGTH * absf(axis.dot(axis_b_z))
		var separation: float = absf(delta.dot(axis))
		var depth: float = projection_a + projection_b - separation
		if depth <= 0.0:
			return 0.0
		min_depth = minf(min_depth, depth)

	return min_depth

func _drive(sequence: Node3D, until: float = -1.0) -> void:
	var limit: float = until if until > 0.0 else sequence.SEQUENCE_DURATION + 0.5
	var elapsed: float = 0.0
	while elapsed <= limit:
		sequence._process(STEP)
		elapsed += STEP