# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


@tool
class_name BoundariesGenerator extends Node3D

const ROOT_NODE_NAME: String = "Boundaries"
const RACE_BOUNDARY_SCRIPT = preload("res://scripts/race_global_boundary.gd")
const LOCAL_RACE_BOUNDARY_SCRIPT = preload("res://scripts/race_local_boundary.gd")
const DEBUG_ENABLED = false

@export var loader: MapDataLoader

var _race_2d_polygon: Array[Vector2] = []
## Array[Array[Vector2]]
var _out_of_bounds_polygons: Array[Array] = []
var _is_loaded: bool = false
@export var is_loaded: bool:
	get: return _is_loaded

func _ready() -> void:
	assert(loader != null)

## For a given point in meters, says if it is in the race area.
func is_point_within_race_area(p: Vector2) -> bool:
	# see: https://forum.godotengine.org/t/how-to-check-if-a-point-is-in-a-polygon2d/9651/2
	if (_race_2d_polygon.size() == 0):
		return false
	else:
		return Geometry2D.is_point_in_polygon(p, _race_2d_polygon)

## Returns true if the given polygon is entirely within
## one of the local race boundaries area (polygon).
func is_building_polygon_within_out_of_bounds_area(polygon: Array[Vector2]) -> bool:
	for area_polygon in _out_of_bounds_polygons:
		var i: int = 0
		var one_point_outside_poly: bool = false
		while i < polygon.size() and not one_point_outside_poly:
			var is_in_poly: bool = Geometry2D.is_point_in_polygon(polygon[i], area_polygon)
			if not is_in_poly:
				one_point_outside_poly = true
			i += 1
		
		if not one_point_outside_poly:
			return true
	return false

var _data

func _load_data() -> void:
	# see https://docs.godotengine.org/en/stable/classes/class_json.html#class-json-method-parse
	# see https://docs.godotengine.org/en/stable/classes/class_fileaccess.html
	var file = FileAccess.open(loader.boundaries_data_path, FileAccess.READ)
	_data = JSON.parse_string(file.get_as_text())
	assert(_data != null)
	file.close()


func reload_action(data_holder: Node3D) -> void:
	_is_loaded = false
	_regenerate_data(data_holder)
	_is_loaded = true

func _build_area(kind: String, coords: Array[Array], boundaries_node: Node3D, id: String) -> bool:
	print("boundary data:")
	print(kind)
	print(coords)
	
	var area_3d: Area3D = Area3D.new()
	# concave shapes are not supported by Area3D, except if made with a polygon.
	var collider: CollisionPolygon3D = CollisionPolygon3D.new()
	area_3d.add_child(collider)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var coords_meters: Array[Vector3] = []
	var area_2d_polygon: Array[Vector2] = []
	for c in coords:
		var meters_coord = loader.lat_alt_lon_to_world_global_pos(Vector3(c[0], 0.0, c[1]))
		coords_meters.append(meters_coord)
		area_2d_polygon.append(Vector2(meters_coord.x, meters_coord.z))
			
	if (kind == "race"):
		_race_2d_polygon = area_2d_polygon.duplicate()
	elif (kind == "local_race_boundary"):
		_out_of_bounds_polygons.append(area_2d_polygon.duplicate())
	
	print("converted boundary data:")
	print(coords_meters)
	
	var elevation_min = -100
	var elevation_max = 9000
	for i in range(0, coords_meters.size()):
		# build square using 2 mesh triangles and four positions
		var from = coords_meters[i]
		var to: Vector3
		if (i == coords_meters.size() - 1):
			# loop and attach back to start
			to = coords_meters[0]
		else:
			to = coords_meters[i + 1]
			
		var bottom_l = from + Vector3(0, elevation_min, 0)
		var bottom_r = to + Vector3(0, elevation_min, 0)
		var top_l = from + Vector3(0, elevation_max, 0)
		var top_r = to + Vector3(0, elevation_max, 0)

		# print("making square with points: ", bottomL, ", ", bottomR, ", ", topL, ", ", topR)
		
		# first triangle
		surface_tool.add_vertex(top_l)
		surface_tool.add_vertex(bottom_r)
		surface_tool.add_vertex(bottom_l)
		
		# second triangle
		surface_tool.add_vertex(top_r)
		surface_tool.add_vertex(bottom_r)
		surface_tool.add_vertex(top_l)
		
	mesh.mesh = surface_tool.commit()
	area_3d.add_child(mesh)
	#collider.position = Vector3(0, elevationMin, 0)
	collider.basis = Basis(Vector3.LEFT, PI / 2).rotated(Vector3.UP, PI).orthonormalized()
	collider.basis.x *= -1
	collider.depth = elevation_max - elevation_min
	collider.polygon = PackedVector2Array(area_2d_polygon)
	# var debug = Engine.is_editor_hint()
	
	var debug = DEBUG_ENABLED
	if debug:
		var color: Color = Color()
		if (kind == "race"):
			color = Color(1, 0, 1, 0.3)
		elif (kind == "local_race_boundary"):
			color = Color(1, 0.5, 0.5, 0.3)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED # see both sides
		mesh.material_override = mat
	else:
		area_3d.remove_child(mesh)
		mesh.queue_free()
	if (kind == "race"):
		area_3d.name = kind.to_pascal_case()
		area_3d.set_script(RACE_BOUNDARY_SCRIPT)
	elif (kind == "local_race_boundary"):
		area_3d.name = kind.to_pascal_case() + "_" + id
		area_3d.set_script(LOCAL_RACE_BOUNDARY_SCRIPT)

	
	boundaries_node.add_child(area_3d)
	loader.persist_in_current_scene(area_3d)
	loader.persist_in_current_scene(collider)

	return true

func _regenerate_data(data_holder: Node3D) -> void:
	print("Loading Boundaries data for road generation...")
	_load_data()
	
	print("Creating boundaries")
	assert(_data.has("features"))
	var features: Array = _data.features
	print("features: ", features.size())

	var boundaries_node: Node3D = Node3D.new()
	boundaries_node.name = ROOT_NODE_NAME
	
	if (data_holder.has_node(ROOT_NODE_NAME)):
		data_holder.get_node(ROOT_NODE_NAME).free()

	data_holder.add_child(boundaries_node)
	loader.persist_in_current_scene(boundaries_node)
	var areas_count: int = 0
	var areas_count_success: int = 0
	for f: Dictionary in features:
		if (f.has("properties")): # and roadsCount < 1000):
			var properties: Dictionary = f.get("properties")
			# road? https://wiki.openstreetmap.org/wiki/Key:highway
			var is_typed = properties.has("osk_boundary_type")
			var has_coords = f.has("geometry") and f.geometry.has("coordinates")
			if is_typed and has_coords:
				var coords: Array[Array]
				coords.assign(f.geometry.coordinates[0])
				var success: bool = _build_area(properties.osk_boundary_type, coords, boundaries_node, f.get("id", "{0}".format(randi_range(0, 100000))))
				areas_count += 1
				if success:
					areas_count_success += 1
	
	print("Created ", areas_count_success, " boundaries. Tried: ", areas_count)
	print("Nodes: ", boundaries_node.get_child_count())
	print("\nRace polygon: ", _race_2d_polygon)
	print("\nLocal race boundaries: ", _out_of_bounds_polygons)
	
	print("Done.")
