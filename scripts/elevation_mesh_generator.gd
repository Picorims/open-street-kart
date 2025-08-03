# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


@tool
class_name ElevationMeshGenerator extends Node3D

@export var loader: MapDataLoader
@export var enableDebugPoints: bool = false

var _material: Material
const METERS_STEP: float = 30

const ROOT_NODE_NAME: String = "ElevationStaticBody"

var _is_loaded: bool = false
@export var is_loaded: bool:
	get: return _is_loaded
		
		
func _ready() -> void:
	assert(loader != null, "Loader not defined.")
	_material = loader.floorMaterial

func reload_action(mat: Material, dataHolder: Node3D) -> void:
	assert(!(mat == null), "MapDataLoader: Missing material for elevation surface.")
	_material = mat
	_is_loaded = false
	_regenerate_mesh(dataHolder)
	_is_loaded = true

func _process(delta):
	if (is_loaded && enableDebugPoints):
		# draw debug points
		for i in _data:
			var point = loader.lat_alt_lon_to_world_global_pos(i)
			#DebugDraw3D.draw_sphere(point, 15, Color(1,((point.y+150)/200),0,1))
			DebugDraw3D.draw_points([point], 0, 30, Color(1,((point.y+150)/200),0,1))

# see https://forum.godotengine.org/t/how-to-declare-2d-arrays-matrices-in-gdscript/38638/5
var _data: Array[Vector3] = []
var _rows: int = 0
var _cols: int = 0

func _read_data(latIdx: int, lonIdx: int) -> Vector3:
	assert(latIdx >= 0 && lonIdx >= 0 && latIdx < _cols && lonIdx < _rows, "_read_data: illegal indexes: " + str(latIdx) + ", " + str(lonIdx))
	return _data[lonIdx * _cols + latIdx]
	
func _str_to_float(s: String) -> float:
	var dot_pos = s.find(".")
	var floatV: float = 0
	var exp = dot_pos
	for char in s:
		var i = int(char)
		floatV += i * pow(10, exp)
		exp -= 1
	
	return floatV

func _load_data() -> void:
	# see https://forum.godotengine.org/t/how-can-i-import-a-csv-or-txt-file/26027
	# see https://docs.godotengine.org/en/stable/classes/class_fileaccess.html

	var file = FileAccess.open(loader.topoDataPath, FileAccess.READ)
	var oldLat: float = -1000000.0
	_rows = 1
	_cols = 0
	_data = []
	while !file.eof_reached():
		var csv: PackedStringArray = file.get_csv_line("\t")
		if (csv.size() < 3):
			continue
		var lat: float = float(csv[1])
		var lon: float = float(csv[0])
		var elev: float = float(csv[2])
		
		if (oldLat < lat && _rows == 1):
			_cols += 1
		if (oldLat > lat):
			_rows += 1
		
		_data.append(Vector3(lat,elev,lon))

		oldLat = float(lat)
	file.close()

func _regenerate_mesh(dataHolder: Node3D) -> void:
	print("Loading elevation data...")
	_load_data()
	
	print("Loaded. Building mesh...")
	print("rows: ", _rows)
	print("cols: ", _cols)
	print("entries: ", _data.size())
	# see https://www.youtube.com/watch?v=-5L0RK-9Wd4
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var origin: Vector3 = _data[0]
	print("origin: ", origin)
	for lonIdx in range(_rows-1):
		for latIdx in range(_cols-1):
			# build square using 2 mesh triangles and four positions
			# i.e. linear interpolation between elevation points in the grid
			var bottomL = loader.lat_alt_lon_to_world_global_pos(_read_data(latIdx, lonIdx))
			var bottomR = loader.lat_alt_lon_to_world_global_pos(_read_data(latIdx, lonIdx+1))
			var topL = loader.lat_alt_lon_to_world_global_pos(_read_data(latIdx+1, lonIdx))
			var topR = loader.lat_alt_lon_to_world_global_pos(_read_data(latIdx+1, lonIdx+1))

			# print("making square with points: ", bottomL, ", ", bottomR, ", ", topL, ", ", topR)
			
			# first triangle
			surfaceTool.add_vertex(bottomL)
			surfaceTool.add_vertex(bottomR)
			surfaceTool.add_vertex(topL)
			
			# second triangle
			surfaceTool.add_vertex(topL)
			surfaceTool.add_vertex(bottomR)
			surfaceTool.add_vertex(topR)

	# DEBUG TRIANGLE ===
	# surfaceTool.add_vertex(Vector3(0, 0, 0))
	# surfaceTool.add_vertex(Vector3(1, 0, 0))
	# surfaceTool.add_vertex(Vector3(0, 0, 1))
	# DEBUG TRIANGLE ===

	print("triangles defined.")
	print("calculate normals...")
	surfaceTool.generate_normals()
	
	print("commiting...")
	
	
	if (dataHolder.has_node(ROOT_NODE_NAME)):
		dataHolder.get_node(ROOT_NODE_NAME).free()
	
	var root: StaticBody3D = StaticBody3D.new()
	root.name = ROOT_NODE_NAME
	root.set_collision_layer_value(2, true)
	# layer above not saved for some reason, dirty fix
	# in _process() of map_data_loader.gd
	print(root.collision_layer)
	dataHolder.add_child(root)
	loader.persist_in_current_scene(root)
	
	var displayNode: MeshInstance3D = MeshInstance3D.new()
	root.add_child(displayNode)
	loader.persist_in_current_scene(displayNode)
	displayNode.mesh = surfaceTool.commit()
	print("assigning material...")
	var surfacesCount = displayNode.mesh.get_surface_count()
	for i in surfacesCount:
		displayNode.set_surface_override_material(i, _material)
	
	print("assigning collision shape...")
	var collisionNode: CollisionShape3D = CollisionShape3D.new()
	root.add_child(collisionNode)
	loader.persist_in_current_scene(collisionNode)
	var shape: Shape3D = displayNode.mesh.create_trimesh_shape()
	collisionNode.shape = shape

	print("done")

## Returns the interpolated generation based on nearest points known.
## WARNING: This is resource intensive!
## @deprecated
func get_elevation(posMetersFromOrigin: Vector2) -> float:
	# see: https://www.youtube.com/watch?v=BFld4EBO2RE (Painting a Landscape with Mathematics by Inigo Quilez)
	#var originMeters3D: Vector3 = loader.get_origin_meters()
	#var originMeters: Vector2 = Vector2(originMeters3D.x, originMeters3D.z)
	var tileFloor: Vector2 = floor(posMetersFromOrigin / METERS_STEP) * METERS_STEP
	var tileCeil: Vector2 = ceil(posMetersFromOrigin / METERS_STEP) * METERS_STEP
	
	var aMeters: Vector2 = tileFloor
	var bMeters: Vector2 = Vector2(tileCeil.x, tileFloor.y)
	var cMeters: Vector2 = Vector2(tileFloor.x, tileCeil.y)
	var dMeters: Vector2 = tileCeil
	#print("a: ", aMeters, "; b: ", bMeters, "; c: ", cMeters, "; d: ", dMeters)
	
	var aIndexRelative: Vector2 = aMeters / METERS_STEP
	var bIndexRelative: Vector2 = bMeters / METERS_STEP
	var cIndexRelative: Vector2 = cMeters / METERS_STEP
	var dIndexRelative: Vector2 = dMeters / METERS_STEP
	var posIndexRelative: Vector2 = posMetersFromOrigin / METERS_STEP
	
	var aIndex: Vector2 = round(aIndexRelative)
	var bIndex: Vector2 = round(bIndexRelative)
	var cIndex: Vector2 = round(cIndexRelative)
	var dIndex: Vector2 = round(dIndexRelative)
	
	var a: float = _read_data(aIndex.x, aIndex.y).y
	var b: float = _read_data(bIndex.x, bIndex.y).y
	var c: float = _read_data(cIndex.x, cIndex.y).y
	var d: float = _read_data(dIndex.x, dIndex.y).y
	var x: float = posIndexRelative.x
	var z: float = posIndexRelative.y
	var i: float = tileFloor.x
	var j: float = tileFloor.y
	
	var result: float = a + (b-a)*(x-i) + (c-a)*(z-j) + (a-b-c+d)*(x-i)*(z-j)
	# print("at: ", posIndexRelative, "got: ", result)
	return result
