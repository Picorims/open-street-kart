@tool
extends MeshInstance3D

@export var loader: MapDataLoader

var _material: Material

var is_dirty: bool
		
		
func _ready() -> void:
	is_dirty = true

func reload_action(mat: Material) -> void:
	assert(!(mat == null), "MapDataLoader: Missing material for elevation surface.")
	_material = mat
	is_dirty = true

func _process(delta):
	if is_dirty:
		is_dirty = false
		_regenerate_mesh()

# see https://forum.godotengine.org/t/how-to-declare-2d-arrays-matrices-in-gdscript/38638/5
var _data: Array[Vector3] = []
var _rows: int = 0
var _cols: int = 0

func _read_data(latIdx: int, lonIdx: int) -> Vector3:
	assert(latIdx >= 0 && lonIdx >= 0 && latIdx < _rows && lonIdx < _cols, "_read_data: illegal indexes: " + str(latIdx) + ", " + str(lonIdx))
	return _data[latIdx * _cols + lonIdx]
	
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
	var oldLon: float = -1000000.0
	_rows = 1
	_cols = 0
	_data = []
	while !file.eof_reached():
		var csv: PackedStringArray = file.get_csv_line("\t")
		if (csv.size() < 3):
			continue
		var lat: float = float(csv[0]) # _str_to_float(csv[0]) # float(csv[0])
		var lon: float = float(csv[1]) # _str_to_float(csv[1]) # float(csv[1])
		var elev: float = float(csv[2]) # _str_to_float(csv[2]) # float(csv[2])
		
		if (oldLon < lon && _rows == 1):
			_cols += 1
		if (oldLon > lon):
			_rows += 1
		
		_data.append(Vector3(lat,elev,lon))

		oldLon = float(lon)
	file.close()

func _regenerate_mesh() -> void:
	print("Loading elevation data...")
	_load_data()
	
	print("Loaded. Building mesh...")
	print("rows: ", _rows)
	print("cols: ", _cols)
	print("entries: ", _data.size())
	# see https://www.youtube.com/watch?v=-5L0RK-9Wd4
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var scaleTransform: Vector3 = Vector3(loader.latitudeScale, 1, loader.longitudeScale)
	var origin: Vector3 = _data[0]
	print("origin: ", origin)
	for latIdx in range(_rows-1 -150):
		for lonIdx in range(_cols-1 - 370):
			# build square using 2 mesh triangles and four positions
			# i.e. linear interpolation between elevation points in the grid
			var bottomL = (_read_data(latIdx, lonIdx) - origin) * scaleTransform
			var bottomR = (_read_data(latIdx, lonIdx+1) - origin) * scaleTransform
			var topL = (_read_data(latIdx+1, lonIdx) - origin) * scaleTransform
			var topR = (_read_data(latIdx+1, lonIdx+1) - origin) * scaleTransform

			print("making square with points: ", bottomL, ", ", bottomR, ", ", topL, ", ", topR)
			
			# first triangle
			surfaceTool.add_vertex(topL)
			surfaceTool.add_vertex(bottomR)
			surfaceTool.add_vertex(bottomL)
			
			# second triangle
			surfaceTool.add_vertex(topR)
			surfaceTool.add_vertex(bottomR)
			surfaceTool.add_vertex(topL)

	# DEBUG TRIANGLE ===
	# surfaceTool.add_vertex(Vector3(0, 0, 0))
	# surfaceTool.add_vertex(Vector3(1, 0, 0))
	# surfaceTool.add_vertex(Vector3(0, 0, 1))
	# DEBUG TRIANGLE ===

	print("triangles defined.")
	print("calculate normals...")
	surfaceTool.generate_normals()
	print("commiting...")
	self.mesh = surfaceTool.commit()
	print("assigning material...")
	var surfacesCount = mesh.get_surface_count()
	for i in surfacesCount:
		mesh.surface_set_material(i, _material)
	print("done")
