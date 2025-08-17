# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

## Car brain for hooking user input to the car.
class_name UserBrain extends ACarBrain

func tick(globalPos: Vector3, debugPos: Vector3, globalBasis: Basis):
	_driftActive = Input.is_action_pressed("drift")
	_forwardBackward = Input.get_axis("backward", "forward")
	_leftRight = Input.get_axis("left", "right")
