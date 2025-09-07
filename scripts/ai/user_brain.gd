# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

## Car brain for hooking user input to the car.
class_name UserBrain extends ACarBrain

func tick(global_pos: Vector3, debug_pos: Vector3, global_basis: Basis, local_basis: Basis, front_colliding: bool, on_ground: bool):
	super (global_pos, debug_pos, global_basis, local_basis, front_colliding, on_ground)
	_drift_active = Input.is_action_pressed("drift")
	_forward_backward = Input.get_axis("backward", "forward")
	_left_right = Input.get_axis("left", "right")
