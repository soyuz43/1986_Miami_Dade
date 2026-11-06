class_name CrashRoster
extends RefCounted

## The people in the crash scene, and where they were sitting.
##
## Sourcing: docs/RESEARCH_crash.md. Vehicle roles follow the FBI incident
## report (FBI-1) and the FBI case synopsis (FBI-2); the Miami Herald
## reconstruction (MH-1) contributes physical detail such as the Cutlass in
## the driveway and the bottlebrush tree.
##
## The FBI letter designations (Car A through Car E) are deliberately not
## used. FBI-1 shifts them between passages, so this project refers to agents
## by name throughout.
##
## Seat assignments for the FBI cars follow the driver/passenger pairings the
## sources state explicitly. Where a source does not state a passenger's seat
## (the FBI cars are described only by occupant, not by position in the
## vehicle), the assignment is an explicit ASSUMPTION and is flagged as such
## in `source_note` so it is auditable rather than silently baked in.

const VEHICLE_SUBJECT: String = "subject_vehicle"
const VEHICLE_GROGAN_DOVE: String = "grogan_dove_car"
const VEHICLE_HANLON_MIRELES: String = "hanlon_mireles_car"
const VEHICLE_MANAUZZI: String = "manauzzi_car"
const VEHICLE_MCNEILL: String = "mcneill_car"
const VEHICLE_RISNER_ORRANTIA: String = "risner_orrantia_car"

## Vehicle ids as used by CrashBlockout's node names.
const VEHICLE_PARKED_CUTLASS: String = "parked_cutlass"
const VEHICLE_PARKED_TRANSAM: String = "parked_transam"


static func build_occupants() -> Array[SceneOccupant]:
	var occupants: Array[SceneOccupant] = []

	# --- The subjects -------------------------------------------------
	# FBI-1/FBI-2: Platt drove, Matix rode as passenger. FBI ballistics
	# attribute the Mini-14 to Platt; MH-1 reported agents on scene thought
	# Matix carried it and said the identification was in doubt. The FBI
	# attribution governs, but the dispute is carried in the note so the
	# simulation never presents it as settled.
	occupants.append(_make(
		"michael_platt", "Michael Lee Platt", "Subject - driver",
		ActorProfile.Faction.SUSPECT, VEHICLE_SUBJECT, SeatAnchor.SeatId.DRIVER,
		"ruger_mini14", false,
		"FBI ballistics attribute the Mini-14 to Platt (FBI-1, FBI-2). " \
		+ "MH-1 reports agents at the scene identified Matix as the carrier " \
		+ "and says the identification was in doubt. The FBI attribution governs; " \
		+ "the dispute is unresolved and is surfaced, not hidden."
	))
	occupants.append(_make(
		"william_matix", "William Russell Matix", "Subject - passenger",
		ActorProfile.Faction.SUSPECT, VEHICLE_SUBJECT, SeatAnchor.SeatId.FRONT_PASSENGER,
		"", false,
		"Disputed Mini-14 carrier: FBI-1/FBI-2 say Platt, MH-1 says Matix. " \
		+ "No weapon is assigned here because the attribution is disputed."
	))

	# --- The FBI agents ----------------------------------------------
	# FBI-1: "Manauzzi's revolver, resting beside him on the seat, was knocked
	# to the floor during the crash. He exited unarmed and took cover behind
	# a wall on the west side of 82nd Avenue."
	occupants.append(_make(
		"richard_manauzzi", "Richard A. Manauzzi", "FBI - agent, Car B",
		ActorProfile.Faction.FBI, VEHICLE_MANAUZZI, SeatAnchor.SeatId.DRIVER,
		"", true,
		"Performed the first and second rams (FBI-2). FBI-1 records that his " \
		+ "revolver was knocked to the floor during the crash and that he exited " \
		+ "unarmed, taking cover behind the wall west of 82nd Avenue."
	))

	# FBI-1: "Hanlon and Mireles exited their vehicle (which had struck the " \
	# "wall) and crossed the street to assist." His revolver also went to the floor.
	occupants.append(_make(
		"john_hanlon", "John F. Hanlon Jr.", "FBI - agent, Car A",
		ActorProfile.Faction.FBI, VEHICLE_HANLON_MIRELES, SeatAnchor.SeatId.DRIVER,
		"", true,
		"Swing his unit abreast of the subject vehicle and rammed it to stop it " \
		+ "(FBI-2). FBI-1 records his revolver went to the floor during the " \
		+ "impact; he exited and crossed the street to assist."
	))
	occupants.append(_make(
		"edmundo_mireles", "Edmundo Mireles Jr.", "FBI - agent, Car A",
		ActorProfile.Faction.FBI, VEHICLE_HANLON_MIRELES, SeatAnchor.SeatId.FRONT_PASSENGER,
		"", false,
		"Occupant of the vehicle that struck the FPL substation wall. " \
		+ "Seat position is an ASSUMPTION: the sources name him as an occupant " \
		+ "but do not state which seat he held."
	))

	# Grogan initiated the felony car stop; Dove was his passenger. Both are
	# recorded as drawing weapons during the gunfight.
	occupants.append(_make(
		"benjamin_grogan", "Benjamin Grogan", "FBI - agent, Car C",
		ActorProfile.Faction.FBI, VEHICLE_GROGAN_DOVE, SeatAnchor.SeatId.DRIVER,
		"sw_model_459", false,
		"Initiated the felony car stop (FBI-2). FBI-2 records that his unit made " \
		+ "a U-turn and parked to the rear of the subject's vehicle."
	))
	occupants.append(_make(
		"jerry_dove", "Jerry Dove", "FBI - agent, Car C",
		ActorProfile.Faction.FBI, VEHICLE_GROGAN_DOVE, SeatAnchor.SeatId.FRONT_PASSENGER,
		"sw_model_459", false,
		"Occupant of the unit that initiated the car stop. Seat position is an " \
		+ "ASSUMPTION: the sources name him as an occupant but do not state " \
		+ "which seat he held."
	))

	# FBI-1/FBI-2: McNeill came into the area after the crash.
	occupants.append(_make(
		"gordon_mcneill", "Gordon McNeill", "FBI - agent, Car D",
		ActorProfile.Faction.FBI, VEHICLE_MCNEILL, SeatAnchor.SeatId.DRIVER,
		"", false,
		"Per FBI-1, McNeill came into the area after the crash. He observed the " \
		+ "subjects loading weapons before the stop and transmitted that."
	))

	# FBI-2: Risner/Orrantia's unit arrived after the crash and staged on the
	# west side of 82nd Avenue.
	occupants.append(_make(
		"gilbert_orrantia", "Gilbert Orrantia", "FBI - agent, Car E",
		ActorProfile.Faction.FBI, VEHICLE_RISNER_ORRANTIA, SeatAnchor.SeatId.DRIVER,
		"sw_model_459", false,
		"Per FBI-2, this unit arrived after the crash and staged on the west " \
		+ "side of 82nd Avenue. Seat position is an ASSUMPTION."
	))
	occupants.append(_make(
		"ronald_risner", "Ronald Risner", "FBI - agent, Car E",
		ActorProfile.Faction.FBI, VEHICLE_RISNER_ORRANTIA, SeatAnchor.SeatId.FRONT_PASSENGER,
		"sw_model_459", false,
		"Occupant of the unit that staged west of 82nd Avenue after the crash. " \
		+ "Seat position is an ASSUMPTION."
	))

	return occupants


static func _make(
		occupant_id: String,
		display_name: String,
		role: String,
		faction: int,
		vehicle_id: String,
		seat_id: SeatAnchor.SeatId,
		weapon_id: String,
		disarmed: bool,
		note: String
	) -> SceneOccupant:
	var occupant: SceneOccupant = SceneOccupant.new()
	occupant.occupant_id = occupant_id
	occupant.display_name = display_name
	occupant.role = role
	occupant.faction = faction
	occupant.vehicle_id = vehicle_id
	occupant.seat_id = seat_id
	occupant.starting_weapon_id = weapon_id
	occupant.disarmed_by_crash = disarmed
	occupant.source_note = note
	return occupant


## Look up an occupant by id.
static func find_occupant(occupants: Array[SceneOccupant], occupant_id: String) -> SceneOccupant:
	for occupant: SceneOccupant in occupants:
		if occupant.occupant_id == occupant_id:
			return occupant
	return null
