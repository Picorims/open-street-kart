# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
@abstract
class_name Track extends Node3D

enum TrackInstance {
	SERVER,
	CLIENT,
	UNSET,
}

@export var instance: TrackInstance = TrackInstance.UNSET

@onready var _track_state_spawner: MultiplayerSpawner = $TrackStateSpawner
@onready var _track_state_mp_spawner_container: Node = $TrackStateMPSpawnerContainer
@onready var _loop_checkpoints: Node3D = $Checkpoints/LoopCheckpoints
@onready var _player_spawner: PlayerSpawner = $PlayerSpawner
@onready var _procedural_data_holder: Node3D = %ProceduralDataHolder
@onready var _track_state_client: TrackStateClient = $TrackStateClient
@onready var _track_state_server: TrackStateServer = $TrackStateServer


var is_in_game_running: bool = false


func _ready() -> void:
	# track linter
	#assert($Sky3D != null, "Missing Sky3D.")
	assert(instance != TrackInstance.UNSET, "Track instance not set.")
	assert($PlayerSpawner != null, "No player spawner.")
	assert($MapDataLoader != null, "No map data loader.")
	assert($ProceduralDataHolder != null, "No procedural data holder.")
	assert($Checkpoints != null, "No checkpoint.")
	assert($Checkpoints/LoopCheckpoints != null, "No loop checkpoints.")
	assert($Checkpoints/TrackCheckpoints != null, "No track checkpoints.")
	assert($Checkpoints/RacePath != null, "No race path.")
	assert($Jumps != null, "No jumps root.")
	assert($Walls != null, "No walls root.")
	assert($Arrows != null, "No arrows root.")
	assert($ItemsHolder != null, "No items holder root.")
	assert($TrackStateSpawner != null, "No track state spawner to sync state.")
## Entry point of a track, initiates and play the track.
func launch(mode: TrackStateModel.GameMode, speed: TrackStateModel.SpeedMode, cars_count: int):
	var _buildings = get_tree().get_nodes_in_group("buildings")
	var building_mode: Building.Mode = Building.Mode.EDITOR
	if instance == TrackInstance.SERVER:
		building_mode = Building.Mode.SERVER
	elif instance == TrackInstance.CLIENT:
		building_mode = Building.Mode.CLIENT
	for n: Building in _buildings:
		n.mode = building_mode
		n._build_building()
		#TODO restore if needed
		#get_track_region_manager().register_node(n)

	if instance == TrackInstance.CLIENT:
		$Checkpoints.queue_free()
		_track_state_server.queue_free()
	if instance == TrackInstance.SERVER:
		$Arrows.queue_free()
		_track_state_client.queue_free()
		_track_state_spawner.spawn_function = _spawn_track_state
		_track_state_spawner.spawn()
		
		_track_state_server.track = self
		_track_state_server.model = _track_state_mp_spawner_container.get_node("TrackStateModel")
		_track_state_server.loop_checkpoints.assign(_loop_checkpoints)
		_track_state_server.player_spawner = _player_spawner
		_track_state_server.procedural_data_holder = _procedural_data_holder
		_track_state_server.init(mode, speed, cars_count)


func _spawn_track_state(_data):
	var state: TrackStateModel = preload("res://common/track/track_state_model.tscn").instantiate()
	var loop_checkpoints := _loop_checkpoints.get_children()
	for c in loop_checkpoints:
		if is_instance_of(c, LoopCheckpoint):
			continue
		else:
			push_error(c, " is not a LoopCheckpoint.")
	# server has authority on spawned node by default.
	return state

## Contains GDScript logic to apply manual mutations (such as transforms)
## to adjust elements (ex: bench orientation). This is much better than
## manually mutating the scene which may be overriden by reloading data.
## The workflow is as follows: do the modification in the scene until
## satisfied, then reconstruct those modifications through GDScript below.
## It is best to leave a comment to describe the intent, and prefer absolute
## over relative mutations to ease maintenance.
@abstract
func apply_osm_mutations_action(root: Node3D, generator: OSMDataGenerator)
