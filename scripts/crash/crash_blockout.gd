class_name CrashBlockout
extends RefCounted

## Builds the static blockout environment for the April 11, 1986 crash opening.
##
## Every position and dimension in this file comes from CrashGeometry, which
## is the single source of truth for the layout. Nothing here re-declares a
## coordinate: if the geometry moves, the blockout follows it, because the
## two cannot disagree.
##
## Coordinate system (Godot default):
##   -X = west   +X = east
##   -Z = north  +Z = south
## 82nd Avenue runs north/south along the Z axis.
##
## Which side of the avenue each thing is on is settled by the FBI incident
## report, and is recorded in CrashGeometry:
##
##   - The FPL substation retaining wall is on the WEST side.
##   - Hanlon and Mireles "exited their vehicle (which had struck the wall)
##     and crossed the street to assist", so the subjects' vehicle must have
##     come to rest on the OTHER side of the avenue from the wall. The
##     subjects' vehicle therefore rests on the EAST side, in the paved
##     parking area of 12201 Southwest 82nd Avenue, together with Manauzzi's
##     unit, the parked civilian cars and the bottlebrush tree.
##
## The geometry here is the parking area and front yard at 12201 SW 82nd
## Avenue. It is a paved area, not a lawn with a driveway cut into it: the
## subject vehicle came to rest "in the parking area of a front yard", and
## MH-1 has it going "over the sidewalk" and striking a tree that stood in
## the yard.

const ASPHALT_COLOR: Color = Color(0.18, 0.18, 0.19)
const SIDEWALK_COLOR: Color = Color(0.44, 0.43, 0.40)
const GRASS_COLOR: Color = Color(0.20, 0.33, 0.19)
const YARD_COLOR: Color = Color(0.26, 0.38, 0.21)
const WALL_COLOR: Color = Color(0.52, 0.50, 0.46)
const TREE_TRUNK_COLOR: Color = Color(0.30, 0.22, 0.14)
const TREE_LEAF_COLOR: Color = Color(0.16, 0.32, 0.14)
const HEDGE_COLOR: Color = Color(0.14, 0.26, 0.12)

## Depth of the front yard behind the parking apron, measured eastwards
## from the east edge of the avenue's sidewalk.
const YARD_DEPTH: float = 16.0

## Length of the front yard along the avenue.
const YARD_LENGTH: float = 30.0


static func build(parent: Node3D) -> void:
	_build_ground(parent)
	_build_road(parent)
	_build_sidewalks(parent)
	_build_apron(parent)
	_build_yard(parent)
	_build_tree(parent)
	_build_wall(parent)
	_build_hedge(parent)


static func _build_ground(parent: Node3D) -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "Ground"
	var ground_mesh: PlaneMesh = PlaneMesh.new()
	ground_mesh.size = Vector2(160.0, CrashGeometry.ROAD_LENGTH)
	ground.mesh = ground_mesh
	ground.material_override = _make_material(GRASS_COLOR, 0.95)
	parent.add_child(ground)


static func _build_road(parent: Node3D) -> void:
	var road: MeshInstance3D = MeshInstance3D.new()
	road.name = "Road"
	var road_mesh: BoxMesh = BoxMesh.new()
	road_mesh.size = Vector3(CrashGeometry.ROAD_WIDTH, 0.06, CrashGeometry.ROAD_LENGTH)
	road.mesh = road_mesh
	road.position = Vector3(CrashGeometry.ROAD_CENTER_X, 0.03, -60.0)
	road.material_override = _make_material(ASPHALT_COLOR, 0.9)
	parent.add_child(road)

	var lane_center: MeshInstance3D = MeshInstance3D.new()
	lane_center.name = "LaneCenterLine"
	var lane_mesh: BoxMesh = BoxMesh.new()
	lane_mesh.size = Vector3(0.14, 0.02, CrashGeometry.ROAD_LENGTH)
	lane_center.mesh = lane_mesh
	lane_center.position = Vector3(CrashGeometry.ROAD_CENTER_X, 0.075, -60.0)
	lane_center.material_override = _make_material(Color(0.72, 0.70, 0.55), 0.8)
	parent.add_child(lane_center)


static func _build_sidewalks(parent: Node3D) -> void:
	for side: int in [-1, 1]:
		var sidewalk: MeshInstance3D = MeshInstance3D.new()
		sidewalk.name = "SidewalkWest" if side < 0 else "SidewalkEast"
		var sidewalk_mesh: BoxMesh = BoxMesh.new()
		sidewalk_mesh.size = Vector3(3.2, 0.16, CrashGeometry.ROAD_LENGTH)
		sidewalk.mesh = sidewalk_mesh
		sidewalk.position = Vector3(
			side * (CrashGeometry.ROAD_WIDTH * 0.5 + 1.6), 0.08, -60.0
		)
		sidewalk.material_override = _make_material(SIDEWALK_COLOR, 0.9)
		parent.add_child(sidewalk)


## The paved parking area in front of 12201 SW 82nd Avenue, on the EAST
## side of the avenue. The subject vehicle ends up on it, wedged against
## the tree and the parked Cutlass.
static func _build_apron(parent: Node3D) -> void:
	var apron: MeshInstance3D = MeshInstance3D.new()
	apron.name = "ParkingApron"
	var apron_mesh: BoxMesh = BoxMesh.new()
	apron_mesh.size = CrashGeometry.APRON_SIZE
	apron.mesh = apron_mesh
	apron.position = CrashGeometry.APRON_CENTRE
	apron.material_override = _make_material(ASPHALT_COLOR, 0.88)
	parent.add_child(apron)

	# The driveway running from the apron out to the avenue.
	var driveway: MeshInstance3D = MeshInstance3D.new()
	driveway.name = "Driveway"
	var driveway_mesh: BoxMesh = BoxMesh.new()
	driveway_mesh.size = CrashGeometry.DRIVEWAY_SIZE
	driveway.mesh = driveway_mesh
	driveway.position = CrashGeometry.DRIVEWAY_POSITION
	driveway.material_override = _make_material(Color(0.38, 0.37, 0.35), 0.92)
	parent.add_child(driveway)


## The front yard, on the EAST side of the avenue, behind the parking apron.
##
## The apron is the paved area nearest the avenue and the yard lies behind
## it, towards the house, so the yard's west edge is the apron's east edge.
static func _build_yard(parent: Node3D) -> void:
	var yard: MeshInstance3D = MeshInstance3D.new()
	yard.name = "FrontYard"
	var yard_mesh: BoxMesh = BoxMesh.new()
	yard_mesh.size = Vector3(YARD_DEPTH, 0.05, YARD_LENGTH)
	yard.mesh = yard_mesh
	yard.position = Vector3(
		CrashGeometry.APRON_CENTRE.x + CrashGeometry.APRON_SIZE.x * 0.5 + YARD_DEPTH * 0.5,
		0.025,
		CrashGeometry.APRON_CENTRE.z
	)
	yard.material_override = _make_material(YARD_COLOR, 0.95)
	parent.add_child(yard)


## The tree that the subject vehicle struck. The Miami Herald identifies it
## as a 20-year-old bottlebrush; the species is not represented in the
## graybox.
static func _build_tree(parent: Node3D) -> void:
	var tree: Node3D = Node3D.new()
	tree.name = "BottlebrushTree"
	tree.position = CrashGeometry.TREE_POSITION
	parent.add_child(tree)

	var trunk: MeshInstance3D = MeshInstance3D.new()
	trunk.name = "Trunk"
	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.top_radius = CrashGeometry.TREE_TRUNK_RADIUS * 0.73
	trunk_mesh.bottom_radius = CrashGeometry.TREE_TRUNK_RADIUS
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


## The retaining wall on the WEST side of 82nd Avenue against which the
## Hanlon/Mireles FBI vehicle came to rest. The Miami Herald identifies it
## as the wall of a Florida Power & Light substation.
static func _build_wall(parent: Node3D) -> void:
	var wall: MeshInstance3D = MeshInstance3D.new()
	wall.name = "SubstationWall"
	var wall_mesh: BoxMesh = BoxMesh.new()
	wall_mesh.size = CrashGeometry.WALL_SIZE
	wall.mesh = wall_mesh
	wall.position = CrashGeometry.WALL_POSITION
	wall.material_override = _make_material(WALL_COLOR, 0.92)
	parent.add_child(wall)


## The hedge along the front of the property, behind the parking apron.
static func _build_hedge(parent: Node3D) -> void:
	var hedge: MeshInstance3D = MeshInstance3D.new()
	hedge.name = "FrontHedge"
	var hedge_mesh: BoxMesh = BoxMesh.new()
	hedge_mesh.size = Vector3(1.2, 1.1, 16.0)
	hedge.mesh = hedge_mesh
	hedge.position = Vector3(
		CrashGeometry.APRON_CENTRE.x + CrashGeometry.APRON_SIZE.x * 0.5 + YARD_DEPTH - 0.6,
		0.55,
		CrashGeometry.APRON_CENTRE.z
	)
	hedge.material_override = _make_material(HEDGE_COLOR, 0.97)
	parent.add_child(hedge)


static func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
