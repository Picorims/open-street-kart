# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

## Car brain for hooking user input to the car.
class_name UserBrain extends ACarBrain

@export var server: ServerManager

func _init(server_manager: ServerManager) -> void:
	assert(server_manager != null, "user brain: server manager is null.")
	server = server_manager
	server.get_rpc().s_on_receive_input_float.connect(func(k: RPC.InputEventFloatType, v: float):
		if k == RPC.InputEventFloatType.LEFT_RIGHT:
			_left_right = v
		elif k == RPC.InputEventFloatType.BACKWARD_FORWARD:
			_forward_backward = v
	)
	server.get_rpc().s_on_receive_input_bool.connect(func(k: RPC.InputEventBoolType, v: bool):
		if k == RPC.InputEventBoolType.DRIFT:
			_drift_active = v
	)

func tick(global_pos: Vector3, debug_pos: Vector3, global_basis: Basis, local_basis: Basis, front_colliding: bool, on_ground: bool):
	super (global_pos, debug_pos, global_basis, local_basis, front_colliding, on_ground)
