# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool

## Point of the AI's path, with a given angle, predecessors and sucessors, as well as a range.
class_name RacePathNode extends Node3D

## sets the predecessor and successor to bind to previous child.
@export_tool_button("Bind to previous child", "LinkButton") var bind_to_previous_child: Callable = Callable(self, "_bind_to_previous_child")

## defines the ridable area around the point.
@export var range_radius: float = 8:
	set(v):
		range_radius = v
		if (_range_bar_mesh.mesh != null):
			_range_bar_mesh.mesh.size.z = v * 2

@export var predecessor: RacePathNode
@export var successor: RacePathNode


var _range_bar_mesh: MeshInstance3D = MeshInstance3D.new()

func _ready() -> void:
	if (Engine.is_editor_hint() && self.get_child_count() == 0):
		var point_mesh: MeshInstance3D = MeshInstance3D.new()
		var shape_point: SphereMesh = SphereMesh.new()
		shape_point.radius = 0.5
		shape_point.rings = 16
		shape_point.radial_segments = 32
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0, 0)
		shape_point.material = mat
		point_mesh.mesh = shape_point
		self.add_child(point_mesh)
		
		var range_bar_mesh: MeshInstance3D = _range_bar_mesh
		var range_bar_shape: BoxMesh = BoxMesh.new()
		range_bar_shape.size = Vector3(0.2, 0.2, range_radius * 2)
		var mat_bar: StandardMaterial3D = StandardMaterial3D.new()
		mat_bar.albedo_color = Color(0, 0.2, 1)
		range_bar_shape.material = mat_bar
		range_bar_mesh.mesh = range_bar_shape
		self.add_child(range_bar_mesh)
		
		var forward_mesh: MeshInstance3D = MeshInstance3D.new()
		var forward_shape: BoxMesh = BoxMesh.new()
		forward_shape.size = Vector3(2, 0.2, 0.2)
		var mat_forward: StandardMaterial3D = StandardMaterial3D.new()
		mat_forward.albedo_color = Color(0, 1, 0.4)
		forward_shape.material = mat_forward
		forward_mesh.mesh = forward_shape
		self.add_child(forward_mesh)
		forward_mesh.position = Vector3(1, 0, 0)
		

func _bind_to_previous_child():
	print("Attempting a bind to previous child of ", self.name)
	var children: Array[Node] = get_parent_node_3d().get_children()
	var new_predecessor: RacePathNode = null
	for i in range(children.size()):
		if children[i] == self: # equality by ref, not content
			if i == 0:
				print("ERROR: No previous child.")
				return
			
			new_predecessor = children[i - 1]
			break
	if (new_predecessor == null):
		print("ERROR: No previous child found.")
	
	print("Found ", new_predecessor.name)
	new_predecessor.successor = self
	self.predecessor = new_predecessor
	print("Binding done.")
