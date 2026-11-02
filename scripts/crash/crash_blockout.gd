class_name CrashBlockout
extends RefCounted

## Builds the static blockout environment for the April 11, 1986 crash opening.
##
## The layout follows docs/RESEARCH_crash.md. Every dimension here is an ESTIMATE
## derived from the written descriptions in the FBI incident report and the
## Miami Herald reconstruction. The FBI's official Exhibit A diagram (final
## vehicle positions) was not transcribed, so absolute scale is not authoritative.
##
## Coordinate system (Godot default):
##   -X = west   +X = east
##   -Z = north  +Z = south
## 82nd Avenue runs north/south along the Z axis, on the WEST side of the scene.

const ROAD_WIDTH: float = 16.0
const ROAD_CENTER_X: float = 0.0
const ROAD_LENGTH: float = 150.0

const YARD_DEPTH: float = 16.0
const YARD_WEST_EDGE_X: float = -ROAD_WIDTH * 0.5

## Final resting positions. These encode the FBI incident report's statement
## that the subject vehicle came to rest "wedged between a parked civilian
## vehicle, an FBI vehicle and a tree" in a front yard on the west side of
## 82nd Avenue, facing northbound.
## The tree is just ahead of the subject vehicle's north-facing front bumper.
## Manauzzi's car contacts its driver side, and the parked car contacts its
## passenger side, which the Miami Herald reports was jammed shut against it.
const TREE_POSITION: Vector3 = Vector3(-10.9, 0.0, -21.15)
const TREE_TRUNK_RADIUS: float = 0.30

## Lane centres. The road is two lanes wide either side of the centre line.
## Each vehicle is given its own lane so the cars never occupy the same
## stretch of road; they converge only for the documented rams.
const SUBJECT_LANE_X: float = -4.0
const MANAUZZI_LANE_X: float = -7.6
const HANLON_LANE_X: float = 3.6
const GROGAN_LANE_X: float = -0.4

## The subject car's opening position, at the head of the pursuit.
const SUBJECT_APPROACH: Vector3 = Vector3(-4.0, 0.0, -46.0)
const MANAUZZI_APPROACH: Vector3 = Vector3(-7.6, 0.0, -55.0)
const HANLON_APPROACH: Vector3 = Vector3(3.6, 0.0, -50.0)
const GROGAN_APPROACH: Vector3 = Vector3(-0.4, 0.0, -60.0)

## Final resting positions. The subject vehicle ends wedged between Manauzzi's
## FBI car on one side and the parked civilian car on the other, with the
## tree behind it, matching the FBI incident report's description of the car
## being "wedged between a parked civilian vehicle, an FBI vehicle and a tree".
const MANAUZZI_FINAL: Vector3 = Vector3(-12.8, 0.0, -18.4)
const SUBJECT_FINAL: Vector3 = Vector3(-10.9, 0.0, -18.4)
const PARKED_CAR_FINAL: Vector3 = Vector3(-9.0, 0.0, -18.4)
const HANLON_FINAL: Vector3 = Vector3(-10.9, 0.0, -9.0)
const GROGAN_FINAL: Vector3 = Vector3(-4.4, 0.0, -11.2)
const WALL_POSITION: Vector3 = Vector3(-13.9, 1.1, -7.0)
const WALL_SIZE: Vector3 = Vector3(0.45, 2.2, 14.0)
const DRIVEWAY_POSITION: Vector3 = Vector3(-9.9, 0.03, -18.5)
const DRIVEWAY_SIZE: Vector3 = Vector3(4.2, 0.06, 13.0)

const ASPHALT_COLOR: Color = Color(0.18, 0.18, 0.19)
const SIDEWALK_COLOR: Color = Color(0.44, 0.43, 0.40)
const GRASS_COLOR: Color = Color(0.20, 0.33, 0.19)
const YARD_COLOR: Color = Color(0.26, 0.38, 0.21)
const WALL_COLOR: Color = Color(0.52, 0.50, 0.46)
const TREE_TRUNK_COLOR: Color = Color(0.30, 0.22, 0.14)
const TREE_LEAF_COLOR: Color = Color(0.16, 0.32, 0.14)


static func build(parent: Node3D) -> void:
	_build_ground(parent)
	_build_road(parent)
	_build_sidewalks(parent)
	_build_yard(parent)
	_build_tree(parent)
	_build_wall(parent)


static func _build_ground(parent: Node3D) -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "Ground"
	var ground_mesh: PlaneMesh = PlaneMesh.new()
	ground_mesh.size = Vector2(90.0, ROAD_LENGTH)
	ground.mesh = ground_mesh
	ground.material_override = _make_material(GRASS_COLOR, 0.95)
	parent.add_child(ground)


static func _build_road(parent: Node3D) -> void:
	var road: MeshInstance3D = MeshInstance3D.new()
	road.name = "Road"
	var road_mesh: BoxMesh = BoxMesh.new()
	road_mesh.size = Vector3(ROAD_WIDTH, 0.06, ROAD_LENGTH)
	road.mesh = road_mesh
	road.position = Vector3(ROAD_CENTER_X, 0.03, 0.0)
	road.material_override = _make_material(ASPHALT_COLOR, 0.9)
	parent.add_child(road)

	var lane_center: MeshInstance3D = MeshInstance3D.new()
	lane_center.name = "LaneCenterLine"
	var lane_mesh: BoxMesh = BoxMesh.new()
	lane_mesh.size = Vector3(0.14, 0.02, ROAD_LENGTH)
	lane_center.mesh = lane_mesh
	lane_center.position = Vector3(ROAD_CENTER_X, 0.075, 0.0)
	lane_center.material_override = _make_material(Color(0.72, 0.70, 0.55), 0.8)
	parent.add_child(lane_center)


static func _build_sidewalks(parent: Node3D) -> void:
	for side: int in [-1, 1]:
		var sidewalk: MeshInstance3D = MeshInstance3D.new()
		sidewalk.name = "SidewalkWest" if side < 0 else "SidewalkEast"
		var sidewalk_mesh: BoxMesh = BoxMesh.new()
		sidewalk_mesh.size = Vector3(3.2, 0.16, ROAD_LENGTH)
		sidewalk.mesh = sidewalk_mesh
		sidewalk.position = Vector3(side * (ROAD_WIDTH * 0.5 + 1.6), 0.08, 0.0)
		sidewalk.material_override = _make_material(SIDEWALK_COLOR, 0.9)
		parent.add_child(sidewalk)


static func _build_yard(parent: Node3D) -> void:
	var yard: MeshInstance3D = MeshInstance3D.new()
	yard.name = "FrontYard"
	var yard_mesh: BoxMesh = BoxMesh.new()
	yard_mesh.size = Vector3(YARD_DEPTH, 0.05, 30.0)
	yard.mesh = yard_mesh
	yard.position = Vector3(YARD_WEST_EDGE_X - YARD_DEPTH * 0.5, 0.025, -16.0)
	yard.material_override = _make_material(YARD_COLOR, 0.95)
	parent.add_child(yard)

	var driveway: MeshInstance3D = MeshInstance3D.new()
	driveway.name = "Driveway"
	var driveway_mesh: BoxMesh = BoxMesh.new()
	driveway_mesh.size = DRIVEWAY_SIZE
	driveway.mesh = driveway_mesh
	driveway.position = DRIVEWAY_POSITION
	driveway.material_override = _make_material(Color(0.38, 0.37, 0.35), 0.92)
	parent.add_child(driveway)


static func _build_tree(parent: Node3D) -> void:
	# The tree that the subject vehicle struck. The Miami Herald identifies it as a
	# 20-year-old bottlebrush; the species is not represented in the graybox.
	var tree: Node3D = Node3D.new()
	tree.name = "BottlebrushTree"
	tree.position = TREE_POSITION
	parent.add_child(tree)

	var trunk: MeshInstance3D = MeshInstance3D.new()
	trunk.name = "Trunk"
	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.top_radius = TREE_TRUNK_RADIUS * 0.73
	trunk_mesh.bottom_radius = TREE_TRUNK_RADIUS
	trunk_mesh.height = 3.2
	trunk_mesh.radial_segments = 10
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.6
	trunk.material_override = _make_material(TREE_TRUNK_COLOR, 0.95)
	tree.add_child(trunk)

	var canopy: MeshInstance3D = MeshInstance3D.new()
	canopy.name = "Canopy"
	var canopy_mesh: SphereMesh = SphereMesh.new()
	canopy_mesh.radius = 2.1
	canopy_mesh.height = 3.6
	canopy_mesh.radial_segments = 12
	canopy_mesh.rings = 6
	canopy.mesh = canopy_mesh
	canopy.position.y = 4.2
	canopy.material_override = _make_material(TREE_LEAF_COLOR, 0.98)
	tree.add_child(canopy)


static func _build_wall(parent: Node3D) -> void:
	# The retaining wall on the west side of 82nd Avenue against which the
	# Hanlon/Mireles FBI vehicle came to rest. The Miami Herald identifies it as
	# the wall of a Florida Power & Light substation.
	var wall: MeshInstance3D = MeshInstance3D.new()
	wall.name = "SubstationWall"
	var wall_mesh: BoxMesh = BoxMesh.new()
	wall_mesh.size = WALL_SIZE
	wall.mesh = wall_mesh
	wall.position = WALL_POSITION
	wall.material_override = _make_material(WALL_COLOR, 0.92)
	parent.add_child(wall)


static func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
