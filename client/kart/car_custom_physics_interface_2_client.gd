# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name CarCustomPhysics2Client extends Node3D

const KART_REMOTE_NODE_NAME = "KartRemote"

@onready var _moving_item_receiver: MovingItemReceiver = $CarVisualBody/MovingItemReceiver
@onready var _car_visual_body: Node3D = $CarVisualBody

@export var kart_sync: KartSync

@export var drifting_effects: bool = false:
	set(v):
		drifting_effects = v
		$CarVisualBody/WheelBLGPUParticles3D.emitting = v
		$CarVisualBody/WheelBRGPUParticles3D.emitting = v

@export var speed_boost_effects: bool = false:
	set(v):
		speed_boost_effects = v
		$CarVisualBody/SpeedGPUParticles3D.emitting = v

@export var mode: Global.KartMode:
	set(v):
		mode = v
		_car_visual_body.mode = v
		
@export var path: RacePath:
	set(v):
		path = v
		_car_visual_body.path = v

@export var show_debug_arrows: bool:
	set(v):
		show_debug_arrows = v
		_car_visual_body.show_debug_arrows = v

@export var display_name: String:
	set(v):
		display_name = v
		$CarVisualBody/Label3D.text = v

@export var material: StandardMaterial3D:
	set(v):
		material = v
		var mesh: BoxMesh = $CarVisualBody/DebugFrame.mesh
		var new_mesh: BoxMesh = BoxMesh.new()
		new_mesh.size = mesh.size
		new_mesh.material = material
		$CarVisualBody/DebugFrame.mesh = new_mesh

@export var items_holder: Node3D:
	set(v):
		items_holder = v
		_car_visual_body.items_holder = v

@export var estimated_local_velocity: Vector3:
	get():
		return _moving_item_receiver.estimated_local_velocity
	set(v):
		pass
@export var server_velocity: Vector3:
	get():
		return _moving_item_receiver.server_velocity
	set(v):
		pass
@export var current_position: Vector3:
	get():
		return _car_visual_body.global_position
	set(v):
		pass
@export var last_server_timestamp: int:
	get():
		return _moving_item_receiver.last_timestamp
	set(v):
		pass
@export var going_backwards: bool:
	get():
		return _car_visual_body._going_backwards
	set(v):
		pass
@export var car_basis: Basis:
	get():
		return _car_visual_body.global_basis
	set(v):
		pass
@export var track_state: TrackStateClient
@export var network_id := -1:
	set(v):
		network_id = v
		_moving_item_receiver.network_id = v

func _ready() -> void:
	# /!\ Necessary for checkpoints to work!
	assert(has_node("CarVisualBody"), "Car rigid body must be a direct child of the root CarCustomPhysics node.")

func use_item(_item: PlayerItemSlotsState.SlotItem) -> void:
	#if item == PlayerItemSlotsState.SlotItem.SPEED_BOOST:
		#$CarVisualBody.apply_speed_boost_seconds(2.5)
	#if item == PlayerItemSlotsState.SlotItem.AIR_BOMB:
		#$CarVisualBody.launch_air_bomb()
	#TODO refactor multiplayer item visuals client
	pass

func spawn_kart_remote():
	assert(track_state != null, "car client interface: missing track state.")
	var remote := KartRemote.new()
	remote.client = track_state.track.client_manager
	remote.name = KART_REMOTE_NODE_NAME
	add_child(remote)
