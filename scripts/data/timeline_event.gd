class_name TimelineEvent
extends Resource

enum EventType {
	FIRE_WEAPON,
	MOVE_TO,
	RELOAD,
	STATE_CHANGE,
	WEAPON_TRANSITION,
}

@export var timestamp_seconds: float = 0.0
@export var actor_id: String = ""
@export var event_type: EventType = EventType.FIRE_WEAPON
@export var target_actor_id: String = ""
@export var parameters: Dictionary = {}
