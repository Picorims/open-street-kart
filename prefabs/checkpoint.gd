# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
class_name Checkpoint extends Node3D

## the box is always centered.
@export var boxSize: Vector3 = Vector3(5,5,5):
	set(v):
		boxSize = v
		_update_box()

@export var lookTowardsDegrees: int = 0

## in local coords
@export var respawnPoint: Vector3 = Vector3()

func _ready() -> void:
	_update_box()
	var area: Area3D = $Area3D
	area.monitoring = true
	area.body_entered.connect(func (body: Node3D):
		var car: Node3D = body.get_parent_node_3d()
		if (car != null && is_instance_of(car, CarCustomPhysics2)):
			car.lastCheckpoint = self
			
	)

func _process(delta: float) -> void:
	DebugDraw3D.draw_box(self.position, self.basis.get_rotation_quaternion(), boxSize, Color(0,0.8,0.3), true)
	var arrowFrom: Vector3 = get_respawn_global_pos()
	var arrowTo: Vector3 = arrowFrom + Vector3(5,0,0).rotated(Vector3.UP, deg_to_rad(lookTowardsDegrees))
	DebugDraw3D.draw_arrow(arrowFrom, arrowTo, Color(0,0.5,0.1), 0.3)

func _update_box():
	var collShapeNode: CollisionShape3D = $"Area3D/CollisionShape3D"
	if (collShapeNode == null):
		print("ERROR: collision shape undefined, this should not happen!")
		return
	var shape: BoxShape3D = collShapeNode.shape
	shape.size = boxSize
	
	
func get_respawn_global_pos() -> Vector3:
	return self.global_position + respawnPoint
