# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
@icon("Area3D")
class_name TrackCheckpoint extends Node3D

## the box is always centered.
@export var boxSize: Vector3 = Vector3(5,5,5):
	set(v):
		boxSize = v
		_update_box()

@export var lookTowardsDegrees: int = 0

## in local coords
@export var respawnPoint: Vector3 = Vector3()
@export var debugDrawBoxColor: Color = Color(0,0.8,0.3)
@export var debugDrawArrowColor: Color = Color(0,0.5,0.1)
@export var debugShapeFillColor: Color = Color(0.0, 0.792, 0.416, 0.42):
	set (v):
		debugShapeFillColor = v
		assert(_shape != null, "ERROR: shape not initialized.")
		_collider.debug_color = v

signal car_entered(car: CarCustomPhysics2)

var _area: Area3D = Area3D.new()
var _collider: CollisionShape3D = CollisionShape3D.new()
var _shape: BoxShape3D = BoxShape3D.new()

func _ready() -> void:
	self.add_child(_area)
	_area.monitoring = true
	_area.add_child(_collider)
	_collider.debug_color = debugShapeFillColor
	_collider.debug_fill = true
	_collider.shape = _shape
	
	_update_box()
	
	_area.body_entered.connect(func (body: Node3D):
		var car: Node3D = body.get_parent_node_3d()
		if (car != null && is_instance_of(car, CarCustomPhysics2)):
			car.lastCheckpoint = self
			car_entered.emit(car)
	)
	_area.monitoring = true

func _process(delta: float) -> void:
	DebugDraw3D.draw_box(self.position, self.basis.get_rotation_quaternion(), boxSize, debugDrawBoxColor, true)
	var arrowFrom: Vector3 = get_respawn_global_pos()
	var arrowTo: Vector3 = arrowFrom + Vector3(5,0,0).rotated(Vector3.UP, deg_to_rad(lookTowardsDegrees))
	DebugDraw3D.draw_arrow(arrowFrom, arrowTo, debugDrawArrowColor, 0.3)

func _update_box():
	assert(_shape != null, "ERROR: shape not initialized.")
	_shape.size = boxSize
	
	
func get_respawn_global_pos() -> Vector3:
	return self.global_position + respawnPoint
