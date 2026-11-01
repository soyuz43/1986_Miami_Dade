extends Node3D

const SIMULATION_SEED: int = 1986

@export var platt_profile: ActorProfile
@export var dove_profile: ActorProfile
@export var demo_timeline: TimelineData

@onready var demo_camera: Camera3D = $Camera3D
@onready var status_label: Label = $CanvasLayer/StatusLabel

var _playback_started: bool = false

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
	_spawn_actor(platt_profile, Vector3(0.0, 0.0, 0.0), Color(0.78, 0.28, 0.18))
	_spawn_actor(dove_profile, Vector3(10.0, 0.0, 0.0), Color(0.2, 0.43, 0.78))

	SimulationManager.reset(demo_timeline)
	SimulationManager.set_speed(1.0)
	SimulationManager.play()
	_playback_started = true
	status_label.text = "3D overhead blockout  |  Press R to replay\nBox-car placeholders | Test timeline, not a historical reconstruction"

func _process(_delta: float) -> void:
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
	_add_vehicle_placeholder(actor, "Cabin", Vector3(1.45, 0.38, 1.12), Vector3(0.0, 0.86, 0.0), Color(0.12, 0.15, 0.18))

	var name_label: Label3D = Label3D.new()
	name_label.text = actor_profile.display_name
	name_label.font_size = 32
	name_label.pixel_size = 0.005
	name_label.position.y = 1.4
	name_label.modulate = Color(0.98, 0.98, 0.92)
	name_label.outline_size = 8
	name_label.outline_modulate = Color(0.08, 0.09, 0.11)
	actor.add_child(name_label)
	return actor

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

func _add_vehicle_placeholder(parent: Node3D, box_name: String, box_size: Vector3, local_position: Vector3, box_color: Color) -> void:
	parent.add_child(_create_box(box_name, box_size, local_position, box_color))

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
