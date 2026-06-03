# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


@tool
class_name OSMDataGenerator extends Node3D

const ROOT_NODE_NAME: String = "OSMData"

@export var loader: MapDataLoader
@export var boundaries_generator: BoundariesGenerator
@export var elevation_generator: ElevationMeshGenerator
@export var road_material: Material
@export var building_material: Material

enum ReloadKind {
	ROADS,
	BUILDINGS,
	AMENITIES
}

var _road_kinds: Array[String]
var _building_kinds: Array[String]
var _amenity_kinds: Array[String]
var _amenity_kind_to_prefix: Dictionary[String, String]
var _highway_kind_to_prefix: Dictionary[String, String]
var _root_node: Node3D
var _deferred_raycasts: Array[SnapToGroundRayCast3D]
## It is important to append in the order of building.
## The previousRP of a point should always be placed somewhere before.
var _road_points_to_build: Array[RoadPointPlaceholder] = []
var _road_points_built := 0
var _can_build_roads: bool = true
var _road_manager: RoadManager = null
var snaps_left_road: int = 0
var snaps_left: int = 0
static var snap_to_ground_ray_cast_3d_scene: PackedScene = preload("res://prefabs/snap_to_ground_raycast_3d.tscn")
const BIN_SCENE: PackedScene = preload("res://prefabs/collidable_decoration/bin.tscn")
const BENCH_SCENE: PackedScene = preload("res://prefabs/collidable_decoration/bench.tscn")
const BUS_STOP_POLE_SCENE: PackedScene = preload("res://prefabs/collidable_decoration/bus_stop_pole.tscn")
const _MAX_LENGTH_BETWEEN_TWO_ROADS_POINTS: float = 10.0
const _ROAD_SIMPLIFICATION_THRESHOLD: float = 3.0
const _MAX_ROADS_PER_PHYSICS_TICK: int = 1
const _ROADS_GEN_SLEEP_TIME_S: float = 0.1 # reduce editor lag by increasing this value
const VERBOSE = false

class RoadPointPlaceholder:
	var lane_width: float = 0
	var gutter_profile: Vector2 = Vector2(0, 0)
	var traffic_dir: Array[RoadPoint.LaneDir] = []
	var is_road_start: bool = false
	var is_road_end: bool = false
	var previous_rp: RoadPointPlaceholder = null
	var prior_mag: float = 0
	var next_mag: float = 0
	var position: Vector3 = Vector3.ZERO
	var transform: Transform3D
	
	func copy_settings_from(other: RoadPointPlaceholder, with_transform: bool):
		self.lane_width = other.lane_width
		self.gutter_profile = other.gutter_profile
		self.traffic_dir = other.traffic_dir
		if with_transform:
			self.transform = other.transform
			
		
func _ready() -> void:
	assert(loader != null)
	assert(boundaries_generator != null)
	assert(road_material != null)
	assert(elevation_generator != null)
	_road_kinds = [
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
	_building_kinds = [
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
	
	_amenity_kinds = [
		"bench",
		"waste_basket",
	]
	
	_amenity_kind_to_prefix = {
		"bench": "Bench",
		"waste_basket": "Bin",
	}
	_highway_kind_to_prefix = {
		"bus_stop": "BusStop",
	}

var _data

func _load_data() -> void:
	# see https://docs.godotengine.org/en/stable/classes/class_json.html#class-json-method-parse
	# see https://docs.godotengine.org/en/stable/classes/class_fileaccess.html
	var file = FileAccess.open(loader.osm_data_path, FileAccess.READ)
	_data = JSON.parse_string(file.get_as_text())
	assert(_data != null)
	file.close()


func reload_action(data_holder: Node3D, kind: ReloadKind) -> void:
	if not boundaries_generator.is_loaded:
		print("Cannot continue, boundaries not loaded.")
	else:
		_regenerate_data(data_holder, kind)
		_can_build_roads = true

var _last_log: float = 0
var _last_road_gen: float = 0
func _physics_process(delta: float) -> void:
	# need to wait for boundaries or no road will be kept!
	#if (snaps_left_road > 0 or snaps_left > 0): # and not Engine.is_editor_hint():
		#_last_log += delta
		#if _last_log > 10:
			#print("snaps left for roads: ", snaps_left_road)
			#print("snaps left for other things: ", snaps_left)
			#_last_log = 0
		#if (_deferred_raycasts.size() > 0):
			#var raycast: SnapToGroundRayCast3D = _deferred_raycasts.back()
			#if (raycast != null):
				#raycast.force_raycast_update()
				#_deferred_raycasts.pop_back()
	_last_road_gen += delta
	_last_log += delta
	if (
		_can_build_roads
		and _road_points_to_build.size() > 0
		and snaps_left_road == 0
		and _last_road_gen > _ROADS_GEN_SLEEP_TIME_S
	):
		_last_road_gen = 0
		if _last_log > 4:
			print("Building roads...")
			var built := _road_points_built
			var total := _road_points_to_build.size()
			print("points left: ", total - built)
			print("progress: %d/%d (%f %%)" % [built, total, float(built) / float(total) * 100.0])
			_last_log = 0

		# see: https://github.com/TheDuckCow/godot-road-generator/blob/main/demo/procedural_generator/procedural_generator.gd
		# see: https://github.com/TheDuckCow/godot-road-generator/wiki/Class:-RoadPoint
	
		# separate function?
		# build
		var roads_in_this_tick := 0
		
		while roads_in_this_tick < _MAX_ROADS_PER_PHYSICS_TICK and _road_points_built < _road_points_to_build.size():
			var i := _road_points_built
			if not _road_points_to_build[i].is_road_start:
				push_error("OSMDataGenerator: roads to build status left in illegal state: first point isn't a road start.")
				_can_build_roads = false
				break
			_build_one_road_in_scene()
			roads_in_this_tick += 1
			
		if _road_points_built >= _road_points_to_build.size():
			#separate function?
			# flush
			_road_points_to_build = []
			_road_points_built = 0
			_can_build_roads = false
			print("Building roads done.")

func _build_one_road_in_scene():
	var road_container: RoadContainer = RoadContainer.new()
	_road_manager.add_child(road_container)
	loader.persist_in_current_scene(road_container)
	var prev_rp: RoadPoint = null
	const MAX_IT := 10_000
	var count := 0
	if VERBOSE:
		print("Road build starts from index: ", _road_points_built)
	var placeholder_p := _road_points_to_build[_road_points_built]
	if placeholder_p.is_road_end:
		push_error("OSMDataLoader._build_one_road_in_scene: The first point at current process position is a road end. A single point doesn't make sense!")
		return
	if not placeholder_p.is_road_start:
		push_error("OSMDataLoader._build_one_road_in_scene: The first point at current process position must be a road start.")
		return
	while count < MAX_IT: # do:
		count += 1
		
		placeholder_p = _road_points_to_build[_road_points_built]
		var rp: RoadPoint = RoadPoint.new()
		road_container.add_child(rp)
		
		rp.lane_width = placeholder_p.lane_width
		rp.gutter_profile = placeholder_p.gutter_profile
		rp.traffic_dir = placeholder_p.traffic_dir
		rp.next_mag = placeholder_p.next_mag
		rp.prior_mag = placeholder_p.prior_mag
		rp.transform = placeholder_p.transform
		rp.position = placeholder_p.position
		rp.container = road_container
		loader.persist_in_current_scene(rp)
		
		if (not placeholder_p.is_road_start):
			var this_dir = RoadPoint.PointInit.PRIOR
			var target_dir = RoadPoint.PointInit.NEXT
			rp.connect_roadpoint(this_dir, prev_rp, target_dir) # warning here
		prev_rp = rp

		_road_points_built += 1
		if _road_points_to_build[_road_points_built - 1].is_road_end: # while (not <condition>)
			break
	if VERBOSE: print("One road built in scene.")

func _is_road(properties: Dictionary) -> bool:
	if (not properties.has("highway")): return false
	
	var id: String = properties.get("@id")
	if (not id.begins_with("way")): return false
	
	var kind: String = properties.get("highway")
	if _road_kinds.has(kind): return true
	return false

func _is_bus_stop(properties: Dictionary) -> bool:
	if (not properties.has("highway")): return false
	
	var id: String = properties.get("@id")
	if (not id.begins_with("node")): return false
	
	return properties.get("highway") == "bus_stop"

func _is_building(properties: Dictionary) -> bool:
	if (not properties.has("building")): return false
	
	var id: String = properties.get("@id")
	if (not id.begins_with("way")): return false
	
	var kind: String = properties.get("building")
	if _building_kinds.has(kind): return true
	return false

func _is_supported_amenity(properties: Dictionary) -> bool:
	return _amenity_kinds.map(func(kind) -> bool:
		return _is_amenity_kind(kind, properties)
	).any(func(v): return v)

func _is_amenity_kind(kind: String, properties: Dictionary) -> bool:
	if (not properties.has("amenity")): return false
	
	var id: String = properties.get("@id")
	if (not id.begins_with("node")): return false

	return properties.get("amenity") == kind


func _is_bin(properties: Dictionary) -> bool:
	return _is_amenity_kind("waste_basket", properties)

func _is_bench(properties: Dictionary) -> bool:
	return _is_amenity_kind("bench", properties)

func _rotated_point(from_transform: Transform3D, from: Vector3, to: Vector3) -> Transform3D:
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
	# We consider B being the origin to fit looking_at().
	var segment_middle = (from + to) / 2
	# var shouldLookAt = segmentMiddle + (to - segmentMiddle) + (curr - segmentMiddle)
	var should_look_at = (from - segment_middle)
	return from_transform.looking_at(should_look_at)

## Attach a temporary raycast 3D that will detect towards the ground the first colliding object
## and move at the collision point the target. It then deletes itself.
## The collision layers must match.
##
## This variant is designed to account for road processing requirements
func _setup_snapping_road(target: Node3D):
	var snap_ray_cast: SnapToGroundRayCast3D = snap_to_ground_ray_cast_3d_scene.instantiate()
	snap_ray_cast.offset = -0.4
	target.add_child(snap_ray_cast)
	loader.persist_in_current_scene(snap_ray_cast)
	snap_ray_cast.target = target
	snaps_left_road += 1
	snap_ray_cast.snapped_target.connect(func(): # not kept on scene save / reload
		snaps_left_road -= 1
		# this is NOT the right place to refresh segments:
		# - there is a function on the road manager to bulk refresh everything.
		# - there would be as many refresh as points in the road: waste of resources!
	)
	snap_ray_cast.force_raycast_update() # crashes Godot with RoadPoint; road add-on perf issue?
	#_deferred_raycasts.append(snapRayCast)
	
## Attach a temporary raycast 3D that will detect towards the ground the first colliding object
## and move at the collision point the target. It then deletes itself.
## The collision layers must match.
func _setup_snapping(target: Node3D, align_to_normal: bool = false, offset: float = 0.4):
	var snap_ray_cast: SnapToGroundRayCast3D = snap_to_ground_ray_cast_3d_scene.instantiate()
	snap_ray_cast.offset = offset
	snap_ray_cast.align_to_normal = align_to_normal
	target.add_child(snap_ray_cast)
	loader.persist_in_current_scene(snap_ray_cast)
	snap_ray_cast.target = target
	snap_ray_cast.rotation -= target.rotation # ignore rotation
	snaps_left += 1
	snap_ray_cast.snapped_target.connect(func(): # not kept on scene save / reload
		snaps_left -= 1
	)
	snap_ray_cast.force_raycast_update()

## inserts at the end of the array interpolated values between from and to
## so that the length between each of them is below max length between points (constant)
func _append_interpolated_points(from: Vector3, to: Vector3, array: Array[Vector3]):
	var maxLen: float = _MAX_LENGTH_BETWEEN_TWO_ROADS_POINTS
	var length: float = from.distance_to(to)
	var pointsTotal: int = ceil(length / maxLen)
	var pointsToAdd: int = pointsTotal - 2 # exclude start and end
	var step: float = length / pointsTotal
	var stepRatio: float = step / length
	# add points at equal distance
	for i in range(0, pointsToAdd):
		array.append(lerp(from, to, (i + 1) * stepRatio))

## Removes points very close to each other that doesn't play an important role
## in defining the road trajectory
func _simplify_road(meters_coords: Array[Vector3]) -> Array[Vector3]:
	var new_array: Array[Vector3] = []
	for i in range(meters_coords.size()):
		if i == 0 or i == meters_coords.size()-1:
			new_array.append(meters_coords[i])
		else:
			var close_to_previous: bool = new_array[-1].distance_to(meters_coords[i]) < _ROAD_SIMPLIFICATION_THRESHOLD
			var close_to_next: bool = meters_coords[i].distance_to(meters_coords[i+1]) < _ROAD_SIMPLIFICATION_THRESHOLD
			
			if close_to_next and close_to_previous:
				continue
			
			new_array.append(meters_coords[i])
	return new_array

func _build_road(feature: Dictionary, roads_container: Node3D) -> bool:
	if (not feature.has("geometry")): return false
	var geometry: Dictionary = feature.get("geometry")
	if (not geometry.has("coordinates")): return false
	var coordinates: Array = geometry.get("coordinates")
	if (coordinates.size() < 2): return false

	var props = null
	if feature.has("properties"):
		props = feature.get("properties")
	
	var prev_meters: Vector3
	var prev_exists: bool = false
	var meters_coords: Array[Vector3] = []
	for c in coordinates:
		# we need to flip the X axis because X and longitude have opposite directions
		var c_meters = Vector3(-c[0] + loader.width_meters, c[1], c[2])
		if boundaries_generator.is_point_within_race_area(Vector2(c_meters.x, c_meters.z)):
			#var elevation = elevation_generator.get_elevation(Vector2(cMeters.x, cMeters.z))
			#cMeters.y += elevation
			if (prev_exists):
				var distance: float = prev_meters.distance_to(c_meters)
				# if (distance > _MAX_LENGTH_BETWEEN_TWO_ROADS_POINTS):
				# 	_append_interpolated_points(prev_meters, c_meters, meters_coords)
			meters_coords.append(c_meters)
			prev_meters = c_meters
			prev_exists = true
	
	if (meters_coords.size() < 2):
		return false
	
	#meters_coords = _simplify_road(meters_coords)
	
	var reverse_lanes: int = 1
	var forward_lanes: int = 1
	if props != null:
		if props.has("lanes"):
			if props.has("lanes:forward") and props.has("lanes:backward"):
				forward_lanes = props.get("lanes:forward").to_int()
				reverse_lanes = props.get("lanes:backward").to_int()
			else:
				var total: int = props.get("lanes").to_int()
				reverse_lanes = total / 2
				forward_lanes = total - reverse_lanes
	
	var traffic_dir: Array[RoadPoint.LaneDir] = []
	for i in range(reverse_lanes):
		traffic_dir.append(RoadPoint.LaneDir.REVERSE)
	for i in range(forward_lanes):
		traffic_dir.append(RoadPoint.LaneDir.FORWARD)
	
	var init_point: RoadPointPlaceholder = RoadPointPlaceholder.new()
	#roads_container.add_child(init_point)
	#loader.persist_in_current_scene(init_point)
	init_point.lane_width = 3
	init_point.gutter_profile = Vector2(3, -0.5)
	init_point.traffic_dir = traffic_dir
	init_point.position = meters_coords[0]
	
	# we need to do a 180 turn, to face opposite direction
	# we do not use rotated because it does it around the origin, not itself
	var to_mirrored = meters_coords[0] + 2 * (meters_coords[0] - meters_coords[1])
	#initPoint.transform = initPoint.transform.looking_at(metersCoords[1])
	init_point.transform = _rotated_point(init_point.transform, to_mirrored, meters_coords[1])
	
	init_point.is_road_start = true
	init_point.is_road_end = false
	#loader.persist_in_current_scene(init_point)
	_road_points_to_build.append(init_point)
	
	var previous_rp = init_point
	for i in range(1, meters_coords.size()):
		var next_rp: RoadPointPlaceholder = RoadPointPlaceholder.new()
		#roads_container.add_child(next_rp)
		#loader.persist_in_current_scene(next_rp)
		var prev := meters_coords[i - 1]
		var curr := meters_coords[i]
		next_rp.is_road_start = false
		next_rp.is_road_end = false
		next_rp.copy_settings_from(init_point, true) # issue here to copy transform
		next_rp.position = curr
		if (i == meters_coords.size() - 1):
			next_rp.is_road_end = true
			# we need to do a 180 turn, to face opposite direction
			# we do not use rotated because it does it around the origin, not itself
			var prev_mirrored = prev + 2 * (curr - prev)
			#nextRP.transform = nextRP.transform.looking_at(lookingOpposite)
			next_rp.transform = _rotated_point(next_rp.transform, prev, prev_mirrored)
			next_rp.prior_mag = meters_coords[i - 1].distance_to(meters_coords[i]) / 2
		else:
			next_rp.transform = _rotated_point(next_rp.transform, meters_coords[i - 1], meters_coords[i + 1])
			next_rp.prior_mag = meters_coords[i - 1].distance_to(meters_coords[i]) / 2
			next_rp.next_mag = meters_coords[i].distance_to(meters_coords[i + 1]) / 2
		
		next_rp.previous_rp = previous_rp
		_road_points_to_build.append(next_rp)
		previous_rp = next_rp
		
	return true

func _xz(v: Vector3) -> Vector2:
	return Vector2(v[0], v[2])
	
func _array_xz(a: Array[Vector3]) -> Array[Vector2]:
	var arr: Array[Vector2] = []
	for v in a:
		arr.append(_xz(v))
	return arr

func _build_building(feature: Dictionary, buildings_container: Node3D, verbose: bool = false) -> bool:
	const INIT_HEIGHT: float = 1000 # initial height to be able to snap
	if (verbose): print("_build_building: inspecting building data...")
	
	if (not feature.has("geometry")):
		if (verbose): print("building has no geometry, cancel.")
		return false
	var geometry: Dictionary = feature.get("geometry")
	if (not geometry.has("coordinates")):
		if (verbose): print("building has no coordinates, cancel.")
		return false
	var coordinates: Array = geometry.get("coordinates")
	# TODO: handle multi polygon
	if (coordinates.size() == 0):
		if (verbose): print("No building coordinates data, cancel.")
		return false
	if not geometry.get("type") == "LineString":
		if (coordinates.size() > 1):
			if (verbose): print("multi polygon not supported, only loading the first one.")
		coordinates = coordinates[0]
	if (coordinates.size() < 3):
		if (verbose): print("building has not enough nodes (", coordinates.size(), "), cancel.")
		return false
	
	if (verbose): print("building accepted.")
	
	var _prev_meters: Vector3
	var _prev_exists: bool = false
	var meters_coords: Array[Vector3] = []
	for c in coordinates:
		# we need to flip the X axis because X and longitude have opposite directions
		var c_meters: Vector3 = Vector3(-c[0] + loader.width_meters, c[1], c[2])
		if boundaries_generator.is_point_within_race_area(Vector2(c_meters.x, c_meters.z)):
			meters_coords.append(c_meters)
			_prev_meters = c_meters
			_prev_exists = true
	
	if (meters_coords.size() < 3):
		if (verbose): print("building has too few points (", meters_coords.size(), ").")
		return false

	var in_ground_height: float = 5
	var above_ground_height: float = 10
	var height: float = in_ground_height + above_ground_height
	const MAX_VALUE: float = 1000000
	var origin: Vector3 = Vector3(MAX_VALUE, 0, MAX_VALUE)
	# find smallest x and z to define the origin (the corner of the building bounding box)
	for c in meters_coords:
		origin.x = min(origin.x, c.x)
		origin.z = min(origin.z, c.z)

	# translate all points to origin
	for i in range(meters_coords.size()):
		meters_coords[i] -= origin
		meters_coords[i].y = 0 # disable offset

	# build mesh
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# we create an extruded polygon, with only the wall and ceiling

	# walls (also corresponds to occluder)
	var occluder_vertices: PackedVector3Array = []
	var occluder_indices: PackedInt32Array = []
		
	for i in range(meters_coords.size()):
		var next_index = (i + 1) % meters_coords.size()
		var bottom_l = meters_coords[i]
		var bottom_r = meters_coords[next_index]
		var top_l = bottom_l + Vector3(0, height, 0)
		var top_r = bottom_r + Vector3(0, height, 0)
		var width = bottom_l.distance_to(bottom_r)

		# first triangle (ORDER MUST MATCH WITH OCCLUDER !!!)
		surface_tool.set_uv(Vector2(0, height))
		surface_tool.add_vertex(top_l)
		surface_tool.set_uv(Vector2(width, 0))
		surface_tool.add_vertex(bottom_r)
		surface_tool.set_uv(Vector2(0, 0))
		surface_tool.add_vertex(bottom_l)

		# second triangle (ORDER MUST MATCH WITH OCCLUDER !!!)
		surface_tool.set_uv(Vector2(width, height))
		surface_tool.add_vertex(top_r)
		surface_tool.set_uv(Vector2(width, 0))
		surface_tool.add_vertex(bottom_r)
		surface_tool.set_uv(Vector2(0, height))
		surface_tool.add_vertex(top_l)
		
		# occluder
		if (i == 0):
			occluder_vertices.append_array([bottom_l, top_l])
		if (i != meters_coords.size() - 1):
			occluder_vertices.append_array([bottom_r, top_r])
			
		# indices are even at the bottom, odd at the top, growing towards R
		var top_l_index: int
		var bottom_l_index: int
		var top_r_index: int
		var bottom_r_index: int
			
		top_l_index = (2 * i) + 1
		bottom_l_index = 2 * i
		if (i != meters_coords.size() - 1):
			top_r_index = top_l_index + 2
			bottom_r_index = bottom_l_index + 2
		else:
			top_r_index = 1
			bottom_r_index = 0
		occluder_indices.append_array([top_l_index, bottom_r_index, bottom_l_index, top_r_index, bottom_r_index, top_l_index])
	
	surface_tool.generate_normals()
	var mesh: Mesh = surface_tool.commit()
	if (mesh == null):
		if (verbose): print("Failed to create mesh for building, cancel.")
		return false
	
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.mesh = mesh
	var surfaces_count = mesh_node.mesh.get_surface_count()
	for i in surfaces_count:
		mesh_node.set_surface_override_material(i, building_material)
	
	var parent: Node3D = null
	# Only load collisions if necessary.
	# We need to go back from local to global coordinates
	# by adding the origin again.
	var xz_meters_coords: Array[Vector2] = []
	var xz_origin: Vector2 = Vector2(origin.x, origin.z)
	# assign should cast type accordingly.
	xz_meters_coords.assign(meters_coords.map(func(v: Vector3) -> Vector2: return Vector2(v.x, v.z) + xz_origin))
	var mesh_collision_node: CollisionShape3D = null
	if not boundaries_generator.is_building_polygon_within_out_of_bounds_area(xz_meters_coords):
		var static_body: StaticBody3D = StaticBody3D.new()
	
		mesh_collision_node = CollisionShape3D.new()
		mesh_collision_node.shape = mesh.create_trimesh_shape()
		
		parent = static_body
	else:
		parent = Node3D.new()

	buildings_container.add_child(parent)
	loader.persist_in_current_scene(parent)
	parent.add_child(mesh_node)
	loader.persist_in_current_scene(mesh_node)
	if mesh_collision_node != null:
		parent.add_child(mesh_collision_node)
		loader.persist_in_current_scene(mesh_collision_node)

	
	parent.position = origin + Vector3(0, INIT_HEIGHT, 0)
	parent.name = "Building__%s" % [feature.get("properties").get("@id")]
	
	_setup_snapping(parent, false, in_ground_height)
	
	var occluder_instance: OccluderInstance3D = OccluderInstance3D.new()
	parent.add_child(occluder_instance)
	loader.persist_in_current_scene(occluder_instance)
	var occluder_3d_polygon: ArrayOccluder3D = ArrayOccluder3D.new()
	occluder_3d_polygon.set_arrays(occluder_vertices, occluder_indices)
	occluder_instance.occluder = occluder_3d_polygon

	parent.add_to_group("buildings", true)

	return true

func _get_scene_from_feature(feature: Dictionary) -> PackedScene:
	if not feature.has("properties"):
		return null
	var props: Dictionary = feature.get("properties")
	
	if _is_bin(props):
		return BIN_SCENE
	if _is_bench(props):
		return BENCH_SCENE
	if _is_bus_stop(props):
		return BUS_STOP_POLE_SCENE
	
	return null

func _build_amenity(feature: Dictionary, collidable_assets_container: Node3D, verbose: bool = false) -> bool:
	var kind: String = feature.get("properties").get("amenity")
	var prefix: String = _amenity_kind_to_prefix.get(kind)

	if (not feature.has("geometry")):
		if (verbose): print("%s has no geometry, cancel." % prefix)
		return false
	var geometry: Dictionary = feature.get("geometry")
	if (not geometry.has("coordinates")):
		if (verbose): print("%s has no coordinates, cancel." % prefix)
		return false
	var coordinates: Array = geometry.get("coordinates")
	if (coordinates.size() != 3):
		if (verbose): print("%s has invalid coordinates, cancel." % prefix)
		return false

	var pos = coordinates
	# We need to flip the X axis because X and longitude have opposite directions
	var pos_meters: Vector3 = Vector3(-pos[0] + loader.width_meters, pos[1], pos[2])
	# # Y returned from python script is broken, solution was not found yet.
	# pos_meters.y = loader.terrain.data.get_height(pos_meters)

	if not boundaries_generator.is_point_within_race_area(Vector2(pos_meters.x, pos_meters.z)):
		if (verbose): print("%s outside race area, cancel." % prefix)
		return false

	var scene = _get_scene_from_feature(feature).instantiate()
	scene.name = "%s__%s" % [prefix, _get_id_or_rand_str(feature)]
	collidable_assets_container.add_child(scene)
	loader.persist_in_current_scene(scene)
	scene.position = pos_meters
	return true

func _build_highway_node(feature: Dictionary, collidable_assets_container: Node3D, verbose: bool = false) -> bool:
	var kind: String = feature.get("properties").get("highway")
	var prefix: String = _highway_kind_to_prefix.get(kind)

	if (not feature.has("geometry")):
		if (verbose): print("%s has no geometry, cancel." % prefix)
		return false
	var geometry: Dictionary = feature.get("geometry")
	if (not geometry.has("coordinates")):
		if (verbose): print("%s has no coordinates, cancel." % prefix)
		return false
	var coordinates: Array = geometry.get("coordinates")
	if (coordinates.size() != 3):
		if (verbose): print("%s has invalid coordinates, cancel." % prefix)
		return false

	var pos = coordinates
	# We need to flip the X axis because X and longitude have opposite directions
	var pos_meters: Vector3 = Vector3(-pos[0] + loader.width_meters, pos[1], pos[2])
	# # Y returned from python script is broken, solution was not found yet.
	# pos_meters.y = loader.terrain.data.get_height(pos_meters)
	if not boundaries_generator.is_point_within_race_area(Vector2(pos_meters.x, pos_meters.z)):
		if (verbose): print("%s outside race area, cancel." % prefix)
		return false

	var scene = _get_scene_from_feature(feature).instantiate()
	scene.name = "%s__%s" % [prefix, _get_id_or_rand_str(feature)]
	collidable_assets_container.add_child(scene)
	loader.persist_in_current_scene(scene)
	scene.position = pos_meters

	return true

func _regenerate_data(data_holder: Node3D, kind: ReloadKind) -> void:
	if kind == ReloadKind.ROADS:
		snaps_left_road = 0
		snaps_left = 0
		_can_build_roads = false
		_road_points_to_build = []
		_road_points_built = 0
		
	print("Loading OSM data for generation...")
	_load_data()

	if (not data_holder.has_node(ROOT_NODE_NAME)):
		_root_node = Node3D.new()
		_root_node.name = ROOT_NODE_NAME
		data_holder.add_child(_root_node)
		loader.persist_in_current_scene(_root_node)
	else:
		_root_node = data_holder.get_node(ROOT_NODE_NAME)
	
	var roads_container: Node3D = null
	if (kind == ReloadKind.ROADS):
		print("Setup road generator...")
		if _root_node.has_node("Roads"):
			_root_node.get_node("Roads").free()
		roads_container = Node3D.new()
		roads_container.name = "Roads"
		_root_node.add_child(roads_container)
		loader.persist_in_current_scene(roads_container)
		var road_manager = RoadManager.new()
		loader.terrain_connector.road_manager = road_manager
		_road_manager = road_manager
		road_manager.auto_refresh = false
		road_manager.material_resource = road_material
		road_manager.density = 8
		road_manager.collision_layer += 16 # layer 5
		road_manager.collision_layer += 4 # layer 3
		road_manager.collision_layer += 256 # layer 9
		roads_container.add_child(road_manager)
		loader.persist_in_current_scene(road_manager)
	
	var buildings_container: Node3D = null
	if kind == ReloadKind.BUILDINGS:
		if _root_node.has_node("Buildings"):
			_root_node.get_node("Buildings").free()

		buildings_container = Node3D.new()
		_root_node.add_child(buildings_container)
		buildings_container.name = "Buildings"
		loader.persist_in_current_scene(buildings_container)
	
	var collidable_assets_container: Node3D = null
	if kind == ReloadKind.AMENITIES:
		if _root_node.has_node("Collidable Assets"):
			_root_node.get_node("Collidable Assets").free()

		collidable_assets_container = Node3D.new()
		_root_node.add_child(collidable_assets_container)
		collidable_assets_container.name = "Collidable Assets"
		loader.persist_in_current_scene(collidable_assets_container)
	
	print("Creating structures")
	assert(_data.features != null)
	var features: Array = _data.features
	print("features: ", features.size())
	
	var roads_count: int = 0
	var roads_count_success: int = 0
	
	var builds_count: int = 0
	var builds_count_success: int = 0
	
	var amenities_count: int = 0
	var amenities_count_success: int = 0
	
	var highway_nodes_count: int = 0
	var highway_nodes_count_success: int = 0
	
	for f: Dictionary in features:
		if (f.has("properties")):
			var properties: Dictionary = f.get("properties")
			# road? https://wiki.openstreetmap.org/wiki/Key:highway
			if _is_road(properties) and kind == ReloadKind.ROADS:
				#if roads_count_success > 200:
					#continue
				var success: bool = _build_road(f, roads_container)
				roads_count += 1
				if success:
					roads_count_success += 1
			# if false:
			# 	pass
			elif _is_building(properties) and kind == ReloadKind.BUILDINGS: # problem
				#if builds_count_success > 1000:
					#continue
				var success: bool = _build_building(f, buildings_container)
				builds_count += 1
				if success:
					builds_count_success += 1
			elif _is_supported_amenity(properties) and kind == ReloadKind.AMENITIES:
				var success: bool = _build_amenity(f, collidable_assets_container)
				amenities_count += 1
				if success:
					amenities_count_success += 1
			elif _is_bus_stop(properties) and kind == ReloadKind.AMENITIES:
				var success: bool = _build_highway_node(f, collidable_assets_container)
				highway_nodes_count += 1
				if success:
					highway_nodes_count_success += 1
		
	print("Created ", roads_count_success, " roads. Tried: ", roads_count)
	print("Created ", builds_count_success, " buildings. Tried: ", builds_count)
	print("Created ", amenities_count_success, " amenities. Tried: ", amenities_count)
	print("Created ", highway_nodes_count_success, " highway nodes. Tried: ", highway_nodes_count)
	
	print("Nodes: ", _root_node.get_child_count())

	print("Done, snapping and road building excluded.")
	_can_build_roads = true
	if VERBOSE and kind == ReloadKind.ROADS:
		var debug_roads_str: String = ""
		for r in _road_points_to_build:
			if r.is_road_start and r.is_road_end:
				debug_roads_str += "!"
			elif r.is_road_start:
				debug_roads_str += "["
			elif r.is_road_end:
				debug_roads_str += "]"
			else:
				debug_roads_str += "-"
		print("Roads to build: " + debug_roads_str)

## Returns a random int as a string
func _rand_str() -> String:
	return str(randi_range(0, 100_000_000))

## Returns the GeoJSON feature ID, or a random string if not found.
func _get_id_or_rand_str(feature: Dictionary) -> StringName:
	if not feature.has("properties"):
		return _rand_str()
	var prop: Dictionary = feature.get("properties")
	
	if not prop.has("@id"):
		return str(randi_range(0, 100_000_000))
	return prop.get("@id")

## Contains GDScript logic to apply manual mutations (such as transforms)
## to adjust elements (ex: bench orientation). This is much better than
## manually mutating the scene which may be overriden by reloading data.
## The workflow is as follows: do the modification in the scene until
## satisfied, then reconstruct those modifications through GDScript below.
## It is best to leave a comment to describe the intent, and prefer absolute
## over relative mutations to ease maintenance.
func apply_osm_mutations_action(data_holder):
	var root: Node3D = data_holder.get_node(ROOT_NODE_NAME)
	if root == null:
		push_warning("Could not find root Node for mutations. Doing nothing.")
		return
	
	loader.track.apply_osm_mutations_action(root, self)

## Root is OSMData
func get_collidable_asset(root: Node3D, name: StringName) -> Node3D:
	assert(root.name == "OSMData")
	return root.get_node("Collidable Assets/%s" % name)
