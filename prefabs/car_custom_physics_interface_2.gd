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
		if (v != null):
			print("New checkpoint: ", v.name)
		else:
			print("Checkpoint removed.")

func respawn():
	print("Respawning car...")
	var rb: RigidBody3D = $CarRigidBody
	rb.freeze = true
	rb.global_position = lastCheckpoint.get_respawn_global_pos()
	var newBasis: Basis = basis.rotated(Vector3.UP, deg_to_rad(lastCheckpoint.lookTowardsDegrees)).orthonormalized()
	$CarRigidBody.force_basis_on_next_physics_frame(newBasis)
	rb.freeze = false
