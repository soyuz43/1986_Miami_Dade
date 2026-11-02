class_name CrashSequence
extends Node3D

## Drives the deterministic crash opening: approach, felony car stop, first ram,
## U-turn, second ram, impact and settle.
##
## The sequence is a scripted presentation, not a simulation. It is keyframed
## against an explicit timeline of seconds so that every run is identical.
## Event timings below follow the relative phase order documented in
## docs/RESEARCH_crash.md. Absolute wall-clock times are deliberately NOT used:
## the FBI incident report puts the car stop at approximately 9:32 a.m. while
## the Miami Herald reconstruction puts it at approximately 9:19 a.m., and that
## discrepancy is unresolved.
##
## Vehicle roles (see docs/RESEARCH_crash.md for sourcing):
##   SubjectVehicle  - 1982 Chevrolet Monte Carlo, Platt (driver) and Matix (passenger)
##   GroganDoveCar   - Buick Century, SA Grogan (driver) and SA Dove (passenger)
##   HanlonMirelesCar- Chrysler, SA Hanlon (driver) and SA Mireles (passenger)
##   ManauzziCar     - Buick, SA Manauzzi (driver)

signal phase_changed(phase_name: String, phase_index: int)
signal sequence_finished

const PHASE_NAMES: Array[String] = [
	"Approach",
	"Car stop ordered",
	"First ram",
	"U-turn",
	"Second ram",
	"Impact",
	"Settled",
]

const PHASE_APPROACH: int = 0
const PHASE_CAR_STOP: int = 1
const PHASE_FIRST_RAM: int = 2
const PHASE_U_TURN: int = 3
const PHASE_SECOND_RAM: int = 4
const PHASE_IMPACT: int = 5
const PHASE_SETTLED: int = 6

const SEQUENCE_DURATION: float = 13.0

const SUBJECT_COLOR: Color = Color(0.07, 0.07, 0.08)
const GROGAN_DOVE_COLOR: Color = Color(0.72, 0.66, 0.20)
const HANLON_MIRELES_COLOR: Color = Color(0.60, 0.48, 0.16)
const MANAUZZI_COLOR: Color = Color(0.36, 0.37, 0.39)
const PARKED_CAR_COLOR: Color = Color(0.05, 0.05, 0.06)

@export var playback_speed: float = 1.0
@export var auto_start: bool = true

var _time: float = 0.0
var _running: bool = false
var _finished: bool = false
var _current_phase: int = -1
var _is_setup: bool = false

var subject_vehicle: Node3D
var grogan_dove_car: Node3D
var hanlon_mireles_car: Node3D
var manauzzi_car: Node3D
var parked_car: Node3D

var _subject_path: PackedVector3Array = PackedVector3Array()
var _subject_rotations: PackedFloat32Array = PackedFloat32Array()
var _manauzzi_path: PackedVector3Array = PackedVector3Array()
var _manauzzi_rotations: PackedFloat32Array = PackedFloat32Array()
var _hanlon_path: PackedVector3Array = PackedVector3Array()
var _hanlon_rotations: PackedFloat32Array = PackedFloat32Array()
var _grogan_path: PackedVector3Array = PackedVector3Array()
var _grogan_rotations: PackedFloat32Array = PackedFloat32Array()

var _subject_keys: PackedFloat32Array = PackedFloat32Array()
var _manauzzi_keys: PackedFloat32Array = PackedFloat32Array()
var _hanlon_keys: PackedFloat32Array = PackedFloat32Array()
var _grogan_keys: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	setup()
	if auto_start:
		start()


## Builds the vehicles and paths. Separate from _ready so headless verification
## can drive the sequence without depending on scene-tree readiness.
func setup() -> void:
	if _is_setup:
		return
	_is_setup = true
	_build_vehicles()
	_build_paths()
	_validate_paths()
	_apply_at_time(0.0)


## Every path must have exactly one rotation and one key per point, and the
## keys must be strictly increasing. A mismatch here silently drops the last
## keyframe, which would leave a vehicle short of its documented resting place.
func _validate_paths() -> void:
	_validate_path("subject", _subject_path, _subject_rotations, _subject_keys)
	_validate_path("manauzzi", _manauzzi_path, _manauzzi_rotations, _manauzzi_keys)
	_validate_path("hanlon", _hanlon_path, _hanlon_rotations, _hanlon_keys)
	_validate_path("grogan", _grogan_path, _grogan_rotations, _grogan_keys)


func _validate_path(
	label: String,
	path: PackedVector3Array,
	rotations: PackedFloat32Array,
	keys: PackedFloat32Array
) -> void:
	if path.size() != rotations.size() or path.size() != keys.size():
		push_error("Crash path '%s' has mismatched lengths: %d points, %d rotations, %d keys." % [
			label, path.size(), rotations.size(), keys.size()
		])
		return
	for index: int in range(keys.size() - 1):
		if keys[index + 1] <= keys[index]:
			push_error("Crash path '%s' has non-increasing keys at index %d." % [label, index])


func start() -> void:
	_time = 0.0
	_finished = false
	_current_phase = -1
	_running = true
	_apply_at_time(0.0)


func _process(delta: float) -> void:
	if not _running:
		return
	_time += delta * playback_speed
	if _time >= SEQUENCE_DURATION:
		_time = SEQUENCE_DURATION
	_apply_at_time(_time)
	if _time >= SEQUENCE_DURATION and not _finished:
		_finished = true
		_running = false
		_set_phase(PHASE_SETTLED)
		sequence_finished.emit()


func is_running() -> bool:
	return _running


func is_finished() -> bool:
	return _finished


func get_sequence_time() -> float:
	return _time


func get_phase_name() -> String:
	if _current_phase < 0 or _current_phase >= PHASE_NAMES.size():
		return "Idle"
	return PHASE_NAMES[_current_phase]


func _set_phase(phase_index: int) -> void:
	if phase_index == _current_phase:
		return
	_current_phase = phase_index
	phase_changed.emit(get_phase_name(), phase_index)


## Sample every vehicle transform at the given sequence time and update phase state.
func _apply_at_time(time: float) -> void:
	_apply_vehicle(subject_vehicle, _subject_path, _subject_rotations, _subject_keys, time)
	_apply_vehicle(manauzzi_car, _manauzzi_path, _manauzzi_rotations, _manauzzi_keys, time)
	_apply_vehicle(hanlon_mireles_car, _hanlon_path, _hanlon_rotations, _hanlon_keys, time)
	_apply_vehicle(grogan_dove_car, _grogan_path, _grogan_rotations, _grogan_keys, time)
	_update_phase_for_time(time)


func _apply_vehicle(
	vehicle: Node3D,
	path: PackedVector3Array,
	rotations: PackedFloat32Array,
	keys: PackedFloat32Array,
	time: float
) -> void:
	if vehicle == null or path.size() < 2 or keys.size() < 2:
		return
	var segment_index: int = _find_segment(keys, time)
	var key_start: float = keys[segment_index]
	var key_end: float = keys[segment_index + 1]
	var span: float = maxf(key_end - key_start, 0.0001)
	var local_t: float = clampf((time - key_start) / span, 0.0, 1.0)
	local_t = _ease_in_out(local_t)
	var position: Vector3 = path[segment_index].lerp(path[segment_index + 1], local_t)
	var yaw: float = lerpf(rotations[segment_index], rotations[segment_index + 1], local_t)
	vehicle.position = position
	vehicle.rotation.y = yaw


func _find_segment(keys: PackedFloat32Array, time: float) -> int:
	for index: int in range(keys.size() - 1):
		if time <= keys[index + 1]:
			return index
	return keys.size() - 2


func _ease_in_out(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)


## Build the placeholder vehicles and place them in their starting positions.
func _build_vehicles() -> void:
	subject_vehicle = _create_vehicle("SubjectVehicle", SUBJECT_COLOR, Color(0.05, 0.05, 0.06))
	grogan_dove_car = _create_vehicle("GroganDoveCar", GROGAN_DOVE_COLOR, Color(0.30, 0.26, 0.12))
	hanlon_mireles_car = _create_vehicle("HanlonMirelesCar", HANLON_MIRELES_COLOR, Color(0.32, 0.26, 0.10))
	manauzzi_car = _create_vehicle("ManauzziCar", MANAUZZI_COLOR, Color(0.30, 0.31, 0.33))
	parked_car = _create_vehicle("ParkedCivilianCar", PARKED_CAR_COLOR, Color(0.04, 0.04, 0.05))
	parked_car.position = CrashBlockout.PARKED_CAR_FINAL
	parked_car.rotation.y = deg_to_rad(90.0)
	CrashVehicleFactory.add_label(parked_car, "Parked civilian car", 1.9)

	CrashVehicleFactory.add_label(subject_vehicle, "Subject vehicle - Monte Carlo", 1.9)
	CrashVehicleFactory.add_label(manauzzi_car, "FBI car - Manauzzi", 1.9)
	CrashVehicleFactory.add_label(hanlon_mireles_car, "FBI car - Hanlon / Mireles", 1.9)
	CrashVehicleFactory.add_label(grogan_dove_car, "FBI car - Grogan / Dove", 1.9)


func _create_vehicle(node_name: String, body_color: Color, roof_color: Color) -> Node3D:
	var vehicle: Node3D = CrashVehicleFactory.create_vehicle(4.9, 1.9, body_color, roof_color)
	vehicle.name = node_name
	add_child(vehicle)
	return vehicle


## Define the keyframed paths.
##
## Positions are in metres on the blockout's coordinate system. The road runs
## along Z (north/south). During the approach the subject vehicle travels
## southbound (+Z); the U-turn reverses it to face northbound (-Z), matching
## the FBI incident report's statement that the suspect's vehicle came to rest
## "facing northbound".
func _build_paths() -> void:
	# --- Subject vehicle: southbound in its own lane, swerves right off the
	#     pavement during the stop, U-turns, then runs northbound into the front
	#     yard. It ends facing northbound, as the FBI incident report states.
	_subject_path = PackedVector3Array([
		CrashBlockout.SUBJECT_APPROACH,
		Vector3(-4.0, 0.0, -14.0),
		Vector3(-4.2, 0.0, -6.0),
		Vector3(-5.4, 0.0, -1.0),
		Vector3(-6.8, 0.0, -1.0),
		Vector3(-7.8, 0.0, -4.0),
		Vector3(-8.2, 0.0, -6.0),
		Vector3(-8.5, 0.0, -11.0),
		Vector3(-8.6, 0.0, -15.0),
		CrashBlockout.SUBJECT_FINAL,
	])
	_subject_rotations = PackedFloat32Array([
		deg_to_rad(180.0),
		deg_to_rad(180.0),
		deg_to_rad(175.0),
		deg_to_rad(165.0),
		deg_to_rad(200.0),
		deg_to_rad(280.0),
		deg_to_rad(330.0),
		deg_to_rad(350.0),
		deg_to_rad(358.0),
		deg_to_rad(360.0),
	])
	_subject_keys = PackedFloat32Array([
		0.0, 3.2, 4.6, 6.0, 7.2, 8.4, 9.6, 10.6, 11.4, 12.2,
	])

	# --- Manauzzi car: closes from behind in the next lane west, moves toward
	#     the subject car's driver side for the first ram, then drives with it
	#     through the U-turn and finishes alongside it, in contact.
	_manauzzi_path = PackedVector3Array([
		CrashBlockout.MANAUZZI_APPROACH,
		Vector3(-7.6, 0.0, -34.0),
		Vector3(-7.6, 0.0, -20.0),
		Vector3(-7.2, 0.0, -12.0),
		Vector3(-6.8, 0.0, -7.0),
		Vector3(-8.2, 0.0, -3.0),
		Vector3(-9.4, 0.0, -3.0),
		Vector3(-10.0, 0.0, -3.0),
		Vector3(-10.6, 0.0, -7.0),
		Vector3(-11.0, 0.0, -14.0),
		CrashBlockout.MANAUZZI_FINAL,
	])
	_manauzzi_rotations = PackedFloat32Array([
		deg_to_rad(180.0),
		deg_to_rad(180.0),
		deg_to_rad(180.0),
		deg_to_rad(178.0),
		deg_to_rad(172.0),
		deg_to_rad(230.0),
		deg_to_rad(290.0),
		deg_to_rad(320.0),
		deg_to_rad(342.0),
		deg_to_rad(355.0),
		deg_to_rad(360.0),
	])
	_manauzzi_keys = PackedFloat32Array([
		0.0, 3.0, 4.4, 5.2, 6.4, 7.4, 8.6, 9.6, 10.6, 11.4, 12.2,
	])

	# --- Hanlon/Mireles car: starts in the lane east of the subject car, pulls
	#     up on its passenger side during the stop, is struck by the swerving
	#     subject vehicle, spins out, and comes to rest against the substation
	#     wall south of the scene.
	_hanlon_path = PackedVector3Array([
		CrashBlockout.HANLON_APPROACH,
		Vector3(3.6, 0.0, -30.0),
		Vector3(3.2, 0.0, -16.0),
		Vector3(1.6, 0.0, -8.0),
		Vector3(0.2, 0.0, -3.0),
		Vector3(-0.4, 0.0, 0.4),
		Vector3(-1.6, 0.0, -1.0),
		Vector3(-5.0, 0.0, -2.0),
		Vector3(-9.4, 0.0, -3.2),
		Vector3(-11.9, 0.0, -5.6),
		CrashBlockout.HANLON_FINAL,
	])
	_hanlon_rotations = PackedFloat32Array([
		deg_to_rad(180.0),
		deg_to_rad(180.0),
		deg_to_rad(180.0),
		deg_to_rad(180.0),
		deg_to_rad(185.0),
		deg_to_rad(205.0),
		deg_to_rad(250.0),
		deg_to_rad(275.0),
		deg_to_rad(285.0),
		deg_to_rad(290.0),
		deg_to_rad(290.0),
	])
	_hanlon_keys = PackedFloat32Array([
		0.0, 3.0, 4.2, 4.9, 5.8, 6.8, 8.0, 9.0, 10.2, 10.8, 11.4,
	])

	# --- Grogan/Dove car: initiates the felony car stop from directly behind in
	#     the lane east of the subject car, then makes a U-turn further south
	#     and parks behind the subject vehicle.
	_grogan_path = PackedVector3Array([
		CrashBlockout.GROGAN_APPROACH,
		Vector3(-0.4, 0.0, -46.0),
		Vector3(-0.4, 0.0, -30.0),
		Vector3(-0.6, 0.0, -20.0),
		Vector3(-1.4, 0.0, -12.0),
		Vector3(-2.8, 0.0, -6.0),
		Vector3(-3.8, 0.0, -6.6),
		Vector3(-4.2, 0.0, -8.4),
		Vector3(-4.4, 0.0, -10.0),
		CrashBlockout.GROGAN_FINAL,
	])
	_grogan_rotations = PackedFloat32Array([
		deg_to_rad(180.0),
		deg_to_rad(180.0),
		deg_to_rad(180.0),
		deg_to_rad(180.0),
		deg_to_rad(178.0),
		deg_to_rad(172.0),
		deg_to_rad(240.0),
		deg_to_rad(320.0),
		deg_to_rad(350.0),
		deg_to_rad(358.0),
	])
	_grogan_keys = PackedFloat32Array([
		0.0, 2.8, 4.0, 4.6, 5.6, 6.6, 7.8, 9.0, 10.2, 11.2,
	])

## Map sequence time to a narrative phase.
func _update_phase_for_time(time: float) -> void:
	if time < 2.6:
		_set_phase(PHASE_APPROACH)
	elif time < 4.0:
		_set_phase(PHASE_CAR_STOP)
	elif time < 6.0:
		_set_phase(PHASE_FIRST_RAM)
	elif time < 7.6:
		_set_phase(PHASE_U_TURN)
	elif time < 8.8:
		_set_phase(PHASE_SECOND_RAM)
	elif time < 10.6:
		_set_phase(PHASE_IMPACT)
	else:
		_set_phase(PHASE_SETTLED)
