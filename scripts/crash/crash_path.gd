class_name CrashPath
extends RefCounted

## A vehicle's driven line through the crash scene, measured in metres.
##
## The path is sampled as a polyline of equal-length steps so that a vehicle's
## position can be looked up by *distance travelled* rather than by time.
## That distinction is the whole point of this class: position and heading are
## both derived from the same arc-length parameter, so a vehicle can never
## slide sideways relative to its own nose.
##
## Heading defaults to the tangent of the path, which means:
##   - a vehicle always points where it is going;
##   - a vehicle's heading changes only when the line it is driving curves;
##   - slip angle is zero everywhere except where the path deliberately
##     includes a skid.
##
## The previous implementation lerped position and yaw independently with the
## same eased parameter, which decoupled heading from direction of travel. That
## produced up to 178 degrees of slip angle, i.e. cars visibly driving
## backwards relative to their noses.
##
## ## Slip
##
## A skid is expressed as a *slip offset*: an angle added to the tangent
## heading at a point along the path. An offset of zero means the vehicle is
## tracking. A non-zero offset means the vehicle is sliding, or being spun by
## an impact, which is what a car being knocked into a wall actually does.
##
## Offsets are keyed by control point index rather than by absolute distance,
## so extending the approach section of a path does not silently shift where
## the skid happens.

const SAMPLE_SPACING: float = 0.05

## Slip offsets in degrees, interpolated between control point indices.
var _slip_offsets: PackedFloat32Array = PackedFloat32Array()
var _slip_distances: PackedFloat32Array = PackedFloat32Array()

## The heading the vehicle faces at the very end of the path, in degrees.
##
## A vehicle that spins out can come to rest facing back the way it came,
## which is not the direction it was travelling in when it stopped. The
## tangent alone cannot express that, so the path can be told the final
## heading explicitly; the difference between the tangent and that heading
## is applied as a further slip over the last segment.
var _final_heading_degrees: float = NAN

## Total correction in degrees applied at the end of the path.
var _final_heading_offset: float = 0.0

## The heading the vehicle faces at the end of the ramp, in radians.
var _final_heading_target: float = 0.0

## The heading the vehicle had when the ramp started, in radians.
var _final_heading_from: float = 0.0

## Distance at which the ramp starts and ends.
var _final_heading_start: float = 0.0
var _final_heading_end: float = 0.0

var _points: PackedVector3Array = PackedVector3Array()
var _distances: PackedFloat32Array = PackedFloat32Array()
var _total_length: float = 0.0


## Build a path from a list of control points. The polyline is resampled at a
## fixed spacing so that distance -> position lookups are uniform.
##
## `slip_offsets` is optional: a dictionary of {control_point_index: degrees}
## describing where the vehicle slides rather than tracks.
func _init(
		control_points: Array[Vector3],
		slip_offsets: Dictionary = {},
		final_heading_degrees: float = NAN,
		final_heading_ramp_from: int = -1
) -> void:
	if control_points.size() < 2:
		push_error("CrashPath needs at least two control points.")
		return
	_resample(control_points)
	_build_slip_offsets(control_points, slip_offsets)
	_build_final_heading(control_points, final_heading_degrees, final_heading_ramp_from)


func get_length() -> float:
	return _total_length


func is_valid() -> bool:
	return _points.size() >= 2 and _total_length > 0.0


## Position after travelling `distance` metres along the path.
func sample_position(distance: float) -> Vector3:
	if _points.size() < 2:
		return Vector3.ZERO
	var clamped: float = clampf(distance, 0.0, _total_length)
	var index: int = _find_index(clamped)
	var span: float = _distances[index + 1] - _distances[index]
	if span <= 0.00001:
		return _points[index]
	var local_t: float = (clamped - _distances[index]) / span
	return _points[index].lerp(_points[index + 1], local_t)


## Unit tangent of the path at `distance`, i.e. the direction of travel.
func sample_tangent(distance: float) -> Vector3:
	if _points.size() < 2:
		return Vector3.FORWARD
	var clamped: float = clampf(distance, 0.0, _total_length)
	var index: int = _find_index(clamped)
	var span: float = _distances[index + 1] - _distances[index]
	if span <= 0.00001:
		return Vector3.FORWARD
	return (_points[index + 1] - _points[index]).normalized()


## Yaw in radians such that the vehicle's forward axis (-Z) points along the
## path, plus any slip offset. Godot's convention: forward is -Z, so
## yaw = atan2(-tx, -tz).
func sample_yaw(distance: float) -> float:
	var tangent: Vector3 = sample_tangent(distance)
	var tangent_yaw: float = atan2(-tangent.x, -tangent.z)
	return tangent_yaw + deg_to_rad(_sample_slip_offset(distance)) \
		+ _sample_final_heading_offset(distance)


## Heading in degrees, for readability in diagnostics and tests.
func sample_yaw_degrees(distance: float) -> float:
	return rad_to_deg(wrapf(sample_yaw(distance), -PI, PI))


## Signed slip angle in degrees: how far the vehicle's nose is from the
## direction it is actually travelling. Zero means the car is tracking.
func sample_slip_degrees(distance: float) -> float:
	return _sample_slip_offset(distance)


## The slip offset in degrees at the given distance.
func _sample_slip_offset(distance: float) -> float:
	if _slip_offsets.is_empty():
		return 0.0
	if distance <= _slip_distances[0]:
		return _slip_offsets[0]
	for index: int in range(_slip_distances.size() - 1):
		var start: float = _slip_distances[index]
		var end: float = _slip_distances[index + 1]
		if distance <= end:
			var span: float = end - start
			if span <= 0.00001:
				return _slip_offsets[index + 1]
			var local_t: float = (distance - start) / span
			return lerpf(_slip_offsets[index], _slip_offsets[index + 1], local_t)
	return _slip_offsets[_slip_offsets.size() - 1]


func _resample(control_points: Array[Vector3]) -> void:
	# Cumulative distance along the raw control polyline.
	var raw_distances: PackedFloat32Array = PackedFloat32Array()
	var raw_points: PackedVector3Array = PackedVector3Array()
	raw_points.append(control_points[0])
	raw_distances.append(0.0)
	var running: float = 0.0
	for index: int in range(control_points.size() - 1):
		running += (control_points[index + 1] - control_points[index]).length()
		raw_points.append(control_points[index + 1])
		raw_distances.append(running)

	if running <= 0.0:
		push_error("CrashPath control points describe a zero-length line.")
		return

	# Resample at uniform arc length.
	_points.append(raw_points[0])
	_distances.append(0.0)
	var raw_index: int = 0
	var travelled: float = 0.0
	while travelled < running:
		travelled += SAMPLE_SPACING
		if travelled >= running:
			break
		while raw_index < raw_distances.size() - 2 and raw_distances[raw_index + 1] < travelled:
			raw_index += 1
		var segment_start: float = raw_distances[raw_index]
		var segment_end: float = raw_distances[raw_index + 1]
		var span: float = segment_end - segment_start
		var local_t: float = 0.0
		if span > 0.00001:
			local_t = (travelled - segment_start) / span
		_points.append(raw_points[raw_index].lerp(raw_points[raw_index + 1], local_t))
		_distances.append(travelled)
	_points.append(raw_points[raw_points.size() - 1])
	_distances.append(running)
	_total_length = running


## Slip offsets are supplied as {control_point_index: degrees}. They are
## anchored to the arc length of that control point so they stay aligned with
## the geometry as the path is resampled.
func _build_slip_offsets(control_points: Array[Vector3], offsets: Dictionary) -> void:
	if offsets.is_empty():
		return
	var control_distances: PackedFloat32Array = PackedFloat32Array()
	var running: float = 0.0
	control_distances.append(0.0)
	for index: int in range(control_points.size() - 1):
		running += (control_points[index + 1] - control_points[index]).length()
		control_distances.append(running)

	var sorted_keys: Array = offsets.keys()
	sorted_keys.sort()
	for key: Variant in sorted_keys:
		var control_index: int = int(key)
		if control_index < 0 or control_index >= control_distances.size():
			push_error("CrashPath slip offset references invalid control point %d." % control_index)
			continue
		var distance: float = control_distances[control_index]
		# Two control points can share a distance - a vehicle that comes to
		# rest at a point it has already reached has no distance left to
		# slide in. Only one entry can describe that distance, so the later
		# control point wins.
		if _slip_distances.size() > 0 \
				and absf(_slip_distances[_slip_distances.size() - 1] - distance) < 0.0001:
			_slip_offsets[_slip_offsets.size() - 1] = float(offsets[key])
			continue
		_slip_distances.append(distance)
		_slip_offsets.append(float(offsets[key]))


## Work out how much extra heading the vehicle must acquire between the
## tangent it was travelling on and the heading it is declared to be
## resting at.
##
## The correction is applied over the LAST CONTROLLED SEGMENT of the path,
## so the vehicle is already turning into its final attitude as it settles
## rather than snapping round at the very last metre. The last segment is
## found by skipping trailing control points that do not advance the
## vehicle, because a vehicle that comes to rest at a point it has already
## reached has no distance left to turn in.
func _build_final_heading(
		control_points: Array[Vector3],
		final_heading_degrees: float,
		ramp_from: int
) -> void:
	if is_nan(final_heading_degrees):
		return
	_final_heading_degrees = final_heading_degrees

	# Find the last control point that actually advances the vehicle.
	var last_moving: int = control_points.size() - 1
	while last_moving > 0 \
			and (control_points[last_moving] - control_points[last_moving - 1]).length() < 0.0001:
		last_moving -= 1
	if last_moving <= 0:
		return

	# The ramp can start at a named control point, so that a vehicle can
	# complete its turn to face its resting direction while it is still
	# clear of whatever it is about to come to rest against. Otherwise the
	# ramp runs over the last segment only.
	var ramp_start_index: int = last_moving - 1
	if ramp_from >= 1 and ramp_from < last_moving:
		ramp_start_index = ramp_from

	# The tangent approaching the end of the path.
	var approach: Vector3 = control_points[last_moving] - control_points[last_moving - 1]
	if approach.length() < 0.0001:
		return
	approach = approach.normalized()
	var tangent_yaw: float = atan2(-approach.x, -approach.z)

	# The declared heading is a compass bearing: 0 is north (-Z), 90 east.
	# Godot's yaw for that bearing is atan2(-x, -z) of the bearing vector.
	var bearing_radians: float = deg_to_rad(final_heading_degrees)
	var desired_yaw: float = atan2(-sin(bearing_radians), cos(bearing_radians))

	var offset: float = wrapf(desired_yaw - tangent_yaw, -PI, PI)
	_final_heading_offset = rad_to_deg(offset)
	_final_heading_target = desired_yaw

	# The correction runs from the start of the last segment to the end.
	var running: float = 0.0
	for index: int in range(ramp_start_index):
		running += (control_points[index + 1] - control_points[index]).length()
	_final_heading_start = running

	# The heading the vehicle has when the ramp starts, so the ramp can
	# blend from the heading it actually has into the heading it must end
	# at, without a jump at the start of the ramp.
	var ramp_approach: Vector3 = control_points[ramp_start_index + 1] - control_points[ramp_start_index]
	if ramp_approach.length() < 0.0001:
		_final_heading_from = tangent_yaw
	else:
		ramp_approach = ramp_approach.normalized()
		_final_heading_from = atan2(-ramp_approach.x, -ramp_approach.z)
	_final_heading_end = _total_length


## The extra heading correction in radians at the given distance.
func _sample_final_heading_offset(distance: float) -> float:
	if is_nan(_final_heading_degrees) or _total_length <= 0.0:
		return 0.0
	if distance <= _final_heading_start:
		return 0.0
	var span: float = _final_heading_end - _final_heading_start
	if span <= 0.00001:
		return 0.0
	var local_t: float = clampf((distance - _final_heading_start) / span, 0.0, 1.0)
	# The ramp blends from the heading the vehicle has at the start of the
	# ramp to the heading it must be resting at, so the correction is
	# continuous with the tangent at both ends.
	var blended: float = lerpf(_final_heading_from, _final_heading_target, local_t)
	return wrapf(blended - _final_heading_from, -PI, PI)


func _find_index(distance: float) -> int:
	# Binary search over the uniform arc-length table.
	var low: int = 0
	var high: int = _distances.size() - 2
	while low < high:
		var mid: int = (low + high + 1) / 2
		if _distances[mid] <= distance:
			low = mid
		else:
			high = mid - 1
	return low
