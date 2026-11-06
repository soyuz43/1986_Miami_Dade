class_name SceneOccupant
extends Resource

## A person in the scene, and where they were sitting.
##
## This is the roster the crash cinematic and the character-select screen both
## read. It deliberately records only what the sources establish: who was in
## which vehicle, in which seat, and what they were carrying.
##
## The `vehicle_id` and `seat_id` fields link an occupant to a SeatAnchor.
## The two are kept separate so that an occupant can be reassigned (a
## counterfactual, where the player is a different agent) without the vehicle
## geometry changing.

@export var occupant_id: String = ""
@export var display_name: String = ""
@export var role: String = ""
@export var faction: int = 0

@export var vehicle_id: String = ""
@export var seat_id: int = 0

## Weapon carried at the start of the gunfight. An empty string means the
## occupant's weapon was lost during the crash (see docs/RESEARCH_crash.md).
@export var starting_weapon_id: String = ""

## True when the source records that this occupant's weapon was knocked to the
## floor during the crash, or otherwise left them without one.
@export var disarmed_by_crash: bool = false

## Note describing why this occupant is placed where they are, and any
## dispute about it.
@export var source_note: String = ""
