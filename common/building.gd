# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
## X/Z is assumed to be [min_x, min_z] (corner of bounding box),
## While Y is base altitude.
class_name Building extends Node3D

# see: https://wiki.openstreetmap.org/wiki/Simple_3D_Buildings
# see: https://wiki.openstreetmap.org/wiki/Buildings
# see: https://wiki.openstreetmap.org/wiki/Key:building:part

# Note: not all data is used, but relevant data is kept around
# for improving immersion in the future. Structure is heavily
# aligned with OSM tagging schema (on purpose) so that it is possible
# to refer to the wiki for documentation

enum Mode {
	SERVER,
	CLIENT,
	EDITOR,
	UNSET
}

@export var is_part: bool = false
@export var kind: String = ""
@export var amenity: String = ""
@export var shop_kind: String = ""
@export var condition: String = ""
@export var ruins: String = ""
## true if abandoned=yes or abandoned:* is defined.
@export var abandoned: bool = false
@export var disused: String = ""

@export var height_m: float = 10.0
## below is air, above up to height_m is actual height.
@export var min_height_m: float = 0
@export var levels: int = 1
## below is air, above up to levels is actual levels.
@export var min_level: int = 0
## 1 is above ground, -1 is underground.
@export var layer: int = 1

@export var roof_height_m: float = 3.0
@export var roof_angle: float = 0
@export var roof_levels: int = 1
@export var roof_shape: String = ""
@export var roof_orientation: String = ""

@export var wall_material: String = ""
@export var wall_colour: Color = Color.WHITE
@export var roof_material: String = ""
@export var roof_colour: Color = Color.BROWN


@export var entrance_kind: String = ""
@export var entrance_pos: Vector2 = Vector2.ZERO

## Relative coordinates from origin
@export var outline_points_m: Array[Vector2]
@export var is_collidable: bool = false

var mode: Mode = Mode.UNSET
var _collider: StaticBody3D = null
var _mesh: MeshInstance3D = null
var _occluder: OccluderInstance3D = null

func _ready() -> void:
	if not s_global.is_game_running:
		mode = Mode.EDITOR
		_build_building()

func _build_building(verbose: bool = false) -> bool:
	if outline_points_m.size() < 3:
		if (verbose):
			print("building has too few points (", outline_points_m.size(), ").")
		return false

	var in_ground_height: float = 5
	var above_ground_height: float = height_m
	var height: float = in_ground_height + above_ground_height
	var origin: Vector3 = global_position
	origin.y = 0

	# build mesh
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# we create an extruded polygon, with only the wall and ceiling

	# walls (also corresponds to occluder)
	var occluder_vertices: PackedVector3Array = []
	var occluder_indices: PackedInt32Array = []
	var outline_points_m_3d: Array[Vector3] = []
	for p in outline_points_m:
		outline_points_m_3d.append(Vector3(p.x, 0, p.y))
		
	for i in range(outline_points_m_3d.size()):
		var next_index = (i + 1) % outline_points_m_3d.size()
		var bottom_l = outline_points_m_3d[i]
		var bottom_r = outline_points_m_3d[next_index]
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
		if (i != outline_points_m.size() - 1):
			occluder_vertices.append_array([bottom_r, top_r])
			
		# indices are even at the bottom, odd at the top, growing towards R
		var top_l_index: int
		var bottom_l_index: int
		var top_r_index: int
		var bottom_r_index: int
			
		top_l_index = (2 * i) + 1
		bottom_l_index = 2 * i
		if (i != outline_points_m.size() - 1):
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
	
	if mode == Mode.CLIENT or mode == Mode.EDITOR:
		if _mesh != null:
			_discard(_mesh)
		if _occluder != null:
			_discard(_occluder)
		
		_mesh = MeshInstance3D.new()
		_mesh.mesh = mesh
		#FIXME when materials are implemented
		#var surfaces_count := _mesh.mesh.get_surface_count()
		#for i in surfaces_count:
			#_mesh.set_surface_override_material(i, building_material)
		add_child(_mesh)
		
		_occluder = OccluderInstance3D.new()
		var occluder_3d_polygon: ArrayOccluder3D = ArrayOccluder3D.new()
		occluder_3d_polygon.set_arrays(occluder_vertices, occluder_indices)
		_occluder.occluder = occluder_3d_polygon

	if (mode == Mode.SERVER or mode == Mode.EDITOR) and is_collidable:
		if _collider != null:
			_discard(_collider)
		
		_collider = StaticBody3D.new()
	
		var mesh_collision_node = CollisionShape3D.new()
		mesh_collision_node.shape = mesh.create_trimesh_shape()

		_collider.add_child(mesh_collision_node)
		add_child(_collider)
	else:
		if (verbose): print("Cannot use mesh, building mode not set.")

	return true

func _discard(node: Node3D):
	if has_node(node.get_path()):
		remove_child(node)
	node.queue_free()
