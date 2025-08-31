# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name CarCustomPhysics2 extends Node3D

enum CarMode {
	UNSET,
	USER,
	BOT,
}

@export var speedMultiplier: float = 1.0:
	set(v):
		speedMultiplier = v
		$CarRigidBody.speedMultiplier = v
@export var maxSpeedMetersPerSecond: float:
	set(v):
		maxSpeedMetersPerSecond = v
		$CarRigidBody.maxSpeedMetersPerSecond = v
@export var maxSpeedOutOfBoundsMetersPerSecond: float:
	set(v):
		maxSpeedOutOfBoundsMetersPerSecond = v
		$CarRigidBody.maxSpeedOutOfBoundsMetersPerSecond = v

@export var lastCheckpoint: TrackCheckpoint = null:
	set(v):
		lastCheckpoint = v
		if (v != null):
			print("New checkpoint: ", v.name)
		else:
			print("Checkpoint removed.")

@export var driftingEffects: bool = false:
	set(v):
		driftingEffects = v
		$CarRigidBody/WheelBLGPUParticles3D.emitting = v
		$CarRigidBody/WheelBRGPUParticles3D.emitting = v

@export var mode: CarMode:
	set(v):
		mode = v
		$CarRigidBody.mode = v
		
@export var path: RacePath:
	set(v):
		path = v
		$CarRigidBody.path = v

@export var showDebugArrows: bool:
	set(v):
		showDebugArrows = v
		$CarRigidBody.showDebugArrows = v

@export var displayName: String:
	set(v):
		displayName = v
		$CarRigidBody/Label3D.text = v

@export var material: StandardMaterial3D:
	set(v):
		material = v
		var mesh: BoxMesh = $CarRigidBody/DebugFrame.mesh
		var newMesh: BoxMesh = BoxMesh.new()
		newMesh.size = mesh.size
		newMesh.material = material
		$CarRigidBody/DebugFrame.mesh = newMesh

func get_race_path_offset() -> float:
	return $CarRigidBody.get_race_path_offset()

func respawn():
	print("Respawning car...")
	var rb: RigidBody3D = $CarRigidBody
	rb.freeze = true
	if (lastCheckpoint == null):
		print("ERROR: player never encountered a checkpoint, cannot respawn!")
		return
	rb.global_position = lastCheckpoint.get_respawn_global_pos()
	var newBasis: Basis = Basis(Vector3.UP, deg_to_rad(lastCheckpoint.lookTowardsDegrees)).orthonormalized()
	$CarRigidBody.force_basis_on_next_physics_frame(newBasis)
	rb.freeze = false
