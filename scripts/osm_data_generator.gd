# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


@tool
extends Node3D

@export var loader: MapDataLoader
@export var boundariesGenerator: BoundariesGenerator
@export var elevationGenerator: ElevationMeshGenerator
@export var roadMaterial: Material

var isDirty: bool
var _roadKinds: Array[String]
var snapsLeft: int = 0
static var snapToGroundRayCast3DScene: PackedScene = preload("res://prefabs/snap_to_ground_raycast_3d.tscn")
const _MAX_LENGTH_BETWEEN_TWO_ROADS_POINTS: float = 10

func _ready() -> void:
	assert(loader != null)
	assert(boundariesGenerator != null)
	assert(roadMaterial != null)
	assert(elevationGenerator != null)
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
	
	isDirty = true

var _data

func _load_data() -> void:
	# see https://docs.godotengine.org/en/stable/classes/class_json.html#class-json-method-parse
	# see https://docs.godotengine.org/en/stable/classes/class_fileaccess.html

	var file = FileAccess.open(loader.osmDataPath, FileAccess.READ)
	_data = JSON.parse_string(file.get_as_text())
	assert(_data != null)
	file.close()





func reload_action() -> void:
	if !boundariesGenerator.is_loaded:
		print("Cannot continue, boundaries not loaded.")
	elif !elevationGenerator.is_loaded:
		print("Cannot continue, elevation not loaded.")
	else:
		isDirty = true

var _lastLog: float = 0
func _process(delta: float):
	# need to wait for boundaries or no road will be kept!
	if isDirty && boundariesGenerator.is_loaded && elevationGenerator.is_loaded:
		isDirty = false
		snapsLeft = 0
		_regenerate_data()
	elif snapsLeft > 0 && !Engine.is_editor_hint():
		_lastLog += delta
		if  _lastLog > 10:
			print("snaps left for roads: ", snapsLeft)
			_lastLog = 0




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

func _setup_snapping(target: RoadPoint, roadContainer: RoadContainer):
	var snapRayCast: SnapToGroundRayCast3D = snapToGroundRayCast3DScene.instantiate()
	snapRayCast.offset = 0.4
	target.add_child(snapRayCast)
	snapRayCast.target = target
	snapsLeft += 1
	snapRayCast.snapped_target.connect(func():
		roadContainer.rebuild_segments()
		snapsLeft -= 1
	)

## inserts at the end of the array interpolated values between from and to
## so that the length between each of them is below max length between points (constant)
func _append_interpolated_points(from: Vector3, to: Vector3, array: Array[Vector3]):
	var maxLen: float = _MAX_LENGTH_BETWEEN_TWO_ROADS_POINTS
	var len: float = from.distance_to(to)
	var pointsTotal: int = ceil(len / maxLen) 
	var pointsToAdd: int = pointsTotal - 2 # exclude start and end
	var step: float = len / pointsTotal
	var stepRatio: float = step / len
	# add points at equal distance
	for i in range (0, pointsToAdd):
		array.append(lerp(from, to, (i+1)*stepRatio))

func _build_road(feature: Dictionary, roadManager: RoadManager, verbose: bool = false) -> bool:
	if (!feature.has("geometry")): return false
	var geometry: Dictionary = feature.get("geometry")
	if (!geometry.has("coordinates")): return false
	var coordinates: Array = geometry.get("coordinates")
	if (coordinates.size() < 2): return false
	
	var prevMeters: Vector3
	var prevExists: bool = false
	var metersCoords: Array[Vector3] = []
	for c in coordinates:
		var cMeters = loader.lat_alt_lon_to_world_global_pos(Vector3(c[0], 1000, c[1]))
		if boundariesGenerator.is_point_within_race_area(Vector2(cMeters.x, cMeters.z)):
			#var elevation = elevationGenerator.get_elevation(Vector2(cMeters.x, cMeters.z))
			#cMeters.y += elevation
			if (prevExists):
				var distance: float = prevMeters.distance_to(cMeters)
				if (distance > _MAX_LENGTH_BETWEEN_TWO_ROADS_POINTS):
					_append_interpolated_points(prevMeters, cMeters, metersCoords)
			metersCoords.append(cMeters)
			prevMeters = cMeters
			prevExists = true
	
	if (metersCoords.size() < 2):
		return false
	
	# see: https://github.com/TheDuckCow/godot-road-generator/blob/main/demo/procedural_generator/procedural_generator.gd
	# see: https://github.com/TheDuckCow/godot-road-generator/wiki/Class:-RoadPoint
	var roadContainer = RoadContainer.new()
	roadManager.add_child(roadContainer)
	
	var initPoint = RoadPoint.new()
	initPoint.lane_width = 3
	initPoint.gutter_profile = Vector2(3,-0.5)
	var trafficDir: Array[RoadPoint.LaneDir] = [RoadPoint.LaneDir.REVERSE, RoadPoint.LaneDir.FORWARD]
	initPoint.traffic_dir = trafficDir
	initPoint.position = metersCoords[0]
	_setup_snapping(initPoint, roadContainer)
	
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
		_setup_snapping(nextRP, roadContainer)
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
		
	roadContainer.rebuild_segments()
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
	roadManager.auto_refresh = false
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
	
	print("Done, snapping excluded.")
