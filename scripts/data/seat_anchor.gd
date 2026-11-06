class_name SeatAnchor
extends Resource

## A seat inside a vehicle, and who occupies it.
##
## This is the interface between the crash cinematic and player control. Both
## read from the same anchor:
##
##   - The camera director can film the crash from inside the player's own
##     seat, so the cinematic and the handoff share a single viewpoint and the
##     camera never has to cut.
##   - When control is handed over, the player is already at the correct place
##     and orientation. The camera snaps from the cinematic rig to first
##     person at this exact transform.
##
## Local coordinates are relative to the vehicle's origin, with the vehicle's
## forward axis along -Z, matching CrashPath's heading convention.

enum SeatId {
	DRIVER,
	FRONT_PASSENGER,
	REAR_LEFT,
	REAR_RIGHT,
}

@export var vehicle_id: String = ""
@export var seat_id: SeatId = SeatId.DRIVER
@export var occupant_id: String = ""

## Offset from the vehicle origin, in vehicle-local space.
@export var local_position: Vector3 = Vector3.ZERO

## Yaw offset applied to the occupant relative to the vehicle's own heading.
## Zero means the occupant faces the same way as the vehicle.
@export var local_yaw_degrees: float = 0.0


func get_vehicle_local_transform() -> Transform3D:
	var basis: Basis = Basis(Vector3.UP, deg_to_rad(local_yaw_degrees))
	return Transform3D(basis, local_position)


## World-space transform of this seat, given a vehicle transform.
func get_world_transform(vehicle_transform: Transform3D) -> Transform3D:
	return vehicle_transform * get_vehicle_local_transform()


func get_world_position(vehicle_transform: Transform3D) -> Vector3:
	return get_world_transform(vehicle_transform).origin


## The direction the occupant is looking, in world space.
func get_world_forward(vehicle_transform: Transform3D) -> Vector3:
	return (-get_world_transform(vehicle_transform).basis.z).normalized()


func has_occupant() -> bool:
	return not occupant_id.is_empty()


func get_seat_label() -> String:
	match seat_id:
		SeatId.DRIVER:
			return "Driver"
		SeatId.FRONT_PASSENGER:
			return "Front passenger"
		SeatId.REAR_LEFT:
			return "Rear left"
		SeatId.REAR_RIGHT:
			return "Rear right"
	return "Unknown seat"


func _to_string() -> String:
	if has_occupant():
		return "%s / %s (%s)" % [vehicle_id, get_seat_label(), occupant_id]
	return "%s / %s (empty)" % [vehicle_id, get_seat_label()]
