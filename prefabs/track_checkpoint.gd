# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
@icon("Area3D")
class_name TrackCheckpoint extends Node3D

## the box is always centered.
@export var box_size: Vector3 = Vector3(5, 5, 5):
	set(v):
		box_size = v
		_update_box()

@export var look_towards_degrees: int = 0

## in local coords
@export var respawn_point: Vector3 = Vector3()
@export var debug_draw_box_color: Color = Color(0, 0.8, 0.3)
@export var debug_draw_arrow_color: Color = Color(0, 0.5, 0.1)
@export var debug_shape_fill_color: Color = Color(0.0, 0.792, 0.416, 0.42):
	set(v):
		debug_shape_fill_color = v
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
	_collider.debug_color = debug_shape_fill_color
	_collider.debug_fill = true
	_collider.shape = _shape
	
	_update_box()
	
	_area.body_entered.connect(func(body: Node3D):
		var car: Node3D = body.get_parent_node_3d()
		if (car != null and is_instance_of(car, CarCustomPhysics2)):
			car.last_checkpoint = self
			car_entered.emit(car)
	)
	_area.monitoring = true

func _process(_delta: float) -> void:
	DebugDraw3D.draw_box(self.position, self.basis.get_rotation_quaternion(), box_size, debug_draw_box_color, true)
	var arrow_from: Vector3 = get_respawn_global_pos()
	var arrow_to: Vector3 = arrow_from + Vector3(5, 0, 0).rotated(Vector3.UP, deg_to_rad(look_towards_degrees))
	DebugDraw3D.draw_arrow(arrow_from, arrow_to, debug_draw_arrow_color, 0.3)

func _update_box():
	assert(_shape != null, "ERROR: shape not initialized.")
	_shape.size = box_size
	
	
func get_respawn_global_pos() -> Vector3:
	return self.global_position + respawn_point
