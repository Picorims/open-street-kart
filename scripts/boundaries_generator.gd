# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


@tool
class_name BoundariesGenerator extends Node3D

@export var loader: MapDataLoader


var is_dirty: bool
var _race2DPolygon: Array[Vector2] = []
var _is_loaded: bool = false
@export var is_loaded: bool:
	get: return _is_loaded

func _ready() -> void:
	assert(loader != null)
	is_dirty = true

## For a given point in meters, says if it is in the race area.
func is_point_within_race_area(p: Vector2) -> bool:
	# see: https://forum.godotengine.org/t/how-to-check-if-a-point-is-in-a-polygon2d/9651/2
	if (_race2DPolygon.size() == 0):
		return false
	else:
		return Geometry2D.is_point_in_polygon(p, _race2DPolygon)

var _data

func _load_data() -> void:
	# see https://docs.godotengine.org/en/stable/classes/class_json.html#class-json-method-parse
	# see https://docs.godotengine.org/en/stable/classes/class_fileaccess.html

	var file = FileAccess.open(loader.boundariesDataPath, FileAccess.READ)
	_data = JSON.parse_string(file.get_as_text())
	assert(_data != null)
	file.close()





func reload_action() -> void:
	_is_loaded = false
	#is_dirty = true
	_regenerate_data()
	_is_loaded = true

#func _process(delta):
	#if is_dirty:
		#is_dirty = false
		#_regenerate_data()
		#_is_loaded = true

func _build_area(kind: String, coords: Array[Array]) -> bool:
	print("boundary data:")
	print(kind)
	print(coords)
	
	var area3D: Area3D = Area3D.new()
	var collider: CollisionShape3D = CollisionShape3D.new()
	area3D.add_child(collider)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var coordsMeters: Array[Vector3] = []
	_race2DPolygon = []
	for c in coords:
		var metersC = loader.lat_alt_lon_to_world_global_pos(Vector3(c[0], 0.0, c[1]))
		coordsMeters.append(metersC)
		_race2DPolygon.append(Vector2(metersC.x, metersC.z))
	
	print("converted boundary data:")
	print(coordsMeters)
	
	var elevationMin = -100
	var elevationMax = 9000
	for i in range(0, coordsMeters.size()):
		# build square using 2 mesh triangles and four positions
		
		var from = coordsMeters[i]
		var to: Vector3
		if (i == coordsMeters.size() - 1):
			# loop and attach back to start
			to = coordsMeters[0]
		else:
			to = coordsMeters[i+1]
			
		var bottomL = from + Vector3(0,elevationMin,0)
		var bottomR = to + Vector3(0,elevationMin,0)
		var topL = from + Vector3(0,elevationMax,0)
		var topR = to + Vector3(0,elevationMax,0)

		# print("making square with points: ", bottomL, ", ", bottomR, ", ", topL, ", ", topR)
		
		# first triangle
		surfaceTool.add_vertex(topL)
		surfaceTool.add_vertex(bottomR)
		surfaceTool.add_vertex(bottomL)
		
		# second triangle
		surfaceTool.add_vertex(topR)
		surfaceTool.add_vertex(bottomR)
		surfaceTool.add_vertex(topL)
		
	mesh.mesh = surfaceTool.commit()
	area3D.add_child(mesh)
	collider.make_convex_from_siblings() #i.e. from mesh
	# var debug = Engine.is_editor_hint()
	
	var debug = false
	if debug:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(1,0,1,0.3)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED # see both sides
		mesh.material_override = mat
	else:
		area3D.remove_child(mesh)
		mesh.queue_free()
	area3D.name = kind.to_pascal_case()
	self.add_child(area3D)
	return true

func _regenerate_data() -> void:
	print("Boundaries data generation started. Removing existing data...")
	for n in self.get_children():
		self.remove_child(n)
		n.queue_free()
	print("Loading Boundaries data for road generation...")
	_load_data()
	
	print("Creating boundaries")
	assert(_data.has("features"))
	var features: Array = _data.features
	print("features: ", features.size())
	
	var areasCount: int = 0
	var areasCountSuccess: int = 0
	for f: Dictionary in features:
		if (f.has("properties")): #&& roadsCount < 1000):
			var properties: Dictionary = f.get("properties")
			# road? https://wiki.openstreetmap.org/wiki/Key:highway
			var isTyped = properties.has("osk_boundary_type")
			var hasCoords = f.has("geometry") && f.geometry.has("coordinates")
			if isTyped && hasCoords :
				var coords: Array[Array]
				coords.assign(f.geometry.coordinates[0])
				var success: bool = _build_area(properties.osk_boundary_type, coords)
				areasCount += 1
				if success:
					areasCountSuccess += 1
	
	print("Created ", areasCountSuccess, " boundaries. Tried: ", areasCount)
	print("Nodes: ", self.get_child_count())
	
	print("Done.")
