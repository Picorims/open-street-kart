# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


## @abstract
## Class serving as an interface for input querying by the car.
## Can be extended for user input, AI input, etc.
class_name ACarBrain extends Node

var _forwardBackward: float = 0
var _leftRight: float = 0
var _driftActive: bool = false
var path: RacePath
var lastQueryInfo: RacePath.QueryInfo = RacePath.QueryInfo.new()
## Manually updated by the car force integration function.
var populatedLinVel: Vector3
## Manually updated by the car force integration function.
var populatedAngVel: Vector3

## @abstract
## Called at every force integration by the car physics engine.
## Use this function to update input variables that are queried by the
## car physics engine.
func tick(globalPos: Vector3, debugPos: Vector3, globalBasis: Basis, frontColliding: bool) -> void:
	push_error("ACarBrain: tick() is not implemented.")

func get_forward_backward_axis() -> float:
	return clampf(_forwardBackward, -1, 1)

func get_left_right_axis() -> float:
	return clampf(_leftRight, -1, 1)

func drift_input_active() -> bool:
	return _driftActive
