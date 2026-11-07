class_name CrashLayout
extends RefCounted

## Vehicle specifications and seat anchors for the crash scene.
##
## Seat positions are in vehicle-local space, with the vehicle's forward axis
## along -Z. A vehicle's driver sits on the left, which is -X in that frame,
## so the driver's door is on the -X side. That matters for the crash: the
## FBI report has the subject vehicle's driver door jammed against the parked
## Cutlass, and Manauzzi's rams land on that same side.
##
## Occupant-to-seat assignment comes from CrashRoster, so the two stay in
## step. Seat geometry itself is an ASSUMPTION: the sources name occupants
## and vehicles but do not describe the interior layout of any car.

const SEAT_HEIGHT: float = 0.62
const SEAT_FRONT_OFFSET: float = -0.35
const SEAT_REAR_OFFSET: float = 1.25
const SEAT_SIDE_OFFSET: float = 0.42


static func build_vehicle_specs() -> Dictionary:
	var specs: Dictionary = {}

	specs[CrashRoster.VEHICLE_SUBJECT] = _make_spec(
		CrashRoster.VEHICLE_SUBJECT,
		"Subject vehicle - 1982 Chevrolet Monte Carlo",
		4.90, 1.90,
		Color(0.07, 0.07, 0.08), Color(0.05, 0.05, 0.06),
		{
			SeatAnchor.SeatId.DRIVER: ["michael_platt"],
			SeatAnchor.SeatId.FRONT_PASSENGER: ["william_matix"],
		}
	)

	specs[CrashRoster.VEHICLE_GROGAN_DOVE] = _make_spec(
		CrashRoster.VEHICLE_GROGAN_DOVE,
		"FBI car - Buick Century (Grogan / Dove)",
		4.90, 1.90,
		Color(0.72, 0.66, 0.20), Color(0.30, 0.26, 0.12),
		{
			SeatAnchor.SeatId.DRIVER: ["benjamin_grogan"],
			SeatAnchor.SeatId.FRONT_PASSENGER: ["jerry_dove"],
		}
	)

	specs[CrashRoster.VEHICLE_HANLON_MIRELES] = _make_spec(
		CrashRoster.VEHICLE_HANLON_MIRELES,
		"FBI car - 1983 Chrysler (Hanlon / Mireles)",
		4.90, 1.90,
		Color(0.60, 0.48, 0.16), Color(0.32, 0.26, 0.10),
		{
			SeatAnchor.SeatId.DRIVER: ["john_hanlon"],
			SeatAnchor.SeatId.FRONT_PASSENGER: ["edmundo_mireles"],
		}
	)

	specs[CrashRoster.VEHICLE_MANAUZZI] = _make_spec(
		CrashRoster.VEHICLE_MANAUZZI,
		"FBI car - Buick (Manauzzi)",
		4.90, 1.90,
		Color(0.36, 0.37, 0.39), Color(0.30, 0.31, 0.33),
		{
			SeatAnchor.SeatId.DRIVER: ["richard_manauzzi"],
		}
	)

	specs[CrashRoster.VEHICLE_MCNEILL] = _make_spec(
		CrashRoster.VEHICLE_MCNEILL,
		"FBI car - McNeill",
		4.90, 1.90,
		Color(0.30, 0.32, 0.36), Color(0.26, 0.28, 0.32),
		{
			SeatAnchor.SeatId.DRIVER: ["gordon_mcneill"],
		}
	)

	specs[CrashRoster.VEHICLE_RISNER_ORRANTIA] = _make_spec(
		CrashRoster.VEHICLE_RISNER_ORRANTIA,
		"FBI car - Risner / Orrantia",
		4.90, 1.90,
		Color(0.78, 0.78, 0.75), Color(0.66, 0.66, 0.64),
		{
			SeatAnchor.SeatId.DRIVER: ["gilbert_orrantia"],
			SeatAnchor.SeatId.FRONT_PASSENGER: ["ronald_risner"],
		}
	)

	# --- Civilian vehicles in the scene -------------------------------
	# MH-1: "Matix could not open his door because it was wedged against a
	# shiny black Cutlass parked in the driveway, belonging to resident
	# Cory Sukert." The Cutlass is the parked car the driver door jams against.
	specs[CrashRoster.VEHICLE_PARKED_CUTLASS] = _make_spec(
		CrashRoster.VEHICLE_PARKED_CUTLASS,
		"Parked civilian car - Cutlass",
		4.90, 1.90,
		Color(0.05, 0.05, 0.06), Color(0.04, 0.04, 0.05),
		{}
	)

	# MH-1 names a 20-year-old bottlebrush tree struck in the yard.
	specs[CrashRoster.VEHICLE_PARKED_TRANSAM] = _make_spec(
		CrashRoster.VEHICLE_PARKED_TRANSAM,
		"Parked civilian car - Trans Am",
		4.90, 1.90,
		Color(0.90, 0.45, 0.05), Color(0.85, 0.40, 0.05),
		{}
	)

	return specs


static func _make_spec(
		vehicle_id: String,
		display_name: String,
		length: float,
		width: float,
		body_color: Color,
		roof_color: Color,
		occupants_by_seat: Dictionary
	) -> CrashVehicleSpec:
	var spec: CrashVehicleSpec = CrashVehicleSpec.new()
	spec.vehicle_id = vehicle_id
	spec.display_name = display_name
	spec.length = length
	spec.width = width
	spec.body_color = body_color
	spec.roof_color = roof_color

	for seat_id: int in occupants_by_seat.keys():
		var anchor: SeatAnchor = _make_seat(vehicle_id, seat_id as SeatAnchor.SeatId)
		var occupant_ids: Array = occupants_by_seat[seat_id]
		if occupant_ids.size() > 0:
			anchor.occupant_id = String(occupant_ids[0])
		spec.seats.append(anchor)

	return spec


static func _make_seat(vehicle_id: String, seat_id: SeatAnchor.SeatId) -> SeatAnchor:
	var anchor: SeatAnchor = SeatAnchor.new()
	anchor.vehicle_id = vehicle_id
	anchor.seat_id = seat_id

	var is_front: bool = seat_id == SeatAnchor.SeatId.DRIVER \
		or seat_id == SeatAnchor.SeatId.FRONT_PASSENGER
	var side: float = -1.0
	match seat_id:
		SeatAnchor.SeatId.DRIVER:
			side = -1.0
		SeatAnchor.SeatId.FRONT_PASSENGER:
			side = 1.0
		SeatAnchor.SeatId.REAR_LEFT:
			side = -1.0
		SeatAnchor.SeatId.REAR_RIGHT:
			side = 1.0

	anchor.local_position = Vector3(
		side * SEAT_SIDE_OFFSET,
		SEAT_HEIGHT,
		SEAT_FRONT_OFFSET if is_front else SEAT_REAR_OFFSET
	)
	return anchor
