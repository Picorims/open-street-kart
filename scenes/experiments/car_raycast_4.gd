# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


extends RigidBody3D

var _raycast_fl: RayCast3D;
var _raycast_fr: RayCast3D;
var _raycast_bl: RayCast3D;
var _raycast_br: RayCast3D;
var _raycast_ground_f: RayCast3D;
var _raycast_ground_b: RayCast3D;

@export var MAT_GROUND: StandardMaterial3D
@export var MAT_AIR: StandardMaterial3D
@export var MESH: MeshInstance3D

@export var MAX_STEER = 0.9;
@export var ENGINE_POWER = 30000;
@export var SPRING_FORCE = 1800;

func _ready():
	_raycast_bl = get_node("RayCast3D BL")
	_raycast_br = get_node("RayCast3D BR")
	_raycast_fl = get_node("RayCast3D FL")
	_raycast_fr = get_node("RayCast3D FR")
	_raycast_ground_f = get_node("RayCast3DGroundFront")
	_raycast_ground_b = get_node("RayCast3DGroundBack")
	

func _interpol_squared(x):
	return x*x
	
func _interpol_sqrt(x):
	return sqrt(x)
	
#func _get_ground_normal(x) -> Vector3:
	#if (
		#!_raycast_fl_4_ground.is_colliding() ||
		#!_raycast_bl_4_ground.is_colliding() ||
		#!_raycast_br_4_ground.is_colliding() ||
		#!_raycast_fr_4_ground.is_colliding()
	#):
		#return Vector3(0,0,0)
		#
	#var cross_1: Vector3 = _raycast_fl_4_ground.get_collision_point() - _raycast_br_4_ground.get_col

func _get_ground_normal() -> Vector3:
	if (_raycast_ground_b.is_colliding() && _raycast_ground_f.is_colliding()):
		return (_raycast_ground_b.get_collision_normal() + _raycast_ground_f.get_collision_normal()) / 2
	else:
		return Vector3(0,1,0)

func _apply_raycast_force(raycast: RayCast3D, ground_normal: Vector3):
	if (raycast.is_colliding()):
		var raycast_length = raycast.global_position.length()
		var collision_point: Vector3 = raycast.get_collision_point()
		var collision_distance: float = (raycast.global_position - collision_point).length()
		var distance_ratio: float = 1 - collision_distance / raycast_length
		# var force_direction: Vector3 = get_global_transform_interpolated().basis.y.normalized()
		var force_direction: Vector3 = ground_normal
		
		# interpolate force
		var force_to_apply: float = _interpol_squared(distance_ratio)
		var reverse_force_to_apply: float = - _interpol_squared(distance_ratio)
		
		# nerf based on normal to ground
		var normal_to_ground = raycast.get_collision_normal().normalized()
		var alignedCoef = max(normal_to_ground.dot(force_direction), 0)
		# interpolate coef
		alignedCoef = _interpol_squared(alignedCoef)
		
		force_to_apply *= SPRING_FORCE
		reverse_force_to_apply *= SPRING_FORCE
		force_to_apply *= alignedCoef
		reverse_force_to_apply *= alignedCoef
		var gravity_limit: float = get_gravity().length() * mass/4 # + distance_ratio
		# var velocity_limit: float = linear_velocity.length()
		# var force_limit: float = max(velocity_limit, gravity_limit)
		force_to_apply = min(force_to_apply, gravity_limit) # cap force
		reverse_force_to_apply = max(reverse_force_to_apply, -gravity_limit)
		var final_force: Vector3 = force_direction * (force_to_apply + reverse_force_to_apply);
		
		apply_force(final_force, raycast.global_position)
		DebugDraw3D.draw_arrow(raycast.global_position, raycast.global_position + final_force*0.01, Color.BLUE, 0.1, true)
	
	
func _physics_process(_delta: float) -> void:
	# CAR WHEEL SPRINGS (just raycasts making the collider float)
	# see: https://www.youtube.com/watch?v=LG1CtlFRmpU
	# see: https://www.youtube.com/watch?v=CBgtU9FCEh8
	var ground_normal = _get_ground_normal()
	_apply_raycast_force(_raycast_fl, ground_normal)
	_apply_raycast_force(_raycast_fr, ground_normal)
	_apply_raycast_force(_raycast_bl, ground_normal)
	_apply_raycast_force(_raycast_br, ground_normal)
	
	# CAR MOVEMENT (if on ground)
	if (_raycast_ground_b.is_colliding() && _raycast_ground_f.is_colliding()):
		# var aim = get_global_transform_interpolated().basis
		# var forward_force: Vector3 = -aim.z
		# acceleration vector is projected to ground
		var ground_forward: Vector3 = _raycast_ground_b.get_collision_point() - _raycast_ground_f.get_collision_point()
		ground_forward = ground_forward.normalized()
		var accel_brake = ground_forward * Input.get_axis("forward", "backward")
		print(accel_brake, ground_forward, Input.get_axis("forward", "backward"))
		
		# move the car left/right
		apply_torque(Vector3(0,1,0) * Input.get_axis("right", "left") * MAX_STEER)
		# move the car forward
		apply_force(accel_brake * ENGINE_POWER)
		
		# friction
		# linear_velocity *= 0.8
		MESH.material_override = MAT_GROUND
	else:
		MESH.material_override = MAT_AIR
		

	
