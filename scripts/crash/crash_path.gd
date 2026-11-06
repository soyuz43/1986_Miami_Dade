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

var _points: PackedVector3Array = PackedVector3Array()
var _distances: PackedFloat32Array = PackedFloat32Array()
var _total_length: float = 0.0


## Build a path from a list of control points. The polyline is resampled at a
## fixed spacing so that distance -> position lookups are uniform.
##
## `slip_offsets` is optional: a dictionary of {control_point_index: degrees}
## describing where the vehicle slides rather than tracks.
func _init(control_points: Array[Vector3], slip_offsets: Dictionary = {}) -> void:
	if control_points.size() < 2:
		push_error("CrashPath needs at least two control points.")
		return
	_resample(control_points)
	_build_slip_offsets(control_points, slip_offsets)


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
	return tangent_yaw + deg_to_rad(_sample_slip_offset(distance))


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
		_slip_distances.append(control_distances[control_index])
		_slip_offsets.append(float(offsets[key]))


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
