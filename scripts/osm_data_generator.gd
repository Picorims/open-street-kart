# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


@tool
extends Node3D

const BuildingHolder = preload("res://prefabs/building_holder.gd")
const ROOT_NODE_NAME: String = "OSMData"

@export var loader: MapDataLoader
@export var boundariesGenerator: BoundariesGenerator
@export var elevationGenerator: ElevationMeshGenerator
@export var roadMaterial: Material
@export var buildingMaterial: Material

var _roadKinds: Array[String]
var _buildingKinds: Array[String]
var _rootNode: Node3D
var _deferredRaycasts: Array[SnapToGroundRayCast3D]
var snapsLeftRoad: int = 0
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
		"motorway_link",
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
	
	# https://wiki.openstreetmap.org/wiki/Key:building
	_buildingKinds = [
		"yes",
		"apartments",
		"barracks",
		"bungalow",
		"cabin",
		"detached",
		"annexe",
		"dormitory",
		"farm",
		"ger",
		"hotel",
		"house",
		"houseboat",
		"residential",
		"semidetached_house",
		"static_caravan",
		"stilt_house",
		"terrace",
		"tree_house",
		"trullo",
		
		"commercial",
		"industrial",
		"kiosk",
		"office",
		"retail",
		"supermarket",
		"warehouse",
		
		"religious",
		"cathedral",
		"chapel",
		"church",
		"kingdom_hall",
		"monastery",
		"mosque",
		"presbytery",
		"shrine",
		"synagogue",
		"temple",
		
		"bakehouse",
		"bridge",
		"civic",
		"college",
		"fire_station",
		"government",
		"gatehouse",
		"hospital",
		"kindergarten",
		"museum",
		"public",
		"school",
		"toilets",
		"train_station",
		"transportation",
		"university",
		
		"barn",
		"conservatory",
		"cowshed",
		"farm_auxiliary",
		"greenhouse",
		"slurry_tank",
		"stable",
		"sty",
		"livestock",
		
		"grandstand",
		"pavilion",
		"riding_hall",
		"sports_hall",
		"sports_centre",
		"stadium",
		
		"allotment_house",
		"boathouse",
		"hangar",
		"hut",
		"shed",
		
		"carport",
		"garage",
		"garages",
		"parking",
		
		"digester",
		"service",
		"tech_cab",
		"transformer_tower",
		"water_tower",
		"storage_tank",
		"silo",
		
		"beach_hut",
		"bunker",
		"castle",
		"construction",
		"container",
		"guardhouse",
		#"military",
		"outbuilding",
		"pagoda",
		"quonset_hut",
		"roof",
		"ruins",
		"ship",
		"tent",
		"tower",
		"triumphal_arch",
		"windmill",
	]

var _data

func _load_data() -> void:
	# see https://docs.godotengine.org/en/stable/classes/class_json.html#class-json-method-parse
	# see https://docs.godotengine.org/en/stable/classes/class_fileaccess.html

	var file = FileAccess.open(loader.osmDataPath, FileAccess.READ)
	_data = JSON.parse_string(file.get_as_text())
	assert(_data != null)
	file.close()





func reload_action(dataHolder: Node3D) -> void:
	if !boundariesGenerator.is_loaded:
		print("Cannot continue, boundaries not loaded.")
	elif !elevationGenerator.is_loaded:
		print("Cannot continue, elevation not loaded.")
	else:
		snapsLeftRoad = 0
		snapsLeft = 0
		
		_regenerate_data(dataHolder)

var _lastLog: float = 0
func _physics_process(delta: float) -> void:
	# need to wait for boundaries or no road will be kept!
	if (snapsLeftRoad > 0 || snapsLeft > 0):# && !Engine.is_editor_hint():
		_lastLog += delta
		if  _lastLog > 10:
			print("snaps left for roads: ", snapsLeftRoad)
			print("snaps left for other things: ", snapsLeft)
			_lastLog = 0
		if (_deferredRaycasts.size() > 0):
			var raycast: SnapToGroundRayCast3D = _deferredRaycasts.back()
			if (raycast != null):
				raycast.force_raycast_update()
				_deferredRaycasts.pop_back()




func _is_road(properties: Dictionary) -> bool:
	if (!properties.has("highway")): return false
	
	var id: String = properties.get("@id")
	if (!id.begins_with("way")): return false
	
	var kind: String = properties.get("highway")
	if _roadKinds.has(kind): return true
	return false
	
func _is_building(properties: Dictionary) -> bool:
	if (!properties.has("building")): return false
	
	var id: String = properties.get("@id")
	if (!id.begins_with("way")): return false
	
	var kind: String = properties.get("building")
	if _buildingKinds.has(kind): return true
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

## Attach a temporary raycast 3D that will detect towards the ground the first colliding object
## and move at the collision point the target. It then deletes itself.
## The collision layers must match.
##
## This variant is designed to account for road processing requirements
func _setup_snapping_road(target: RoadPoint, roadContainer: RoadContainer):
	var snapRayCast: SnapToGroundRayCast3D = snapToGroundRayCast3DScene.instantiate()
	snapRayCast.offset = -0.4
	target.add_child(snapRayCast)
	loader.persist_in_current_scene(snapRayCast)
	snapRayCast.target = target
	snapsLeftRoad += 1
	snapRayCast.snapped_target.connect(func(): # not kept on scene save / reload
		#print("snapped!")
		snapsLeftRoad -= 1
		#roadContainer.rebuild_segments()
	)
	#snapRayCast.force_raycast_update() # crashes Godot; road plugin interfering?
	_deferredRaycasts.append(snapRayCast)
	
## Attach a temporary raycast 3D that will detect towards the ground the first colliding object
## and move at the collision point the target. It then deletes itself.
## The collision layers must match.
func _setup_snapping(target: Node3D, alignToNormal: bool = false, offset: float = 0.4):
	var snapRayCast: SnapToGroundRayCast3D = snapToGroundRayCast3DScene.instantiate()
	snapRayCast.offset = offset
	snapRayCast.alignToNormal = alignToNormal
	target.add_child(snapRayCast)
	loader.persist_in_current_scene(snapRayCast)
	snapRayCast.target = target
	snapRayCast.rotation -= target.rotation # ignore rotation
	snapsLeft += 1
	snapRayCast.snapped_target.connect(func(): # not kept on scene save / reload
		snapsLeft -= 1
	)
	snapRayCast.force_raycast_update()

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

func _build_road(feature: Dictionary, roadManager: RoadManager) -> bool:
	if (!feature.has("geometry")): return false
	var geometry: Dictionary = feature.get("geometry")
	if (!geometry.has("coordinates")): return false
	var coordinates: Array = geometry.get("coordinates")
	if (coordinates.size() < 2): return false
	
	var prevMeters: Vector3
	var prevExists: bool = false
	var metersCoords: Array[Vector3] = []
	for c in coordinates:
		# high altitude to be able to snap no matter how sloppy the land is.
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
	loader.persist_in_current_scene(roadContainer)
	
	var initPoint = RoadPoint.new()
	initPoint.lane_width = 3
	initPoint.gutter_profile = Vector2(3,-0.5)
	var trafficDir: Array[RoadPoint.LaneDir] = [RoadPoint.LaneDir.REVERSE, RoadPoint.LaneDir.FORWARD]
	initPoint.traffic_dir = trafficDir
	initPoint.position = metersCoords[0]
	
	# we need to do a 180 turn, to face opposite direction
	# we do not use rotated because it does it around the origin, not itself
	var toMirrored = metersCoords[0] + 2 * (metersCoords[0] - metersCoords[1])
	#initPoint.transform = initPoint.transform.looking_at(metersCoords[1])
	initPoint.transform = _rotated_point(initPoint.transform, toMirrored, metersCoords[0], metersCoords[1])
	
	roadContainer.add_child(initPoint)
	loader.persist_in_current_scene(initPoint)
	_setup_snapping_road(initPoint, roadContainer)
	
	var previousRP = initPoint
	for i in range(1, metersCoords.size()):
		var nextRP = RoadPoint.new()
		var prev = metersCoords[i-1]
		var curr = metersCoords[i]
		roadContainer.add_child(nextRP)
		loader.persist_in_current_scene(nextRP)
		nextRP.copy_settings_from(initPoint) # issue here to copy transform
		nextRP.position = curr
		_setup_snapping_road(nextRP, roadContainer)
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
		previousRP.container = roadContainer
		nextRP.container = roadContainer
		nextRP.connect_roadpoint(thisDir, previousRP, targetDir)
		previousRP = nextRP
		
	return true

func _xz(v: Vector3) -> Vector2:
	return Vector2(v[0], v[2])
	
func _array_xz(a: Array[Vector3]) -> Array[Vector2]:
	var arr: Array[Vector2] = []
	for v in a:
		arr.append(_xz(v))
	return arr

func _build_building(feature: Dictionary, buildingsContainer: Node3D, verbose: bool = false) -> bool:
	const INIT_HEIGHT: float = 1000 # initial height to be able to snap
	if (verbose): print("_build_building: inspecting building data...")
	
	if (!feature.has("geometry")):
		if (verbose): print("building has no geometry, cancel.")
		return false
	var geometry: Dictionary = feature.get("geometry")
	if (!geometry.has("coordinates")):
		if (verbose): print("building has no coordinates, cancel.")
		return false
	var coordinates: Array = geometry.get("coordinates")
	# TODO: handle multi polygon
	if (coordinates.size() == 0):
		if (verbose): print("No building coordinates data, cancel.")
		return false
	if (coordinates.size() > 1):
		if (verbose): print("multi polygon not supported, only loading the first one.")
	coordinates = coordinates[0]
	if (coordinates.size() < 3):
		if (verbose): print("building has not enough nodes (", coordinates.size(), "), cancel.")
		return false
	
	if (verbose): print("building accepted.")
	
	var prevMeters: Vector3
	var prevExists: bool = false
	var metersCoords: Array[Vector3] = []
	for c in coordinates:
		# high altitude to be able to snap no matter how sloppy the land is.
		var cMeters = loader.lat_alt_lon_to_world_global_pos(Vector3(c[0], INIT_HEIGHT, c[1]))
		if boundariesGenerator.is_point_within_race_area(Vector2(cMeters.x, cMeters.z)):
			metersCoords.append(cMeters)
			prevMeters = cMeters
			prevExists = true
	
	if (metersCoords.size() < 3):
		if (verbose): print("building has too few points (",metersCoords.size(),").")
		return false

	var inGroundHeight: float = 5
	var aboveGroundHeight: float = 10
	const MAX_VALUE: float = 1000000
	var origin: Vector3 = Vector3(MAX_VALUE, 0, MAX_VALUE)
	# find smallest x and z to define the origin (the corner of the building bounding box)
	for c in metersCoords:
		origin.x = min(origin.x, c.x)
		origin.z = min(origin.z, c.z)

	# translate all points to origin
	for i in range(metersCoords.size()):
		metersCoords[i] -= origin
		metersCoords[i].y = 0 # disable offset

	# build mesh
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# we create an extruded polygon, with only the wall and ceiling

	# walls
	for i in range(metersCoords.size()):
		var nextIdx = (i + 1) % metersCoords.size()
		var bottomL = metersCoords[i]
		var bottomR = metersCoords[nextIdx]
		var topL = bottomL + Vector3(0, inGroundHeight + aboveGroundHeight, 0)
		var topR = bottomR + Vector3(0, inGroundHeight + aboveGroundHeight, 0)

		# first triangle
		surfaceTool.add_vertex(topL)
		surfaceTool.add_vertex(bottomR)
		surfaceTool.add_vertex(bottomL)

		# second triangle
		surfaceTool.add_vertex(topR)
		surfaceTool.add_vertex(bottomR)
		surfaceTool.add_vertex(topL)
	
	surfaceTool.generate_normals()
	var mesh: Mesh = surfaceTool.commit()
	if (mesh == null):
		if (verbose): print("Failed to create mesh for building, cancel.")
		return false
	
	var meshNode: MeshInstance3D = MeshInstance3D.new()
	meshNode.mesh = mesh
	var surfacesCount = meshNode.mesh.get_surface_count()
	for i in surfacesCount:
		meshNode.set_surface_override_material(i, buildingMaterial)

	var meshCollisionNode: CollisionShape3D = CollisionShape3D.new()
	meshCollisionNode.shape = mesh.create_trimesh_shape()

	var staticBody: StaticBody3D = StaticBody3D.new()
	buildingsContainer.add_child(staticBody)
	loader.persist_in_current_scene(staticBody)
	staticBody.add_child(meshNode)
	loader.persist_in_current_scene(meshNode)
	staticBody.add_child(meshCollisionNode)
	loader.persist_in_current_scene(meshCollisionNode)
	staticBody.position = origin + Vector3(0, INIT_HEIGHT, 0)

	_setup_snapping(staticBody, false, inGroundHeight)

	return true

func _regenerate_data(dataHolder: Node3D) -> void:
	print("Loading OSM data for road generation...")
	_load_data()

	_rootNode = Node3D.new()
	_rootNode.name = ROOT_NODE_NAME
	
	if (dataHolder.has_node(ROOT_NODE_NAME)):
		dataHolder.get_node(ROOT_NODE_NAME).free()
	
	dataHolder.add_child(_rootNode)
	loader.persist_in_current_scene(_rootNode)
		
	print("Setup road generator...")
	var roadManager = RoadManager.new()
	roadManager.auto_refresh = false
	roadManager.material_resource = roadMaterial
	roadManager.density = 8
	_rootNode.add_child(roadManager)
	loader.persist_in_current_scene(roadManager)
	
	var buildingsContainer = Node3D.new()
	_rootNode.add_child(buildingsContainer)
	buildingsContainer.name = "Buildings"
	loader.persist_in_current_scene(buildingsContainer)
	
	print("Creating structures")
	assert(_data.features != null)
	var features: Array = _data.features
	print("features: ", features.size())
	
	var roadsCount: int = 0
	var roadsCountSuccess: int = 0
	
	var buildsCount: int = 0
	var buildsCountSuccess: int = 0
	for f: Dictionary in features:
		if (f.has("properties")): #&& roadsCount < 1000):
			var properties: Dictionary = f.get("properties")
			# road? https://wiki.openstreetmap.org/wiki/Key:highway
			if _is_road(properties):
				var success: bool = _build_road(f, roadManager)
				roadsCount += 1
				if success:
					roadsCountSuccess += 1
			elif _is_building(properties):
				var success: bool = _build_building(f, buildingsContainer)
				buildsCount += 1
				if success:
					buildsCountSuccess += 1
	
	print("Refreshing road segments...")
	
	print("Created ", roadsCountSuccess, " roads. Tried: ", roadsCount)
	print("Created ", buildsCountSuccess, " buildings. Tried: ", buildsCount)
	
	print("Nodes: ", _rootNode.get_child_count())

	print("Done, snapping excluded.")
