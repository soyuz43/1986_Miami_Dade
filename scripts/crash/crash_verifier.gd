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
	_check_first_ram(failures)
	_check_phase_timing(failures)
	_check_restart(run_a, failures)
	_check_pass_through_detector(failures)
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
			or sequence.hanlon_mireles_car == null or sequence.grogan_dove_car == null \
			or sequence.parked_car == null:
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
		"parked_position": sequence.parked_car.position,
		"parked_rotation": sequence.parked_car.rotation.y,
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

	# Check body-to-body and body-to-obstacle clearances, not centre distances.
	var tree_clearance: float = _circle_rect_clearance(
		subject_position, subject_rotation,
		CrashBlockout.TREE_POSITION, CrashBlockout.TREE_TRUNK_RADIUS
	)
	_assert_contact("subject/tree", tree_clearance, failures)

	var parked_clearance: float = _rect_clearance(
		subject_position, subject_rotation,
		run["parked_position"], run["parked_rotation"]
	)
	_assert_contact("subject/parked civilian car", parked_clearance, failures)
	if absf(subject_position.x - CrashBlockout.SUBJECT_FINAL.x) > 0.001:
		failures.append("subject vehicle did not reach its documented final position.")

	# Manauzzi's car must be in contact with the subject vehicle (locked together).
	var manauzzi_position: Vector3 = run["manauzzi_position"]
	var manauzzi_clearance: float = _rect_clearance(
		subject_position, subject_rotation,
		manauzzi_position, run["manauzzi_rotation"]
	)
	_assert_contact("subject/Manauzzi", manauzzi_clearance, failures)
	if absf(manauzzi_position.x - CrashBlockout.MANAUZZI_FINAL.x) > 0.001:
		failures.append("Manauzzi's car did not reach its documented final position.")

	# Hanlon/Mireles car must be against the wall, south of the subject vehicle.
	var hanlon_position: Vector3 = run["hanlon_position"]
	var wall_clearance: float = _rect_clearance(
		hanlon_position, run["hanlon_rotation"],
		CrashBlockout.WALL_POSITION, 0.0,
		VEHICLE_HALF_WIDTH, VEHICLE_HALF_LENGTH,
		CrashBlockout.WALL_SIZE.x * 0.5, CrashBlockout.WALL_SIZE.z * 0.5
	)
	_assert_contact("Hanlon/Mireles car/substation wall", wall_clearance, failures)
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


func _assert_contact(label: String, clearance: float, failures: Array[String]) -> void:
	if absf(clearance) > CONTACT_TOLERANCE:
		failures.append("%s clearance is %.2f m; expected contact within %.2f m." % [
			label, clearance, CONTACT_TOLERANCE
		])


func _check_first_ram(failures: Array[String]) -> void:
	var sequence: Node3D = load(SEQUENCE_SCRIPT).new()
	root.add_child(sequence)
	sequence.auto_start = false
	sequence.set_process(false)
	sequence.setup()
	sequence.start()

	var contact_time: float = -1.0
	while sequence.get_sequence_time() < 6.0:
		sequence._process(STEP)
		var clearance: float = _rect_clearance(
			sequence.subject_vehicle.position, sequence.subject_vehicle.rotation.y,
			sequence.manauzzi_car.position, sequence.manauzzi_car.rotation.y
		)
		if absf(clearance) <= CONTACT_TOLERANCE:
			contact_time = sequence.get_sequence_time()
			break

	if contact_time < 0.0:
		failures.append("subject and Manauzzi's car never make body contact during the first-ram phase.")
	else:
		print("VERIFY: first-ram body contact at t=%.2fs" % contact_time)

	root.remove_child(sequence)
	sequence.free()


func _check_phase_timing(failures: Array[String]) -> void:
	var sequence: Node3D = load(SEQUENCE_SCRIPT).new()
	root.add_child(sequence)
	sequence.auto_start = false
	sequence.set_process(false)
	sequence.setup()
	sequence.start()

	while sequence.get_sequence_time() < 10.7:
		sequence._process(STEP)
	if sequence.get_phase_name() != "Impact":
		failures.append("sequence reported '%s' at 10.7s; vehicles are still moving during impact." % sequence.get_phase_name())

	while sequence.get_sequence_time() < 12.25:
		sequence._process(STEP)
	if sequence.get_phase_name() != "Settled":
		failures.append("sequence did not report Settled after the last vehicle keyframe.")

	root.remove_child(sequence)
	sequence.free()


## Restarting the sequence must return the scene to its opening state and then
## reproduce the identical end state, including when restarted after completion.
func _check_restart(run_a: Dictionary, failures: Array[String]) -> void:
	var sequence: Node3D = load(SEQUENCE_SCRIPT).new()
	root.add_child(sequence)
	sequence.auto_start = false
	sequence.set_process(false)
	sequence.setup()

	# Complete once so the restart exercises the finished-state transition.
	sequence.start()
	_drive(sequence)
	if not sequence.is_finished():
		failures.append("initial restart-test run did not reach completion.")

	# Restart must snap every vehicle back to the opening keyframe.
	sequence.start()
	if sequence.get_sequence_time() > 0.0001:
		failures.append("restart did not reset the sequence clock (time=%.4f)." % sequence.get_sequence_time())
	if not sequence.subject_vehicle.position.is_equal_approx(CrashBlockout.SUBJECT_APPROACH):
		failures.append("restart did not return the subject vehicle to its opening position (%s)." % sequence.subject_vehicle.position)
	if not sequence.manauzzi_car.position.is_equal_approx(CrashBlockout.MANAUZZI_APPROACH):
		failures.append("restart did not return Manauzzi's car to its opening position (%s)." % sequence.manauzzi_car.position)
	if not sequence.hanlon_mireles_car.position.is_equal_approx(CrashBlockout.HANLON_APPROACH):
		failures.append("restart did not return Hanlon/Mireles' car to its opening position (%s)." % sequence.hanlon_mireles_car.position)
	if not sequence.grogan_dove_car.position.is_equal_approx(CrashBlockout.GROGAN_APPROACH):
		failures.append("restart did not return Grogan/Dove's car to its opening position (%s)." % sequence.grogan_dove_car.position)
	if sequence.is_finished():
		failures.append("restart did not clear the finished flag.")

	# Running the restarted sequence must reproduce the same end state.
	_drive(sequence)
	if sequence.subject_vehicle.position != (run_a["subject_position"] as Vector3):
		failures.append("restart did not reproduce the subject vehicle's final position.")
	if sequence.manauzzi_car.position != (run_a["manauzzi_position"] as Vector3):
		failures.append("restart did not reproduce Manauzzi's car final position.")
	if sequence.hanlon_mireles_car.position != (run_a["hanlon_position"] as Vector3):
		failures.append("restart did not reproduce Hanlon/Mireles' car final position.")
	if sequence.grogan_dove_car.position != (run_a["grogan_position"] as Vector3):
		failures.append("restart did not reproduce Grogan/Dove's car final position.")
	if sequence.subject_vehicle.rotation.y != (run_a["subject_rotation"] as float):
		failures.append("restart did not reproduce the subject vehicle final rotation.")
	if sequence.manauzzi_car.rotation.y != (run_a["manauzzi_rotation"] as float):
		failures.append("restart did not reproduce Manauzzi's car final rotation.")
	if sequence.hanlon_mireles_car.rotation.y != (run_a["hanlon_rotation"] as float):
		failures.append("restart did not reproduce Hanlon/Mireles' car final rotation.")
	if sequence.grogan_dove_car.rotation.y != (run_a["grogan_rotation"] as float):
		failures.append("restart did not reproduce Grogan/Dove's car final rotation.")
	if not sequence.is_finished():
		failures.append("replayed run did not reach completion again.")

	root.remove_child(sequence)
	sequence.free()


## Check complete center-through-center crossings across every unique vehicle pair.
const VEHICLE_HALF_WIDTH: float = CrashVehicleFactory.DEFAULT_WIDTH * 0.5
const VEHICLE_HALF_LENGTH: float = CrashVehicleFactory.DEFAULT_LENGTH * 0.5
const CONTACT_TOLERANCE: float = 0.2

var _failures: Array[String] = []


func _report_separation() -> void:
	var sequence: Node3D = load(SEQUENCE_SCRIPT).new()
	root.add_child(sequence)
	sequence.auto_start = false
	sequence.set_process(false)
	sequence.setup()
	sequence.start()

	var vehicles: Array[Dictionary] = [
		{"name": "subject", "vehicle": sequence.subject_vehicle},
		{"name": "manauzzi", "vehicle": sequence.manauzzi_car},
		{"name": "hanlon", "vehicle": sequence.hanlon_mireles_car},
		{"name": "grogan", "vehicle": sequence.grogan_dove_car},
		{"name": "parked", "vehicle": sequence.parked_car},
	]
	var pair_tracks: Array[Dictionary] = []
	for first_index: int in range(vehicles.size()):
		for second_index: int in range(first_index + 1, vehicles.size()):
			var first: Dictionary = vehicles[first_index]
			var second: Dictionary = vehicles[second_index]
			var first_vehicle: Node3D = first["vehicle"]
			var second_vehicle: Node3D = second["vehicle"]
			pair_tracks.append({
				"key": "%s/%s" % [first["name"], second["name"]],
				"vehicle_a": first_vehicle,
				"vehicle_b": second_vehicle,
				"positions_a": PackedVector3Array([first_vehicle.position]),
				"yaws_a": PackedFloat32Array([first_vehicle.rotation.y]),
				"positions_b": PackedVector3Array([second_vehicle.position]),
				"yaws_b": PackedFloat32Array([second_vehicle.rotation.y]),
				"depth": 0.0,
				"time": 0.0,
				"preimpact_parked_overlap_time": -1.0,
			})
	if pair_tracks.size() != vehicles.size() * (vehicles.size() - 1) / 2:
		_failures.append("whole-scene check did not generate every unique vehicle pair.")

	var elapsed: float = 0.0
	while elapsed <= sequence.SEQUENCE_DURATION + 0.5:
		sequence._process(STEP)
		elapsed += STEP
		for pair_index: int in range(pair_tracks.size()):
			var track: Dictionary = pair_tracks[pair_index]
			var first_vehicle: Node3D = track["vehicle_a"]
			var second_vehicle: Node3D = track["vehicle_b"]
			var positions_a: PackedVector3Array = track["positions_a"]
			var yaws_a: PackedFloat32Array = track["yaws_a"]
			var positions_b: PackedVector3Array = track["positions_b"]
			var yaws_b: PackedFloat32Array = track["yaws_b"]
			positions_a.append(first_vehicle.position)
			yaws_a.append(first_vehicle.rotation.y)
			positions_b.append(second_vehicle.position)
			yaws_b.append(second_vehicle.rotation.y)
			track["positions_a"] = positions_a
			track["yaws_a"] = yaws_a
			track["positions_b"] = positions_b
			track["yaws_b"] = yaws_b

			var overlap: float = _overlap_depth(
				first_vehicle.position, first_vehicle.rotation.y,
				second_vehicle.position, second_vehicle.rotation.y
			)
			if overlap > float(track["depth"]):
				track["depth"] = overlap
				track["time"] = sequence.get_sequence_time()
			if track["key"] == "subject/parked" and sequence.get_sequence_time() < 8.8 \
					and overlap > 0.05 and float(track["preimpact_parked_overlap_time"]) < 0.0:
				track["preimpact_parked_overlap_time"] = sequence.get_sequence_time()
			pair_tracks[pair_index] = track

	for track: Dictionary in pair_tracks:
		var passed_through: bool = _has_passed_through(
			track["positions_a"], track["yaws_a"],
			track["positions_b"], track["yaws_b"]
		)
		var flag: String = "  <-- PASSES THROUGH" if passed_through else ""
		print("VERIFY: worst overlap %-20s %.2f m at t=%.1fs%s" % [
			track["key"], float(track["depth"]), float(track["time"]), flag
		])
		if passed_through:
			_failures.append("'%s' vehicle centers pass through one another during the sequence." % track["key"])
		if track["key"] == "subject/parked" and float(track["preimpact_parked_overlap_time"]) >= 0.0:
			_failures.append("subject vehicle intersects the parked car before the crash impacts at t=%.2fs." % float(track["preimpact_parked_overlap_time"]))

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
	var centre_a_2d: Vector2 = Vector2(centre_a.x, centre_a.z)
	var centre_b_2d: Vector2 = Vector2(centre_b.x, centre_b.z)
	var delta: Vector2 = centre_b_2d - centre_a_2d
	var axes: Array[Vector2] = _rectangle_axes(yaw_a, yaw_b)
	var min_depth: float = INF

	for axis: Vector2 in axes:
		var projection_a: float = _projection_radius(yaw_a, axis)
		var projection_b: float = _projection_radius(yaw_b, axis)
		var separation: float = absf(delta.dot(axis))
		var depth: float = projection_a + projection_b - separation
		if depth <= 0.0:
			return 0.0
		min_depth = minf(min_depth, depth)

	return min_depth


func _check_pass_through_detector(failures: Array[String]) -> void:
	var moving_positions: PackedVector3Array = PackedVector3Array()
	var moving_yaws: PackedFloat32Array = PackedFloat32Array()
	var stationary_positions: PackedVector3Array = PackedVector3Array()
	var stationary_yaws: PackedFloat32Array = PackedFloat32Array()
	for sample: int in range(61):
		var progress: float = float(sample) / 60.0
		moving_positions.append(Vector3(lerpf(-10.0, 10.0, progress), 0.0, 0.0))
		moving_yaws.append(PI * 0.5)
		stationary_positions.append(Vector3.ZERO)
		stationary_yaws.append(PI * 0.5)

	if not _has_passed_through(moving_positions, moving_yaws, stationary_positions, stationary_yaws):
		failures.append("pass-through detector accepted a vehicle driven fully through a stationary car.")
	else:
		print("VERIFY: full vehicle pass-through test rejected as expected")


func _has_passed_through(
	positions_a: PackedVector3Array,
	yaws_a: PackedFloat32Array,
	positions_b: PackedVector3Array,
	yaws_b: PackedFloat32Array
) -> bool:
	if positions_a.size() < 2 or positions_a.size() != yaws_a.size() \
			or positions_a.size() != positions_b.size() or positions_a.size() != yaws_b.size():
		return false

	var axes: Array[Vector2] = _rectangle_axes(yaws_a[0], yaws_b[0])
	var outside_sides: Array[int] = [0, 0, 0, 0]
	var entry_sides: Array[int] = [0, 0, 0, 0]
	var crossed_centres: Array[bool] = [false, false, false, false]
	for sample: int in range(positions_a.size()):
		var yaw_a: float = yaws_a[sample]
		var yaw_b: float = yaws_b[sample]
		var centre_a: Vector2 = Vector2(positions_a[sample].x, positions_a[sample].z)
		var centre_b: Vector2 = Vector2(positions_b[sample].x, positions_b[sample].z)
		var delta: Vector2 = centre_b - centre_a
		var previous_delta: Vector2 = Vector2.ZERO
		if sample > 0:
			previous_delta = Vector2(
				positions_b[sample - 1].x - positions_a[sample - 1].x,
				positions_b[sample - 1].z - positions_a[sample - 1].z
			)

		for axis_index: int in range(axes.size()):
			var axis: Vector2 = axes[axis_index]
			var perpendicular: Vector2 = Vector2(-axis.y, axis.x)
			var axis_extent: float = _projection_radius(yaw_a, axis) + _projection_radius(yaw_b, axis)
			var perpendicular_extent: float = _projection_radius(yaw_a, perpendicular) + _projection_radius(yaw_b, perpendicular)
			var signed_distance: float = delta.dot(axis)
			var current_side: int = 1 if signed_distance >= 0.0 else -1

			if absf(signed_distance) > axis_extent:
				if entry_sides[axis_index] != 0:
					if current_side != entry_sides[axis_index] and crossed_centres[axis_index]:
						return true
					entry_sides[axis_index] = 0
					crossed_centres[axis_index] = false
				outside_sides[axis_index] = current_side
				continue

			if entry_sides[axis_index] == 0 and outside_sides[axis_index] != 0:
				entry_sides[axis_index] = outside_sides[axis_index]
			if entry_sides[axis_index] != 0 and absf(delta.dot(perpendicular)) <= perpendicular_extent and sample > 0:
				var previous_signed_distance: float = previous_delta.dot(axis)
				if previous_signed_distance * signed_distance <= 0.0 and _overlap_depth(
					positions_a[sample], yaw_a, positions_b[sample], yaw_b
				) > 0.5:
					crossed_centres[axis_index] = true

	return false


func _rectangle_axes(yaw_a: float, yaw_b: float) -> Array[Vector2]:
	return [
		Vector2(cos(yaw_a), -sin(yaw_a)),
		Vector2(sin(yaw_a), cos(yaw_a)),
		Vector2(cos(yaw_b), -sin(yaw_b)),
		Vector2(sin(yaw_b), cos(yaw_b)),
	]


func _projection_radius(yaw: float, axis: Vector2) -> float:
	var local_x: Vector2 = Vector2(cos(yaw), -sin(yaw))
	var local_z: Vector2 = Vector2(sin(yaw), cos(yaw))
	return VEHICLE_HALF_WIDTH * absf(axis.dot(local_x)) + VEHICLE_HALF_LENGTH * absf(axis.dot(local_z))


func _rect_clearance(
	centre_a: Vector3,
	yaw_a: float,
	centre_b: Vector3,
	yaw_b: float,
	half_width_a: float = VEHICLE_HALF_WIDTH,
	half_length_a: float = VEHICLE_HALF_LENGTH,
	half_width_b: float = VEHICLE_HALF_WIDTH,
	half_length_b: float = VEHICLE_HALF_LENGTH
) -> float:
	var delta: Vector2 = Vector2(centre_b.x - centre_a.x, centre_b.z - centre_a.z)
	var axes: Array[Vector2] = _rectangle_axes(yaw_a, yaw_b)
	var clearance: float = -INF
	for axis: Vector2 in axes:
		var radius_a: float = half_width_a * absf(axis.dot(Vector2(cos(yaw_a), -sin(yaw_a)))) \
			+ half_length_a * absf(axis.dot(Vector2(sin(yaw_a), cos(yaw_a))))
		var radius_b: float = half_width_b * absf(axis.dot(Vector2(cos(yaw_b), -sin(yaw_b)))) \
			+ half_length_b * absf(axis.dot(Vector2(sin(yaw_b), cos(yaw_b))))
		clearance = maxf(clearance, absf(delta.dot(axis)) - radius_a - radius_b)
	return clearance


func _circle_rect_clearance(
	rect_centre: Vector3,
	rect_yaw: float,
	circle_centre: Vector3,
	circle_radius: float
) -> float:
	var local_x_axis: Vector2 = Vector2(cos(rect_yaw), -sin(rect_yaw))
	var local_z_axis: Vector2 = Vector2(sin(rect_yaw), cos(rect_yaw))
	var delta: Vector2 = Vector2(circle_centre.x - rect_centre.x, circle_centre.z - rect_centre.z)
	var local_x: float = delta.dot(local_x_axis)
	var local_z: float = delta.dot(local_z_axis)
	var excess_x: float = maxf(absf(local_x) - VEHICLE_HALF_WIDTH, 0.0)
	var excess_z: float = maxf(absf(local_z) - VEHICLE_HALF_LENGTH, 0.0)
	if excess_x == 0.0 and excess_z == 0.0:
		var depth_inside: float = minf(VEHICLE_HALF_WIDTH - absf(local_x), VEHICLE_HALF_LENGTH - absf(local_z))
		return -circle_radius - depth_inside
	return Vector2(excess_x, excess_z).length() - circle_radius

func _drive(sequence: Node3D, until: float = -1.0) -> void:
	var limit: float = until if until > 0.0 else sequence.SEQUENCE_DURATION + 0.5
	var elapsed: float = 0.0
	while elapsed <= limit:
		sequence._process(STEP)
		elapsed += STEP
