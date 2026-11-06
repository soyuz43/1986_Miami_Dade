class_name CrashGeometry
extends RefCounted

## Where each vehicle is, and where it goes.
##
## This replaces the inline keyframe arrays in the old crash_sequence.gd. Two
## things changed:
##
##   1. Positions and headings are no longer independent keyframes. Each
##      vehicle has one CrashPath (a line through the world) and one
##      CrashSpeedProfile (how fast it covers that line). The path's tangent
##      supplies the heading, so the vehicle always points where it is going.
##
##   2. The paths are built from the documented sequence rather than from
##      hand-tuned keyframes, so a reader can trace each line back to the
##      account it represents.
##
## Coordinate system (Godot default):
##   -X = west   +X = east
##   -Z = north  +Z = south
## 82nd Avenue runs north/south along the Z axis. The subject vehicle is
## travelling southbound during the approach, then turns and ends facing
## northbound, which the FBI incident report states explicitly.
##
## ## Which side of the avenue
##
## The crash is placed on the WEST side of 82nd Avenue. The FBI incident
## report places the retaining wall on the west side, and the address
## 12201 Southwest 82nd Avenue is an odd number, which in the Miami-Dade
## grid lies on the west side of a north-south street. The reference diagram
## this project was given appears to mirror the scene east-for-west; it is a
## secondary source and does not override the FBI report.
##
## ## Contact geometry
##
## The rams are the hard part. Two cars 1.9 m wide that touch must have
## their centres exactly 1.9 m apart *measured perpendicular to their
## headings*, not 1.9 m apart in world X. If they are not, the corners
## overlap and the cars visibly interpenetrate.
##
## The choreography exploits this: both rams happen while both vehicles are
## heading due south (the first ram) or due north (the second), so the
## perpendicular separation is simply the world X separation, and the
## contact points can be stated exactly.
##
## ## Magnitudes
##
## The metre values are still estimates. The FBI's Exhibit A diagram of final
## vehicle positions was never transcribed, so what is authoritative is the
## arrangement and the ordering of events, not the distances.

## --- Heading constants -------------------------------------------------
##
## Headings are compass bearings: 0 = north (-Z), 90 = east (+X),
## 180 = south (+Z), 270 = west (-X).
const HEADING_NORTH: float = 0.0
const HEADING_NORTHEAST: float = 45.0
const HEADING_EAST: float = 90.0
const HEADING_SOUTHEAST: float = 135.0
const HEADING_SOUTH: float = 180.0
const HEADING_SOUTHWEST: float = 225.0
const HEADING_WEST: float = 270.0
const HEADING_NORTHWEST: float = 315.0

## Vehicle width. Two cars in contact have their centres this far apart.
const VEHICLE_WIDTH: float = 1.9

## --- Road geometry ---------------------------------------------------
const ROAD_WIDTH: float = 16.0
const ROAD_CENTER_X: float = 0.0
const ROAD_LENGTH: float = 300.0

## Lane centres. All four pursuing units run southbound, so under
## right-hand traffic they occupy the western half of the carriageway.
const SUBJECT_LANE_X: float = -3.2
const MANAUZZI_LANE_X: float = -6.4
const HANLON_LANE_X: float = 3.2
const GROGAN_LANE_X: float = -3.2
const MCNEILL_LANE_X: float = -6.0
const RISNER_LANE_X: float = -12.0

## --- Final resting places ---------------------------------------------
##
## The subject vehicle rests facing northbound in the parking area at 12201
## SW 82nd Avenue, wedged between the parked civilian car, an FBI vehicle
## and a tree, and flanked by two FBI vehicles (FBI-1, FBI-2).
##
## Because the car faces north, its left side faces west and its right side
## faces east. The driver's seat is therefore on the west (-X) side, which
## is the side Manauzzi's unit ends up against: FBI-1 records the subject
## vehicle "impacted once again into the driver's side". The front
## passenger's seat is on the east side, which is the side the parked Cutlass
## is on: MH-1 has Matix unable to open his door because it was wedged
## against the Cutlass in the driveway.
const SUBJECT_FINAL: Vector3 = Vector3(-10.9, 0.0, -18.4)

## Manauzzi's unit, locked against the subject vehicle's driver side.
## The separation is exactly the vehicle width, so the bodies touch.
const MANAUZZI_FINAL: Vector3 = Vector3(-12.8, 0.0, -18.4)

## The parked civilian car: a black Cutlass in the driveway of 12201 SW 82nd
## Avenue, belonging to resident Cory Sukert (MH-1).
const PARKED_CUTLASS_FINAL: Vector3 = Vector3(-9.0, 0.0, -18.4)

## Hanlon's Chrysler came to rest against the wall on the west side of the
## avenue, south of the subject vehicle, after striking a post, a melaleuca
## and the wall of the Florida Power and Light substation (FBI-1, MH-1).
## Its final heading is south-south-east, so it rests diagonally against the
## wall rather than square to it.
const HANLON_FINAL: Vector3 = Vector3(-11.78, 0.0, -6.2)
const HANLON_FINAL_HEADING: float = 155.0

## Grogan's unit parked to the rear of the subject vehicle after its U-turn.
const GROGAN_FINAL: Vector3 = Vector3(-4.4, 0.0, -11.2)

## McNeill and Risner arrive after the crash.
const MCNEILL_FINAL: Vector3 = Vector3(-6.6, 0.0, -12.0)
const RISNER_FINAL: Vector3 = Vector3(-13.2, 0.0, -28.0)

## The bottlebrush tree the subject vehicle struck (MH-1). It sits just
## ahead of the subject vehicle's north-facing front bumper.
const TREE_POSITION: Vector3 = Vector3(-10.9, 0.0, -21.15)
const TREE_TRUNK_RADIUS: float = 0.30

## The retaining wall of the Florida Power and Light substation, on the west
## side of 82nd Avenue (FBI-1, MH-1). Its east face is at x = -13.675.
const WALL_POSITION: Vector3 = Vector3(-13.9, 1.1, -5.5)
const WALL_SIZE: Vector3 = Vector3(0.45, 2.2, 12.0)

## The driveway of 12201 SW 82nd Avenue, where the Cutlass was parked.
const DRIVEWAY_POSITION: Vector3 = Vector3(-9.9, 0.03, -18.5)
const DRIVEWAY_SIZE: Vector3 = Vector3(4.2, 0.06, 13.0)

## --- Path construction ------------------------------------------------
##
## Every path is built the same way: a *core* describing the documented
## action, plus a straight approach prepended so that the path is exactly as
## long as the vehicle's speed profile says it will travel. Without that
## correction the vehicle would stop short of its documented resting place,
## because the speeds are authored in m/s and the geometry in metres, and
## the two have to agree.
##
## The slip offsets are keyed by core control point index. The helper shifts
## them to account for the prepended approach points.

static func _polyline_length(points: Array[Vector3]) -> float:
	var total: float = 0.0
	for index: int in range(points.size() - 1):
		total += (points[index + 1] - points[index]).length()
	return total


## Build a path from a core and a speed profile, prepending a straight
## approach of exactly the length needed to exhaust the speed profile.
static func _build_path(
		core: Array[Vector3],
		speed: CrashSpeedProfile,
		slip_offsets: Dictionary = {}
	) -> CrashPath:
	var core_length: float = _polyline_length(core)
	var demanded: float = speed.distance_at(speed.get_end_time())
	var extension: float = demanded - core_length

	if extension <= 0.0:
		push_error("CrashGeometry: the speed profile needs %.1f m but the core path is only %.1f m; the vehicle would stop short." % [
			demanded, core_length
		])
		return CrashPath.new(core)

	# The approach continues backwards along the core's initial direction.
	var direction: Vector3 = (core[1] - core[0]).normalized()
	var steps: int = 4
	var points: Array[Vector3] = []
	for step_index: int in range(steps, 0, -1):
		var offset: float = extension * float(step_index) / float(steps)
		points.append(core[0] - direction * offset)
	points.append_array(core)

	# Shift the slip keys to match the new control point numbering.
	var shifted: Dictionary = {}
	for key: Variant in slip_offsets.keys():
		shifted[int(key) + steps] = slip_offsets[key]

	return CrashPath.new(points, shifted)


## Unit vector for a compass bearing, in Godot's coordinate frame.
## 0 = north (-Z), 90 = east (+X).
static func _compass_direction(heading_degrees: float) -> Vector3:
	var radians: float = deg_to_rad(heading_degrees)
	return Vector3(sin(radians), 0.0, -cos(radians))


## Points along a circular arc, used for the subject vehicle's U-turn.
##
## The arc is described the way a driver would describe it: where the vehicle
## enters, which way it is pointing, and how far it turns.
##
## A positive `turn_degrees` turns to the right (clockwise seen from above);
## a negative value turns to the left. The centre of the arc lies on the
## inside of the turn, so the vehicle swings out to the outside and ends up
## displaced sideways from its entry point. That sideways displacement is
## what makes a U-turn.
static func _arc_points(
		entry: Vector3,
		heading_degrees: float,
		turn_degrees: float,
		radius: float,
		steps: int
	) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if steps <= 0:
		return points
	var centre: Vector3 = entry + _compass_direction(heading_degrees + 90.0) * radius
	for step_index: int in range(1, steps + 1):
		var fraction: float = float(step_index) / float(steps)
		var heading: float = heading_degrees + turn_degrees * fraction
		# The vehicle sits `radius` from the centre, on the side opposite the
		# turn's inside.
		var offset: Vector3 = -_compass_direction(heading + 90.0) * radius
		points.append(centre + offset)
	return points


## --- Vehicle paths ----------------------------------------------------

## The subject vehicle: the 1982 Monte Carlo.
##
## Southbound in its lane, a swerve right off the pavement (FBI-2), a tight
## U-turn back to the north, then north into the yard where the tree and the
## parked Cutlass are.
##
## The turn's entry geometry is chosen so that the arc leaves the vehicle
## pointing due north at the yard's edge, which is what the FBI report's
## "came to rest facing northbound" requires. After the arc the vehicle runs
## dead straight north along x = -10.9, which is what lets the parked Cutlass
## and Manauzzi's unit sit exactly one vehicle width away on either side.
static func subject_path() -> CrashPath:
	# Entry to the U-turn: heading south-south-west, 3.0 m radius. The arc
	# ends at (-10.90, -15.50) pointing due north.
	var turn_entry: Vector3 = Vector3(-5.08, 0.0, -14.47)
	var turn_heading: float = 200.0
	var turn_radius: float = 3.0

	var core: Array[Vector3] = [
		Vector3(SUBJECT_LANE_X, 0.0, -34.0),
		Vector3(SUBJECT_LANE_X, 0.0, -26.0),
		Vector3(SUBJECT_LANE_X, 0.0, -19.0),
		Vector3(-3.6, 0.0, -16.2),
		turn_entry,
	]
	core.append_array(_arc_points(turn_entry, turn_heading, 160.0, turn_radius, 8))
	core.append_array([
		Vector3(-10.9, 0.0, -17.0),
		SUBJECT_FINAL,
	])

	return _build_path(core, subject_speed_profile())


## Manauzzi's unit: closes from behind, makes the first ram on the subject
## vehicle's west side, is checked by the U-turn, comes back around, and ends
## locked against the subject vehicle's driver side.
##
## The first ram happens while both vehicles run due south, so the contact
## line is a constant x = subject_x - 1.9. The second ram and the final
## locked position happen while both run due north, on the same principle.
static func manauzzi_path() -> CrashPath:
	var contact_x: float = SUBJECT_LANE_X - VEHICLE_WIDTH
	var core: Array[Vector3] = [
		Vector3(MANAUZZI_LANE_X, 0.0, -42.0),
		Vector3(MANAUZZI_LANE_X, 0.0, -32.0),
		Vector3(contact_x, 0.0, -28.0),
		Vector3(contact_x, 0.0, -22.0),
		Vector3(contact_x, 0.0, -19.0),
		# Checked by the U-turn; FBI-2 records Manauzzi as "momentarily
		# stopped by the earlier impact" before he comes back around. He
		# swings wide to the south-west so the subject's turn does not foul
		# him.
		Vector3(-6.4, 0.0, -20.4),
		Vector3(-9.2, 0.0, -22.0),
		Vector3(-12.0, 0.0, -21.4),
		# Now lined up on the subject vehicle's driver side, due north.
		Vector3(-12.8, 0.0, -20.0),
		Vector3(-12.8, 0.0, -19.0),
		MANAUZZI_FINAL,
	]
	return _build_path(core, manauzzi_speed_profile())


## Hanlon's Chrysler: runs east of the subject vehicle, pulls alongside, is
## struck, spins out, and comes to rest against the substation wall.
##
## The spin is a slip offset rather than an independent heading keyframe:
## the car's nose rotates away from its direction of travel while it slides,
## which is what being knocked into a wall actually looks like.
static func hanlon_path() -> CrashPath:
	var core: Array[Vector3] = [
		Vector3(HANLON_LANE_X, 0.0, -34.0),
		Vector3(HANLON_LANE_X, 0.0, -24.0),
		Vector3(2.6, 0.0, -16.0),
		Vector3(0.6, 0.0, -11.0),
		Vector3(-1.8, 0.0, -8.4),
		Vector3(-5.0, 0.0, -7.4),
		Vector3(-8.4, 0.0, -7.6),
		Vector3(-11.0, 0.0, -8.4),
		Vector3(-12.63, 0.0, -8.01),
		HANLON_FINAL,
	]
	return _build_path(core, hanlon_speed_profile(), {
		3: 0.0,
		5: -24.0,
		7: -44.0,
		9: -30.0,
	})


## Grogan and Dove's unit: initiates the felony car stop from directly
## behind, then falls back and makes a U-turn further south, ending parked
## behind the subject vehicle (FBI-2).
##
## Grogan stays behind the subject vehicle throughout, so his path stays in
## the subject's lane but never closes to less than a car's length.
static func grogan_path() -> CrashPath:
	var core: Array[Vector3] = [
		Vector3(GROGAN_LANE_X, 0.0, -38.0),
		Vector3(GROGAN_LANE_X, 0.0, -30.0),
		Vector3(GROGAN_LANE_X, 0.0, -24.0),
		Vector3(-3.4, 0.0, -19.0),
		Vector3(-3.6, 0.0, -14.0),
		Vector3(-4.0, 0.0, -11.4),
		Vector3(-4.4, 0.0, -11.0),
		GROGAN_FINAL,
	]
	return _build_path(core, grogan_speed_profile())


## McNeill, who came into the area after the crash (FBI-1).
static func mcneill_path() -> CrashPath:
	var core: Array[Vector3] = [
		Vector3(MCNEILL_LANE_X, 0.0, -26.0),
		Vector3(MCNEILL_LANE_X, 0.0, -19.0),
		MCNEILL_FINAL,
	]
	return _build_path(core, mcneill_speed_profile())


## Risner and Orrantia's unit, which staged on the west side of 82nd Avenue
## north-west of the scene (FBI-2).
static func risner_path() -> CrashPath:
	var core: Array[Vector3] = [
		Vector3(RISNER_LANE_X, 0.0, -36.0),
		Vector3(RISNER_LANE_X, 0.0, -30.0),
		RISNER_FINAL,
	]
	return _build_path(core, risner_speed_profile())


## --- Speed profiles ----------------------------------------------------
##
## The pursuit runs at roughly 35 mph (MH-1), which is 15.6 m/s. The speeds
## then fall away sharply as the vehicles brake, swerve, and ram.
##
## These are deliberately continuous. The old implementation eased each
## keyframe segment separately, which forced speed to zero at every keyframe
## boundary and made the vehicles stutter.
##
## The subject vehicle's profile deserves a note. It must slow hard for the
## swerve and the U-turn: a 3 m radius turn at 15 mph would demand about
## 1.5 g of lateral acceleration, which is at the limit for a 1982 Monte
## Carlo with a handbrake. MH-1 has Platt yanking the wheel into a sharp
## left turn to complete the U-turn, so the sim shows the car slowing first
## and then swinging.

## The subject vehicle: at pursuit speed, braking for the stop, slow through
## the U-turn, then driven into the yard by the second ram.
static func subject_speed_profile() -> CrashSpeedProfile:
	return CrashSpeedProfile.new([
		{"time": 0.0, "speed": CrashSpeedProfile.mph(35.0)},
		{"time": 2.9, "speed": CrashSpeedProfile.mph(35.0)},
		{"time": 3.9, "speed": CrashSpeedProfile.mph(14.0)},
		{"time": 4.8, "speed": CrashSpeedProfile.mph(8.0)},
		{"time": 5.9, "speed": CrashSpeedProfile.mph(6.0)},
		{"time": 7.1, "speed": CrashSpeedProfile.mph(8.0)},
		{"time": 8.0, "speed": CrashSpeedProfile.mph(11.0)},
		{"time": 9.0, "speed": CrashSpeedProfile.mph(14.0)},
		{"time": 10.6, "speed": CrashSpeedProfile.mph(7.0)},
		{"time": 12.2, "speed": 0.0},
	])


## Manauzzi: closes from behind at pursuit speed, slows for the first ram,
## then accelerates into the second.
static func manauzzi_speed_profile() -> CrashSpeedProfile:
	return CrashSpeedProfile.new([
		{"time": 0.0, "speed": CrashSpeedProfile.mph(35.0)},
		{"time": 3.4, "speed": CrashSpeedProfile.mph(35.0)},
		{"time": 4.6, "speed": CrashSpeedProfile.mph(16.0)},
		{"time": 5.6, "speed": CrashSpeedProfile.mph(9.0)},
		{"time": 6.6, "speed": CrashSpeedProfile.mph(6.0)},
		{"time": 7.6, "speed": CrashSpeedProfile.mph(12.0)},
		{"time": 8.8, "speed": CrashSpeedProfile.mph(20.0)},
		{"time": 10.6, "speed": CrashSpeedProfile.mph(11.0)},
		{"time": 12.2, "speed": 0.0},
	])


## Hanlon: abreast of the subject vehicle during the stop, then spun out.
static func hanlon_speed_profile() -> CrashSpeedProfile:
	return CrashSpeedProfile.new([
		{"time": 0.0, "speed": CrashSpeedProfile.mph(34.0)},
		{"time": 3.6, "speed": CrashSpeedProfile.mph(34.0)},
		{"time": 4.8, "speed": CrashSpeedProfile.mph(16.0)},
		{"time": 6.0, "speed": CrashSpeedProfile.mph(9.0)},
		{"time": 7.6, "speed": CrashSpeedProfile.mph(7.0)},
		{"time": 9.4, "speed": CrashSpeedProfile.mph(5.0)},
		{"time": 11.4, "speed": 0.0},
	])


## Grogan: holds station behind during the stop, then falls back and makes
## his U-turn.
static func grogan_speed_profile() -> CrashSpeedProfile:
	return CrashSpeedProfile.new([
		{"time": 0.0, "speed": CrashSpeedProfile.mph(35.0)},
		{"time": 3.0, "speed": CrashSpeedProfile.mph(35.0)},
		{"time": 4.4, "speed": CrashSpeedProfile.mph(20.0)},
		{"time": 5.8, "speed": CrashSpeedProfile.mph(10.0)},
		{"time": 7.2, "speed": CrashSpeedProfile.mph(8.0)},
		{"time": 9.0, "speed": CrashSpeedProfile.mph(7.0)},
		{"time": 11.2, "speed": 0.0},
	])


## McNeill arrives after the crash.
static func mcneill_speed_profile() -> CrashSpeedProfile:
	return CrashSpeedProfile.new([
		{"time": 0.0, "speed": CrashSpeedProfile.mph(32.0)},
		{"time": 4.0, "speed": CrashSpeedProfile.mph(30.0)},
		{"time": 7.0, "speed": CrashSpeedProfile.mph(18.0)},
		{"time": 10.0, "speed": CrashSpeedProfile.mph(8.0)},
		{"time": 12.2, "speed": 0.0},
	])


## Risner and Orrantia stage on the west side.
static func risner_speed_profile() -> CrashSpeedProfile:
	return CrashSpeedProfile.new([
		{"time": 0.0, "speed": CrashSpeedProfile.mph(30.0)},
		{"time": 5.0, "speed": CrashSpeedProfile.mph(26.0)},
		{"time": 8.0, "speed": CrashSpeedProfile.mph(12.0)},
		{"time": 11.0, "speed": 0.0},
	])
