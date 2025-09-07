# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


## @abstract
## Class serving as an interface for input querying by the car.
## Can be extended for user input, AI input, etc.
class_name ACarBrain extends Node

var _forward_backward: float = 0
var _left_right: float = 0
var _drift_active: bool = false
var path: RacePath
var last_query_info: RacePath.QueryInfo = RacePath.QueryInfo.new()
## Manually updated by the car force integration function.
var populated_lin_vel: Vector3
## Manually updated by the car force integration function.
var populated_ang_vel: Vector3
var show_debug_arrows: bool = false

## Called at every force integration by the car physics engine.
## Use this function to update input variables that are queried by the
## car physics engine.
func tick(global_pos: Vector3, _debug_pos: Vector3, _global_basis: Basis, _local_basis: Basis, _front_colliding: bool, _on_ground: bool) -> void:
	if (path == null):
		return
	var q: RacePath.QueryInfo = path.query_info(global_pos)
	last_query_info = q


func get_forward_backward_axis() -> float:
	return clampf(_forward_backward, -1, 1)

func get_left_right_axis() -> float:
	return clampf(_left_right, -1, 1)

func drift_input_active() -> bool:
	return _drift_active
