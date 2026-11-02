class_name CrashVehicleFactory
extends RefCounted

## Builds the box-shaped placeholder vehicles used by the crash blockout.
##
## These are deliberately primitive. Milestone 1 exists to test staging,
## scale and sequence, not to reproduce the shape of any real vehicle.

const DEFAULT_LENGTH: float = 4.9
const DEFAULT_WIDTH: float = 1.9
const DEFAULT_WHEEL_RADIUS: float = 0.35

const GLASS_COLOR: Color = Color(0.05, 0.06, 0.07)
const TYRE_COLOR: Color = Color(0.04, 0.04, 0.05)
const HEADLIGHT_COLOR: Color = Color(0.85, 0.85, 0.75)
const TAILLIGHT_COLOR: Color = Color(0.55, 0.07, 0.06)


static func create_vehicle(
	length: float = DEFAULT_LENGTH,
	width: float = DEFAULT_WIDTH,
	body_color: Color = Color(0.12, 0.12, 0.14),
	roof_color: Color = Color(0.10, 0.10, 0.12),
	wheel_radius: float = DEFAULT_WHEEL_RADIUS
) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Vehicle"

	var lower_body: MeshInstance3D = MeshInstance3D.new()
	lower_body.name = "LowerBody"
	var body_mesh: BoxMesh = BoxMesh.new()
	body_mesh.size = Vector3(width, 0.62, length)
	lower_body.mesh = body_mesh
	lower_body.position.y = 0.66
	lower_body.material_override = _make_material(body_color, 0.45)
	root.add_child(lower_body)

	var glass: MeshInstance3D = MeshInstance3D.new()
	glass.name = "Glass"
	var glass_mesh: BoxMesh = BoxMesh.new()
	glass_mesh.size = Vector3(width * 0.92, 0.50, length * 0.44)
	glass.mesh = glass_mesh
	glass.position = Vector3(0.0, 1.04, 0.05)
	glass.material_override = _make_material(GLASS_COLOR, 0.20)
	root.add_child(glass)

	var roof: MeshInstance3D = MeshInstance3D.new()
	roof.name = "Roof"
	var roof_mesh: BoxMesh = BoxMesh.new()
	roof_mesh.size = Vector3(width * 0.87, 0.12, length * 0.40)
	roof.mesh = roof_mesh
	roof.position = Vector3(0.0, 1.34, 0.05)
	roof.material_override = _make_material(roof_color, 0.55)
	root.add_child(roof)

	var headlight_material: StandardMaterial3D = _make_material(HEADLIGHT_COLOR, 0.25)
	headlight_material.emission_enabled = true
	headlight_material.emission = HEADLIGHT_COLOR
	headlight_material.emission_energy_multiplier = 0.6
	var taillight_material: StandardMaterial3D = _make_material(TAILLIGHT_COLOR, 0.25)
	taillight_material.emission_enabled = true
	taillight_material.emission = TAILLIGHT_COLOR
	taillight_material.emission_energy_multiplier = 0.6

	var half_track: float = width * 0.5 - 0.02
	var half_wheelbase: float = length * 0.5 - 0.95
	for side: int in [-1, 1]:
		var headlight: MeshInstance3D = MeshInstance3D.new()
		headlight.name = "HeadlightLeft" if side < 0 else "HeadlightRight"
		var headlight_mesh: BoxMesh = BoxMesh.new()
		headlight_mesh.size = Vector3(0.28, 0.16, 0.08)
		headlight.mesh = headlight_mesh
		headlight.position = Vector3(side * (half_track - 0.22), 0.74, -length * 0.5 + 0.03)
		headlight.material_override = headlight_material
		root.add_child(headlight)

		var taillight: MeshInstance3D = MeshInstance3D.new()
		taillight.name = "TaillightLeft" if side < 0 else "TaillightRight"
		var taillight_mesh: BoxMesh = BoxMesh.new()
		taillight_mesh.size = Vector3(0.28, 0.16, 0.08)
		taillight.mesh = taillight_mesh
		taillight.position = Vector3(side * (half_track - 0.22), 0.74, length * 0.5 - 0.03)
		taillight.material_override = taillight_material
		root.add_child(taillight)

	for side: int in [-1, 1]:
		for axle: int in [-1, 1]:
			var wheel: MeshInstance3D = MeshInstance3D.new()
			wheel.name = "Wheel%s%s" % ["L" if side < 0 else "R", "Front" if axle < 0 else "Rear"]
			var wheel_mesh: CylinderMesh = CylinderMesh.new()
			wheel_mesh.top_radius = wheel_radius
			wheel_mesh.bottom_radius = wheel_radius
			wheel_mesh.height = 0.24
			wheel_mesh.radial_segments = 12
			wheel.mesh = wheel_mesh
			wheel.position = Vector3(side * half_track, wheel_radius, axle * half_wheelbase)
			wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			wheel.material_override = _make_material(TYRE_COLOR, 0.9)
			root.add_child(wheel)

	return root


static func add_label(parent: Node3D, text: String, height: float = 2.1) -> Label3D:
	var label: Label3D = Label3D.new()
	label.name = "Label"
	label.text = text
	label.font_size = 26
	label.pixel_size = 0.0045
	label.position.y = height
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(0.97, 0.97, 0.92)
	label.outline_size = 10
	label.outline_modulate = Color(0.05, 0.06, 0.08)
	parent.add_child(label)
	return label


static func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.15
	return material
