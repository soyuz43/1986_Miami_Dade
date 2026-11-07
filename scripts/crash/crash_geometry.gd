class_name CrashGeometry
extends RefCounted

const VEHICLE_WIDTH: float = 1.90
const VEHICLE_LENGTH: float = 4.90

const ROAD_WIDTH: float = 11.0
const ROAD_CENTER_X: float = 0.0
const ROAD_LENGTH: float = 300.0
const SIDEWALK_WIDTH: float = 3.0

const SUBJECT_LANE_X: float = -1.6
const MANAUZZI_LANE_X: float = 0.3
const HANLON_LANE_X: float = -3.5
const GROGAN_LANE_X: float = -1.6
const MCNEILL_LANE_X: float = -1.6
const RISNER_LANE_X: float = -3.5

const SUBJECT_FINAL: Vector3 = Vector3(9.6, 0.0, -22.1)
const MANAUZZI_FINAL: Vector3 = Vector3(7.7, 0.0, -22.1)
const PARKED_CUTLASS_FINAL: Vector3 = Vector3(11.5, 0.0, -22.1)

const PARKED_ROW: Array[Vector3] = [
	Vector3(13.0, 0.0, -22.6),
	Vector3(15.2, 0.0, -23.3),
	Vector3(17.4, 0.0, -24.0),
]

## X=-8.55. Car half-width is 0.95. -8.55 - 0.95 = -9.50, which is the exact
## X coordinate of the wall's east face. Perfect contact when slip is 0.
const HANLON_FINAL: Vector3 = Vector3(-8.55, 0.0, -11.0)
const HANLON_FINAL_HEADING: float = 180.0

const GROGAN_FINAL: Vector3 = Vector3(1.6, 0.0, -13.0)
const MCNEILL_FINAL: Vector3 = Vector3(-1.6, 0.0, -14.0)
const RISNER_FINAL: Vector3 = Vector3(-3.5, 0.0, -40.0)

const TREE_POSITION: Vector3 = Vector3(9.6, 0.0, -24.85)
const TREE_TRUNK_RADIUS: float = 0.30

const WALL_POSITION: Vector3 = Vector3(-9.725, 1.1, -10.0)
const WALL_SIZE: Vector3 = Vector3(0.45, 2.2, 14.0)

const APRON_CENTRE: Vector3 = Vector3(14.0, 0.02, -15.25)
const APRON_SIZE: Vector3 = Vector3(12.0, 0.04, 18.5)

const DRIVEWAY_POSITION: Vector3 = Vector3(6.75, 0.03, -7.5)
const DRIVEWAY_SIZE: Vector3 = Vector3(2.5, 0.06, 7.0)

const SLIDE_ARC_RADIUS: float = 6.0
const SLIDE_ARC_TURN: float = 30.0
const SLIDE_RUN_LENGTH: float = 12.784
const SLIDE_TAIL_LENGTH: float = 9.04 # Adjusted to end exactly at SUBJECT_FINAL Z

const SEQUENCE_DURATION: float = 13.0
const SECOND_RAM_TIME: float = 8.4
const SECOND_RAM_POSITION: Vector3 = Vector3(1.6, 0.0, 4.0)

class Track:
	extends RefCounted
	var points: Array[Vector3] = []
	var times: Array[float] = []
	var slip_offsets: Dictionary = {}
	var beat_indices: Array[int] = []

	func add_point(point: Vector3, time: float) -> int:
		points.append(point)
		times.append(time)
		beat_indices.append(points.size() - 1)
		return points.size() - 1

	func add_run(run: Array[Vector3], start_time: float, end_time: float) -> int:
		if run.is_empty(): return points.size() - 1
		var lengths: Array[float] = []
		var total: float = 0.0
		var previous: Vector3 = points[points.size() - 1]
		for point: Vector3 in run:
			total += (point - previous).length()
			lengths.append(total)
			previous = point
		var first_index: int = points.size()
		for index: int in range(run.size()):
			var fraction: float = 0.0
			if total > 0.0001: fraction = lengths[index] / total
			points.append(run[index])
			times.append(lerpf(start_time, end_time, fraction))
		return first_index

	func distances() -> PackedFloat32Array:
		var result: PackedFloat32Array = PackedFloat32Array()
		var running: float = 0.0
		for index: int in range(points.size()):
			if index > 0: running += (points[index] - points[index - 1]).length()
			result.append(running)
		return result

	func milestones() -> Array[Dictionary]:
		var distances: PackedFloat32Array = distances()
		var result: Array[Dictionary] = []
		for index: int in beat_indices:
			if result.size() > 0 and distances[index] - float(result[-1]["distance"]) < 0.0001:
				continue
			result.append({"time": times[index], "distance": distances[index]})
		return result

static var _tracks: Dictionary = {}
static func _track_for(key: String, builder: Callable) -> Track:
	if _tracks.has(key): return _tracks[key]
	var track: Track = builder.call()
	_tracks[key] = track
	return track

static func _path_for(track: Track) -> CrashPath: return CrashPath.new(track.points, track.slip_offsets)
static func _profile_for(track: Track) -> CrashSpeedProfile: return CrashSpeedProfile.new(track.milestones())

static func _compass_direction(bearing_degrees: float) -> Vector3:
	var radians: float = deg_to_rad(bearing_degrees)
	return Vector3(sin(radians), 0.0, -cos(radians))

static func _arc_points(entry: Vector3, bearing_degrees: float, turn_degrees: float, radius: float, steps: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if steps <= 0 or is_zero_approx(turn_degrees): return points
	var direction: float = signf(turn_degrees)
	var centre: Vector3 = entry + _compass_direction(bearing_degrees - direction * 90.0) * radius
	for step_index: int in range(1, steps + 1):
		var fraction: float = float(step_index) / float(steps)
		var bearing: float = bearing_degrees - turn_degrees * fraction
		points.append(centre + _compass_direction(bearing + direction * 90.0) * radius)
	return points

static func _offset_perpendicular(points: Array[Vector3], offset: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for index: int in range(points.size()):
		var tangent: Vector3 = Vector3.ZERO
		if points.size() > 1:
			if index == 0: tangent = points[1] - points[0]
			elif index == points.size() - 1: tangent = points[index] - points[index - 1]
			else: tangent = points[index + 1] - points[index - 1]
			tangent = tangent.normalized()
		var left: Vector3 = Vector3(tangent.z, 0.0, -tangent.x)
		result.append(points[index] + left * offset)
	return result

static func _shared_slide() -> Array[Vector3]:
	var points: Array[Vector3] = []
	points.append_array(_arc_points(SECOND_RAM_POSITION, 0.0, -SLIDE_ARC_TURN, SLIDE_ARC_RADIUS, 8))
	var after_first_arc: Vector3 = points[points.size() - 1]
	points.append(after_first_arc + _compass_direction(SLIDE_ARC_TURN) * SLIDE_RUN_LENGTH)
	var after_run: Vector3 = points[points.size() - 1]
	points.append_array(_arc_points(after_run, SLIDE_ARC_TURN, SLIDE_ARC_TURN, SLIDE_ARC_RADIUS, 8))
	var after_second_arc: Vector3 = points[points.size() - 1]
	points.append(after_second_arc + _compass_direction(0.0) * SLIDE_TAIL_LENGTH)
	return points

static func subject_track() -> Track:
	return _track_for("subject", func() -> Track:
		var track: Track = Track.new()
		track.add_point(Vector3(SUBJECT_LANE_X, 0.0, -44.2), 0.0)
		track.add_point(Vector3(SUBJECT_LANE_X, 0.0, -3.6), 2.6)

		# Swerve right (West) to graze Hanlon. Hanlon is at approx X=-4.55, Z=1.0 at t=3.1.
		# Targeting X=-2.65, Z=1.0 ensures exactly 1.9m separation (0.0m overlap).
		track.add_point(Vector3(-2.65, 0.0, 1.0), 3.1)
		track.add_point(Vector3(-3.0, 0.0, 2.5), 3.4)
		track.add_point(Vector3(-3.4, 0.0, 4.0), 4.0)

		# Clean 180-degree left U-turn from (-3.4, 4.0) facing South to (1.6, 4.0) facing North.
		track.add_run(_arc_points(Vector3(-3.4, 0.0, 4.0), 180.0, 180.0, 2.5, 16), 4.0, 5.4)

		# Creep north to the second ram impact point.
		track.add_point(Vector3(1.6, 0.0, 4.0), 8.4)

		# Second ram drives the pair east over the sidewalk.
		track.add_run(_shared_slide(), SECOND_RAM_TIME, 12.2)
		track.add_point(SUBJECT_FINAL, 12.2)
		track.add_point(SUBJECT_FINAL, SEQUENCE_DURATION)
		return track
	)

static func subject_path() -> CrashPath: return _path_for(subject_track())
static func subject_speed_profile() -> CrashSpeedProfile: return _profile_for(subject_track())

static func manauzzi_track() -> Track:
	return _track_for("manauzzi", func() -> Track:
		var track: Track = Track.new()
		track.add_point(Vector3(SUBJECT_LANE_X, 0.0, -58.0), 0.0)
		track.add_point(Vector3(MANAUZZI_LANE_X, 0.0, -35.0), 1.2)
		track.add_point(Vector3(MANAUZZI_LANE_X, 0.0, -9.88), 2.2)
		track.add_point(Vector3(7.7, 0.0, 14.0), 5.4)
		var turn_entry: Vector3 = track.points[track.points.size() - 1]
		track.add_run(_arc_points(turn_entry, 180.0, -180.0, 4.0, 14), 5.4, 7.0)
		track.add_point(Vector3(-0.3, 0.0, 4.0), 8.4)
		track.add_run(_offset_perpendicular(_shared_slide(), VEHICLE_WIDTH), SECOND_RAM_TIME, 12.2)
		track.add_point(MANAUZZI_FINAL, 12.2)
		track.add_point(MANAUZZI_FINAL, SEQUENCE_DURATION)
		return track
	)

static func manauzzi_path() -> CrashPath: return _path_for(manauzzi_track())
static func manauzzi_speed_profile() -> CrashSpeedProfile: return _profile_for(manauzzi_track())

static func hanlon_track() -> Track:
	return _track_for("hanlon", func() -> Track:
		var track: Track = Track.new()
		track.add_point(Vector3(HANLON_LANE_X, 0.0, -38.8), 0.0)
		track.add_point(Vector3(HANLON_LANE_X, 0.0, 1.8), 2.6)

		# Knocked west and spun out of control.
		# Kept at X >= -6.5 while slip is high to prevent bounding box corners
		# from penetrating the wall at X=-9.50.
		track.add_point(Vector3(-5.6, 0.0, 0.2), 3.6)
		track.add_point(Vector3(-6.0, 0.0, -2.0), 5.0)
		track.add_point(Vector3(-6.5, 0.0, -5.0), 7.0)
		track.add_point(Vector3(-7.5, 0.0, -8.0), 8.5)

		# Final resting place. X=-8.55 ensures perfect contact with the wall face.
		track.add_point(HANLON_FINAL, 10.0)
		track.add_point(HANLON_FINAL, SEQUENCE_DURATION)

		# Slip peaks at 15 degrees, then smoothly returns to 0.
		track.slip_offsets = {
			2: 0.0,
			3: 10.0,
			4: 15.0,
			5: 10.0,
			6: 0.0,
		}
		return track
	)

static func hanlon_path() -> CrashPath:
	var track: Track = hanlon_track()
	return CrashPath.new(track.points, track.slip_offsets, HANLON_FINAL_HEADING, 4)

static func hanlon_speed_profile() -> CrashSpeedProfile: return _profile_for(hanlon_track())

static func grogan_track() -> Track:
	return _track_for("grogan", func() -> Track:
		var track: Track = Track.new()
		track.add_point(Vector3(GROGAN_LANE_X, 0.0, -75.0), 0.0)
		track.add_point(Vector3(GROGAN_LANE_X, 0.0, 20.0), 6.2)
		var turn_entry: Vector3 = track.points[track.points.size() - 1]
		track.add_run(_arc_points(turn_entry, 180.0, 180.0, 3.2, 12), 6.2, 7.8)
		var after_turn: Vector3 = track.points[track.points.size() - 1]
		track.add_run(_arc_points(after_turn, 0.0, 45.0, 5.46, 8), 7.8, 8.8)
		var after_s_curve: Vector3 = track.points[track.points.size() - 1]
		track.add_run(_arc_points(after_s_curve, 45.0, -45.0, 5.46, 8), 8.8, 9.6)
		track.add_point(GROGAN_FINAL, 12.0)
		track.add_point(GROGAN_FINAL, SEQUENCE_DURATION)
		return track
	)

static func grogan_path() -> CrashPath: return _path_for(grogan_track())
static func grogan_speed_profile() -> CrashSpeedProfile: return _profile_for(grogan_track())

static func mcneill_track() -> Track:
	return _track_for("mcneill", func() -> Track:
		var track: Track = Track.new()
		track.add_point(Vector3(MCNEILL_LANE_X, 0.0, -40.0), 3.0)
		track.add_point(Vector3(MCNEILL_LANE_X, 0.0, -14.0), 9.0)
		track.add_point(MCNEILL_FINAL, 11.0)
		track.add_point(MCNEILL_FINAL, SEQUENCE_DURATION)
		return track
	)

static func mcneill_path() -> CrashPath: return _path_for(mcneill_track())
static func mcneill_speed_profile() -> CrashSpeedProfile: return _profile_for(mcneill_track())

static func risner_track() -> Track:
	return _track_for("risner", func() -> Track:
		var track: Track = Track.new()
		track.add_point(Vector3(RISNER_LANE_X, 0.0, -60.0), 8.0)
		track.add_point(Vector3(RISNER_LANE_X, 0.0, -40.0), 12.0)
		track.add_point(RISNER_FINAL, SEQUENCE_DURATION)
		return track
	)

static func risner_path() -> CrashPath: return _path_for(risner_track())
static func risner_speed_profile() -> CrashSpeedProfile: return _profile_for(risner_track())