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
	#"pedestrian",
	#"track",
	"bus_guideway",
	#"escape",
	"raceway",
	"road",
	#"busway",
	#"footway",
	#"bridleway",
	#"steps",
	#"corridor",
	#"path",
	#"cycleway",
	#"construction",
	#"emergency_bay",
	#"platform",
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

func _rotated_point(transform: Transform3D, from: Vector3, curr: Vector3, to: Vector3) -> Transform3D:
	# given this:
	# A--M--C
	# |\ | /
	# | \ /
	# L--B
	# where A is the previous point,
	# C the next one, and B the current one;
	# and where M is middle of AC and L where we shall look at.
	# For a smooth transition, we want to look in the direction of the
	# [AC] axis, parallel to [BL] axis. We thus need to look at L.
	# L = B - (A-M)
	var segmentMiddle = (from+to)/2
	# var shouldLookAt = segmentMiddle + (to - segmentMiddle) + (curr - segmentMiddle)
	var shouldLookAt = curr + (from - segmentMiddle) 
	return transform.looking_at(shouldLookAt)

func _build_road(feature: Dictionary, roadManager: RoadManager, verbose: bool = false) -> bool:
	if (!feature.has("geometry")): return false
	var geometry: Dictionary = feature.get("geometry")
	if (!geometry.has("coordinates")): return false
	var coordinates: Array = geometry.get("coordinates")
	if (coordinates.size() < 2): return false
	
	var metersCoords: Array[Vector3] = []
	for c in coordinates:
		metersCoords.append(loader.lat_alt_lon_to_world_global_pos(Vector3(c[0], 200, c[1])))
	
	# see: https://github.com/TheDuckCow/godot-road-generator/blob/main/demo/procedural_generator/procedural_generator.gd
	# see: https://github.com/TheDuckCow/godot-road-generator/wiki/Class:-RoadPoint
	var roadContainer = RoadContainer.new()
	roadManager.add_child(roadContainer)
	
	var initPoint = RoadPoint.new()
	initPoint.lane_width = 3.5
	var trafficDir: Array[RoadPoint.LaneDir] = [RoadPoint.LaneDir.REVERSE, RoadPoint.LaneDir.FORWARD]
	initPoint.traffic_dir = trafficDir
	initPoint.position = metersCoords[0]
	
	# we need to do a 180 turn, to face opposite direction
	# we do not use rotated because it does it around the origin, not itself
	var toMirrored = metersCoords[0] + 2 * (metersCoords[0] - metersCoords[1])
	#initPoint.transform = initPoint.transform.looking_at(metersCoords[1])
	initPoint.transform = _rotated_point(initPoint.transform, toMirrored, metersCoords[0], metersCoords[1])
	
	roadContainer.add_child(initPoint)
	
	var previousRP = initPoint
	for i in range(1, metersCoords.size()):
		var nextRP = RoadPoint.new()
		var prev = metersCoords[i-1]
		var curr = metersCoords[i]
		roadContainer.add_child(nextRP)
		nextRP.copy_settings_from(initPoint)
		nextRP.position = curr
		if (i == metersCoords.size() - 1):
			# we need to do a 180 turn, to face opposite direction
			# we do not use rotated because it does it around the origin, not itself
			var prevMirrored = prev + 2 * (curr - prev)
			#nextRP.transform = nextRP.transform.looking_at(lookingOpposite)
			nextRP.transform = _rotated_point(nextRP.transform, prev, curr, prevMirrored)
			nextRP.prior_mag = metersCoords[i-1].distance_to(metersCoords[i]) / 2
		else:
			nextRP.transform = _rotated_point(nextRP.transform, metersCoords[i-1], metersCoords[i], metersCoords[i+1])
			nextRP.prior_mag = metersCoords[i-1].distance_to(metersCoords[i]) / 2
			nextRP.next_mag = metersCoords[i].distance_to(metersCoords[i+1]) / 2
		
		var thisDir = RoadPoint.PointInit.PRIOR
		var targetDir = RoadPoint.PointInit.NEXT
		nextRP.connect_roadpoint(thisDir, previousRP, targetDir)
		previousRP = nextRP
		
	return true
	
	#var path3D: Path3D = Path3D.new()
		#
	#if verbose:
		#print(coordinates)
		#
	#var root: Vector3 = Vector3(coordinates[0][0], 170, coordinates[0][1])
	#root = loader.lat_alt_lon_to_world_global_pos(root, verbose)
	#
	#if verbose:
		#print("root is: ", root)
		#
	#var curve3D: Curve3D = Curve3D.new()
	## x is lat, z is lon
	#for p: Array in coordinates:
		#if p.size() == 2:
			#var absPos: Vector3 = Vector3(p[0], 170, p[1])
			#if verbose:
				#print("next pos is made of latitude, elevation, longitude: ", absPos)
			#absPos = loader.lat_alt_lon_to_world_global_pos(absPos, verbose)
			## curve3D.add_point(absPos - root)
			#curve3D.add_point(absPos)
			#if verbose:
				#print("added pos (abs, rel): ", absPos, " ", absPos - root)
	#path3D.curve = curve3D
	#
	#var roadCSG: CSGPolygon3D = CSGPolygon3D.new()
	##roadCSG.material = roadMaterial
	#self.add_child(roadCSG)
	#roadCSG.add_child(path3D)
	#path3D.global_position = root
	#roadCSG.mode = CSGPolygon3D.MODE_PATH
	#roadCSG.depth = 1
	#roadCSG.polygon = PackedVector2Array([0,0,0,1,1,1,1,0])
	#roadCSG.path_local = true
	#roadCSG.path_node = ^"Path3D" # parent
	#
	#var meshNode: MeshInstance3D = MeshInstance3D.new()
	#self.add_child(meshNode)
	#meshNode.mesh = roadCSG.bake_static_mesh()
	#var surfacesCount = meshNode.mesh.get_surface_count()
	#for i in surfacesCount:
		#meshNode.set_surface_override_material(i, roadMaterial)
	## DebugDraw3D.draw_line_path(curve3D.get_baked_points(), Color(1,0,0,1), 500)
	## DebugDraw3D.draw_position(path3D.transform, Color(0,1,0,1), 500)
	## DebugDraw3D.draw_point_path(curve3D.get_baked_points(), DebugDraw3D.POINT_TYPE_SQUARE, 0.25, Color(1,0,0,1), Color(0,0,1,1), 500)
	#return true


func _regenerate_data() -> void:
	print("OSM data generation started. Removing existing data...")
	for n in self.get_children():
		self.remove_child(n)
		n.queue_free()
	print("Loading OSM data for road generation...")
	_load_data()
	
	print("Setup road generator...")
	var roadManager = RoadManager.new()
	roadManager.auto_refresh = true
	roadManager.material_resource = roadMaterial
	roadManager.density = 8
	self.add_child(roadManager)
	
	print("Creating structures")
	assert(_data.features != null)
	var features: Array = _data.features
	print("features: ", features.size())
	
	var roadsCount: int = 0
	var roadsCountSuccess: int = 0
	for f: Dictionary in features:
		if (f.has("properties")): #&& roadsCount < 1000):
			var properties: Dictionary = f.get("properties")
			# road? https://wiki.openstreetmap.org/wiki/Key:highway
			if _is_road(properties):
				var success: bool = _build_road(f, roadManager, roadsCount == 0)
				roadsCount += 1
				if success:
					roadsCountSuccess += 1
	
	print("Created ", roadsCountSuccess, " roads. Tried: ", roadsCount)
	print("Nodes: ", self.get_child_count())
	
	print("Done.")
