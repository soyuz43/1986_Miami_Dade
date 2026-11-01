class_name WeaponData
extends Resource

enum WeaponClass {
	RIFLE,
	PISTOL,
	REVOLVER,
	SHOTGUN,
}

@export var display_name: String = ""
@export var weapon_class: WeaponClass = WeaponClass.RIFLE
@export var caliber: String = ""
@export var magazine_size: int = 0
@export var rounds_per_minute: float = 0.0
@export var reload_time_seconds: float = 0.0
@export var spread_degrees: float = 0.0
@export_range(0.0, 100.0) var penetration_power: float = 0.0
@export var damage_base: float = 0.0
@export var can_fire_one_handed: bool = false
@export_range(0.0, 1.0) var malfunction_chance: float = 0.0
