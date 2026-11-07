class_name CrashSpeedProfile
extends RefCounted

const MPH_TO_MPS: float = 0.44704

var _times: PackedFloat32Array = PackedFloat32Array()
var _distances: PackedFloat32Array = PackedFloat32Array()
var _tangents: PackedFloat32Array = PackedFloat32Array()

func _init(milestones: Array[Dictionary]) -> void:
	var sorted: Array[Dictionary] = []
	for milestone: Dictionary in milestones:
		sorted.append(milestone)
	sorted.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return float(left["time"]) < float(right["time"]))

	for milestone: Dictionary in sorted:
		var time: float = float(milestone["time"])
		var distance: float = float(milestone["distance"])
		if _times.size() > 0 and time <= _times[_times.size() - 1] + 0.0001:
			if distance > _distances[_distances.size() - 1]:
				_distances[_distances.size() - 1] = distance
			continue
		_times.append(time)
		_distances.append(distance)

	if _times.size() < 2:
		push_error("CrashSpeedProfile needs at least two milestones.")
		return
	if _distances[0] > 0.0001:
		push_error("CrashSpeedProfile should start at distance 0.0.")

	_build_tangents()

func is_valid() -> bool: return _times.size() >= 2
func get_start_time() -> float: return _times[0] if _times.size() > 0 else 0.0
func get_end_time() -> float: return _times[_times.size() - 1] if _times.size() > 0 else 0.0
func get_total_distance() -> float: return _distances[_distances.size() - 1] if _distances.size() > 0 else 0.0

func distance_at(time: float) -> float:
	if _times.size() < 2: return 0.0
	if time <= _times[0]: return _distances[0]
	if time >= _times[_times.size() - 1]: return _distances[_distances.size() - 1]
	var index: int = _find_index(time)
	var span: float = _times[index + 1] - _times[index]
	if span <= 0.0: return _distances[index + 1]
	var local_t: float = (time - _times[index]) / span
	var d0: float = _distances[index]
	var d1: float = _distances[index + 1]
	var m0: float = _tangents[index] * span
	var m1: float = _tangents[index + 1] * span
	var t2: float = local_t * local_t
	var t3: float = t2 * local_t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * d0 + (t3 - 2.0 * t2 + local_t) * m0 + (-2.0 * t3 + 3.0 * t2) * d1 + (t3 - t2) * m1

func speed_at(time: float) -> float:
	if _times.size() < 2: return 0.0
	if time <= _times[0]: return _tangents[0]
	if time >= _times[_times.size() - 1]: return _tangents[_tangents.size() - 1]
	var index: int = _find_index(time)
	var span: float = _times[index + 1] - _times[index]
	if span <= 0.0: return _tangents[index + 1]
	var local_t: float = (time - _times[index]) / span
	var d0: float = _distances[index]
	var d1: float = _distances[index + 1]
	var m0: float = _tangents[index]
	var m1: float = _tangents[index + 1]
	var t2: float = local_t * local_t
	return ((6.0 * t2 - 6.0 * local_t) * d0 + (-6.0 * t2 + 6.0 * local_t) * d1) / span + (3.0 * t2 - 4.0 * local_t + 1.0) * m0 + (3.0 * t2 - 2.0 * local_t) * m1

func time_for_distance(distance: float) -> float:
	if _times.size() < 2: return _times[0] if _times.size() > 0 else 0.0
	if distance <= _distances[0]: return _times[0]
	if distance >= _distances[_distances.size() - 1]: return _times[_times.size() - 1]
	var low: float = _times[0]
	var high: float = _times[_times.size() - 1]
	for _iteration: int in range(48):
		var mid: float = (low + high) * 0.5
		if distance_at(mid) < distance: low = mid
		else: high = mid
	return (low + high) * 0.5

func _build_tangents() -> void:
	var count: int = _times.size()
	var secants: PackedFloat32Array = PackedFloat32Array()
	var spans: PackedFloat32Array = PackedFloat32Array()
	for index: int in range(count - 1):
		var span: float = _times[index + 1] - _times[index]
		spans.append(span)
		secants.append((_distances[index + 1] - _distances[index]) / maxf(span, 0.00001))

	for index: int in range(count):
		var tangent: float = 0.0
		if index == 0:
			tangent = secants[0]
		elif index == count - 1:
			tangent = secants[count - 2]
		else:
			var m0: float = secants[index - 1]
			var m1: float = secants[index]
			if m0 * m1 <= 0.0:
				tangent = 0.0
			else:
				var span0: float = spans[index - 1]
				var span1: float = spans[index]
				var w1: float = 2.0 * span1 + span0
				var w2: float = span1 + 2.0 * span0
				tangent = (w1 + w2) / (w1 / m0 + w2 / m1)
				var max_tangent: float = 3.0 * minf(absf(m0), absf(m1))
				if absf(tangent) > max_tangent:
					tangent = signf(tangent) * max_tangent
		_tangents.append(tangent)

func _find_index(time: float) -> int:
	var low: int = 0
	var high: int = _times.size() - 2
	while low < high:
		var mid: int = (low + high + 1) / 2
		if _times[mid] <= time: low = mid
		else: high = mid - 1
	return low

static func mph(value: float) -> float: return value * MPH_TO_MPS