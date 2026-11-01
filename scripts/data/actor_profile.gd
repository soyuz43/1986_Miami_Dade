class_name ActorProfile
extends Resource

enum Faction {
	FBI,
	SUSPECT,
}

@export var actor_id: String = ""
@export var display_name: String = ""
@export var faction: Faction = Faction.FBI
@export var starting_health: float = 100.0
@export var starting_weapon: WeaponData = null
@export var backup_weapon: WeaponData = null
