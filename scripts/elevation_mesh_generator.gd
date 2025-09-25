# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


@tool
class_name ElevationMeshGenerator extends Node3D

@export var loader: MapDataLoader
@export var enable_debug_points: bool = false

var _material: Material
const METERS_STEP: float = 30

const ROOT_NODE_NAME: String = "ElevationStaticBody"

var _is_loaded: bool = false
@export var is_loaded: bool:
	get: return _is_loaded
		
		
func _ready() -> void:
	assert(loader != null, "Loader not defined.")
	_material = loader.floor_material

func reload_action(mat: Material, data_holder: Node3D) -> void:
	assert(mat != null, "MapDataLoader: Missing material for elevation surface.")
	_material = mat
	_is_loaded = false
	_regenerate_mesh(data_holder)
	_is_loaded = true

func _process(_delta):
	if (is_loaded and enable_debug_points):
		# draw debug points
		for i in _data:
			var point = loader.lat_alt_lon_to_world_global_pos(i)
			#DebugDraw3D.draw_sphere(point, 15, Color(1,((point.y+150)/200),0,1))
			DebugDraw3D.draw_points([point], 0, 30, Color(1, ((point.y + 150) / 200), 0, 1))

# see https://forum.godotengine.org/t/how-to-declare-2d-arrays-matrices-in-gdscript/38638/5
var _data: Array[Vector3] = []
var _rows: int = 0
var _cols: int = 0

func _get_data_index(lat_index: int, lon_index: int) -> int:
	assert(lat_index >= 0 and lon_index >= 0 and lat_index < _cols and lon_index < _rows, "_get_data_index: illegal indexes: " + str(lat_index) + ", " + str(lon_index))
	return lon_index * _cols + lat_index

func _read_data(lat_index: int, lon_index: int) -> Vector3:
	assert(lat_index >= 0 and lon_index >= 0 and lat_index < _cols and lon_index < _rows, "_read_data: illegal indexes: " + str(lat_index) + ", " + str(lon_index))
	return _data[_get_data_index(lat_index, lon_index)]
	
func _str_to_float(s: String) -> float:
	var dot_pos = s.find(".")
	var float_value: float = 0
	var exp_count = dot_pos
	for character in s:
		var i = int(character)
		float_value += i * pow(10, exp_count)
		exp_count -= 1
	
	return float_value

func _load_data() -> void:
	# see https://forum.godotengine.org/t/how-can-i-import-a-csv-or-txt-file/26027
	# see https://docs.godotengine.org/en/stable/classes/class_fileaccess.html
	var file = FileAccess.open(loader.topo_data_path, FileAccess.READ)
	var old_lat: float = -1000000.0
	_rows = 1
	_cols = 0
	_data = []
	while not file.eof_reached():
		var csv: PackedStringArray = file.get_csv_line("\t")
		if (csv.size() < 3):
			continue
		var lat: float = float(csv[1])
		var lon: float = float(csv[0])
		var elev: float = float(csv[2])
		
		if (old_lat < lat and _rows == 1):
			_cols += 1
		if (old_lat > lat):
			_rows += 1
		
		_data.append(Vector3(lat, elev, lon))

		old_lat = float(lat)
	file.close()

func _regenerate_mesh(data_holder: Node3D) -> void:
	print("Loading elevation data...")
	_load_data()
	
	print("Loaded. Building mesh...")
	print("rows: ", _rows)
	print("cols: ", _cols)
	print("entries: ", _data.size())
	# see https://www.youtube.com/watch?v=-5L0RK-9Wd4
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var origin: Vector3 = _data[0]
	var occluder_vertices: PackedVector3Array
	var occluder_indices: PackedInt32Array
	
	var points_meters: Array[Vector3] = []
	for v in _data:
		points_meters.append(loader.lat_alt_lon_to_world_global_pos(v))
	
	occluder_vertices.append_array(points_meters)
	
	print("origin: ", origin)
	for lon_index in range(_rows - 1):
		for lat_index in range(_cols - 1):
			# build square using 2 mesh triangles and four positions
			# i.e. linear interpolation between elevation points in the grid
			var bottom_l = points_meters[_get_data_index(lat_index, lon_index)]
			var bottom_r = points_meters[_get_data_index(lat_index, lon_index + 1)]
			var top_l = points_meters[_get_data_index(lat_index + 1, lon_index)]
			var top_r = points_meters[_get_data_index(lat_index + 1, lon_index + 1)]

			# print("making square with points: ", bottomL, ", ", bottomR, ", ", topL, ", ", topR)
			
			# ORDER OF VERTICES MUST BE COHERENT WITH OCCLUDER INDICES ORDER !!!
			# first triangle
			surface_tool.add_vertex(bottom_l)
			surface_tool.add_vertex(bottom_r)
			surface_tool.add_vertex(top_l)
			
			# ORDER OF VERTICES MUST BE COHERENT WITH OCCLUDER INDICES ORDER !!!
			# second triangle
			surface_tool.add_vertex(top_l)
			surface_tool.add_vertex(bottom_r)
			surface_tool.add_vertex(top_r)
			
			# occluder
			# size = last_index + 1 = first index available
			var bottom_l_index: int = _get_data_index(lat_index, lon_index)
			var bottom_r_index: int = _get_data_index(lat_index, lon_index + 1)
			var top_l_index: int = _get_data_index(lat_index + 1, lon_index)
			var top_r_index: int = _get_data_index(lat_index + 1, lon_index + 1)
			occluder_indices.append_array([bottom_l_index, bottom_r_index, top_l_index, top_l_index, bottom_r_index, top_r_index])

	# DEBUG TRIANGLE ===
	# surfaceTool.add_vertex(Vector3(0, 0, 0))
	# surfaceTool.add_vertex(Vector3(1, 0, 0))
	# surfaceTool.add_vertex(Vector3(0, 0, 1))
	# DEBUG TRIANGLE ===

	print("triangles defined.")
	print("calculate normals...")
	surface_tool.generate_normals()
	surface_tool.set_material(_material)
	
	print("commiting...")
	
	
	if (data_holder.has_node(ROOT_NODE_NAME)):
		data_holder.get_node(ROOT_NODE_NAME).free()
	
	var root: StaticBody3D = StaticBody3D.new()
	root.name = ROOT_NODE_NAME
	root.set_collision_layer_value(2, true)
	root.set_collision_layer_value(4, true) # to see if needs the dirty fix
	root.set_collision_layer_value(5, true) # to see if needs the dirty fix
	root.set_collision_layer_value(9, true) # to see if needs the dirty fix
	# layer above not saved for some reason, dirty fix
	# in _process() of map_data_loader.gd
	print(root.collision_layer)
	data_holder.add_child(root)
	loader.persist_in_current_scene(root)
	
	var display_node: MeshInstance3D = MeshInstance3D.new()
	root.add_child(display_node)
	loader.persist_in_current_scene(display_node)
	display_node.mesh = surface_tool.commit()
	
	print("assigning collision shape...")
	var collision_node: CollisionShape3D = CollisionShape3D.new()
	root.add_child(collision_node)
	loader.persist_in_current_scene(collision_node)
	var shape: Shape3D = display_node.mesh.create_trimesh_shape()
	collision_node.shape = shape
	
	print("assigning occluder...")
	var occluder_instance: OccluderInstance3D = OccluderInstance3D.new()
	root.add_child(occluder_instance)
	loader.persist_in_current_scene(occluder_instance)
	var occluder_3d_polygon: ArrayOccluder3D = ArrayOccluder3D.new()
	occluder_3d_polygon.set_arrays(occluder_vertices, occluder_indices)
	occluder_instance.occluder = occluder_3d_polygon

	print("done")

## Returns the interpolated generation based on nearest points known.
## WARNING: This is resource intensive!
## @deprecated
func get_elevation(posMetersFromOrigin: Vector2) -> float:
	# see: https://www.youtube.com/watch?v=BFld4EBO2RE (Painting a Landscape with Mathematics by Inigo Quilez)
	#var originMeters3D: Vector3 = loader.get_origin_meters()
	#var originMeters: Vector2 = Vector2(originMeters3D.x, originMeters3D.z)
	var tile_floor: Vector2 = floor(posMetersFromOrigin / METERS_STEP) * METERS_STEP
	var tile_ceil: Vector2 = ceil(posMetersFromOrigin / METERS_STEP) * METERS_STEP
	
	var a_meters: Vector2 = tile_floor
	var b_meters: Vector2 = Vector2(tile_ceil.x, tile_floor.y)
	var c_meters: Vector2 = Vector2(tile_floor.x, tile_ceil.y)
	var d_meters: Vector2 = tile_ceil
	#print("a: ", aMeters, "; b: ", bMeters, "; c: ", cMeters, "; d: ", dMeters)
	
	var a_index_relative: Vector2 = a_meters / METERS_STEP
	var b_index_relative: Vector2 = b_meters / METERS_STEP
	var c_index_relative: Vector2 = c_meters / METERS_STEP
	var d_index_relative: Vector2 = d_meters / METERS_STEP
	var pos_index_relative: Vector2 = posMetersFromOrigin / METERS_STEP
	
	var a_index: Vector2 = round(a_index_relative)
	var b_index: Vector2 = round(b_index_relative)
	var c_index: Vector2 = round(c_index_relative)
	var d_index: Vector2 = round(d_index_relative)
	
	var a: float = _read_data(a_index.x, a_index.y).y
	var b: float = _read_data(b_index.x, b_index.y).y
	var c: float = _read_data(c_index.x, c_index.y).y
	var d: float = _read_data(d_index.x, d_index.y).y
	var x: float = pos_index_relative.x
	var z: float = pos_index_relative.y
	var i: float = tile_floor.x
	var j: float = tile_floor.y
	
	var result: float = a + (b - a) * (x - i) + (c - a) * (z - j) + (a - b - c + d) * (x - i) * (z - j)
	# print("at: ", posIndexRelative, "got: ", result)
	return result
