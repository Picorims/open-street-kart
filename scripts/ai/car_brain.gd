# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


## @abstract
## Class serving as an interface for input querying by the car.
## Can be extended for user input, AI input, etc.
class_name ACarBrain extends Node

## @abstract
func get_forward_backward_axis() -> float:
	push_error("ACarBrain: get_forward_backward_axis() is not implemented.")
	return 0

## @abstract	
func get_left_right_axis() -> float:
	push_error("ACarBrain: get_left_right_axis() is not implemented.")
	return 0

## @abstract
func drift_input_active() -> bool:
	push_error("ACarBrain: drift_input_active() is not implemented.")
	return false
