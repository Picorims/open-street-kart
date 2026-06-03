# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name CarCustomPhysics2 extends Node3D

enum CarMode {
	UNSET,
	USER,
	BOT,
}

@export var speed_multiplier: float = 1.0:
	set(v):
		speed_multiplier = v
		$CarRigidBody.speed_multiplier = v
@export var max_speed_meters_per_second: float:
	set(v):
		max_speed_meters_per_second = v
		$CarRigidBody.max_speed_meters_per_second = v
@export var max_speed_out_of_bounds_meters_per_second: float:
	set(v):
		max_speed_out_of_bounds_meters_per_second = v
		$CarRigidBody.max_speed_out_of_bounds_meters_per_second = v

@export var last_checkpoint: TrackCheckpoint = null:
	set(v):
		last_checkpoint = v
		if (v != null):
			print("New checkpoint: ", v.name)
		else:
			print("Checkpoint removed.")

@export var drifting_effects: bool = false:
	set(v):
		drifting_effects = v
		$CarRigidBody/WheelBLGPUParticles3D.emitting = v
		$CarRigidBody/WheelBRGPUParticles3D.emitting = v

@export var speed_boost_effects: bool = false:
	set(v):
		speed_boost_effects = v
		$CarRigidBody/SpeedGPUParticles3D.emitting = v

@export var mode: CarMode:
	set(v):
		mode = v
		$CarRigidBody.mode = v
		
@export var path: RacePath:
	set(v):
		path = v
		$CarRigidBody.path = v

@export var show_debug_arrows: bool:
	set(v):
		show_debug_arrows = v
		$CarRigidBody.show_debug_arrows = v

@export var display_name: String:
	set(v):
		display_name = v
		$CarRigidBody/Label3D.text = v

@export var material: StandardMaterial3D:
	set(v):
		material = v
		var mesh: BoxMesh = $CarRigidBody/DebugFrame.mesh
		var new_mesh: BoxMesh = BoxMesh.new()
		new_mesh.size = mesh.size
		new_mesh.material = material
		$CarRigidBody/DebugFrame.mesh = new_mesh

@export var items_holder: Node3D:
	set(v):
		items_holder = v
		$CarRigidBody.items_holder = v

func _ready() -> void:
	# /!\ Necessary for checkpoints to work!
	assert(has_node("CarRigidBody"), "Car rigid body must be a direct child of the root CarCustomPhysics node.")

func get_race_path_offset() -> float:
	return $CarRigidBody.get_race_path_offset()

func respawn():
	print("Respawning car...")
	var rb: RigidBody3D = $CarRigidBody
	rb.freeze = true
	if (last_checkpoint == null):
		print("ERROR: player never encountered a checkpoint, cannot respawn!")
		return
	rb.global_position = last_checkpoint.get_respawn_global_pos()
	var new_basis: Basis = Basis(Vector3.UP, deg_to_rad(last_checkpoint.look_towards_degrees)).orthonormalized()
	$CarRigidBody.force_basis_on_next_physics_frame(new_basis)
	$CarRigidBody.clear_speed_boost()
	rb.freeze = false

func use_item(item: PlayerItemSlotsState.SlotItem) -> void:
	if item == PlayerItemSlotsState.SlotItem.SPEED_BOOST:
		$CarRigidBody.apply_speed_boost_seconds(2.5)
	if item == PlayerItemSlotsState.SlotItem.AIR_BOMB:
		$CarRigidBody.launch_air_bomb()
	pass
