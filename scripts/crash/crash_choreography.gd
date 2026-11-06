class_name CrashChoreography
extends RefCounted

## The documented beats of the crash, in order.
##
## This is the narrative layer. It sits between the research
## (docs/RESEARCH_crash.md) and the animation, and it records which source
## supports each beat. Nothing here is invented: every entry cites the
## incident report, the case synopsis, or the Herald reconstruction.
##
## The choreography drives two things:
##   - the phase state the HUD reports, and
##   - the camera director's framing.
##
## It deliberately does NOT specify vehicle paths. Those live in
## CrashPath, keyed to the same time base, so that a change to the geometry
## does not silently invalidate the narrative.

## Phase identifiers, in order.
const PHASE_APPROACH: int = 0
const PHASE_CAR_STOP: int = 1
const PHASE_FIRST_RAM: int = 2
const PHASE_U_TURN: int = 3
const PHASE_SECOND_RAM: int = 4
const PHASE_IMPACT: int = 5
const PHASE_SETTLED: int = 6

## A beat: a phase, the time window it covers, and its sourcing.
class Beat:
	extends RefCounted

	var phase_index: int
	var start_time: float
	var end_time: float
	var title: String
	var source: String
	var description: String

	func _init(
			phase: int,
			start: float,
			end: float,
			beat_title: String,
			beat_source: String,
			beat_description: String
	) -> void:
		phase_index = phase
		start_time = start
		end_time = end
		title = beat_title
		source = beat_source
		description = beat_description

	func contains(time: float) -> bool:
		return time >= start_time and time < end_time


const PHASE_NAMES: Array[String] = [
	"Approach",
	"Car stop ordered",
	"First ram",
	"U-turn",
	"Second ram",
	"Impact",
	"Settled",
]


static func build_beats() -> Array[Beat]:
	var beats: Array[Beat] = []

	beats.append(Beat.new(
		PHASE_APPROACH, 0.0, 2.6,
		"Approach",
		"FBI-2, MH-1",
		"The pursuit travels south on 82nd Avenue. MH-1 places the subjects at "
		+ "roughly 35 mph. Grogan radios that he is behind the black Monte Carlo."
	))

	beats.append(Beat.new(
		PHASE_CAR_STOP, 2.6, 4.0,
		"Car stop ordered",
		"FBI-2, MH-1",
		"Grogan orders the felony car stop and engages lights and siren. The "
		+ "subject vehicle swerves right, brakes, and leaves the pavement."
	))

	beats.append(Beat.new(
		PHASE_FIRST_RAM, 4.0, 6.0,
		"First ram",
		"FBI-2 (disputed by MH-1)",
		"Manauzzi's unit, coming from behind, rams the Monte Carlo to "
		+ "incapacitate the occupants. FBI-2 places Manauzzi's ram before "
		+ "Hanlon's; MH-1 instead describes Hanlon pulling alongside and being "
		+ "struck. The animation follows the FBI account and does not claim the "
		+ "order is settled."
	))

	beats.append(Beat.new(
		PHASE_U_TURN, 6.0, 7.6,
		"U-turn",
		"FBI-2, MH-1",
		"The subjects negotiate a high-speed U-turn to head back north on "
		+ "82nd Avenue. Platt yanks the wheel into a sharp left turn to "
		+ "complete it, striking a three-foot post that splits the radiator."
	))

	beats.append(Beat.new(
		PHASE_SECOND_RAM, 7.6, 8.8,
		"Second ram",
		"FBI-1, FBI-2, MH-1",
		"Manauzzi, momentarily stopped by the earlier impact, observes the "
		+ "subject vehicle returning in his direction and rams it a second time, "
		+ "terminating the vehicle stop effort."
	))

	beats.append(Beat.new(
		PHASE_IMPACT, 8.8, 12.2,
		"Impact",
		"FBI-1, FBI-2, MH-1",
		"Manauzzi's unit hits the driver's side and the two cars go over the "
		+ "sidewalk into the yard, locked together. Platt swerves into Hanlon's "
		+ "Chrysid; the Chrysler strikes a post, a melaleuca, and the wall of "
		+ "the Florida Power and Light substation. The Monte Carlo uproots a "
		+ "melaleuca and comes to rest against the bottlebrush tree and the "
		+ "parked Cutlass."
	))

	beats.append(Beat.new(
		PHASE_SETTLED, 12.2, 999.0,
		"Settled",
		"FBI-1, FBI-2",
		"The subject vehicle rests facing northbound, wedged between the parked "
		+ "civilian car, an FBI vehicle and a tree, and flanked by two FBI "
		+ "vehicles. The subjects fire from within the vehicle before agents "
		+ "can fully exit."
	))

	return beats


## Find the beat covering the given sequence time.
static func find_beat(beats: Array[Beat], time: float) -> Beat:
	for beat: Beat in beats:
		if beat.contains(time):
			return beat
	return beats[beats.size() - 1]


## The phase index covering the given sequence time.
static func phase_at(beats: Array[Beat], time: float) -> int:
	return find_beat(beats, time).phase_index


static func get_phase_name(phase_index: int) -> String:
	if phase_index < 0 or phase_index >= PHASE_NAMES.size():
		return "Idle"
	return PHASE_NAMES[phase_index]
