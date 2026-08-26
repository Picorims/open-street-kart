# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


## Handles countdown state and its evolution. It should not contain any other game logic.
class_name CountdownStateMachine extends Node

signal go

enum CountdownState {
	THREE = 3,
	TWO = 2,
	ONE = 1,
	GO = 0,
	IDLE = -1,
}

var running := false
var _countdown_elapsed: float = 0
var model: TrackStateModel

## Starts the countdown before the race start.
func countdown():
	assert(model != null, "Cannot countdown if model is not defined.")
	_countdown_elapsed = 0
	model.countdown_state = CountdownState.IDLE
	model.in_countdown = true

func _process(delta: float) -> void:
	if model != null and model.in_countdown:
		_countdown_elapsed += delta
		
		if (model.countdown_state == CountdownState.IDLE and _countdown_elapsed <= 1): # initialize
			print("3...")
			model.countdown_state = CountdownState.THREE
		elif (model.countdown_state == CountdownState.THREE and _countdown_elapsed > 1):
			print("2...")
			model.countdown_state = CountdownState.TWO
		elif (model.countdown_state == CountdownState.TWO and _countdown_elapsed > 2):
			print("1...")
			model.countdown_state = CountdownState.ONE
		elif (model.countdown_state == CountdownState.ONE and _countdown_elapsed > 3):
			print("GO!")
			model.countdown_state = CountdownState.GO
			go.emit()
