extends Node

@export var active_timeline: TimelineData

var current_time: float = 0.0
var is_playing: bool = false
var playback_speed: float = 1.0
var _executed_event_indices: Dictionary = {}
var _last_timeline: TimelineData = null
var _ordered_event_indices: Array[int] = []

func reset(timeline: TimelineData = null) -> void:
	is_playing = false
	current_time = 0.0
	if timeline != null:
		active_timeline = timeline
	_last_timeline = active_timeline
	_executed_event_indices.clear()
	_refresh_event_order()

func _physics_process(delta: float) -> void:
	if active_timeline != _last_timeline:
		_last_timeline = active_timeline
		_executed_event_indices.clear()
		_refresh_event_order()

	if not is_playing or active_timeline == null:
		return

	if current_time <= 0.0 and _executed_event_indices.is_empty():
		_dispatch_events_at_start()

	var previous_time: float = current_time
	var next_time: float = previous_time + delta * playback_speed
	for event_index: int in _ordered_event_indices:
		if _executed_event_indices.has(event_index):
			continue

		var event: TimelineEvent = active_timeline.events[event_index]
		if event == null:
			_executed_event_indices[event_index] = true
			continue

		if event.timestamp_seconds > previous_time and event.timestamp_seconds <= next_time:
			_executed_event_indices[event_index] = true
			current_time = event.timestamp_seconds
			execute_event(event)

	current_time = next_time
	if _executed_event_indices.size() >= active_timeline.events.size():
		is_playing = false

func execute_event(event: TimelineEvent) -> void:
	if event == null:
		return

	var actor: Actor = _find_actor_by_id(event.actor_id)
	if actor == null:
		push_warning("Timeline event references unknown actor '%s'." % event.actor_id)
		return

	match event.event_type:
		TimelineEvent.EventType.FIRE_WEAPON:
			var target_actor: Actor = _find_actor_by_id(event.target_actor_id)
			if target_actor == null:
				push_warning("Timeline event references unknown target actor '%s'." % event.target_actor_id)
				return
			actor.fire_weapon(target_actor)
		TimelineEvent.EventType.MOVE_TO:
			var destination: Variant = event.parameters.get("position")
			if destination is Vector3:
				actor.move_to(destination)
				print("[T:%.2f] %s MOVE_TO -> %s." % [current_time, _actor_display_name(actor), actor.global_position])
			else:
				push_warning("MOVE_TO event requires a Vector3 'position' parameter.")
		TimelineEvent.EventType.RELOAD:
			actor.reload_weapon()
		TimelineEvent.EventType.STATE_CHANGE:
			var state_value: Variant = event.parameters.get("state", "")
			if _apply_state_change(actor, state_value):
				print("[T:%.2f] %s state -> %s." % [current_time, _actor_display_name(actor), str(state_value).to_upper()])
		TimelineEvent.EventType.WEAPON_TRANSITION:
			var weapon_slot: String = str(event.parameters.get("weapon_slot", "backup"))
			if not actor.transition_weapon(weapon_slot):
				push_warning("WEAPON_TRANSITION could not equip slot '%s'." % weapon_slot)

func play() -> void:
	is_playing = true

func pause() -> void:
	is_playing = false

func set_speed(multiplier: float) -> void:
	playback_speed = maxf(multiplier, 0.0)

func seek_to(time: float) -> void:
	current_time = time
	_executed_event_indices.clear()

func _find_actor_by_id(actor_id: String) -> Actor:
	if actor_id.is_empty():
		return null
	return _find_actor_recursive(get_tree().root, actor_id)

func _dispatch_events_at_start() -> void:
	if active_timeline == null:
		return
	for event_index: int in _ordered_event_indices:
		if _executed_event_indices.has(event_index):
			continue
		var event: TimelineEvent = active_timeline.events[event_index]
		if event == null or event.timestamp_seconds > current_time:
			continue
		_executed_event_indices[event_index] = true
		execute_event(event)

func _refresh_event_order() -> void:
	_ordered_event_indices.clear()
	if active_timeline == null:
		return
	for event_index: int in range(active_timeline.events.size()):
		_ordered_event_indices.append(event_index)
	_ordered_event_indices.sort_custom(func(left_index: int, right_index: int) -> bool:
		var left_event: TimelineEvent = active_timeline.events[left_index]
		var right_event: TimelineEvent = active_timeline.events[right_index]
		if left_event == null:
			return false
		if right_event == null:
			return true
		if left_event.timestamp_seconds == right_event.timestamp_seconds:
			return left_index < right_index
		return left_event.timestamp_seconds < right_event.timestamp_seconds
	)

func _find_actor_recursive(node: Node, actor_id: String) -> Actor:
	if node is Actor:
		var actor: Actor = node as Actor
		if actor.profile != null and actor.profile.actor_id == actor_id:
			return actor

	for child: Node in node.get_children():
		var found_actor: Actor = _find_actor_recursive(child, actor_id)
		if found_actor != null:
			return found_actor
	return null

func _apply_state_change(actor: Actor, state_value: Variant) -> bool:
	var state_name: String = str(state_value).to_upper()
	match state_name:
		"0", "IDLE":
			actor.set_actor_state(Actor.ActorState.IDLE)
		"1", "MOVING":
			actor.set_actor_state(Actor.ActorState.MOVING)
		"2", "FIRING":
			actor.set_actor_state(Actor.ActorState.FIRING)
		"3", "RELOADING":
			actor.set_actor_state(Actor.ActorState.RELOADING)
		"4", "WOUNDED":
			actor.set_actor_state(Actor.ActorState.WOUNDED)
		"5", "INCAPACITATED":
			actor.set_actor_state(Actor.ActorState.INCAPACITATED)
		"6", "DEAD":
			actor.set_actor_state(Actor.ActorState.DEAD)
		_:
			push_warning("STATE_CHANGE has an invalid actor state '%s'." % state_name)
			return false
	return true

func _actor_display_name(actor: Actor) -> String:
	if actor.profile != null and not actor.profile.display_name.is_empty():
		return actor.profile.display_name
	return actor.name
