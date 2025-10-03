# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
class_name Track extends Node3D

func _ready() -> void:
	# track linter
	assert($Sky3D != null, "Missing Sky3D.")
	assert($PlayerSpawner != null, "No player spawner.")
	assert($MapDataLoader != null, "No map data loader.")
	assert($ProceduralDataHolder != null, "No procedural data holder.")
	assert($Checkpoints != null, "No checkpoint.")
	assert($Checkpoints/LoopCheckpoints != null, "No loop checkpoints.")
	assert($Checkpoints/TrackCheckpoints != null, "No track checkpoints.")
	assert($Checkpoints/RacePath != null, "No race path.")
	assert($TrackState != null, "No track state.")
	assert($Jumps != null, "No jumps root.")
	assert($Walls != null, "No walls root.")
	assert($Arrows != null, "No arrows root.")
	assert($TrackState.is_in_group("track_state"), "missing track_state group on TrackState")

func launch(mode: TrackState.GameMode, speed: TrackState.SpeedMode):
	var state: TrackState = $TrackState
	state.init(mode, speed)

## @abstract
## Contains GDScript logic to apply manual mutations (such as transforms)
## to adjust elements (ex: bench orientation). This is much better than
## manually mutating the scene which may be overriden by reloading data.
## The workflow is as follows: do the modification in the scene until
## satisfied, then reconstruct those modifications through GDScript below.
## It is best to leave a comment to describe the intent, and prefer absolute
## over relative mutations to ease maintenance.
func apply_osm_mutations_action(root: Node3D, generator: OSMDataGenerator):
	push_error("apply_osm_mutations_action not implemented.")
