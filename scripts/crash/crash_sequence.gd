class_name CrashSequence
extends Node3D

## Drives the deterministic crash opening: approach, felony car stop, first
## ram, U-turn, second ram, impact and settle.

signal phase_changed(phase_name: String, phase_index: int)
signal sequence_finished

const SEQUENCE_DURATION: float = 13.0

const PHASE_APPROACH: int = 0
const PHASE_CAR_STOP: int = 1
const PHASE_FIRST_RAM: int = 2
const PHASE_U_TURN: int = 3
const PHASE_SECOND_RAM: int = 4
const PHASE_IMPACT: int = 5
const PHASE_SETTLED: int = 6

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
var mcneill_car: Node3D
var risner_orrantia_car: Node3D
var parked_cutlass: Node3D
var parked_transam: Node3D
var parked_row: Array[Node3D] = []

var subject_driver: CrashVehicleDriver
var grogan_driver: CrashVehicleDriver
var hanlon_driver: CrashVehicleDriver
var manauzzi_driver: CrashVehicleDriver
var mcneill_driver: CrashVehicleDriver
var risner_driver: CrashVehicleDriver

var _beats: Array[CrashChoreography.Beat] = []
var _specs: Dictionary = {}


func _ready() -> void:
	setup()
	if auto_start:
		start()


func setup() -> void:
	if _is_setup:
		return
	_is_setup = true
	_specs = CrashLayout.build_vehicle_specs()
	_beats = CrashChoreography.build_beats()
	_build_vehicles()
	_build_drivers()
	_validate_drivers()
	_apply_at_time(0.0)


func start() -> void:
	_time = 0.0
	_finished = false
	_current_phase = -1
	_running = true
	_reset_drivers()
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
		_set_phase(CrashChoreography.PHASE_SETTLED)
		sequence_finished.emit()


func is_running() -> bool: return _running
func is_finished() -> bool: return _finished
func get_sequence_time() -> float: return _time
func get_phase_name() -> String: return CrashChoreography.get_phase_name(_current_phase)
func get_phase_index() -> int: return _current_phase
func get_current_beat() -> CrashChoreography.Beat: return CrashChoreography.find_beat(_beats, _time)
func get_beats() -> Array[CrashChoreography.Beat]: return _beats
func get_spec(vehicle_id: String) -> CrashVehicleSpec: return _specs.get(vehicle_id, null)
func get_specs() -> Dictionary: return _specs

func find_seat_for(occupant_id: String) -> SeatAnchor:
	for spec: CrashVehicleSpec in _specs.values():
		var seat: SeatAnchor = spec.find_seat_for_occupant(occupant_id)
		if seat != null:
			return seat
	return null

func get_seat_world_transform(occupant_id: String, time: float) -> Transform3D:
	var seat: SeatAnchor = find_seat_for(occupant_id)
	if seat == null: return Transform3D.IDENTITY
	var vehicle: Node3D = _vehicle_for_id(seat.vehicle_id)
	if vehicle == null: return Transform3D.IDENTITY
	return seat.get_world_transform(vehicle.transform)

func _set_phase(phase_index: int) -> void:
	if phase_index == _current_phase: return
	_current_phase = phase_index
	phase_changed.emit(get_phase_name(), phase_index)

func _apply_at_time(time: float) -> void:
	subject_driver.apply_at_time(time)
	manauzzi_driver.apply_at_time(time)
	hanlon_driver.apply_at_time(time)
	grogan_driver.apply_at_time(time)
	mcneill_driver.apply_at_time(time)
	risner_driver.apply_at_time(time)
	_update_phase_for_time(time)

func _update_phase_for_time(time: float) -> void:
	var beat: CrashChoreography.Beat = CrashChoreography.find_beat(_beats, time)
	_set_phase(beat.phase_index)


func _build_vehicles() -> void:
	subject_vehicle = _create_vehicle(CrashRoster.VEHICLE_SUBJECT)
	grogan_dove_car = _create_vehicle(CrashRoster.VEHICLE_GROGAN_DOVE)
	hanlon_mireles_car = _create_vehicle(CrashRoster.VEHICLE_HANLON_MIRELES)
	manauzzi_car = _create_vehicle(CrashRoster.VEHICLE_MANAUZZI)
	mcneill_car = _create_vehicle(CrashRoster.VEHICLE_MCNEILL)
	risner_orrantia_car = _create_vehicle(CrashRoster.VEHICLE_RISNER_ORRANTIA)

	parked_cutlass = _create_vehicle(CrashRoster.VEHICLE_PARKED_CUTLASS)
	parked_cutlass.position = CrashGeometry.PARKED_CUTLASS_FINAL
	parked_cutlass.rotation.y = 0.0

	# The parked civilian row, running away from the subject vehicle towards the house.
	parked_row.clear()
	for index: int in range(CrashGeometry.PARKED_ROW.size()):
		var position: Vector3 = CrashGeometry.PARKED_ROW[index]
		var car: Node3D = _create_vehicle(CrashRoster.VEHICLE_PARKED_TRANSAM)
		if index == 0:
			car.name = CrashRoster.VEHICLE_PARKED_TRANSAM
			parked_transam = car
		else:
			car.name = "%s_%d" % [CrashRoster.VEHICLE_PARKED_TRANSAM, index]
		car.position = position
		car.rotation.y = 0.0
		parked_row.append(car)


func _create_vehicle(vehicle_id: String) -> Node3D:
	var spec: CrashVehicleSpec = _specs[vehicle_id]
	var vehicle: Node3D = CrashVehicleFactory.create_vehicle(
		spec.length, spec.width, spec.body_color, spec.roof_color
	)
	vehicle.name = spec.vehicle_id
	add_child(vehicle)
	return vehicle


func _build_drivers() -> void:
	subject_driver = _make_driver(subject_vehicle, CrashRoster.VEHICLE_SUBJECT,
		CrashGeometry.subject_path(), CrashGeometry.subject_speed_profile())
	manauzzi_driver = _make_driver(manauzzi_car, CrashRoster.VEHICLE_MANAUZZI,
		CrashGeometry.manauzzi_path(), CrashGeometry.manauzzi_speed_profile())
	hanlon_driver = _make_driver(hanlon_mireles_car, CrashRoster.VEHICLE_HANLON_MIRELES,
		CrashGeometry.hanlon_path(), CrashGeometry.hanlon_speed_profile())
	grogan_driver = _make_driver(grogan_dove_car, CrashRoster.VEHICLE_GROGAN_DOVE,
		CrashGeometry.grogan_path(), CrashGeometry.grogan_speed_profile())
	mcneill_driver = _make_driver(mcneill_car, CrashRoster.VEHICLE_MCNEILL,
		CrashGeometry.mcneill_path(), CrashGeometry.mcneill_speed_profile())
	risner_driver = _make_driver(risner_orrantia_car, CrashRoster.VEHICLE_RISNER_ORRANTIA,
		CrashGeometry.risner_path(), CrashGeometry.risner_speed_profile())


func _make_driver(vehicle: Node3D, vehicle_id: String, path: CrashPath, speed: CrashSpeedProfile) -> CrashVehicleDriver:
	return CrashVehicleDriver.new(vehicle, path, speed, _specs[vehicle_id])


func _validate_drivers() -> void:
	_validate_driver("subject", subject_driver)
	_validate_driver("manauzzi", manauzzi_driver)
	_validate_driver("hanlon", hanlon_driver)
	_validate_driver("grogan", grogan_driver)
	_validate_driver("mcneill", mcneill_driver)
	_validate_driver("risner", risner_driver)


func _validate_driver(label: String, driver: CrashVehicleDriver) -> void:
	if driver == null or not driver.is_valid():
		push_error("CrashSequence: the '%s' driver is not valid." % label)
		return
	var needed: float = driver.speed_profile.distance_at(driver.speed_profile.get_end_time())
	var available: float = driver.path.get_length()
	if available < needed - 0.01:
		push_error("CrashSequence: the '%s' path is %.2f m but its speed profile travels %.2f m; the vehicle would stop short." % [label, available, needed])


func _reset_drivers() -> void:
	subject_driver.reset()
	manauzzi_driver.reset()
	hanlon_driver.reset()
	grogan_driver.reset()
	mcneill_driver.reset()
	risner_driver.reset()


func _vehicle_for_id(vehicle_id: String) -> Node3D:
	match vehicle_id:
		CrashRoster.VEHICLE_SUBJECT: return subject_vehicle
		CrashRoster.VEHICLE_GROGAN_DOVE: return grogan_dove_car
		CrashRoster.VEHICLE_HANLON_MIRELES: return hanlon_mireles_car
		CrashRoster.VEHICLE_MANAUZZI: return manauzzi_car
		CrashRoster.VEHICLE_MCNEILL: return mcneill_car
		CrashRoster.VEHICLE_RISNER_ORRANTIA: return risner_orrantia_car
		CrashRoster.VEHICLE_PARKED_CUTLASS: return parked_cutlass
		CrashRoster.VEHICLE_PARKED_TRANSAM: return parked_transam
	return null