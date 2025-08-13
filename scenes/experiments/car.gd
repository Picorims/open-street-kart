# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


extends RigidBody3D

@export var MAX_STEER = 300
@export var ENGINE_POWER = 6000

func _physics_process(delta: float) -> void:
	var aim = get_global_transform_interpolated().basis
	# move the car left/right
	apply_torque(Vector3(0,1,0) * Input.get_axis("right", "left") * MAX_STEER)
	# steering = move_toward(steering, Input.get_axis("right", "left") * MAX_STEER, delta * 10)
	# move the car forward
	apply_force(-aim.z * Input.get_axis("forward", "backward") * ENGINE_POWER)
	# engine_force = Input.get_axis("backward", "forward") * ENGINE_POWER
