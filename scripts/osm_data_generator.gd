@tool
extends Node3D

@export var loader: MapDataLoader
@export var roadMaterial: Material

var is_dirty: bool
var _roadKinds: Array[String]


func _ready() -> void:
	assert(loader != null)
	assert(roadMaterial != null)
	_roadKinds = [
	"motorway",
	"trunk",
	"primary",
	"secondary",
	"tertiary",
	"unclassified",
	"residential",
	"motrway_link",
	"trunk_link",
	"primary_link",
	"secondary_link",
	"tertiary_link",
	"living_street",
	"service",
	"pedestrian",
	"track",
	"bus_guideway",
	"escape",
	"raceway",
	"road",
	"busway",
	"footway",
	"bridleway",
	"steps",
	"corridor",
	"path",
	"cycleway",
	"construction",
	"emergency_bay",
	"platform",
]
	#is_dirty = true
	is_dirty = false

var _data

func _load_data() -> void:
	# see https://docs.godotengine.org/en/stable/classes/class_json.html#class-json-method-parse
	# see https://docs.godotengine.org/en/stable/classes/class_fileaccess.html

	var file = FileAccess.open(loader.osmDataPath, FileAccess.READ)
	_data = JSON.parse_string(file.get_as_text())
	assert(_data != null)
	file.close()





func reload_action() -> void:
	is_dirty = true

func _process(delta):
	if is_dirty:
		is_dirty = false
		_regenerate_data()
		




func _is_road(properties: Dictionary) -> bool:
	if (!properties.has("highway")): return false
	
	var id: String = properties.get("@id")
	if (!id.begins_with("way")): return false
	
	var kind: String = properties.get("highway")
	if _roadKinds.has(kind): return true
	return false

func _build_road(feature: Dictionary, verbose: bool = false) -> bool:
	if (!feature.has("geometry")): return false
	var geometry: Dictionary = feature.get("geometry")
	if (!geometry.has("coordinates")): return false
	var coordinates: Array = geometry.get("coordinates")
	if (coordinates.size() < 2): return false
	
	var path3D: Path3D = Path3D.new()
		
	if verbose:
		print(coordinates)
		
	var root: Vector3 = Vector3(coordinates[0][0], 170, coordinates[0][1])
	root = loader.lat_alt_lon_to_world_global_pos(root, verbose)
	
	if verbose:
		print("root is: ", root)
		
	var curve3D: Curve3D = Curve3D.new()
	# x is lat, z is lon
	for p: Array in coordinates:
		if p.size() == 2:
			var absPos: Vector3 = Vector3(p[0], 170, p[1])
			if verbose:
				print("next pos is made of latitude, elevation, longitude: ", absPos)
			absPos = loader.lat_alt_lon_to_world_global_pos(absPos, verbose)
			# curve3D.add_point(absPos - root)
			curve3D.add_point(absPos)
			if verbose:
				print("added pos (abs, rel): ", absPos, " ", absPos - root)
	path3D.curve = curve3D
	
	var roadCSG: CSGPolygon3D = CSGPolygon3D.new()
	#roadCSG.material = roadMaterial
	self.add_child(roadCSG)
	roadCSG.add_child(path3D)
	path3D.global_position = root
	roadCSG.mode = CSGPolygon3D.MODE_PATH
	roadCSG.depth = 1
	roadCSG.polygon = PackedVector2Array([0,0,0,1,1,1,1,0])
	roadCSG.path_local = true
	roadCSG.path_node = ^"Path3D" # parent
	
	var meshNode: MeshInstance3D = MeshInstance3D.new()
	self.add_child(meshNode)
	meshNode.mesh = roadCSG.bake_static_mesh()
	var surfacesCount = meshNode.mesh.get_surface_count()
	for i in surfacesCount:
		meshNode.set_surface_override_material(i, roadMaterial)
	# DebugDraw3D.draw_line_path(curve3D.get_baked_points(), Color(1,0,0,1), 500)
	# DebugDraw3D.draw_position(path3D.transform, Color(0,1,0,1), 500)
	# DebugDraw3D.draw_point_path(curve3D.get_baked_points(), DebugDraw3D.POINT_TYPE_SQUARE, 0.25, Color(1,0,0,1), Color(0,0,1,1), 500)
	return true


func _regenerate_data() -> void:
	print("OSM data generation started. Removing existing data...")
	for n in self.get_children():
		self.remove_child(n)
		n.queue_free()
	print("Loading OSM data for road generation...")
	_load_data()
	
	print("Creating structures")
	assert(_data.features != null)
	var features: Array = _data.features
	print("features: ", features.size())
	
	var roadsCount: int = 0
	for f: Dictionary in features:
		if (!f.has("properties")): continue
		
		var properties: Dictionary = f.get("properties")
		# road? https://wiki.openstreetmap.org/wiki/Key:highway
		if _is_road(properties):
			var success: bool = _build_road(f, roadsCount == 0)
			if success:
				roadsCount += 1
				if roadsCount > 10000: break
	
	print("Created ", roadsCount, " roads.")
	print("Nodes: ", self.get_child_count())
	
	print("Done.")
