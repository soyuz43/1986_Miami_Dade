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
##
## The gates here are deliberately strict. An earlier version of this
## harness only rejected a *complete* center-through-center crossing, which
## let 2.31 m of interpenetration between the subject vehicle and
## Manauzzi's car pass unnoticed. The overlap gate below now rejects any
## pair whose bodies overlap by more than a hand's width, which is what
## "clipping" looks like on screen.

const SEQUENCE_SCRIPT: String = "res://scripts/crash/crash_sequence.gd"
const STEP: float = 1.0 / 60.0

## Maximum allowed body overlap between any two vehicles, in metres. A car
## overlapping another by more than this reads as clipping.
const MAX_PAIR_OVERLAP: float = 0.10

## Maximum allowed penetration of a vehicle into a static obstacle.
const MAX_OBSTACLE_PENETRATION: float = 0.05

## Maximum allowed slip angle (nose versus direction of travel) in degrees,
## for vehicles that are not declared to be sliding.
const MAX_SLIP_DEGREES: float = 1.0

## Maximum allowed change in speed between consecutive frames, in m/s.
## This catches the "velocity stalls at every keyframe" defect, where the
## old easing drove speed to zero at each keyframe boundary.
const MAX_FRAME_SPEED_JUMP: float = 0.60

## Tolerance for the documented end-state contacts.
const CONTACT_TOLERANCE: float = 0.25

const VEHICLE_HALF_WIDTH: float = CrashVehicleFactory.DEFAULT_WIDTH * 0.5
const VEHICLE_HALF_LENGTH: float = CrashVehicleFactory.DEFAULT_LENGTH * 0.5

var _failures: Array[String] = []


func _initialize() -> void:
	var run_a: Dictionary = _run_sequence()
	var run_b: Dictionary = _run_sequence()

	_check_determinism(run_a, run_b, _failures)
	_check_end_state(run_a, _failures)
	_check_first_ram(_failures)
	_check_phase_timing(_failures)
	_check_restart(run_a, _failures)
	_check_overlap(_failures)
	_check_obstacles(_failures)
	_check_slip(_failures)
	_check_speed_continuity(_failures)
	_check_seat_anchors(_failures)
	_report_separation()

	if _failures.is_empty():
		print("VERIFY: PASS - crash opening is deterministic and reaches the documented end state.")
		quit(0)
		return

	for failure: String in _failures:
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
			or sequence.parked_cutlass == null:
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
		"cutlass_position": sequence.parked_cutlass.position,
		"cutlass_rotation": sequence.parked_cutlass.rotation.y,
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

	# The subject vehicle must come to rest facing northbound (FBI incident
	# report). North is -Z, so a north-facing yaw is 0 radians.
	var facing_north: bool = absf(wrapf(subject_rotation, -PI, PI)) < deg_to_rad(20.0)
	if not facing_north:
		failures.append("subject vehicle does not face northbound (yaw %.1f deg)." % rad_to_deg(subject_rotation))

	# The subject vehicle must be on the EAST side of 82nd Avenue, in the
	# parking area of 12201 SW 82nd Avenue. The FBI report records that
	# Hanlon and Mireles "exited their vehicle (which had struck the wall)
	# and crossed the street to assist", so the subjects' vehicle must have
	# come to rest on the opposite side of the avenue from the substation
	# wall. The wall is west (see CrashGeometry.WALL_POSITION), therefore
	# the subject is east.
	if subject_position.x < 5.0:
		failures.append("subject vehicle did not end on the east side of 82nd Avenue (x=%.2f)." % subject_position.x)

	# Contact with the tree.
	var tree_clearance: float = _circle_rect_clearance(
		subject_position, subject_rotation,
		CrashGeometry.TREE_POSITION, CrashGeometry.TREE_TRUNK_RADIUS
	)
	_assert_contact("subject/tree", tree_clearance, failures)

	# Contact with the parked civilian car.
	var parked_clearance: float = _rect_clearance(
		subject_position, subject_rotation,
		run["cutlass_position"], run["cutlass_rotation"]
	)
	_assert_contact("subject/parked civilian car", parked_clearance, failures)
	if absf(subject_position.x - CrashGeometry.SUBJECT_FINAL.x) > 0.001:
		failures.append("subject vehicle did not reach its documented final position.")

	# Contact with Manauzzi's car.
	var manauzzi_position: Vector3 = run["manauzzi_position"]
	var manauzzi_clearance: float = _rect_clearance(
		subject_position, subject_rotation,
		manauzzi_position, run["manauzzi_rotation"]
	)
	_assert_contact("subject/Manauzzi", manauzzi_clearance, failures)
	if absf(manauzzi_position.x - CrashGeometry.MANAUZZI_FINAL.x) > 0.001:
		failures.append("Manauzzi's car did not reach its documented final position.")

	# Hanlon/Mireles' car must be against the wall, south of the subject vehicle.
	var hanlon_position: Vector3 = run["hanlon_position"]
	var wall_clearance: float = _rect_clearance(
		hanlon_position, run["hanlon_rotation"],
		CrashGeometry.WALL_POSITION, 0.0,
		VEHICLE_HALF_WIDTH, VEHICLE_HALF_LENGTH,
		CrashGeometry.WALL_SIZE.x * 0.5, CrashGeometry.WALL_SIZE.z * 0.5
	)
	_assert_contact("Hanlon/Mireles car/substation wall", wall_clearance, failures)
	# +Z is south, so the Hanlon/Mireles car is south of the subject vehicle
	# when its Z is GREATER than the subject vehicle's Z.
	if hanlon_position.z < subject_position.z:
		failures.append("Hanlon/Mireles car is not south of the subject vehicle.")
	if hanlon_position.x > -6.0:
		failures.append("Hanlon/Mireles car did not come to rest on the west side (x=%.2f)." % hanlon_position.x)

	# Grogan/Dove's car must be behind (south of) the subject vehicle.
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


## Restarting the sequence must return the scene to its opening state and
## then reproduce the identical end state.
func _check_restart(run_a: Dictionary, failures: Array[String]) -> void:
	var sequence: Node3D = load(SEQUENCE_SCRIPT).new()
	root.add_child(sequence)
	sequence.auto_start = false
	sequence.set_process(false)
	sequence.setup()

	sequence.start()
	_drive(sequence)
	if not sequence.is_finished():
		failures.append("initial restart-test run did not reach completion.")

	sequence.start()
	if sequence.get_sequence_time() > 0.0001:
		failures.append("restart did not reset the sequence clock (time=%.4f)." % sequence.get_sequence_time())
	if not sequence.subject_vehicle.position.is_equal_approx(sequence.subject_driver.path.sample_position(0.0)):
		failures.append("restart did not return the subject vehicle to its opening position (%s)." % sequence.subject_vehicle.position)
	if sequence.is_finished():
		failures.append("restart did not clear the finished flag.")

	_drive(sequence)
	if sequence.subject_vehicle.position != (run_a["subject_position"] as Vector3):
		failures.append("restart did not reproduce the subject vehicle's final position.")
	if sequence.manauzzi_car.position != (run_a["manauzzi_position"] as Vector3):
		failures.append("restart did not reproduce Manauzzi's car final position.")
	if sequence.hanlon_mireles_car.position != (run_a["hanlon_position"] as Vector3):
		failures.append("restart did not reproduce the Hanlon/Mireles' car final position.")
	if sequence.grogan_dove_car.position != (run_a["grogan_position"] as Vector3):
		failures.append("restart did not reproduce the Grogan/Dove's car final position.")
	if sequence.subject_vehicle.rotation.y != (run_a["subject_rotation"] as float):
		failures.append("restart did not reproduce the subject vehicle final rotation.")
	if not sequence.is_finished():
		failures.append("replayed run did not reach completion again.")

	root.remove_child(sequence)
	sequence.free()


## No two vehicles may interpenetrate by more than MAX_PAIR_OVERLAP.
func _check_overlap(failures: Array[String]) -> void:
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
		{"name": "cutlass", "vehicle": sequence.parked_cutlass},
	]

	var worst: Dictionary = {}
	while not sequence.is_finished():
		sequence._process(STEP)
		for first_index: int in range(vehicles.size()):
			for second_index: int in range(first_index + 1, vehicles.size()):
				var first: Node3D = vehicles[first_index]["vehicle"]
				var second: Node3D = vehicles[second_index]["vehicle"]
				var depth: float = _overlap_depth(
					first.position, first.rotation.y,
					second.position, second.rotation.y
				)
				var key: String = "%s/%s" % [vehicles[first_index]["name"], vehicles[second_index]["name"]]
				if not worst.has(key) or depth > float(worst[key]["depth"]):
					worst[key] = {"depth": depth, "time": sequence.get_sequence_time()}

	for key: String in worst.keys():
		var entry: Dictionary = worst[key]
		print("VERIFY: worst overlap %-20s %.3f m at t=%.1fs" % [
			key, float(entry["depth"]), float(entry["time"])])
		if float(entry["depth"]) > MAX_PAIR_OVERLAP:
			failures.append("'%s' vehicles overlap by %.2f m at t=%.1fs, which reads as clipping." % [
				key, float(entry["depth"]), float(entry["time"])])

	root.remove_child(sequence)
	sequence.free()


## No vehicle may sink into the wall or the tree.
func _check_obstacles(failures: Array[String]) -> void:
	var sequence: Node3D = load(SEQUENCE_SCRIPT).new()
	root.add_child(sequence)
	sequence.auto_start = false
	sequence.set_process(false)
	sequence.setup()
	sequence.start()

	var wall_face_x: float = CrashGeometry.WALL_POSITION.x + CrashGeometry.WALL_SIZE.x * 0.5
	var wall_min_z: float = CrashGeometry.WALL_POSITION.z - CrashGeometry.WALL_SIZE.z * 0.5
	var wall_max_z: float = CrashGeometry.WALL_POSITION.z + CrashGeometry.WALL_SIZE.z * 0.5
	var worst_wall: float = -INF
	var worst_tree: float = -INF

	while not sequence.is_finished():
		sequence._process(STEP)
		for vehicle: Node3D in [sequence.hanlon_mireles_car, sequence.subject_vehicle, sequence.manauzzi_car]:
			# Penetration past the wall's east face.
			var min_x: float = INF
			for sz: float in [-VEHICLE_HALF_LENGTH, VEHICLE_HALF_LENGTH]:
				for sx: float in [-VEHICLE_HALF_WIDTH, VEHICLE_HALF_WIDTH]:
					var yaw: float = vehicle.rotation.y
					min_x = minf(min_x, vehicle.position.x + sx * cos(yaw) + sz * sin(yaw))
			# The wall is a finite run of masonry, not an infinite line. A
			# vehicle only collides with it while it is alongside the wall's
			# length; a vehicle that passes beyond the end of the wall has
			# not touched it at all.
			var overlaps_wall_span: bool = (vehicle.position.z - VEHICLE_HALF_LENGTH) < wall_max_z \
				and (vehicle.position.z + VEHICLE_HALF_LENGTH) > wall_min_z
			if overlaps_wall_span:
				worst_wall = maxf(worst_wall, wall_face_x - min_x)

			# Penetration into the tree trunk.
			var tree_clearance: float = _circle_rect_clearance(
				vehicle.position, vehicle.rotation.y,
				CrashGeometry.TREE_POSITION, CrashGeometry.TREE_TRUNK_RADIUS
			)
			worst_tree = maxf(worst_tree, -tree_clearance)

	print("VERIFY: deepest wall penetration  %.3f m" % worst_wall)
	print("VERIFY: deepest tree penetration  %.3f m" % worst_tree)
	if worst_wall > MAX_OBSTACLE_PENETRATION:
		failures.append("a vehicle sank %.2f m into the substation wall (limit %.2f m)." % [
			worst_wall, MAX_OBSTACLE_PENETRATION])
	if worst_tree > MAX_OBSTACLE_PENETRATION:
		failures.append("a vehicle sank %.2f m into the tree (limit %.2f m)." % [
			worst_tree, MAX_OBSTACLE_PENETRATION])

	root.remove_child(sequence)
	sequence.free()


## Every vehicle must track its own path, except where the path declares a
## deliberate skid. Slip of 178 degrees was the old default.
func _check_slip(failures: Array[String]) -> void:
	var sequence: Node3D = load(SEQUENCE_SCRIPT).new()
	root.add_child(sequence)
	sequence.auto_start = false
	sequence.set_process(false)
	sequence.setup()
	sequence.start()

	var drivers: Dictionary = {
		"subject": sequence.subject_driver,
		"manauzzi": sequence.manauzzi_driver,
		"hanlon": sequence.hanlon_driver,
		"grogan": sequence.grogan_driver,
		"mcneill": sequence.mcneill_driver,
		"risner": sequence.risner_driver,
	}

	while not sequence.is_finished():
		sequence._process(STEP)
		for key: String in drivers.keys():
			var driver: CrashVehicleDriver = drivers[key]
			var slip: float = absf(driver.get_slip_degrees())
			# Hanlon's Chrysler is documented as spinning out after being
			# struck, so it is allowed to slide. Its slip is bounded by the
			# offsets the path declares.
			if key == "hanlon":
				if slip > 60.0:
					failures.append("'%s' slipped %.1f deg, beyond its declared skid." % [key, slip])
				continue
			if slip > MAX_SLIP_DEGREES:
				failures.append("'%s' slipped %.1f deg at t=%.1fs; a tracking vehicle must not slide." % [
					key, slip, sequence.get_sequence_time()])

	root.remove_child(sequence)
	sequence.free()


## Speed must not jump discontinuously. The old easing drove speed to zero
## at every keyframe, which the per-frame jump check would also catch, but
## this is the explicit guard against reintroducing it.
func _check_speed_continuity(failures: Array[String]) -> void:
	var sequence: Node3D = load(SEQUENCE_SCRIPT).new()
	root.add_child(sequence)
	sequence.auto_start = false
	sequence.set_process(false)
	sequence.setup()
	sequence.start()

	var drivers: Array[CrashVehicleDriver] = [
		sequence.subject_driver,
		sequence.manauzzi_driver,
		sequence.hanlon_driver,
		sequence.grogan_driver,
		sequence.mcneill_driver,
		sequence.risner_driver,
	]

	var previous: Array[float] = []
	for driver: CrashVehicleDriver in drivers:
		previous.append(driver.get_speed())

	while not sequence.is_finished():
		sequence._process(STEP)
		for index: int in range(drivers.size()):
			var jump: float = absf(drivers[index].get_speed() - previous[index])
			if jump > MAX_FRAME_SPEED_JUMP:
				failures.append("a vehicle's speed jumped %.2f m/s in one frame at t=%.1fs." % [
					jump, sequence.get_sequence_time()])
			previous[index] = drivers[index].get_speed()

	root.remove_child(sequence)
	sequence.free()


## The roster and the seat anchors must agree, and every occupant must have
## a seat that resolves to a position in the scene.
func _check_seat_anchors(failures: Array[String]) -> void:
	var sequence: Node3D = load(SEQUENCE_SCRIPT).new()
	root.add_child(sequence)
	sequence.auto_start = false
	sequence.set_process(false)
	sequence.setup()

	var occupants: Array[SceneOccupant] = CrashRoster.build_occupants()
	if occupants.is_empty():
		failures.append("the crash roster is empty; the handoff would have nobody to seat.")
	for occupant: SceneOccupant in occupants:
		var seat: SeatAnchor = sequence.find_seat_for(occupant.occupant_id)
		if seat == null:
			failures.append("occupant '%s' has no seat anchor." % occupant.occupant_id)
			continue
		if seat.occupant_id != occupant.occupant_id:
			failures.append("seat anchor for '%s' names '%s' instead." % [
				occupant.occupant_id, seat.occupant_id])
		if seat.vehicle_id != occupant.vehicle_id:
			failures.append("occupant '%s' is seated in '%s' but the anchor says '%s'." % [
				occupant.occupant_id, occupant.vehicle_id, seat.vehicle_id])
		# The seat must resolve to a finite world position.
		var transform: Transform3D = sequence.get_seat_world_transform(occupant.occupant_id, 0.0)
		if not is_finite(transform.origin.x) or not is_finite(transform.origin.z):
			failures.append("seat anchor for '%s' does not resolve to a finite position." % occupant.occupant_id)

	# Every seat must be on a vehicle that exists in the scene.
	for spec: CrashVehicleSpec in sequence.get_specs().values():
		for seat: SeatAnchor in spec.seats:
			if not seat.has_occupant():
				continue
			if sequence.find_seat_for(seat.occupant_id) == null:
				failures.append("seat '%s' names occupant '%s', who is not in the roster." % [
					seat.vehicle_id, seat.occupant_id])

	print("VERIFY: roster entries checked     %d" % occupants.size())

	root.remove_child(sequence)
	sequence.free()


func _report_separation() -> void:
	pass


## Separating-axis overlap depth for two oriented rectangles on the XZ plane.
## Returns 0.0 when they do not overlap, otherwise the penetration depth.
##
## The penetration depth is the SMALLEST distance one rectangle would have
## to move to separate the pair. For each candidate axis the two bodies
## overlap by (radius_a + radius_b - separation); the smallest such
## overlap across all axes is the depth at which they first touch.
##
## Taking the DEEPEST overlap instead - which is what this function used to
## do - reports the full body length of the car as penetration even when
## the two cars are merely touching along their flanks, and it reported a
## 4.9 m interpenetration between two cars parked 1.9 m apart.
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
		var radius_a: float = _projection_radius(yaw_a, axis)
		var radius_b: float = _projection_radius(yaw_b, axis)
		min_depth = minf(min_depth, radius_a + radius_b - absf(delta.dot(axis)))

	return maxf(0.0, min_depth)


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
