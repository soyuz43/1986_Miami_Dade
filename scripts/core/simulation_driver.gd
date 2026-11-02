extends Node3D

const SIMULATION_SEED: int = 1986
const SHOOTER_EXIT_DURATION: float = 0.65
const MUZZLE_FLASH_DURATION: float = 0.12

@export var platt_profile: ActorProfile
@export var dove_profile: ActorProfile
@export var demo_timeline: TimelineData

@onready var demo_camera: Camera3D = $Camera3D
@onready var status_label: Label = $CanvasLayer/StatusLabel

var _playback_started: bool = false
var _platt_actor: Actor
var _shooter_figure: Node3D
var _muzzle_flash: MeshInstance3D
var _last_platt_ammo: int = 0
var _muzzle_flash_timer: float = 0.0
var _shooter_exit_started: bool = false

func _ready() -> void:
	if platt_profile == null or dove_profile == null or demo_timeline == null:
		push_error("The simulation demo requires both actor profiles and a timeline.")
		return

	demo_camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	_build_blockout()
	print("=== MIAMI 1986 SIMULATION PROTOTYPE ===")
	print("Timeline: %s | Account: %s" % [demo_timeline.timeline_name, demo_timeline.source_account])
	print("Deterministic random seed: %d" % SIMULATION_SEED)
	print("Press R in the game window to replay this test timeline.")

	Actor.set_random_seed(SIMULATION_SEED)
	BallisticSolver.set_random_seed(SIMULATION_SEED)
	_platt_actor = _spawn_actor(platt_profile, Vector3(0.0, 0.0, 0.0), Color(0.78, 0.28, 0.18))
	_spawn_actor(dove_profile, Vector3(10.0, 0.0, 0.0), Color(0.2, 0.43, 0.78))
	_last_platt_ammo = _platt_actor.current_ammo

	SimulationManager.reset(demo_timeline)
	SimulationManager.set_speed(1.0)
	SimulationManager.play()
	_playback_started = true
	status_label.text = "Platt exits the car, then fires  |  Press R to replay\nBox-car placeholders | Test timeline, not a historical reconstruction"

func _process(delta: float) -> void:
	if _platt_actor != null:
		if not _shooter_exit_started and _platt_actor.position.distance_squared_to(Vector3.ZERO) > 0.001:
			_animate_shooter_exit()
		if _platt_actor.current_ammo < _last_platt_ammo:
			_muzzle_flash_timer = MUZZLE_FLASH_DURATION
			_muzzle_flash.visible = true
		_last_platt_ammo = _platt_actor.current_ammo

	if _muzzle_flash_timer > 0.0:
		_muzzle_flash_timer = maxf(_muzzle_flash_timer - delta, 0.0)
		_muzzle_flash.visible = _muzzle_flash_timer > 0.0

	if _playback_started and not SimulationManager.is_playing:
		_playback_started = false
		status_label.text = "Replay complete  |  Press R to replay\nBox-car placeholders | Test timeline, not a historical reconstruction"

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func _spawn_actor(actor_profile: ActorProfile, spawn_position: Vector3, marker_color: Color) -> Actor:
	var actor: Actor = Actor.new()
	actor.name = actor_profile.actor_id
	actor.profile = actor_profile
	actor.position = spawn_position
	add_child(actor)

	_add_vehicle_placeholder(actor, "Body", Vector3(2.8, 0.65, 1.4), Vector3(0.0, 0.36, 0.0), marker_color)
	if actor_profile == platt_profile:
		_shooter_figure = _add_shooter_figure(actor)
		_add_vehicle_placeholder(actor, "Cabin", Vector3(1.45, 0.38, 1.12), Vector3(0.0, 0.86, 0.0), Color(0.12, 0.15, 0.18), true)
	else:
		_add_vehicle_placeholder(actor, "Cabin", Vector3(1.45, 0.38, 1.12), Vector3(0.0, 0.86, 0.0), Color(0.12, 0.15, 0.18))

	var name_label: Label3D = Label3D.new()
	name_label.text = actor_profile.display_name
	name_label.font_size = 32
	name_label.pixel_size = 0.005
	name_label.position.y = 1.4
	name_label.modulate = Color(0.98, 0.98, 0.92)
	name_label.outline_size = 8
	name_label.outline_modulate = Color(0.08, 0.09, 0.11)
	if actor_profile == platt_profile:
		name_label.position.y = 1.7
		_shooter_figure.add_child(name_label)
	else:
		actor.add_child(name_label)
	return actor

func _add_shooter_figure(parent: Node3D) -> Node3D:
	var figure: Node3D = Node3D.new()
	figure.name = "PlattOnFoot"
	parent.add_child(figure)

	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Body"
	var body_mesh: CapsuleMesh = CapsuleMesh.new()
	body_mesh.radius = 0.22
	body_mesh.height = 1.1
	body.mesh = body_mesh
	body.position.y = 0.62
	var body_material: StandardMaterial3D = StandardMaterial3D.new()
	body_material.albedo_color = Color(0.95, 0.52, 0.16)
	body_material.roughness = 1.0
	body.material_override = body_material
	figure.add_child(body)

	var head: MeshInstance3D = MeshInstance3D.new()
	head.name = "Head"
	var head_mesh: SphereMesh = SphereMesh.new()
	head_mesh.radius = 0.17
	head_mesh.height = 0.34
	head.mesh = head_mesh
	head.position.y = 1.31
	head.material_override = body_material
	figure.add_child(head)

	var weapon: MeshInstance3D = MeshInstance3D.new()
	weapon.name = "Weapon"
	var weapon_mesh: BoxMesh = BoxMesh.new()
	weapon_mesh.size = Vector3(0.55, 0.08, 0.1)
	weapon.mesh = weapon_mesh
	weapon.position = Vector3(0.38, 0.8, 0.0)
	var weapon_material: StandardMaterial3D = StandardMaterial3D.new()
	weapon_material.albedo_color = Color(0.08, 0.08, 0.07)
	weapon.material_override = weapon_material
	figure.add_child(weapon)

	_muzzle_flash = MeshInstance3D.new()
	_muzzle_flash.name = "MuzzleFlash"
	var flash_mesh: SphereMesh = SphereMesh.new()
	flash_mesh.radius = 0.16
	flash_mesh.height = 0.32
	_muzzle_flash.mesh = flash_mesh
	_muzzle_flash.position = Vector3(0.72, 0.8, 0.0)
	var flash_material: StandardMaterial3D = StandardMaterial3D.new()
	flash_material.albedo_color = Color(1.0, 0.72, 0.12)
	flash_material.emission_enabled = true
	flash_material.emission = Color(1.0, 0.46, 0.04)
	_muzzle_flash.material_override = flash_material
	_muzzle_flash.visible = false
	figure.add_child(_muzzle_flash)
	return figure

func _animate_shooter_exit() -> void:
	_shooter_exit_started = true
	var exit_tween: Tween = create_tween()
	exit_tween.tween_property(_shooter_figure, "position", Vector3(0.0, 0.0, 1.2), SHOOTER_EXIT_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _build_blockout() -> void:
	var blockout: Node3D = Node3D.new()
	blockout.name = "OverheadBlockout"
	add_child(blockout)

	_add_box(blockout, "MainRoad", Vector3(36.0, 0.12, 8.0), Vector3(3.0, -0.005, 0.0), Color(0.34, 0.35, 0.36))
	_add_box(blockout, "SouthRoad", Vector3(7.0, 0.12, 17.0), Vector3(2.0, -0.005, 8.5), Color(0.34, 0.35, 0.36))
	_add_road_segment(blockout, "CurvedApproach1", Vector3(-21.0, 0.0, -10.0), Vector3(-21.0, 0.0, -5.0), 6.5)
	_add_road_segment(blockout, "CurvedApproach2", Vector3(-21.0, 0.0, -5.0), Vector3(-18.0, 0.0, -1.5), 6.5)
	_add_road_segment(blockout, "CurvedApproach3", Vector3(-18.0, 0.0, -1.5), Vector3(-12.0, 0.0, 0.0), 6.5)

	_add_box(blockout, "ParkingLot", Vector3(15.0, 0.12, 8.0), Vector3(4.0, -0.005, -10.0), Color(0.4, 0.41, 0.42))
	_add_box(blockout, "ParkingEntrance", Vector3(4.0, 0.12, 5.0), Vector3(4.0, -0.005, -4.5), Color(0.34, 0.35, 0.36))
	_add_road_markings(blockout)
	_add_parking_stalls(blockout)
	_add_parked_vehicles(blockout)

func _add_road_segment(parent: Node3D, segment_name: String, start: Vector3, finish: Vector3, width: float) -> void:
	var direction: Vector3 = finish - start
	var road: MeshInstance3D = _create_box(segment_name, Vector3(direction.length() + 0.25, 0.12, width), (start + finish) * 0.5, Color(0.34, 0.35, 0.36))
	road.rotation.y = atan2(-direction.z, direction.x)
	parent.add_child(road)

func _add_road_markings(parent: Node3D) -> void:
	var marking_color: Color = Color(0.83, 0.82, 0.72)
	for index: int in range(7):
		var dash_x: float = -8.0 + float(index) * 4.0
		_add_box(parent, "RoadDash_%d" % index, Vector3(1.8, 0.025, 0.12), Vector3(dash_x, 0.07, 0.0), marking_color)
	for index: int in range(4):
		var dash_z: float = 5.0 + float(index) * 3.0
		_add_box(parent, "BranchDash_%d" % index, Vector3(0.12, 0.025, 1.5), Vector3(2.0, 0.07, dash_z), marking_color)

func _add_parking_stalls(parent: Node3D) -> void:
	var line_color: Color = Color(0.78, 0.78, 0.7)
	for index: int in range(4):
		var divider_x: float = -3.0 + float(index) * 3.5
		_add_box(parent, "ParkingDivider_%d" % index, Vector3(0.07, 0.025, 6.8), Vector3(divider_x, 0.07, -10.0), line_color)

func _add_parked_vehicles(parent: Node3D) -> void:
	var vehicle_positions: Array[Vector3] = [
		Vector3(-1.0, 0.0, -10.0),
		Vector3(2.5, 0.0, -10.0),
		Vector3(6.0, 0.0, -10.0),
		Vector3(9.5, 0.0, -10.0),
	]
	var vehicle_colors: Array[Color] = [
		Color(0.72, 0.65, 0.36),
		Color(0.24, 0.28, 0.32),
		Color(0.68, 0.7, 0.72),
		Color(0.28, 0.38, 0.62),
	]
	for index: int in range(vehicle_positions.size()):
		var vehicle: Node3D = Node3D.new()
		vehicle.name = "ParkedCar_%d" % (index + 1)
		vehicle.position = vehicle_positions[index]
		parent.add_child(vehicle)
		_add_vehicle_placeholder(vehicle, "Body", Vector3(2.6, 0.62, 1.25), Vector3(0.0, 0.35, 0.0), vehicle_colors[index])
		_add_vehicle_placeholder(vehicle, "Cabin", Vector3(1.45, 0.36, 1.02), Vector3(0.0, 0.84, 0.0), Color(0.14, 0.17, 0.2))

func _add_vehicle_placeholder(parent: Node3D, box_name: String, box_size: Vector3, local_position: Vector3, box_color: Color, transparent: bool = false) -> void:
	var vehicle_part: MeshInstance3D = _create_box(box_name, box_size, local_position, box_color)
	if transparent:
		var material: StandardMaterial3D = vehicle_part.material_override as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var cabin_color: Color = material.albedo_color
		cabin_color.a = 0.4
		material.albedo_color = cabin_color
	parent.add_child(vehicle_part)

func _add_box(parent: Node3D, box_name: String, box_size: Vector3, box_position: Vector3, box_color: Color) -> void:
	parent.add_child(_create_box(box_name, box_size, box_position, box_color))

func _create_box(box_name: String, box_size: Vector3, box_position: Vector3, box_color: Color) -> MeshInstance3D:
	var box: MeshInstance3D = MeshInstance3D.new()
	box.name = box_name
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = box_size
	box.mesh = box_mesh
	box.position = box_position
	var box_material: StandardMaterial3D = StandardMaterial3D.new()
	box_material.albedo_color = box_color
	box_material.roughness = 1.0
	box.material_override = box_material
	return box
