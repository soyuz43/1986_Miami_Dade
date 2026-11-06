class_name CrashVehicleDriver
extends RefCounted

## Drives one vehicle along a CrashPath at the speeds given by a
## CrashSpeedProfile.
##
## This replaces the old keyframe evaluator, which lerped position and yaw
## independently with the same eased parameter. That produced two problems:
##
##   1. Heading was decoupled from direction of travel, so vehicles showed up
##      to 178 degrees of slip angle (driving sideways, or backwards).
##   2. The easing was applied per keyframe segment, so speed fell to zero
##      at every keyframe boundary and the vehicles stuttered.
##
## Here, the sequence time drives a distance via the speed profile, and the
## distance drives both the position and the heading from the same path. Slip
## is therefore zero by construction unless the path declares a deliberate
## skid with a heading override.

var vehicle: Node3D
var path: CrashPath
var speed_profile: CrashSpeedProfile
var spec: CrashVehicleSpec

var _current_time: float = 0.0
var _current_distance: float = 0.0


func _init(
		vehicle_node: Node3D,
		vehicle_path: CrashPath,
		vehicle_speed: CrashSpeedProfile,
		vehicle_spec: CrashVehicleSpec
	) -> void:
	vehicle = vehicle_node
	path = vehicle_path
	speed_profile = vehicle_speed
	spec = vehicle_spec


func is_valid() -> bool:
	return vehicle != null and path != null and speed_profile != null \
		and path.is_valid() and speed_profile.is_valid()


## Distance travelled by the given sequence time.
func distance_at(time: float) -> float:
	return speed_profile.distance_at(time)


## Apply the transform for the given sequence time.
func apply_at_time(time: float) -> void:
	if vehicle == null or not path.is_valid():
		return
	_current_time = time
	_current_distance = speed_profile.distance_at(time)
	var position: Vector3 = path.sample_position(_current_distance)
	var yaw: float = path.sample_yaw(_current_distance)
	vehicle.position = position
	vehicle.rotation.y = yaw


## The world transform of the vehicle at the given sequence time, without
## mutating the vehicle. Used by the camera director and the seat anchors.
func transform_at_time(time: float) -> Transform3D:
	var distance: float = speed_profile.distance_at(time)
	var basis: Basis = Basis(Vector3.UP, path.sample_yaw(distance))
	return Transform3D(basis, path.sample_position(distance))


## Current slip angle in degrees: how far the vehicle's nose is from the
## direction it is travelling. Zero unless the path declares a skid.
func get_slip_degrees() -> float:
	if path == null or not path.is_valid():
		return 0.0
	return path.sample_slip_degrees(_current_distance)


## Current speed in m/s.
func get_speed() -> float:
	if speed_profile == null:
		return 0.0
	return speed_profile.speed_at(_current_time)


## True once the vehicle has reached the end of its speed profile.
func is_finished() -> bool:
	if speed_profile == null:
		return true
	return _current_time >= speed_profile.get_end_time()


## Reset to the opening state.
func reset() -> void:
	_current_time = speed_profile.get_start_time() if speed_profile != null else 0.0
	_current_distance = 0.0
	if vehicle != null and path != null and path.is_valid():
		vehicle.position = path.sample_position(0.0)
		vehicle.rotation.y = path.sample_yaw(0.0)
