class_name CrashSpeedProfile
extends RefCounted

## How fast a vehicle is travelling over the course of the crash sequence.
##
## The old implementation eased each keyframe segment independently with a
## smoothstep, which meant velocity fell to zero at *every* keyframe. Measured
## on the subject vehicle that produced speeds of 0.05-0.33 m/s at the
## boundaries, so the cars appeared to stutter rather than drive.
##
## This profile is defined as a list of speed knots over *sequence time*, with
## the speed varying smoothly between them. It is deliberately a separate
## concept from CrashPath's arc length: the path says where a vehicle is, this
## says how fast it gets there, and the sequence integrates one into the other.
##
## Speed is expressed in metres per second. Conversion: 1 m/s = 2.2369 mph.
## The Miami Herald places the pursuit at roughly 35 mph, i.e. 15.6 m/s.

const MPH_TO_MPS: float = 0.44704

## A knot: at `time` seconds the vehicle is travelling `speed` m/s.
var _knots: Array[Dictionary] = []
var _times: PackedFloat32Array = PackedFloat32Array()
var _speeds: PackedFloat32Array = PackedFloat32Array()


func _init(knots: Array[Dictionary]) -> void:
	# Each knot: {"time": float, "speed": float} (metres per second).
	var sorted: Array[Dictionary] = []
	for knot: Dictionary in knots:
		sorted.append(knot)
	sorted.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return float(left["time"]) < float(right["time"]))

	for knot: Dictionary in sorted:
		_knots.append(knot)
		_times.append(float(knot["time"]))
		_speeds.append(float(knot["speed"]))

	if _times.size() > 0 and _times[0] > 0.0:
		push_error("CrashSpeedProfile should start at t=0.0; inserting a stop knot.")


func is_valid() -> bool:
	return _knots.size() >= 2


func get_start_time() -> float:
	return _times[0] if _times.size() > 0 else 0.0


func get_end_time() -> float:
	return _times[_times.size() - 1] if _times.size() > 0 else 0.0


## Speed in m/s at the given sequence time. Smoothstep between knots, so the
## derivative (acceleration) is continuous at every knot.
func speed_at(time: float) -> float:
	if _times.is_empty():
		return 0.0
	if time <= _times[0]:
		return _speeds[0]
	if time >= _times[_times.size() - 1]:
		return _speeds[_speeds.size() - 1]

	var index: int = _find_index(time)
	var start_time: float = _times[index]
	var end_time: float = _times[index + 1]
	var span: float = end_time - start_time
	if span <= 0.00001:
		return _speeds[index + 1]
	var local_t: float = (time - start_time) / span
	local_t = local_t * local_t * (3.0 - 2.0 * local_t)
	return lerpf(_speeds[index], _speeds[index + 1], local_t)


## Integrate the profile to get the distance travelled by `time`.
## Uses Simpson's rule per knot interval, which keeps the integral accurate
## even where the speed profile curves sharply.
func distance_at(time: float) -> float:
	if _times.size() < 2:
		return 0.0
	if time <= _times[0]:
		return 0.0
	if time >= _times[_times.size() - 1]:
		return _total_distance()

	var total: float = 0.0
	var index: int = _find_index(time)
	for knot_index: int in range(index):
		total += _integrate_segment(_times[knot_index], _times[knot_index + 1])
	total += _integrate_segment(_times[index], time)
	return total


func _total_distance() -> float:
	var total: float = 0.0
	for knot_index: int in range(_times.size() - 1):
		total += _integrate_segment(_times[knot_index], _times[knot_index + 1])
	return total


func _integrate_segment(start_time: float, end_time: float) -> float:
	var steps: int = 8
	var span: float = end_time - start_time
	if span <= 0.0:
		return 0.0
	var step: float = span / float(steps)
	var total: float = 0.0
	for step_index: int in range(steps):
		var t0: float = start_time + step * float(step_index)
		var t1: float = t0 + step
		var tm: float = (t0 + t1) * 0.5
		total += (speed_at(t0) + 4.0 * speed_at(tm) + speed_at(t1)) * step / 6.0
	return total


## Inverse lookup: the sequence time at which the vehicle has travelled
## `distance` metres. Used to derive a vehicle's position from its speed.
func time_for_distance(distance: float) -> float:
	if _times.size() < 2:
		return _times[0] if _times.size() > 0 else 0.0
	if distance <= 0.0:
		return _times[0]
	var total: float = _total_distance()
	if distance >= total:
		return _times[_times.size() - 1]

	var low: float = _times[0]
	var high: float = _times[_times.size() - 1]
	# Binary search on the monotone distance_at().
	for _iteration: int in range(40):
		var mid: float = (low + high) * 0.5
		if distance_at(mid) < distance:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5


func _find_index(time: float) -> int:
	var low: int = 0
	var high: int = _times.size() - 2
	while low < high:
		var mid: int = (low + high + 1) / 2
		if _times[mid] <= time:
			low = mid
		else:
			high = mid - 1
	return low


static func mph(value: float) -> float:
	return value * MPH_TO_MPS
