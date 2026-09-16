# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name CarCustomPhysics2Client extends Node3D

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

@export var current_velocity: Vector3:
	get():
		return $CarRigidBody.current_velocity
	set(v):
		pass
@export var current_position: Vector3:
	get():
		return $CarRigidBody.current_position
	set(v):
		pass
@export var going_backwards: bool:
	get():
		return $CarRigidBody._going_backwards
	set(v):
		pass
@export var car_basis: Basis:
	get():
		return $CarRigidBody.global_basis
	set(v):
		pass

func _ready() -> void:
	# /!\ Necessary for checkpoints to work!
	assert(has_node("CarRigidBody"), "Car rigid body must be a direct child of the root CarCustomPhysics node.")

func use_item(item: PlayerItemSlotsState.SlotItem) -> void:
	#if item == PlayerItemSlotsState.SlotItem.SPEED_BOOST:
		#$CarRigidBody.apply_speed_boost_seconds(2.5)
	#if item == PlayerItemSlotsState.SlotItem.AIR_BOMB:
		#$CarRigidBody.launch_air_bomb()
	#TODO refactor multiplayer item visuals client
	pass
