# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool

## Point of the AI's path, with a given angle, predecessors and sucessors, as well as a range.
class_name RacePathNode extends Node3D

## sets the predecessor and successor to bind to previous child.
@export_tool_button("Bind to previous child", "LinkButton") var bindToPreviousChild: Callable = Callable(self, "_bind_to_previous_child")

## defines the ridable area around the point.
@export var rangeRadius: float = 8:
	set(v):
		rangeRadius = v
		if (_rangeBarMesh.mesh != null):
			_rangeBarMesh.mesh.size.z = v * 2

@export var predecessor: RacePathNode
@export var successor: RacePathNode


var _rangeBarMesh: MeshInstance3D = MeshInstance3D.new()

func _ready() -> void:
	if (Engine.is_editor_hint() && self.children_count == 0):
		var pointMesh: MeshInstance3D = MeshInstance3D.new()
		var shapePoint: SphereMesh = SphereMesh.new()
		shapePoint.radius = 0.5
		shapePoint.rings = 16
		shapePoint.radial_segments = 32
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(1,0,0)
		shapePoint.material = mat
		pointMesh.mesh = shapePoint
		self.add_child(pointMesh)
		
		var rangeBarMesh: MeshInstance3D = _rangeBarMesh
		var rangeBarShape: BoxMesh = BoxMesh.new()
		rangeBarShape.size = Vector3(0.2, 0.2, rangeRadius * 2)
		var matBar: StandardMaterial3D = StandardMaterial3D.new()
		matBar.albedo_color = Color(0,0.2,1)
		rangeBarShape.material = matBar
		rangeBarMesh.mesh = rangeBarShape
		self.add_child(rangeBarMesh)
		
		var forwardMesh: MeshInstance3D = MeshInstance3D.new()
		var forwardShape: BoxMesh = BoxMesh.new()
		forwardShape.size = Vector3(2, 0.2, 0.2)
		var matForward: StandardMaterial3D = StandardMaterial3D.new()
		matForward.albedo_color = Color(0,1,0.4)
		forwardShape.material = matForward
		forwardMesh.mesh = forwardShape
		self.add_child(forwardMesh)
		forwardMesh.position = Vector3(1,0,0)
		

func _bind_to_previous_child():
	print("Attempting a bind to previous child of ", self.name)
	var children: Array[Node] = get_parent_node_3d().get_children()
	var newPredecessor: RacePathNode = null
	for i in range(children.size()):
		if children[i] == self: # equality by ref, not content
			if i == 0:
				print("ERROR: No previous child.")
				return
			
			newPredecessor = children[i-1]
			break
	if (newPredecessor == null):
		print("ERROR: No previous child found.")
	
	print("Found ", newPredecessor.name)
	newPredecessor.successor = self
	self.predecessor = newPredecessor
	print("Binding done.")
