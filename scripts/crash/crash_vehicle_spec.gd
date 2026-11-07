class_name CrashVehicleSpec
extends Resource

## A vehicle's dimensions, appearance and seats.
##
## The spec is the single source of truth for a vehicle's size. Both the
## geometry builder and the verifier read it, so a change to a vehicle's
## dimensions automatically updates the collision checks.
##
## Seat positions are stored as SeatAnchor resources in vehicle-local space,
## with the vehicle's forward axis along -Z. For a vehicle whose width is
## `width`, the driver sits on the left, which is -X in that frame.

@export var vehicle_id: String = ""
@export var display_name: String = ""
@export var length: float = 4.9
@export var width: float = 1.9
@export var body_color: Color = Color(0.12, 0.12, 0.14)
@export var roof_color: Color = Color(0.10, 0.10, 0.12)
@export var seats: Array[SeatAnchor] = []


func get_half_length() -> float:
	return length * 0.5


func get_half_width() -> float:
	return width * 0.5


func find_seat(seat_id: SeatAnchor.SeatId) -> SeatAnchor:
	for seat: SeatAnchor in seats:
		if seat.seat_id == seat_id:
			return seat
	return null


func find_seat_for_occupant(occupant_id: String) -> SeatAnchor:
	for seat: SeatAnchor in seats:
		if seat.occupant_id == occupant_id:
			return seat
	return null


func get_occupied_seats() -> Array[SeatAnchor]:
	var occupied: Array[SeatAnchor] = []
	for seat: SeatAnchor in seats:
		if seat.has_occupant():
			occupied.append(seat)
	return occupied
