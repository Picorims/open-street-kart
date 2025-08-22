# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
class_name Wheel extends FreezeManagedRigidBody3D

@export var radius: float:
	set(v):
		radius = v
		_shape.radius = v
		_shapeMesh.top_radius = v
		_shapeMesh.bottom_radius = v
		
@export var height: float:
	set(v):
		height = v
		_shape.height = v
		_shapeMesh.height = v
		
@export var color: Color:
	set(v):
		color = v
		_mat.albedo_color = v

var _shape: CylinderShape3D = CylinderShape3D.new()
var _shapeMesh: CylinderMesh = CylinderMesh.new()
var _mat: StandardMaterial3D = StandardMaterial3D.new()

func _ready() -> void:
	freeze = true
	mass = 100
	var collider: CollisionShape3D = CollisionShape3D.new()
	add_child(collider)
	var shape: CylinderShape3D = CylinderShape3D.new()
	collider.shape = _shape
	var mesh: MeshInstance3D = MeshInstance3D.new()
	add_child(mesh)
	_shapeMesh.radial_segments = 16
	mesh.mesh = _shapeMesh
	_shapeMesh.material = _mat
	timeout.connect(func():
		# when emitted, necessarily not frozen.
		
		# force the wheel to fall on the side so that
		# it freezes by itself by stopping moving.
		center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = Vector3(0, -3 * height, 0)
	)
	freezeChanged.connect(func(frozen: bool):
		center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_AUTO
	)
