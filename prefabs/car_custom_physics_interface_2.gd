# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name CarCustomPhysics2 extends Node3D

@export var speedMultiplier: float = 1.0:
	set(v):
		speedMultiplier = v
		$CarRigidBody.speedMultiplier = v

@export var lastCheckpoint: Checkpoint = null:
	set(v):
		lastCheckpoint = v
		print("New checkpoint: ", v.name)
