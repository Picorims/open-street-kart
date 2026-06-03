# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# @tool
## `RigidBody3D` with finer freeze control for performance improvement.
## Has exclusivity over Physics3D Layer 6
class_name FreezeManagedRigidBody3D extends RigidBody3D

signal freezeChanged(freeze: bool)
## emitted after timeout ellapsed since unfrozen, if effectively still unfrozen.
signal timeout

## Use this instead of `freeze` for the signal and other logic to work.
@export var managed_freeze: bool:
	get:
		return freeze
	set(v):
		managed_freeze = v
		# caching and restoring global transform to avoid
		# a reset of the position/rotation when changing freeze state.
		var temp_pos: Vector3 = global_position
		var temp_rot: Basis = global_transform.basis
		freeze = v
		global_position = temp_pos
		global_transform.basis = temp_rot
		freezeChanged.emit(v)
		if (not freeze):
			_last_unfreeze_ms = Time.get_ticks_msec()
		_timeout_emitted = false

## Timeout before the timeout signal is emitted.
@export var timeout_ms: float = 15_000
## Minimum timeout before freezing can happen again.
@export var min_timeout_ms: float = 1_000

## Together with the `freeze_not_moving_threshold`, freeze if the linear velocity
## is below this value
@export var freeze_if_not_moving: bool = true

## If `freeze_if_not_moving` and linear velocity is below this value, freeze.
@export var freeze_not_moving_threshold: float = 0.05:
	set(v):
		freeze_not_moving_threshold = v
		_freeze_not_moving_threshold_squared = v * v

var _last_unfreeze_ms: float = 0
var _freeze_not_moving_threshold_squared: float = freeze_not_moving_threshold * freeze_not_moving_threshold
var _timeout_emitted: bool = false

func _ready() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	managed_freeze = true
	
	var track_state: TrackState = get_tree().get_first_node_in_group("track_state")
	assert(track_state != null, "track state not found.")
	track_state.get_track_region_manager().register_node(self)

var _elapsed: float = 0
func _physics_process(delta: float) -> void:
	if (not can_process()):
		return
	if (not get_collision_layer_value(6)):
		set_collision_layer_value(6, true)
	
	# avoid running too often
	_elapsed += delta
	if (_elapsed < 0.1):
		return
	else:
		_elapsed = 0
	
	var now_ms: float = Time.get_ticks_msec()
	var unfrozen_elapsed: float = now_ms - _last_unfreeze_ms
	if (unfrozen_elapsed > timeout_ms and not freeze and not _timeout_emitted):
		timeout.emit()
	if (linear_velocity.length_squared() < _freeze_not_moving_threshold_squared and not freeze) and unfrozen_elapsed > min_timeout_ms:
		managed_freeze = true
