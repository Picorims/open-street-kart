# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


@tool
class_name SnapToGroundRayCast3D extends RayCast3D

## Node that will be moved
@export var target: Node3D
## Offset from the ground
@export var offset: float = 0
## If true, object is rotated according to the collision normal
@export var alignToNormal: bool = true
## when snapped happened
signal snapped_target

var _initialized = false

var _ellapsed: float = 0
func _physics_process(delta: float) -> void:
	if (target == null):
		return
	
	if (is_colliding()):
		self.debug_shape_custom_color = Color(1,0,0, 0.3)
		if (Engine.is_editor_hint()): DebugDraw3D.draw_line(self.global_position, self.get_collision_point(), Color(1,0,0,1))
		var distance = self.get_collision_point().distance_to(self.global_position)
		#print("{0} before: {1}, distance: {2}, offset: {3}".format([self.name, target.global_position.y, distance, offset]))
		target.global_position.y -= distance + offset
		#print(self.name, " after: ", target.global_position.y)
		
		if (alignToNormal):
			# align to normal, see: https://kidscancode.org/godot_recipes/4.x/3d/3d_align_surface/index.html
			# and: https://forum.godotengine.org/t/need-help-with-aligning-player-rotation-to-ground-normal/49907
			var normal = get_collision_normal()
			target.basis.y = normal
			target.basis.x = -target.basis.z.cross(normal)
			target.basis = target.basis.orthonormalized()
		
		snapped_target.emit()
		self.enabled = false
		self.queue_free()
	else:
		self.debug_shape_custom_color = Color(1,0,1, 0.3)
		# print("pas boom")
		#if (Engine.is_editor_hint()): DebugDraw3D.draw_line(self.global_position, self.global_position + self.target_position, Color(1,0,1,1))
	
	_ellapsed += delta
	if (_ellapsed > 1):
		_ellapsed = 0
		# force snapping in editor
		force_raycast_update()
